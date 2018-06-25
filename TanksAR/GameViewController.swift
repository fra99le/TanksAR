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

class GameViewController: UIViewController, ARSCNViewDelegate, CAAnimationDelegate, UIGestureRecognizerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var useBlocks: Bool = false
    var boardDrawer: GameViewDrawer!
    var boardPlaced = false
    var boardSize: Float = 1.0
    var boardScaleFactor: Float = 1.0
    let tankScale = 10
    var candidatePlanes: [SCNNode] = []
    var board = SCNNode()
    var gameModel = GameModel()
    var users: [UserConfig] = []
    var numHumans: Int = 0
    var humanLeft: Int = 0
    var numAIs: Int = 0
    var numRounds: Int = 0
    var roundChanged: Bool = false
    var gameOver = false
    
    @IBOutlet var tapToSelectLabel: UILabel!
    @IBOutlet var fireButton: UIButton!
    @IBOutlet var powerSlider: UISlider!
    @IBOutlet var powerLabel: UILabel!
    @IBOutlet weak var hudStackView: UIStackView!
    
    
    @IBOutlet weak var manualTrainButton: UIButton!
    @IBOutlet weak var azimuthLabel: UILabel!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var velocityLabel: UILabel!
    @IBOutlet weak var weaponLabel: UILabel!    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        // create the game board
        if useBlocks {
            boardDrawer = GameViewBlockDrawer()
            boardDrawer.numPerSide = 50
        } else {
            boardDrawer = GameViewTrigDrawer()
            boardDrawer.numPerSide = 100
        }
        boardDrawer.gameModel = gameModel
        boardDrawer.board = board

        // start a game
        NSLog("\(#function) starting \(numRounds) round game.")
        gameModel.startGame(numPlayers: numHumans, numAIs: numAIs, rounds: numRounds)
        boardDrawer.addBoard()
        users = [UserConfig](repeating: UserConfig(scaleFactor: 1.0, rotation: 0.0, tank: nil),
                             count: gameModel.board.players.count)
        addTanks()

        unplaceBoard()
        rotateGesture.delegate = self
        rescaleGesture.delegate = self
        
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
        updateUI()
    }
    

    
    @IBOutlet var screenDraggingGesture: UIPanGestureRecognizer!
    @IBAction func screenDragged(_ sender: UIGestureRecognizer) {
        guard let gesture = sender as? UIPanGestureRecognizer else { return }
        guard boardDrawer.tankNodes.count > 0 else { return }
        
        //NSLog("Screen dragged \(gesture).")
        //NSLog("velocity: \(gesture.velocity(in: nil)), translation: \(gesture.translation(in: nil))")
        // determine player
        let player = gameModel.board.currentPlayer
        let tankNode = boardDrawer.tankNodes[player]
        
        // get tank aiming values from model
        let tank = gameModel.getTank(forPlayer: player)
        let currAzimuth = tank.azimuth
        let currAltitude = tank.altitude
        //NSLog("currAzimuth: \(currAzimuth), currAltitude: \(currAltitude)")

        // update values
        let translation = gesture.translation(in: nil)
        
        let rotationScale: Float = 5
        let newAzimuth = currAzimuth + Float(translation.x) / rotationScale
        let newAltitude = currAltitude - Float(translation.y) / rotationScale

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
        let newScale = CGFloat(boardScaleFactor) * CGFloat(users[player].scaleFactor) * sender.scale
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

    // see: https://stackoverflow.com/questions/30829973/simultaneous-gesture-recognition-for-specific-gestures
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer is UIPanGestureRecognizer || gestureRecognizer is UIRotationGestureRecognizer) {
            return true
        } else {
            return false
        }
    }
    
    // MARK: - UI element actions
    // make this a target for unwinding segues
    @IBAction func unwindToGameScreen(unwindSegue: UIStoryboardSegue) {
        
    }
    
    @IBAction func fireButtonPressed(_ sender: UIButton) {
        NSLog("Fire button pressed")
        disableUI()
        launchProjectile()
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
        boardBaseNode.position = SCNVector3(0,-1,0)
        board.addChildNode(boardBaseNode)

        // disable selection of a board location
        boardPlaced = true
        placeBoardGesture.isEnabled = false
        backupPlaceBoardGesture.isEnabled = false
        tapToSelectLabel.isHidden = true
        enableUI()

        boardDrawer.updateBoard()
        
        finishTurn()
        
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
    
    // Tank drawing methods
    func addTanks() {
        NSLog("\(#function) started")
        boardDrawer.tankNodes = [SCNNode](repeating: SCNNode(), count: gameModel.board.players.count)
        
        for i in 0..<gameModel.board.players.count {
            let player = gameModel.board.players[i]
            let tankScene = SCNScene(named: "art.scnassets/Tank.scn")
            guard let tankNode = tankScene?.rootNode.childNode(withName: "Tank", recursively: false) else { continue }
            
            guard let tank = player.tank else { continue }
            tankNode.position = boardDrawer.fromModelSpace(tank.position)
            tankNode.scale = SCNVector3(tankScale,tankScale,tankScale)
            //tankNode.eulerAngles.x = Float.pi / 2
            users[i].tank = tankNode
            
            NSLog("Adding tank at \(tankNode.position)")
            board.addChildNode(tankNode)
            boardDrawer.tankNodes[i] = tankNode
        }
        NSLog("\(#function) finished")
    }
    
    func removeTanks() {
        for i in 0..<gameModel.board.players.count {
            users[i].tank?.removeFromParentNode()
        }
    }
    
    func launchProjectile() {
        NSLog("\(#function) started")

        // get location of muzzle
        let tankNode = boardDrawer.tankNodes[gameModel.board.currentPlayer]
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
        let velocity = SCNVector3(xVel, yVel, zVel)
        
        // convert to model coordinate space
        var muzzlePosition = position
        var muzzleVelocity = velocity
        muzzlePosition = boardDrawer.toModelSpace(position)
        muzzleVelocity = boardDrawer.toModelScale(velocity)

        let fireResult = gameModel.fire(muzzlePosition: muzzlePosition, muzzleVelocity: muzzleVelocity)

        // record result for AIs
        if let ai = gameModel.board.players[fireResult.playerID].ai {
            // player is an AI
            let impact = fireResult.trajectory.last!
            ai.recordResult(azimuth: tank.azimuth, altitude: tank.altitude, velocity: tank.velocity,
                              impactX: impact.x, impactY: impact.y, impactZ: impact.z)
        }

        // count human players left
        humanLeft = 0
        for player in gameModel.board.players {
            if let _ = player.ai {
                // player is an AI
            } else {
                if player.hitPoints > 0 {
                    humanLeft += 1
                    boardDrawer.timeScaling = 3
                }
            }
        }
        
        boardDrawer.animateResult(fireResult: fireResult, from: self)
        roundChanged = fireResult.newRound
        
        NSLog("\(#function) finished")
    }
    
    
    func animationDidStart(_ anim: CAAnimation) {
        NSLog("Animation started")
    }
    
    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
        NSLog("Animation stopped (finished: \(finished))\n\n\n")
        //NSLog("\tbegan at: \(animation.beginTime), with duration: \(animation.duration)")

        finishTurn()
    }
    
    func finishTurn() {
        NSLog("\(#function) started")

        // do AI stuff if next player is an AI
        if let ai = gameModel.board.players[gameModel.board.currentPlayer].ai {
            if humanLeft == 0 {
                boardDrawer.timeScaling *= 1.01
                NSLog("timeScaling now \(boardDrawer.timeScaling)")
            }
            // player is an AI
            disableUI()
            let (azi, alt, vel) = ai.fireParameters(players: gameModel.board.players)
            NSLog("ai firing parameters, azi,alt,vel: (\(azi),\(alt),\(vel))")
            gameModel.setTankAim(azimuth: azi, altitude: alt)
            gameModel.setTankPower(power: vel)
            let tank = gameModel.board.players[gameModel.board.currentPlayer].tank!
            NSLog("ai firing parameters, azi,alt,vel: (\(tank.azimuth),\(tank.altitude),\(tank.velocity)) (updated)")
            updateUI()
            launchProjectile()
        } else {
            // return control to human player
            boardDrawer.timeScaling = 3
            updateUI()
            enableUI()
        }

        NSLog("\(#function) finished")
    }
    
    func enableUI() {
        fireButton.isHidden = false
        fireButton.isEnabled = true
        powerSlider.isHidden = false
        powerSlider.isEnabled = true
        powerLabel.isHidden = false
        screenDraggingGesture.isEnabled = true
        manualTrainButton.isEnabled = true
        manualTrainButton.isHidden = false
        hudStackView.isHidden = false
    }
    
    func disableUI() {
        fireButton.isHidden = true
        fireButton.isEnabled = false
        powerSlider.isHidden = true
        powerSlider.isEnabled = false
        powerLabel.isHidden = true
        screenDraggingGesture.isEnabled = false
        manualTrainButton.isEnabled = false
        manualTrainButton.isHidden = true
    }
    
    func updateUI() {
        guard boardPlaced else { return }

        //NSLog("\(#function) started")
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
        powerSlider.minimumValue = 0
        powerSlider.maximumValue = gameModel.maxPower
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
        //NSLog("rotating to \(rotationAnimation.toValue!) for user \(gameModel.board.currentPlayer)")
        
        let rescaleAnimation = CABasicAnimation(keyPath: "scale")
        rescaleAnimation.fromValue = scaleNode.scale
        let newFactor = boardScaleFactor * users[gameModel.board.currentPlayer].scaleFactor
        let newScale = SCNVector3(newFactor,newFactor,newFactor)
        rescaleAnimation.toValue = newScale
        rescaleAnimation.beginTime = 0
        rescaleAnimation.duration = 1
        scaleNode.addAnimation(rescaleAnimation, forKey: "Player Scaling")
        scaleNode.scale = newScale
        //NSLog("scaling to \(rescaleAnimation.toValue!) for user \(gameModel.board.currentPlayer)")

        updateHUD()
        
        // update all tanks turrets and existence
        for i in 0..<users.count {
            let player = gameModel.board.players[i]
            let user = users[i]
            guard let tankNode = user.tank else { continue }

            if player.hitPoints <= 0 {
                tankNode.removeFromParentNode()
            } else {
                let newPos = boardDrawer.fromModelSpace(player.tank.position)
                let oldPos = tankNode.position
                if newPos.x != oldPos.x || newPos.y != oldPos.y || newPos.z != oldPos.z {
                    let tankMove = SCNAction.move(to: newPos, duration: 1.0)
                    tankNode.runAction(tankMove)
                }
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
        boardDrawer.updateBoard()
        
        //NSLog("\(#function) finished")
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
        if !mapImage.isHidden {
            mapImage.image = gameModel.board.surface.asUIImage()
        }
    }
}
