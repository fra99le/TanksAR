//
//  GameViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit
import SceneKit
import ARKit

// Note: board placement doesn't seem to work when resuming if the app didn't fully quit
// Note: player changes strangely on a new round in unlimited round mode
// Note: see: https://developer.apple.com/documentation/arkit/creating_a_multiuser_ar_experience

struct UserConfig {
    var scaleFactor: Float
    var rotation: Float
    var tank: SCNNode?
}

enum drawerMode : String, Codable {
    case blocks, plainTrigs, coloredTrigs, texturedTrigs
}

struct GameConfig : Codable {
    var numHumans: Int = 1
    var numAIs: Int = 1
    var numRounds: Int = 3
    var mode: drawerMode = .texturedTrigs
    var credit: Int64 = 5000
    var playerNames: [String] = []
    var networked: Bool = false
}

class GameViewController: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var gameConfig = GameConfig()
    var boardDrawer: GameViewDrawer!
    var boardPlaced = false
    var boardSize: Float = 1.0
    var boardScaleFactor: Float = 1.0
    let tankScale: Float = 10
    var candidatePlanes: [SCNNode] = []
    var board = SCNNode()
    var prevTraj = SCNNode()
    var currTraj = SCNNode()
    var gameModel: GameModel = GameModel()
    var users: [UserConfig] = []
    var currentUser = 0
    var humanLeft: Int = 0
    var saveStateController: UIViewController? = nil
    var roundChanged: Bool = false
    var playerNameNode = SCNNode()
    var playerArrowNode = SCNNode()
    var viewIsLoaded = false
    var uiEnabled = false
    
    var networkGameController: NetworkedGameController?
    
    @IBOutlet var tapToSelectLabel: UILabel!
    @IBOutlet var fireButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var exitButton: UIButton!
    @IBOutlet var powerSlider: UISlider!
    @IBOutlet weak var hudStackView: UIStackView!
    @IBOutlet weak var hudBackground: UIView!
    
    @IBOutlet weak var manualTrainButton: UIButton!
    @IBOutlet weak var azimuthLabel: UILabel!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var velocityLabel: UILabel!
    @IBOutlet weak var weaponLabel: UILabel!    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSLog("GameViewController loaded")
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        // see: https://stackoverflow.com/questions/24046164/how-do-i-get-a-reference-to-the-app-delegate-in-swift
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.gameController = self
        
        setupDrawer()
        
        unplaceBoard()
        rotateGesture.delegate = self
        rescaleGesture.delegate = self
        screenDraggingGesture.delegate = self
        
        viewIsLoaded = true
    }
    
    func setupDrawer() {
        // create the game board
        switch gameConfig.mode {
        case .blocks:
            boardDrawer = GameViewBlockDrawer(sceneView: sceneView, model: gameModel, node: board, numPerSide: 50, tankScale: tankScale)
        case .plainTrigs:
            boardDrawer = GameViewTrigDrawer(sceneView: sceneView, model: gameModel, node: board, numPerSide: 100, tankScale: tankScale)
        case .coloredTrigs:
            boardDrawer = GameViewColoredTrigDrawer(sceneView: sceneView, model: gameModel, node: board, numPerSide: 100, tankScale: tankScale)
        case .texturedTrigs:
            boardDrawer = GameViewTexturedTrigDrawer(sceneView: sceneView, model: gameModel, node: board, numPerSide: 200, tankScale: tankScale)
        }
        boardDrawer.setupLighting()
    }
    
    func updateDrawer() {
        boardDrawer.gameModel = gameModel
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Enable horizontal plane detection
        configuration.planeDetection = [.horizontal]
        
        // see: https://blog.markdaws.net/arkit-by-example-part-4-realism-lighting-pbr-b9a0bedb013e
        configuration.isLightEstimationEnabled = true
        
        if let saveStateController = saveStateController as? MenuViewController {
            NSLog("Writing to saveStateController in GameViewController")
            saveStateController.gameState = GameState(model: gameModel, config: gameConfig)
        }
        
        // start a game
        removeTanks()
        if !gameModel.gameStarted && !gameModel.gameOver {
            NSLog("\(#function) starting \(gameConfig.numRounds) round game. (gameStarted=\(gameModel.gameStarted))")
            gameModel.startGame(withConfig: gameConfig)
            updateDrawer()
            // destroy old per user info, as order may have changed
            users = []
                        
            if let networkController = networkGameController {
                NSLog("\(#function): setting up network play")
                networkController.viewController = self
                networkController.startGame()
                networkController.startRound()
            } else {
                NSLog("\(#function): networkGameController not available")
            }
        }
        boardDrawer.updateBoard()
        NSLog("users.count = \(users.count); players.count = \(gameModel.board.players.count)")
        if users.count != gameModel.board.players.count {
            users = [UserConfig](repeating: UserConfig(scaleFactor: 1.0, rotation: 0.0, tank: nil),
                                 count: gameModel.board.players.count)
            currentUser = gameModel.board.currentPlayer
        }
        addTanks()
 
        // set UI to requested state for networked game
        if let _ = networkGameController {
            if uiEnabled {
                enableUI()
            } else {
                disableUI()
            }
        }

        updateUI()

        placeBoardGesture.require(toFail: backupPlaceBoardGesture)
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

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
        NSLog("\(#function): \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        NSLog("\(#function): \(session)")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        NSLog("\(#function): \(session)")
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
        candidatePlanes.append(node)
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
        NSLog("\(#function)")
        guard let gesture = sender as? UIPanGestureRecognizer else { return }
        guard boardDrawer.tankNodes.count > 0 else { return }
        
        if !playerArrowNode.isHidden && gesture.state == .began {
            //NSLog("Hiding player arrow")
            // arrow appear animation
            let arrowHideAction = SCNAction.sequence([.scale(to: 0, duration: 1),
                                                      .hide(),
                                                      .removeFromParentNode()])
            playerArrowNode.runAction(arrowHideAction)
        }

        NSLog("Screen dragged \(gesture).")
        NSLog("velocity: \(gesture.velocity(in: nil)), translation: \(gesture.translation(in: nil))")
        // determine player
        let playerID = gameModel.board.currentPlayer
        
        // get tank aiming values from model
        let tank = gameModel.getTank(forPlayer: playerID)
        let currAzimuth = tank.azimuth
        let currAltitude = tank.altitude
        //NSLog("currAzimuth: \(currAzimuth), currAltitude: \(currAltitude)")

        // update values
        let translation = gesture.translation(in: nil)
        
        let rotationScale: Float = 5
        let newAzimuth = currAzimuth + Float(translation.x) / rotationScale
        let newAltitude = currAltitude - Float(translation.y) / rotationScale

        updateTankNode()
        
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

    func updateTankNode() {
        // find/adjust tank model's aiming
        let playerID = gameModel.board.currentPlayer
        let tankNode = boardDrawer.tankNodes[playerID]
        guard let turretNode = tankNode.childNode(withName: "turret", recursively: true) else { return }
        guard let hingeNode = tankNode.childNode(withName: "barrelHinge", recursively: true) else { return }
        let newAzimuth = gameModel.board.players[playerID].tank.azimuth
        let newAltitude = gameModel.board.players[playerID].tank.altitude
        turretNode.eulerAngles.y = newAzimuth * (Float.pi/180)
        hingeNode.eulerAngles.x = newAltitude * (Float.pi/180)
        //NSLog("newAzimuth: \(newAzimuth), newAltitude: \(newAltitude)")
    }
    
    @IBOutlet var rescaleGesture: UIPinchGestureRecognizer!
    @IBAction func rescaleGesture(_ sender: UIPinchGestureRecognizer) {
        let player = currentUser

        // update view
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
        let player = currentUser
        
        // update view
        board.eulerAngles.y = Float(CGFloat(users[player].rotation) - sender.rotation)
        
        if sender.state == .ended {
            //NSLog("rotate gesture: \(sender.rotation) ended or player \(player)")
            users[player].rotation -= Float(sender.rotation)
            //NSLog("rotation for user \(player) set to \(users[player].rotation)")
        }
    }

    // see: https://stackoverflow.com/questions/30829973/simultaneous-gesture-recognition-for-specific-gestures
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        // allow simultaneous pinching and zooming
        if (gestureRecognizer is UIPinchGestureRecognizer &&
            otherGestureRecognizer is UIRotationGestureRecognizer) {
            return true
        }
        if (otherGestureRecognizer is UIPinchGestureRecognizer &&
            gestureRecognizer is UIRotationGestureRecognizer) {
            return true
        }
        
        // disable panning when pinching and zooming
        if(gestureRecognizer is UIPanGestureRecognizer) {
            return false
        }
        
        return false
    }
    
    // MARK: - UI element actions
    // make this a target for unwinding segues
    @IBAction func unwindToGameScreen(unwindSegue: UIStoryboardSegue) {
        
    }
    
    @IBAction func exitButtonTapped(_ sender: UIButton) {
        NSLog("Exit button tapped")
        disableUI()
        exitButton.isEnabled = false
        exitButton.isHidden = true
        hudStackView.isHidden = true
        hudBackground.isHidden = true

        // see: https://www.andrewcbancroft.com/2015/12/18/working-with-unwind-segues-programmatically-in-swift/

        let alert = UIAlertController(title: "Quit Game?", message: "Current game will be lost if you quit.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Resume", comment: "Default inaction"), style: .default, handler: { _ in
            NSLog("Exit canceled.")
            self.exitButton.isEnabled = true
            self.exitButton.isHidden = false
            self.updateUI()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Quit", comment: "Default action"), style: .default, handler: { _ in
            NSLog("Exiting game!")
            self.doExitGame()
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func doExitGame() {
        gameModel.gameStarted = false
        disableUI()
        unplaceBoard()
        gameModel.gameOver = true
        users = []
        if let saveStateController = saveStateController as? MenuViewController {
            saveStateController.gameState = nil
            saveStateController.removeStateFile()
        }
        if let networkController = networkGameController {
            networkController.disconnect()
        }
        // see: https://www.andrewcbancroft.com/2015/12/18/working-with-unwind-segues-programmatically-in-swift/
        performSegue(withIdentifier: "unwindToMainMenu", sender: self)
    }
    
    @IBAction func fireButtonPressed(_ sender: UIButton) {
        NSLog("Fire button pressed")
        if !playerArrowNode.isHidden {
            NSLog("Hiding player arrow")
            // arrow appear animation
            let arrowHideAction = SCNAction.sequence([.scale(to: 0, duration: 0),
                                                      .hide(),
                                                      .removeFromParentNode()])
            playerArrowNode.runAction(arrowHideAction)
        }
        
        if let networkController = networkGameController {
            NSLog("\(#function) notifying other players via playerAiming(isFiring: true)")
            networkController.playerAiming(isFiring: true)
        }

        disableUI()
        launchProjectile()
    }
    
    @IBAction func skipButtonTapped(_ sender: UIButton) {
        NSLog("Skipping rest of this round")
        skipButton.isHidden = true
        skipButton.isEnabled = false
        gameModel.skipRound()
        if let _ = gameModel.board.players[gameModel.board.currentPlayer].ai {
            finishTurn()
        }
        roundChanged = true
        updateUI()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let dest = segue.destination as? WeaponsViewController {
            dest.gameModel = gameModel
        } else if let dest = segue.destination as? GameOverViewController {
            gameModel.gameStarted = false
            if let saveStateController = saveStateController as? MenuViewController {
                saveStateController.gameState = nil
                saveStateController.removeStateFile()
            }
            dest.players = gameModel.board.players
            dest.gameConfig = gameConfig
        }
    }
    
    @IBAction func powerChanged(_ sender: UISlider) {
        gameModel.setTankPower(power: sender.value)
        //NSLog("set tank power to \(sender.value)")
        updateHUD()
    }
 
    @IBOutlet weak var playerNameLabel: UILabel!
    @IBOutlet weak var playerScoreLabel: UILabel!
    @IBOutlet weak var roundLabel: UILabel!
    
    // MARK: - Helper methods
    func clearAllPlanes() {
        for plane in candidatePlanes {
            plane.isHidden = true
        }
    }
    
    func restoreAllPlanes() {
        for plane in candidatePlanes {
            plane.isHidden = false
        }
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
        geometry.firstMaterial?.diffuse.contents = UIColor.brown

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
        skipButton.isEnabled = false
        skipButton.isHidden = true
        screenDraggingGesture.isEnabled = false
        powerSlider.isHidden = true
        playerNameLabel.isHidden = true
        playerScoreLabel.isHidden = true
        roundLabel.isHidden = true
        hudStackView.isHidden = true
        hudBackground.isHidden = true
        
        // remove board and tanks
        board.removeFromParentNode()
        
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
            
            let tank = player.tank
            tankNode.position = boardDrawer.fromModelSpace(tank.position)
            tankNode.scale = SCNVector3(tankScale,tankScale,tankScale)
            
            NSLog("(re)Adding tank at \(tankNode.position)")
            boardDrawer.tankNodes[i].removeFromParentNode()
            board.addChildNode(tankNode)
            boardDrawer.tankNodes[i] = tankNode
            users[i].tank = tankNode
        }
        NSLog("\(#function) finished")
    }
    
    func removeTanks() {
        guard users.count > 0 else { return }
        for i in 0..<users.count {
            guard let tank = users[i].tank else { continue }
            tank.removeFromParentNode()
            if i < users.count {
                users[i].tank = nil
            }
        }
    }
    
//    func muzzleParameters() -> (muzzlePosition: Vector3, muzzleVelocity: Vector3) {
//        // get location of muzzle
//        let playerID = gameModel.board.currentPlayer
//        let tankNode = boardDrawer.tankNodes[playerID]
//        guard let muzzleNode = tankNode.childNode(withName: "muzzle", recursively: true)
//            else { return (Vector3(),Vector3()) }
//        let position = muzzleNode.convertPosition(muzzleNode.position, to: board)
//
//        // get muzzle velocity
//        let tank = gameModel.getTank(forPlayer: playerID)
//        let power = tank.velocity
//        let azi = tank.azimuth * (Float.pi/180)
//        let alt = tank.altitude * (Float.pi/180)
//
//        let xVel = -power * sin(azi) * cos(alt)
//        let yVel = power * sin(alt)
//        let zVel = -power * cos(azi) * cos(alt)
//
//        //NSLog("tank angles: \(tank.azimuth),\(tank.altitude)")
//        let velocity = SCNVector3(xVel, yVel, zVel)
//
//        // convert to model coordinate space
//        let muzzlePosition = boardDrawer.toModelSpace(position)
//        let muzzleVelocity = boardDrawer.toModelScale(velocity)
//
//        //NSLog("\(#function): returning position: \(muzzlePosition), velocity: \(muzzleVelocity)")
//        return (muzzlePosition, muzzleVelocity)
//    }
    
    func launchProjectile() {
        NSLog("\(#function) started")

        // get muzzle position and velocity
        let playerID = gameModel.board.currentPlayer
        //let (muzzlePosition, muzzleVelocity) = muzzleParameters()
        let (muzzlePosition, muzzleVelocity) = gameModel.muzzleParameters(forPlayer: playerID)
        NSLog("tank at: \(gameModel.board.players[playerID].tank.position)")
        NSLog("tank is: \(gameModel.board.players[playerID].tank)")
        NSLog("\(#function): position: \(muzzlePosition), velocity: \(muzzleVelocity)")

        let fireResult = gameModel.fire(muzzlePosition: muzzlePosition, muzzleVelocity: muzzleVelocity)
        NSLog("\(#function): impact at \(fireResult.trajectories.first!.last!)")

        // record result for AIs
        let tank = gameModel.getTank(forPlayer: gameModel.board.currentPlayer)
        if let ai = gameModel.board.players[fireResult.playerID].ai,
            let impact = gameModel.board.players[fireResult.playerID].prevTrajectory.last {
            // player is an AI
            _ = ai.recordResult(gameModel: gameModel, azimuth: tank.azimuth, altitude: tank.altitude, velocity: tank.velocity,
                              impactX: impact.x, impactY: impact.y, impactZ: impact.z)
        } else {
            // this is a human, remove previous trajectory from board
            prevTraj.isHidden = true
            prevTraj.removeFromParentNode()
        }
        humanLeft = fireResult.humanLeft

        if fireResult.humanLeft > 0 {
            boardDrawer.timeScaling = 3
        }
        
        currTraj.isHidden = true
        currTraj.removeFromParentNode()
        boardDrawer.animateResult(fireResult: fireResult, from: self)
        roundChanged = fireResult.newRound

        if gameConfig.numRounds == 0 && fireResult.humanLeft == 0 {
            roundChanged = true
        }
        
        NSLog("\(#function) finished")
    }
    
    
    func finishTurn() {
        NSLog("\(#function) started")

        // do AI stuff if next player is an AI
        let playerID = gameModel.board.currentPlayer
        if let ai = gameModel.board.players[playerID].ai {
            NSLog("player '\(gameModel.board.players[playerID].name)' is an AI.")
            if humanLeft == 0 {
                boardDrawer.timeScaling *= 1.01
                NSLog("timeScaling now \(boardDrawer.timeScaling)")
            }
            // player is an AI
            disableUI()
            
            var doAImove = false
            if let networkController = networkGameController {
                doAImove = networkController.isLeader
            } else {
                doAImove = true
            }

            if doAImove {
                let (azi, alt, vel) = ai.fireParameters(gameModel: gameModel, players: gameModel.board.players, num: 20)
                NSLog("ai firing parameters, azi,alt,vel: (\(azi),\(alt),\(vel))")
                gameModel.setTankAim(azimuth: azi, altitude: alt)
                gameModel.setTankPower(power: vel)
                let tank = gameModel.board.players[playerID].tank
                NSLog("ai firing parameters, azi,alt,vel: (\(tank.azimuth),\(tank.altitude),\(tank.velocity)) (updated)")
                if let networkController = networkGameController {
                    NSLog("\(#function) notifying other players of AI move via playerAiming(isFiring: true)")
                    networkController.playerAiming(isFiring: true)
                }
                
                updateUI()
                launchProjectile()
            }
        } else {
            // return control to human player
            boardDrawer.timeScaling = 3
            updateUI()
            enableUI()
            
            // restore board
            if let testModel = gameModel as? TestGameModel {
                if testModel.board.currentPlayer % 2 != 0 {
                    testModel.initializeBoard()
                }
            }
            currentUser = playerID
        }
        
//        // save game after each turn
//        if let saveStateController = saveStateController as? MenuViewController {
//            saveStateController.saveStateFile()
//        }

        if let networkController = networkGameController {
            NSLog("\(#function) notifying other players via finishedTurn()")
            networkController.finishedTurn()
        }
        
        NSLog("\(#function) finished")
    }
    
    func enableUI() {
        exitButton.isHidden = false
        exitButton.isEnabled = true
        if boardPlaced {
            fireButton.isHidden = false
            fireButton.isEnabled = true
            skipButton.isHidden = true
            skipButton.isEnabled = false
            hudStackView.isHidden = false
            hudBackground.isHidden = false
            powerSlider.isHidden = false
            powerSlider.isEnabled = true
            manualTrainButton.isHidden = false
            manualTrainButton.isEnabled = true
            screenDraggingGesture.isEnabled = true
            playerNameLabel.isHidden = false
            playerScoreLabel.isHidden = false
            roundLabel.isHidden = false
        }
        
        uiEnabled = true;
    }
    
    func disableUI() {
        // don't mess with exit button here!
        fireButton.isHidden = true
        fireButton.isEnabled = false
        if boardPlaced {
            if humanLeft == 0 && gameModel.gameStarted {
                skipButton.isHidden = false
                skipButton.isEnabled = true
            }
            hudStackView.isHidden = false
            hudBackground.isHidden = false
        }
        powerSlider.isHidden = true
        powerSlider.isEnabled = false
        manualTrainButton.isHidden = true
        manualTrainButton.isEnabled = false
        screenDraggingGesture.isEnabled = false
        playerNameLabel.isHidden = false
        playerScoreLabel.isHidden = false
        roundLabel.isHidden = false
        
        uiEnabled = false;
    }
    
    func updateUI() {
        guard viewIsLoaded else { return }
        guard boardPlaced else { return }

        //NSLog("\(#function) started")
        if roundChanged || gameModel.gameOver {
            NSLog("round change detected, \(humanLeft) humans left")
            roundChanged = false
            removeTanks()
            if gameModel.gameOver {
                NSLog("round \(gameModel.board.currentRound) > \(gameModel.board.totalRounds), game over!")
                gameModel.gameStarted = false
                performSegue(withIdentifier: "Game Over", sender: nil)
                return
            }
            // Game model might change next player to start new round (e.g. unlimited rounds mode)
            currentUser = gameModel.board.currentPlayer
            
            NSLog("Starting round \(gameModel.board.currentRound) of \(gameModel.board.currentRound).")
            addTanks()
            
            // save game at start of each new round
            if let saveStateController = saveStateController as? MenuViewController {
                saveStateController.saveStateFile()
            }

        }
        humanLeft = gameConfig.numHumans
        
        // make sure power slider matches player
        let playerID = gameModel.board.currentPlayer
        let player = gameModel.board.players[playerID]
        let currentPower = gameModel.board.players[playerID].tank.velocity
        powerSlider.minimumValue = 0
        powerSlider.maximumValue = gameModel.maxPower
        powerSlider.setValue(currentPower, animated: false)
        
        let gameBoard = gameModel.board
        if let _ = player.ai {
            // player is an AI
        } else {
            // determine minimal rotation
            let currAngle = board.eulerAngles.y
            let destAngle = users[playerID].rotation
            let currAngleClean = atan2(sin(currAngle),cos(currAngle))
            let destAngleClean = atan2(sin(destAngle),cos(destAngle))
            var angleDiff = destAngleClean - currAngleClean
            if angleDiff > Float.pi {
                angleDiff -= 2*Float.pi
            } else if angleDiff < -Float.pi {
                angleDiff += 2*Float.pi
            }
            NSLog("old angle was \(users[playerID].rotation), board at \(board.eulerAngles.y)")
            users[playerID].rotation = board.eulerAngles.y + angleDiff
            NSLog("new angle is \(users[playerID].rotation), diff is \(angleDiff)")

            // update scale and rotation for player
            let scaleNode = board
            let rotationAnimation = CABasicAnimation(keyPath: "eulerAngles.y")
            rotationAnimation.fromValue = scaleNode.eulerAngles.y
            rotationAnimation.toValue = users[playerID].rotation
            rotationAnimation.beginTime = 0
            rotationAnimation.duration = 1
            scaleNode.addAnimation(rotationAnimation, forKey: "Player Rotation")
            scaleNode.eulerAngles.y = users[playerID].rotation
            //NSLog("rotating to \(rotationAnimation.toValue!) for user \(playerID)")
            
            let rescaleAnimation = CABasicAnimation(keyPath: "scale")
            rescaleAnimation.fromValue = scaleNode.scale
            let newFactor = boardScaleFactor * users[playerID].scaleFactor
            let newScale = SCNVector3(newFactor,newFactor,newFactor)
            rescaleAnimation.toValue = newScale
            rescaleAnimation.beginTime = 0
            rescaleAnimation.duration = 1
            scaleNode.addAnimation(rescaleAnimation, forKey: "Player Scaling")
            scaleNode.scale = newScale
            //NSLog("scaling to \(rescaleAnimation.toValue!) for user \(playerID)")
        }
        
        playerNameLabel.text = "\(player.name)"
        playerScoreLabel.text = "Score:\n\(player.score)"
        if gameBoard.totalRounds > 0 {
            roundLabel.text = "Round:\n\(gameBoard.currentRound) of \(gameBoard.totalRounds)"
        } else {
            roundLabel.text = "Round:\n\(gameBoard.currentRound)"
        }

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
            
            let tank = player.tank
            guard let turretNode = tankNode.childNode(withName: "turret", recursively: true) else { continue }
            guard let hingeNode = tankNode.childNode(withName: "barrelHinge", recursively: true) else { continue }
            guard let barrelNode = tankNode.childNode(withName: "barrel", recursively: true) else { continue }
            turretNode.eulerAngles.y = tank.azimuth * (Float.pi/180)
            hingeNode.eulerAngles.x = tank.altitude * (Float.pi/180)

            // set colors to highlight current player
            var color = UIColor.darkGray
            if gameModel.board.totalRounds == 0 {
                // For unlimited rounds, make AIs and Humans distinctive
                if player.ai != nil {
                    // Als
                    color = #colorLiteral(red: 1, green: 0.1491314173, blue: 0, alpha: 1)
                } else {
                    // humans
                    color = #colorLiteral(red: 0.004859850742, green: 0.09608627111, blue: 0.5749928951, alpha: 1)
                }
            }
            var showAimGuide = false
            var showWind = false
            var showPlayerArrow = false
            if gameModel.board.currentPlayer == i {
                color = UIColor.gray
                showAimGuide = true
                showWind = true
                // show player arrow if there is no prevTraj
                if player.prevTrajectory.count <= 0 && player.ai == nil {
                    showPlayerArrow = true
                }
            }
            tankNode.geometry?.firstMaterial?.diffuse.contents = color
            turretNode.geometry?.firstMaterial?.diffuse.contents = color
            barrelNode.geometry?.firstMaterial?.diffuse.contents = color
            
            // set up aim guide
            guard let aimGuide = barrelNode.childNode(withName: "aimGuide", recursively: true) else { continue }
            guard let lastBall = aimGuide.childNode(withName: "lastBall", recursively: true) else { continue }
            if showAimGuide {
                aimGuide.isHidden = false
                let moveAction = SCNAction.repeatForever(.sequence([.move(to: SCNVector3(0,-1,0), duration: 1),
                                                                    .move(to: SCNVector3(0,0,0), duration: 0)]))
                aimGuide.runAction(moveAction)
                
                let fadeAction = SCNAction.repeatForever(.sequence([.fadeIn(duration: 0),
                                                                    .fadeOut(duration: 1)]))
                lastBall.runAction(fadeAction)
            } else {
                aimGuide.isHidden = true
                aimGuide.removeAllActions()
                lastBall.removeAllActions()
            }
            
            // adjust wind indicator
            guard let windArrow = tankNode.childNode(withName: "windArrow", recursively: true) else { continue }
            guard let arrow = windArrow.childNode(withName: "arrow", recursively: true) else { continue }
            if showWind {
                NSLog("setting up wind arrow for player \(i)")
                windArrow.eulerAngles.y = -gameBoard.windDir * (Float.pi / 180)
                arrow.scale.x = 0.25 + 2 * (gameBoard.windSpeed / gameModel.maxWindSpeed)
                windArrow.isHidden = false
            } else {
                windArrow.isHidden = true
            }
            
            // show player arrow
            if showPlayerArrow {
                NSLog("setting up player arrow for \(player.name)")
                // draw arrow pointing to current player
                let arrowScene = SCNScene(named: "art.scnassets/DownArrow.scn")
                guard let labeledArrowNode = arrowScene?.rootNode.childNode(withName: "LabeledArrow", recursively: true) else { break }
                guard let arrowNode = arrowScene?.rootNode.childNode(withName: "Arrow", recursively: true) else { break }
                guard let labelNode = arrowScene?.rootNode.childNode(withName: "Label", recursively: true) else { break }

                // set label
                for label in labelNode.childNodes {
                    label.removeFromParentNode()
                }
                let textGeometry = SCNText(string: player.name, extrusionDepth: 2)
                playerNameNode = SCNNode(geometry: textGeometry)
                let (minExtent, maxExtent) = playerNameNode.boundingBox
                playerNameNode.position = SCNVector3( -(maxExtent.x+minExtent.x)/2, -(maxExtent.y+minExtent.y)/2, -(maxExtent.z+minExtent.z)/2)
                playerNameNode.position.y = 0
                playerNameNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
                labelNode.addChildNode(playerNameNode)
                let labelScale: CGFloat = 0.1
                labelNode.scale = SCNVector3(labelScale,labelScale,labelScale)
                

                // label spin animation
                let nameSpinAction = SCNAction.repeatForever(.rotateBy(x: 0, y: CGFloat(-Float.pi*2), z: 0, duration: 2))
                labelNode.runAction(nameSpinAction)
                labelNode.isHidden = false

                // arrow spin animation
                let arrowSpinAction = SCNAction.repeatForever(.rotateBy(x: 0, y: CGFloat(Float.pi*2), z: 0, duration: 4))
                arrowNode.runAction(arrowSpinAction)
                arrowNode.scale = SCNVector3(0.5,1,0.5)
                arrowNode.isHidden = false

                // arrow appear animation
//                let arrowAppearAction = SCNAction.sequence([.scale(to: 0, duration: 0),
//                                                             .unhide(),
//                                                             .scale(to: 2, duration: 1)])
//                labeledArrowNode.runAction(arrowAppearAction)
                labeledArrowNode.isHidden = false
                
                let modelTankPos = boardDrawer.toModelSpace(tankNode.position)
                let elevation = gameModel.getElevation(longitude: Int(modelTankPos.x),
                                                       latitude: Int(modelTankPos.y))
                NSLog("\(#function): name: \(player.name), tankNode.position.y: \(tankNode.position.y), elevation: \(elevation)")
                let arrowPosition = SCNVector3(tankNode.position.x,
                                               max(tankNode.position.y, elevation) + 50,
                                               tankNode.position.z)
                labeledArrowNode.position = arrowPosition
                labeledArrowNode.scale = SCNVector3(30,30,30)
                playerArrowNode.removeFromParentNode()
                board.addChildNode(labeledArrowNode)
                playerArrowNode = labeledArrowNode
            }
        }
        
        updateHUD()
        
        // show previous trajectory for user
        if player.prevTrajectory.count > 0 {
            boardDrawer.addTrajectory(trajectory: player.prevTrajectory, toNode: prevTraj, color: UIColor.yellow)
            if prevTraj.parent == nil {
                board.addChildNode(prevTraj)
                prevTraj.isHidden = false
            }
        } else {
            prevTraj.isHidden = true
            prevTraj.removeFromParentNode()
        }
        
        // update board
        boardDrawer.updateBoard()
   
        if let _ = gameModel.board.players[playerID].ai {
            // player is an AI
            disableUI()
        } else {
            // player is human
            enableUI()
        }
        
        //NSLog("\(#function) finished")
    }
    
    func drawCurrentTrajectory() {
        //let (muzzlePosition, muzzleVelocity) = muzzleParameters()
        let playerID = gameModel.board.currentPlayer
        let (muzzlePosition, muzzleVelocity) = gameModel.muzzleParameters(forPlayer: playerID)
        let playerTraj = gameModel.computeTrajectory(muzzlePosition: muzzlePosition,
                                                     muzzleVelocity: muzzleVelocity,
                                                     withTimeStep: 1/6.0)
        boardDrawer.addTrajectory(trajectory: playerTraj, toNode: currTraj, color: UIColor.lightGray)
        currTraj.isHidden = false
        if currTraj.parent == nil {
            board.addChildNode(currTraj)
        }
    }

    func updateHUD() {
        NSLog("\(#function)")
        guard viewIsLoaded else { return }

        let board = gameModel.board
        let player = board.players[board.currentPlayer]
        let tank = player.tank
        
        azimuthLabel.text = String(format: "%.02fº", tank.azimuth)
        altitudeLabel.text = String(format: "%.02fº", tank.altitude)
        velocityLabel.text = String(format: "%.02f m/s", tank.velocity)

        var weaponName = gameModel.weaponsList[player.weaponID].name
        let sizeStr = gameModel.weaponsList[player.weaponID].sizes[player.weaponSizeID].name
        if sizeStr != "" && sizeStr.lowercased() != "n/a" {
            weaponName.append(" (\(sizeStr))")
        }
        weaponLabel.text = weaponName
        
        // update targeting computer
        if player.useTargetingComputer {
            drawCurrentTrajectory()
        } else {
            currTraj.removeFromParentNode()
        }

        // update on-screen tank
        updateTankNode()

        if let networkController = networkGameController {
            NSLog("has networkGameController: \(networkController)")
            NSLog("\(#function) notifying other players via playerAiming()")
            networkController.playerAiming()
            NSLog("currentPlayer: \(gameModel.board.currentPlayer), myPlayerID: \(networkGameController?.myPlayerID ?? -1)")
            if gameModel.board.currentPlayer == networkGameController?.myPlayerID {
                enableUI()
            } else {
                disableUI()
            }
        }
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
