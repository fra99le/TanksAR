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

class GameViewController: UIViewController, ARSCNViewDelegate, CAAnimationDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var boardPlaced = false
    var boardSize: Float = 1.0
    var candidatePlanes: [SCNNode] = []
    var board: SCNNode? = nil
    var gameModel = GameModel()
    var tankNodes: [SCNNode] = []
    var shellNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    var explosionNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    let timeScaling = 10
    let numPerSide = 50
    var boardBlocks: [[SCNNode]] = []
    
    @IBOutlet var tapToSelectLabel: UILabel!
    @IBOutlet var fireButton: UIButton!
    @IBOutlet var powerSlider: UISlider!
    @IBOutlet var powerLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // create the game board
        gameModel.generateBoard()
        
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Enable horizontal plane detection
        configuration.planeDetection = [.horizontal]

        // cause board placement to occur when view reappears
        unplaceBoard()
        updateUI()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // cause board placement to occur when view reappears
        unplaceBoard()

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

    @IBOutlet var placeBoardGesture: UITapGestureRecognizer!
    @IBAction func screenTapped(_ sender: UIGestureRecognizer) {
        let touchLocation = sender.location(in: sceneView)
        NSLog("Screen tapped at \(touchLocation)")
        let hitTestResult = sceneView.hitTest(touchLocation, types: [.existingPlaneUsingGeometry])
        
        for result in hitTestResult {
            if !boardPlaced {
                if (result.anchor as? ARPlaneAnchor) != nil {
                    placeBoard(result)
                    break
                }
            } else {
                NSLog("Board already placed")
            }
        }
    }

    @IBOutlet var screenDraggingGesture: UIPanGestureRecognizer!
    @IBAction func screenDragged(_ sender: UIGestureRecognizer) {
        guard let gesture = sender as? UIPanGestureRecognizer else { return }
        guard tankNodes.count > 0 else { return }
        
        NSLog("Screen dragged \(gesture).")
        NSLog("velocity: \(gesture.velocity(in: nil)), translation: \(gesture.translation(in: nil))")
        // determine player
        let player = gameModel.board.currentPlayer
        let tankNode = tankNodes[player]
        
        // get tank aiming values from model
        let tank = gameModel.getTank(forPlayer: player)
        let currAzimuth = tank.azimuth
        let currAltitude = tank.altitude
        NSLog("currAzimuth: \(currAzimuth), currAltitude: \(currAltitude)")

        // update values
        let translation = gesture.translation(in: nil)
        let newAzimuth = currAzimuth + Float(translation.x)
        let newAltitude = currAltitude - Float(translation.y)

        // find/adjust tank model's aiming
        guard let turretNode = tankNode.childNode(withName: "turret", recursively: true) else { return }
        guard let hingeNode = tankNode.childNode(withName: "barrelHinge", recursively: true) else { return }
        turretNode.eulerAngles.y = newAzimuth * (Float.pi/180)
        hingeNode.eulerAngles.x = newAltitude * (Float.pi/180)
        NSLog("newAzimuth: \(newAzimuth), newAltitude: \(newAltitude)")
        
        if gesture.state == .ended {
            gameModel.setTankAim(azimuth: newAzimuth, altitude: newAltitude)
        }
    }

    @IBAction func powerChanged(_ sender: UISlider) {
        gameModel.setTankPower(power: sender.value)
        //print("set tank power to \(sender.value)")
    }
    
    func clearAllPlanes() {
        for plane in candidatePlanes {
            plane.removeFromParentNode()
        }
        candidatePlanes.removeAll()
    }
    
    func placeBoard(_ atLocationOf: ARHitTestResult) {
        guard let withExtentOf = atLocationOf.anchor as? ARPlaneAnchor else { return }
        
        // remove all candidate planes
        clearAllPlanes()
        
        NSLog("Placing board at \(withExtentOf)")
        NSLog("plane extents are \(withExtentOf.extent.x),\(withExtentOf.extent.z).")

        let scaleNode = SCNNode()
        let boardBaseNode = SCNNode()

        // set scale factor for scaling node
        let planePosition = atLocationOf.worldTransform.columns.3
        scaleNode.position = SCNVector3(planePosition.x, planePosition.y, planePosition.z)
        let boardSize = min(withExtentOf.extent.x,withExtentOf.extent.z)
        let scaleFactor = Float(boardSize) / Float(gameModel.board.boardSize)
        scaleNode.scale = SCNVector3(scaleFactor,scaleFactor,scaleFactor)
        board = scaleNode
        sceneView.scene.rootNode.addChildNode(scaleNode)

        // set size, orientation, and color of board base
        let geometry = SCNPlane(width: CGFloat(gameModel.board.boardSize),
                                height: CGFloat(gameModel.board.boardSize))
        geometry.firstMaterial?.diffuse.contents = UIColor.green
        boardBaseNode.geometry = geometry
        boardBaseNode.eulerAngles.x = -Float.pi / 2
        boardBaseNode.opacity = 1.0
        board?.addChildNode(boardBaseNode)

        gameModel.startGame(numPlayers: 2)
        addBoard()
        addTanks()
        
        // disable selection of a board location
        boardPlaced = true
        placeBoardGesture.isEnabled = false
        tapToSelectLabel.isHidden = true
        fireButton.isEnabled = true
        fireButton.isHidden = false
        screenDraggingGesture.isEnabled = true
        powerLabel.isHidden = false
        powerSlider.isHidden = false
    }

    func unplaceBoard() {
        // enable selection of a board location
        boardPlaced = false
        placeBoardGesture.isEnabled = true
        tapToSelectLabel.isHidden = false
        fireButton.isEnabled = false
        fireButton.isHidden = true
        screenDraggingGesture.isEnabled = false
        powerLabel.isHidden = true
        powerSlider.isHidden = true
        
        // remove board and tanks
        if let nodes = board?.childNodes {
            for node in  nodes {
                node.removeFromParentNode()
            }
        }
    }
    
    func addTanks() {
        for player in gameModel.board.players {
            let tankScene = SCNScene(named: "art.scnassets/Tank.scn")
            guard let tankNode = tankScene?.rootNode.childNode(withName: "Tank", recursively: false) else { continue }
            
            guard let tank = player.tank else { continue }
            tankNode.position = SCNVector3(tank.lon-Float(gameModel.board.boardSize/2),
                                           tank.elev,
                                           tank.lat-Float(gameModel.board.boardSize/2))
            tankNode.scale = SCNVector3(30,30,30)
            //tankNode.eulerAngles.x = Float.pi / 2

            NSLog("Adding tank at \(tankNode.position)")
            board?.addChildNode(tankNode)
            tankNodes.append(tankNode)
        }
    }
    
    func addBoard() {
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
                board?.addChildNode(boardBlocks[i][j])
            }
        }
        updateBoard()
    }
    
    func updateBoard() {
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
                        geometry.firstMaterial?.diffuse.contents = UIColor.green
                    }
                }
            }
        }
    }
    
    // MARK: UI elements
    @IBAction func fireButtonPressed(_ sender: UIButton) {
        print("Fire button pressed")
        launchProjectile()
        fireButton.isEnabled = false
        powerSlider.isEnabled = false
    }
    
    func launchProjectile() {
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
        muzzlePosition.x = position.x + Float(gameModel.board.boardSize/2)
        muzzlePosition.y = position.z + Float(gameModel.board.boardSize/2)
        muzzlePosition.z = position.y
        muzzleVelocity.x = velocity.x
        muzzleVelocity.y = velocity.z
        muzzleVelocity.z = velocity.y
        NSLog("view pos: \(position)")
        NSLog("view vel: \(velocity)")
        NSLog("model pos: \(muzzlePosition)")
        NSLog("model vel: \(muzzleVelocity)")

        let fireResult = gameModel.fire(muzzlePosition: muzzlePosition, muzzleVelocity: muzzleVelocity)

        // time for use in animations
        var currTime = CFTimeInterval(0)

        // create shell object
        if let oldShell = shellNode {
            oldShell.removeFromParentNode()
        }
        shellNode = SCNNode(geometry: SCNSphere(radius: 10))
        if let shell = shellNode,
            let firstPosition = fireResult.trajectory.first {
            shell.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            // convert back to view coordinates
            shell.position.x = firstPosition.x - Float(gameModel.board.boardSize/2)
            shell.position.y = firstPosition.z
            shell.position.z = firstPosition.y - Float(gameModel.board.boardSize/2)
            shell.opacity = 0.0
            board?.addChildNode(shellNode!)

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
                var arPosition = currPosition
                arPosition.x = currPosition.x - Float(gameModel.board.boardSize/2)
                arPosition.y = currPosition.z
                arPosition.z = currPosition.y - Float(gameModel.board.boardSize/2)
                
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
        }
        
        // animate explosion
        if let oldExplosion = explosionNode {
            oldExplosion.removeFromParentNode()
        }
        explosionNode = SCNNode(geometry: SCNSphere(radius: 1))
        if let explosion = explosionNode,
            let position = fireResult.trajectory.last {
            explosion.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            // convert back to view coordinates
            explosion.position.x = position.x - Float(gameModel.board.boardSize/2)
            explosion.position.y = position.z
            explosion.position.z = position.y - Float(gameModel.board.boardSize/2)
            explosion.opacity = 0
            board?.addChildNode(explosion)
            
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
            group.delegate = self // will call updateUI when animation finishes
            explosion.addAnimation(group, forKey: "explosion")
        }
    }
    
    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
            fireButton.isEnabled = true
            powerSlider.isEnabled = true
            updateUI()
    }
    
    func updateUI() {
        guard boardPlaced else { return }

        // make sure power slider matches player
        let currentPower = gameModel.board.players[gameModel.board.currentPlayer].tank.velocity
        powerSlider.setValue(currentPower, animated: false)
        
        // update all tank turrets

        // updte board
        updateBoard()
    }
}
