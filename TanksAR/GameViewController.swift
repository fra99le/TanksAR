//
//  GameViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

struct UserConfig {
    var scaleFactor: Float
    var rotation: Float
    var tank: SCNNode?
}

class GameViewController: UIViewController, ARSCNViewDelegate, CAAnimationDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var boardPlaced = false
    var boardSize: Float = 1.0
    var boardScaleFactor: Float = 1.0
    var candidatePlanes: [SCNNode] = []
    var board = SCNNode()
    var gameModel = GameModel()
    var tankNodes: [SCNNode] = []
    var shellNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    var explosionNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    let timeScaling = 3
    let numPerSide = 50
    var boardBlocks: [[SCNNode]] = []
    var dropBlocks: [SCNNode] = []
    var users: [UserConfig] = []
    var numHumans: Int = 0
    var numAIs: Int = 0
    var numRounds: Int = 0
    var roundChanged: Bool = false
    var gameOver = false
    
    @IBOutlet var tapToSelectLabel: UILabel!
    @IBOutlet var fireButton: UIButton!
    @IBOutlet var powerSlider: UISlider!
    @IBOutlet var powerLabel: UILabel!
    @IBOutlet weak var hudStackView: UIStackView!
    
    @IBOutlet weak var azimuthLabel: UILabel!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var velocityLabel: UILabel!
    @IBOutlet weak var weaponLabel: UILabel!    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // create the game board

        // start a game
        NSLog("\(#function) starting \(numRounds) round game.")
        gameModel.startGame(numPlayers: numHumans, numAIs: numAIs, rounds: numRounds)
        addBoard()
        users = [UserConfig](repeating: UserConfig(scaleFactor: 1.0, rotation: 0.0, tank: nil),
                             count: gameModel.board.players.count)
        addTanks()
        mapImage.image = gameModel.board.surface.asUIImage()

        unplaceBoard()
        
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Enable horizontal plane detection
        configuration.planeDetection = [.horizontal]

        // cause board placement to occur when view reappears
        // this causes problems with the weapons view
        //unplaceBoard()
        //updateUI()
        
        updateHUD()

        placeBoardGesture.require(toFail: backupPlaceBoardGesture)
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // cause board placement to occur when view reappears
        //unplaceBoard()

        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard !boardPlaced else { return }
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        for node in node.childNodes {
            node.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
            if let plane = node.geometry as? SCNPlane {
                plane.width = CGFloat(planeAnchor.extent.x)
                plane.height = CGFloat(planeAnchor.extent.z)
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard !boardPlaced else { return }
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        let floor = candidatePlane(planeAnchor)
        node.addChildNode(floor)
        candidatePlanes.append(floor)
    }

    func candidatePlane(_ planeAnchor: ARPlaneAnchor) -> SCNNode {
        let node = SCNNode()
        
        NSLog("plane extents are \(planeAnchor.extent.x),\(planeAnchor.extent.z).")
        let geometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        node.geometry = geometry
        
        node.eulerAngles.x = -Float.pi / 2
        node.opacity = 0.25
        
        return node
    }

    // MARK: - Gesture Regcognizers
    @IBOutlet var placeBoardGesture: UITapGestureRecognizer!
    @IBAction func screenTapped(_ sender: UIGestureRecognizer) {
        let touchLocation = sender.location(in: sceneView)
        NSLog("Screen tapped at \(touchLocation)")
        let hitTestResult = sceneView.hitTest(touchLocation, types: [.existingPlaneUsingGeometry])
        
        for result in hitTestResult {
            if !boardPlaced {
                if (result.anchor as? ARPlaneAnchor) != nil {
                    placeBoard(result)
                    updateUI()
                    break
                }
            } else {
                NSLog("Board already placed")
            }
        }
    }

    @IBOutlet var backupPlaceBoardGesture: UITapGestureRecognizer!
    @IBAction func screenDoubleTapped(_ sender: UIGestureRecognizer) {
        let touchLocation = sender.location(in: sceneView)
        NSLog("Screen double tapped at \(touchLocation)")

        let position = SCNVector3(0, -0.5, -2.0)
        let scaleFactor = 1.0 / Float(gameModel.board.boardSize)
        placeBoard(atLocation: position, withScaleFactor: scaleFactor)
    }
    

    
    @IBOutlet var screenDraggingGesture: UIPanGestureRecognizer!
    @IBAction func screenDragged(_ sender: UIGestureRecognizer) {
        guard let gesture = sender as? UIPanGestureRecognizer else { return }
        guard tankNodes.count > 0 else { return }
        
        //NSLog("Screen dragged \(gesture).")
        //NSLog("velocity: \(gesture.velocity(in: nil)), translation: \(gesture.translation(in: nil))")
        // determine player
        let player = gameModel.board.currentPlayer
        let tankNode = tankNodes[player]
        
        // get tank aiming values from model
        let tank = gameModel.getTank(forPlayer: player)
        let currAzimuth = tank.azimuth
        let currAltitude = tank.altitude
        //NSLog("currAzimuth: \(currAzimuth), currAltitude: \(currAltitude)")

        // update values
        let translation = gesture.translation(in: nil)
        let newAzimuth = currAzimuth + Float(translation.x)
        let newAltitude = currAltitude - Float(translation.y)

        // find/adjust tank model's aiming
        guard let turretNode = tankNode.childNode(withName: "turret", recursively: true) else { return }
        guard let hingeNode = tankNode.childNode(withName: "barrelHinge", recursively: true) else { return }
        turretNode.eulerAngles.y = newAzimuth * (Float.pi/180)
        hingeNode.eulerAngles.x = newAltitude * (Float.pi/180)
        //NSLog("newAzimuth: \(newAzimuth), newAltitude: \(newAltitude)")
        
        if gesture.state == .ended {
            gameModel.setTankAim(azimuth: newAzimuth, altitude: newAltitude)
            updateHUD()
        } else {
            // hack to allow realtime updating of HUD
            gameModel.setTankAim(azimuth: newAzimuth, altitude: newAltitude)
            updateHUD()
            gameModel.setTankAim(azimuth: currAzimuth, altitude: currAltitude)
        }
    }

    @IBOutlet var rescaleGesture: UIPinchGestureRecognizer!
    @IBAction func rescaleGesture(_ sender: UIPinchGestureRecognizer) {
        let player = gameModel.board.currentPlayer
        let newScale = CGFloat(boardScaleFactor) * sender.scale
        board.scale = SCNVector3(newScale,newScale,newScale)

        if sender.state == .ended {
            //NSLog("pinch gesture: \(sender.scale)x ended for player \(player)")
            users[player].scaleFactor *= Float(sender.scale)
            //NSLog("scale for user \(player) set to \(users[player].scaleFactor)")
        }
    }

    @IBOutlet var rotateGesture: UIRotationGestureRecognizer!
    @IBAction func rotateGesture(_ sender: UIRotationGestureRecognizer) {
        let player = gameModel.board.currentPlayer
        board.eulerAngles.y = Float(CGFloat(users[player].rotation) - sender.rotation)

        if sender.state == .ended {
            //NSLog("rotate gesture: \(sender.rotation) ended or player \(player)")
            users[player].rotation -= Float(sender.rotation)
            //NSLog("rotation for user \(player) set to \(users[player].rotation)")
        }
    }
    

    // MARK: - UI element actions
    // make this a target for unwinding segues
    @IBAction func unwindToGameScreen(unwindSegue: UIStoryboardSegue) {
        
    }
    
    @IBAction func fireButtonPressed(_ sender: UIButton) {
        NSLog("Fire button pressed")
        launchProjectile()
        fireButton.isEnabled = false
        powerSlider.isEnabled = false
        screenDraggingGesture.isEnabled = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dest = segue.destination as? WeaponsViewController {
            dest.gameModel = gameModel
        } else if let dest = segue.destination as? GameOverViewController {
            let (name, score) = gameModel.getWinner()
            dest.winner = name
            dest.score = score
        } else {
            super.prepare(for: segue, sender: sender)
        }
    }
    
    @IBAction func powerChanged(_ sender: UISlider) {
        gameModel.setTankPower(power: sender.value)
        //NSLog("set tank power to \(sender.value)")
        updateHUD()
    }
    
    // MARK: - Helper methods
    func toModelSpace(_ position: SCNVector3) -> SCNVector3 {
        return SCNVector3(x: position.x + Float(gameModel.board.boardSize/2),
                            y: position.z + Float(gameModel.board.boardSize/2),
                            z: position.y)
    }

    func fromModelSpace(_ position: SCNVector3) -> SCNVector3 {
        return SCNVector3(x: position.x - Float(gameModel.board.boardSize/2),
                          y: position.z,
                          z: position.y - Float(gameModel.board.boardSize/2))
    }

    func toModelScale(_ vector: SCNVector3) -> SCNVector3 {
        let ret = SCNVector3(vector.x,vector.z,vector.y)
        return ret
    }

    func fromModelScale(_ vector: SCNVector3) -> SCNVector3 {
        let ret = SCNVector3(vector.x,vector.z,vector.y)
        return ret
    }
    
    func clearAllPlanes() {
        for plane in candidatePlanes {
            plane.removeFromParentNode()
        }
        candidatePlanes.removeAll()
    }
    
    func placeBoard(_ atLocationOf: ARHitTestResult) {
        guard let withExtentOf = atLocationOf.anchor as? ARPlaneAnchor else { return }
        let planePosition = atLocationOf.worldTransform.columns.3
        let position = SCNVector3(planePosition.x, planePosition.y, planePosition.z)
        let boardSize = min(withExtentOf.extent.x,withExtentOf.extent.z)
        let scaleFactor = Float(boardSize) / Float(gameModel.board.boardSize)

        NSLog("Placing board at \(withExtentOf)")
        NSLog("plane extents are \(withExtentOf.extent.x),\(withExtentOf.extent.z).")
        
        placeBoard(atLocation: position, withScaleFactor: scaleFactor)
    }

    func placeBoard(atLocation: SCNVector3, withScaleFactor: Float) {
        NSLog("\(#function) started")

        // remove all candidate planes
        clearAllPlanes()
        
        // set scale factor for scaling node
        let scaleNode = board
        scaleNode.position = atLocation
        boardScaleFactor = withScaleFactor
        scaleNode.scale = SCNVector3(boardScaleFactor,boardScaleFactor,boardScaleFactor)
        scaleNode.name = "scaleNode"
        sceneView.scene.rootNode.addChildNode(scaleNode)

        // set size, orientation, and color of board base
        let geometry = SCNPlane(width: CGFloat(gameModel.board.boardSize),
                                height: CGFloat(gameModel.board.boardSize))
        geometry.firstMaterial?.diffuse.contents = UIColor.green

        let boardBaseNode = SCNNode()
        boardBaseNode.geometry = geometry
        boardBaseNode.eulerAngles.x = -Float.pi / 2
        boardBaseNode.opacity = 1.0
        board.addChildNode(boardBaseNode)

        // disable selection of a board location
        boardPlaced = true
        placeBoardGesture.isEnabled = false
        backupPlaceBoardGesture.isEnabled = false
        tapToSelectLabel.isHidden = true
        fireButton.isEnabled = true
        fireButton.isHidden = false
        screenDraggingGesture.isEnabled = true
        powerLabel.isHidden = false
        powerSlider.isHidden = false
        hudStackView.isHidden = false

        updateBoard()
        
        NSLog("\(#function) finished")
    }

    func unplaceBoard() {
        NSLog("\(#function) started")

        // enable selection of a board location
        boardPlaced = false
        placeBoardGesture.isEnabled = true
        backupPlaceBoardGesture.isEnabled = true
        tapToSelectLabel.isHidden = false
        fireButton.isEnabled = false
        fireButton.isHidden = true
        screenDraggingGesture.isEnabled = false
        powerLabel.isHidden = true
        powerSlider.isHidden = true
        hudStackView.isHidden = true
        
        // remove board and tanks
//        let nodes = board.childNodes
//        for node in  nodes {
//            node.removeFromParentNode()
//        }
        
        NSLog("\(#function) finished")
    }
    
    func addTanks() {
        NSLog("\(#function) started")
        tankNodes = [SCNNode](repeating: SCNNode(), count: gameModel.board.players.count)
        
        for i in 0..<gameModel.board.players.count {
            let player = gameModel.board.players[i]
            let tankScene = SCNScene(named: "art.scnassets/Tank.scn")
            guard let tankNode = tankScene?.rootNode.childNode(withName: "Tank", recursively: false) else { continue }
            
            guard let tank = player.tank else { continue }
            tankNode.position = fromModelSpace(tank.position)
            tankNode.scale = SCNVector3(30,30,30)
            //tankNode.eulerAngles.x = Float.pi / 2
            users[i].tank = tankNode
            
            NSLog("Adding tank at \(tankNode.position)")
            board.addChildNode(tankNode)
            tankNodes[i] = tankNode
        }
        NSLog("\(#function) finished")
    }
    
    func removeTanks() {
        for i in 0..<gameModel.board.players.count {
            users[i].tank?.removeFromParentNode()
        }
    }
    
    func addBoard() {
        NSLog("\(#function) started")

        // use cubes until I can sort out actual Meshes.
        
        // keep references to each block
        boardBlocks = Array(repeating: Array(repeating: SCNNode(), count: numPerSide), count: numPerSide)
        let edgeSize = CGFloat(gameModel.board.boardSize / numPerSide)

        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                // create block
                let blockNode = SCNNode(geometry: SCNBox(width: edgeSize, height: 1, length: edgeSize, chamferRadius: 0))
                boardBlocks[i][j] = blockNode
                blockNode.position.y = -1 // make sure update will happen initially

                // add to board
                board.addChildNode(boardBlocks[i][j])
            }
        }
        updateBoard()
        //mapImage.image = gameModel.board.surface.asUIImage()
        
        NSLog("\(#function) finished")
    }
    
    func removeBoard() {
        NSLog("\(#function) started")
        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                boardBlocks[i][j].removeFromParentNode()
            }
        }
        board.removeFromParentNode()
        NSLog("\(#function) finished")
    }
    

    func updateBoard() {
        NSLog("\(#function) started")
        let edgeSize = CGFloat(gameModel.board.boardSize / numPerSide)

        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                // determine location of segment
                let xPos = CGFloat(i)*edgeSize + edgeSize/2
                let zPos = CGFloat(j)*edgeSize + edgeSize/2
                let elevation = gameModel.getElevation(longitude: Int(xPos), latitude: Int(zPos))
                let yPos = CGFloat(elevation/2)
                let ySize = CGFloat(elevation)

                // update cube
                let blockNode = boardBlocks[i][j]
                
                if blockNode.position.y != Float(yPos) {
                    //NSLog("block at \(i),\(j) is \(blockNode)")
                    blockNode.position = SCNVector3(xPos-CGFloat(gameModel.board.boardSize/2),
                                                    yPos,
                                                    zPos-CGFloat(gameModel.board.boardSize/2))
                    if let geometry = blockNode.geometry as? SCNBox {
                        geometry.width = edgeSize
                        geometry.height = ySize
                        geometry.length = edgeSize
                    }
                }
                
                // update color
                blockNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            }
        }

        // remove any dropBlocks that may still be around
        for block in dropBlocks {
            block.removeFromParentNode()
        }
        NSLog("\(#function) finished")
    }
    
    func launchProjectile() {
        NSLog("\(#function) started")

        // get location of muzzle
        let tankNode = tankNodes[gameModel.board.currentPlayer]
        guard let muzzleNode = tankNode.childNode(withName: "muzzle", recursively: true) else { return }
        let position = muzzleNode.convertPosition(muzzleNode.position, to: board)
        
        // get muzzle velocity
        let tank = gameModel.getTank(forPlayer: gameModel.board.currentPlayer)
        let power = tank.velocity
        let azi = tank.azimuth * (Float.pi/180)
        let alt = tank.altitude * (Float.pi/180)
        
        let xVel = -power * sin(azi) * cos(alt)
        let yVel = power * sin(alt)
        let zVel = -power * cos(azi) * cos(alt)
        
        NSLog("tank angles: \(tank.azimuth),\(tank.altitude)")
        NSLog("angles in radians: \(azi),\(alt)")
        NSLog("velocity: \(xVel),\(yVel),\(zVel)")
        NSLog("position: \(position)")
        let velocity = SCNVector3(xVel, yVel, zVel)
        
        // convert to model coordinate space
        var muzzlePosition = position
        var muzzleVelocity = velocity
        muzzlePosition = toModelSpace(position)
        muzzleVelocity = toModelScale(velocity)
        NSLog("view pos: \(position)")
        NSLog("view vel: \(velocity)")
        NSLog("model pos: \(muzzlePosition)")
        NSLog("model vel: \(muzzleVelocity)")

        let fireResult = gameModel.fire(muzzlePosition: muzzlePosition, muzzleVelocity: muzzleVelocity)

        // record result for AIs
        if let ai = gameModel.board.players[gameModel.board.currentPlayer].ai {
            // player is an AI
            let impact = fireResult.trajectory.last!
            ai.recordResult(azimuth: azi, altitude: alt, velocity: power,
                              impactX: impact.x, impactY: impact.y, impactZ: impact.z)
        }

        animateResult(fireResult: fireResult)
        roundChanged = fireResult.newRound
        
        NSLog("\(#function) finished")
    }
    
    func animateResult(fireResult: FireResult) {
        NSLog("\(#function) started")

        // time for use in animations
        var currTime = CFTimeInterval(0)
        var finalAnimation: CAAnimation? = nil
        
        // create shell object
        if let oldShell = shellNode {
            oldShell.removeFromParentNode()
        }
        shellNode = SCNNode(geometry: SCNSphere(radius: 10))
        if let shell = shellNode,
            let firstPosition = fireResult.trajectory.first {
            shell.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            // convert back to view coordinates
            shell.position = fromModelSpace(firstPosition)
            shell.opacity = 0.0
            board.addChildNode(shellNode!)

            // see: https://stackoverflow.com/questions/11737658/how-to-chain-different-caanimation-in-an-ios-application
            var animations: [CABasicAnimation] = []

            // make shell appear
            let animation0 = CABasicAnimation(keyPath: "opacity")
            animation0.fromValue = 0
            animation0.toValue = 1
            animation0.beginTime = 0
            animation0.duration = 0
            animations.append(animation0)

            var prevPosition = firstPosition
            let timeStep = CFTimeInterval(fireResult.timeStep / Float(timeScaling))
            for currPosition in fireResult.trajectory {
                //NSLog("trajectory position: \(currPosition) at time \(currTime)")
                // convert currPostion to AR space
                let arPosition = fromModelSpace(currPosition)
                
                // add animations for shell here
                let animation = CABasicAnimation(keyPath: "position")
                animation.fromValue = prevPosition
                animation.toValue = arPosition
                animation.beginTime = currTime
                animation.duration = timeStep
                animations.append(animation)

                prevPosition = arPosition
                currTime += timeStep
            }
            
            // make shell disappear
            let animation3 = CABasicAnimation(keyPath: "opacity")
            animation3.fromValue = 1
            animation3.toValue = 0
            animation3.beginTime = currTime
            animation3.duration = 0
            animations.append(animation3)

            let group = CAAnimationGroup()
            group.beginTime = 0
            group.duration = currTime
            group.repeatCount = 1
            group.isRemovedOnCompletion = true
            group.animations = animations
            shell.addAnimation(group, forKey: "balistics")
            finalAnimation = group
        }
        NSLog("shell landed at time \(currTime).")
        
        // animate explosion
        if let oldExplosion = explosionNode {
            oldExplosion.removeFromParentNode()
        }
        explosionNode = SCNNode(geometry: SCNSphere(radius: 1))
        if let explosion = explosionNode,
            let lastPosition = fireResult.trajectory.last {
            explosion.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            // convert back to view coordinates
            explosion.position = fromModelSpace(lastPosition)
            explosion.opacity = 0
            board.addChildNode(explosion)
            
            var animations: [CABasicAnimation] = []
            
            // make explosion disappear
            let animation0 = CABasicAnimation(keyPath: "opacity")
            animation0.fromValue = 0
            animation0.toValue = 1
            animation0.beginTime = currTime
            animation0.duration = 0
            animations.append(animation0)

            // add expansion animation
            let animation1 = CABasicAnimation(keyPath: "geometry.radius")
            animation1.fromValue = 1
            animation1.toValue = fireResult.explosionRadius
            animation1.beginTime = currTime
            animation1.duration = CFTimeInterval(1.0)
            animations.append(animation1)
            currTime += 1.0

            // add collapse animation
            let animation2 = CABasicAnimation(keyPath: "geometry.radius")
            animation2.fromValue = fireResult.explosionRadius
            animation2.toValue = 0
            animation2.beginTime = currTime
            animation2.duration = CFTimeInterval(1.0)
            animations.append(animation2)
            currTime += 1.0
            
            // make explosion disappear
            let animation3 = CABasicAnimation(keyPath: "opacity")
            animation3.fromValue = 1
            animation3.toValue = 0
            animation3.beginTime = currTime
            animation3.duration = 0
            animations.append(animation3)

            let group = CAAnimationGroup()
            group.beginTime = 0
            group.duration = currTime
            group.repeatCount = 1
            group.isRemovedOnCompletion = true
            group.animations = animations
            //group.delegate = self
            explosion.addAnimation(group, forKey: "explosion")
            finalAnimation = group
        }
        NSLog("explosion ended at time \(currTime).")

        // animate board update
        var dropNeeded = false
        let dropTime: Double = 3
        for block in dropBlocks {
            block.removeFromParentNode()
        }
        // stages:
        //  1. dropBlocks created, boardBlocks set to bottom height (immediate)
        //  2. dropBlocks drop over fixed interval
        //  3. dropBlocks dissappear, boardBlocks set to final height (immediate)
        for j in 0..<numPerSide {
            for i in 0..<numPerSide {
                let boardBlock = boardBlocks[i][j]
                let blockGeometry = boardBlock.geometry as! SCNBox
                let modelPos = toModelSpace(boardBlock.position)

                // get elevations for block
                let current = gameModel.getElevation(fromMap: fireResult.mapUpdate,
                                                     longitude: Int(modelPos.x), latitude: Int(modelPos.y),
                                                     forMode: .old)
                let top = gameModel.getElevation(fromMap: fireResult.mapUpdate,
                                                 longitude: Int(modelPos.x), latitude: Int(modelPos.y),
                                                 forMode: .top)
                let middle = gameModel.getElevation(fromMap: fireResult.mapUpdate,
                                                    longitude: Int(modelPos.x), latitude: Int(modelPos.y),
                                                    forMode: .middle)
                let bottom = gameModel.getElevation(fromMap: fireResult.mapUpdate,
                                                    longitude: Int(modelPos.x), latitude: Int(modelPos.y),
                                                    forMode: .bottom)
                
                if top > middle && middle > bottom {
                    dropNeeded = true
                    //NSLog("(\(i),\(j)) will drop, top: \(top), middle: \(middle), bottom: \(bottom)")
                    // need to create and animate a drop block
                    let dropBlock = SCNNode(geometry: SCNBox(width: blockGeometry.width,
                                                             height: CGFloat(top-middle),
                                                             length: blockGeometry.length, chamferRadius: 0))
                    dropBlock.position = boardBlock.position
                    dropBlock.position.y = (top+middle)/2
                    board.addChildNode(dropBlock)
                    dropBlocks.append(dropBlock)

                    var finalPosition = dropBlock.position
                    finalPosition.y = bottom + (top-middle)/2
                    
                    var animations: [CAAnimation] = []
                    
                    // make block appear
                    let animation1 = CABasicAnimation(keyPath: "opacity")
                    animation1.fromValue = 0
                    animation1.toValue = 1
                    animation1.beginTime = currTime
                    animation1.duration = 0
                    animations.append(animation1)
                    
                    // animate drop
                    let animation2 = CABasicAnimation(keyPath: "position")
                    animation2.fromValue = dropBlock.position
                    animation2.toValue = finalPosition
                    animation2.beginTime = currTime
                    animation2.duration = CFTimeInterval(dropTime)
                    animations.append(animation2)
                    
                    let group = CAAnimationGroup()
                    group.beginTime = 0
                    group.duration = currTime + dropTime
                    group.repeatCount = 1
                    group.isRemovedOnCompletion = true
                    group.animations = animations
                    dropBlock.addAnimation(group, forKey: "block \(i),\(j) drop")
                    finalAnimation = group
                }
                
                let collapseHeight = min(bottom,current)
                if  bottom != current {
                    // heigth adjustment needed
                    //NSLog("(\(i),\(j)) height change needed, \(current) -> \(bottom), top: \(top), middle: \(middle), bottom: \(bottom)")
                    
                    // resize at appropriate time
                    let animation1 = CABasicAnimation(keyPath: "geometry.height")
                    animation1.fromValue = blockGeometry.height
                    animation1.toValue = collapseHeight
                    animation1.beginTime = currTime
                    animation1.duration = CFTimeInterval(0)
                    boardBlocks[i][j].addAnimation(animation1, forKey: "block \(i),\(j) resize")

                    // handle repositioning
                    let animation2 = CABasicAnimation(keyPath: "position.y")
                    animation2.fromValue = boardBlock.position.y
                    animation2.toValue = collapseHeight/2
                    animation2.beginTime = currTime
                    animation2.duration = CFTimeInterval(0)
                    boardBlocks[i][j].addAnimation(animation2, forKey: "block \(i),\(j) reposition")
                }
            }
        }
        if dropNeeded {
            currTime += dropTime
        }
        NSLog("board settled at time \(currTime).")
        
        // a do-nothing animation to call the delegate
        NSLog("animation should stop at time \(currTime)")
        NSLog("final animiation starts at \(String(describing: finalAnimation?.beginTime))s and goes for \(String(describing: finalAnimation?.duration))s.")
        finalAnimation?.delegate = self
        
        NSLog("\(#function) finished")
    }
    
    func animationDidStart(_ anim: CAAnimation) {
        NSLog("Animation started")
    }
    
    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
        NSLog("Animation stopped (finished: \(finished))")
        NSLog("\tbegan at: \(animation.beginTime), with duration: \(animation.duration)")
        
        // do AI stuff if next player is an AI
        if let ai = gameModel.board.players[gameModel.board.currentPlayer].ai {
            // player is an AI
            let (azimuth: azi, altitude: alt, velocity: vel) = ai.fireParameters(players: gameModel.board.players)
            gameModel.setTankAim(azimuth: azi, altitude: alt)
            gameModel.setTankPower(power: vel)
            updateUI()
            launchProjectile()
        } else {
            // return control to human player
            fireButton.isEnabled = true
            powerSlider.isEnabled = true
            screenDraggingGesture.isEnabled = true
            updateUI()
        }
        
    }
    
    func updateUI() {
        guard boardPlaced else { return }

        NSLog("\(#function) started")
        //mapImage.image = fireResult.mapUpdate.asUIImage()
        if roundChanged {
            NSLog("round change detected")
            if gameModel.board.currentRound > gameModel.board.totalRounds {
                NSLog("round \(gameModel.board.currentRound) > \(gameModel.board.totalRounds), game over!")
                gameOver = true
                performSegue(withIdentifier: "Game Over", sender: nil)
                return
            }
            NSLog("Starting round \(gameModel.board.currentRound) of \(gameModel.board.currentRound).")
            removeTanks()
            addTanks()
            roundChanged = false
        }
        
        // make sure power slider matches player
        let currentPower = gameModel.board.players[gameModel.board.currentPlayer].tank.velocity
        powerSlider.setValue(currentPower, animated: false)
        
        // update scale and rotation for player
        let scaleNode = board
        let rotationAnimation = CABasicAnimation(keyPath: "eulerAngles.y")
        rotationAnimation.fromValue = scaleNode.eulerAngles.y
        rotationAnimation.toValue = users[gameModel.board.currentPlayer].rotation
        rotationAnimation.beginTime = 0
        rotationAnimation.duration = 1
        scaleNode.addAnimation(rotationAnimation, forKey: "Player Rotation")
        scaleNode.eulerAngles.y = users[gameModel.board.currentPlayer].rotation
        NSLog("rotating to \(rotationAnimation.toValue!) for user \(gameModel.board.currentPlayer)")
        
        let rescaleAnimation = CABasicAnimation(keyPath: "scale")
        rescaleAnimation.fromValue = scaleNode.scale
        let newFactor = boardScaleFactor * users[gameModel.board.currentPlayer].scaleFactor
        let newScale = SCNVector3(newFactor,newFactor,newFactor)
        rescaleAnimation.toValue = newScale
        rescaleAnimation.beginTime = 0
        rescaleAnimation.duration = 1
        scaleNode.addAnimation(rescaleAnimation, forKey: "Player Scaling")
        scaleNode.scale = newScale
        NSLog("scaling to \(rescaleAnimation.toValue!) for user \(gameModel.board.currentPlayer)")

        updateHUD()
        
        // update all tanks turrets and existence
        for i in 0..<users.count {
            let player = gameModel.board.players[i]
            let user = users[i]
            guard let tankNode = user.tank else { continue }

            if player.hitPoints <= 0 {
                tankNode.removeFromParentNode()
            }
            
            guard let tank = player.tank else { continue }
            guard let turretNode = tankNode.childNode(withName: "turret", recursively: true) else { return }
            guard let hingeNode = tankNode.childNode(withName: "barrelHinge", recursively: true) else { return }
            guard let barrelNode = tankNode.childNode(withName: "barrel", recursively: true) else { return }
            turretNode.eulerAngles.y = tank.azimuth * (Float.pi/180)
            hingeNode.eulerAngles.x = tank.altitude * (Float.pi/180)

            // set colors to highlight current player
            var color = UIColor.darkGray
            if gameModel.board.currentPlayer == i {
                color = UIColor.gray
            }
            tankNode.geometry?.firstMaterial?.diffuse.contents = color
            turretNode.geometry?.firstMaterial?.diffuse.contents = color
            barrelNode.geometry?.firstMaterial?.diffuse.contents = color
        }
        
        // update board
        updateBoard()
        
        NSLog("\(#function) finished")
    }
    
    func updateHUD() {
        let board = gameModel.board
        let player = board.players[board.currentPlayer]
        let tank = player.tank!
        
        azimuthLabel.text = String(format: "%.02fº", tank.azimuth)
        altitudeLabel.text = String(format: "%.02fº", tank.altitude)
        velocityLabel.text = String(format: "%.02f m/s", tank.velocity)

        var weaponName = gameModel.weaponsList[player.weaponID].name
        let sizeStr = gameModel.weaponsList[player.weaponID].sizes[player.weaponSizeID].name
        if sizeStr != "" && sizeStr.lowercased() != "n/a" {
            weaponName.append(" (\(sizeStr))")
        }
        weaponLabel.text = weaponName
    }
    
    // MARK: - Map View
    
    @IBOutlet var mapImage: UIImageView!
    
    @IBAction func toggleMap(_ sender: UIButton) {
        mapImage.isHidden = !mapImage.isHidden
    }
}
