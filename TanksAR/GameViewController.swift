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

enum drawerMode : String, Codable {
    case blocks, plainTrigs, coloredTrigs, texturedTrigs
}

struct GameConfig : Codable {
    var numHumans: Int = 0
    var numAIs: Int = 0
    var numRounds: Int = 0
    var mode: drawerMode = .blocks
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
    var humanLeft: Int {
        let players = gameModel.board.players
        // count human players left
        var num = 0
        for player in players {
            if let _ = player.ai {
                // player is an AI
            } else {
                if player.hitPoints > 0 {
                    num += 1
                }
            }
        }
        NSLog("\(num) humans left")
        return num
    }
    var saveStateController: UIViewController? = nil
    var roundChanged: Bool = false
    var gameOver = false
    
    @IBOutlet var tapToSelectLabel: UILabel!
    @IBOutlet var fireButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var exitButton: UIButton!
    @IBOutlet var powerSlider: UISlider!
    @IBOutlet weak var hudStackView: UIStackView!
    
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
        
        // create the game board
        switch gameConfig.mode {
        case .blocks:
            boardDrawer = GameViewBlockDrawer(sceneView: sceneView, model: gameModel, node: board, numPerSide: 50)
        case .plainTrigs:
            boardDrawer = GameViewTrigDrawer(sceneView: sceneView, model: gameModel, node: board, numPerSide: 100)
        case .coloredTrigs:
            boardDrawer = GameViewColoredTrigDrawer(sceneView: sceneView, model: gameModel, node: board, numPerSide: 100)
        case .texturedTrigs:
            boardDrawer = GameViewTexturedTrigDrawer(sceneView: sceneView, model: gameModel, node: board, numPerSide: 200)
        }
        boardDrawer.setupLighting()
        
        unplaceBoard()
        rotateGesture.delegate = self
        rescaleGesture.delegate = self
        screenDraggingGesture.delegate = self
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Enable horizontal plane detection
        configuration.planeDetection = [.horizontal]
        
        // see: https://blog.markdaws.net/arkit-by-example-part-4-realism-lighting-pbr-b9a0bedb013e
        configuration.isLightEstimationEnabled = true
        
        // cause board placement to occur when view reappears
        // this causes problems with the weapons view
        //unplaceBoard()
        //updateUI()
    
        if let saveStateController = saveStateController as? MenuViewController {
            NSLog("Writing to saveStateController in GameViewController")
            saveStateController.gameState = GameState(model: gameModel, config: gameConfig)
        }
        
        // start a game
        NSLog("\(#function) starting \(gameConfig.numRounds) round game. (gameStarted=\(gameModel.gameStarted))")
        if !gameModel.gameStarted && !gameOver {
            gameModel.startGame(numPlayers: gameConfig.numHumans, numAIs: gameConfig.numAIs, rounds: gameConfig.numRounds)
            gameModel.gameStarted = true
        }
        boardDrawer.updateBoard()
        NSLog("users.count = \(users.count); players.count = \(gameModel.board.players.count)")
        if users.count != gameModel.board.players.count {
            users = [UserConfig](repeating: UserConfig(scaleFactor: 1.0, rotation: 0.0, tank: nil),
                                 count: gameModel.board.players.count)
            currentUser = gameModel.board.currentPlayer
        }
        removeTanks()
        addTanks()
        
        updateUI()

        placeBoardGesture.require(toFail: backupPlaceBoardGesture)
        //screenDraggingGesture.require(toFail: rotateGesture)
        
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
        
        // see: https://www.andrewcbancroft.com/2015/12/18/working-with-unwind-segues-programmatically-in-swift/

        let alert = UIAlertController(title: "Quit Game?", message: "Current game will be lost if you quit.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Resume", comment: "Default inaction"), style: .default, handler: { _ in
            NSLog("Exit canceled.")
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
        gameOver = true
        users = []
        if let saveStateController = saveStateController as? MenuViewController {
            saveStateController.gameState = nil
            saveStateController.removeStateFile()
        }
        // see: https://www.andrewcbancroft.com/2015/12/18/working-with-unwind-segues-programmatically-in-swift/
        performSegue(withIdentifier: "unwindToMainMenu", sender: self)
    }
    
    @IBAction func fireButtonPressed(_ sender: UIButton) {
        NSLog("Fire button pressed")
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
        for i in 0..<gameModel.board.players.count {
            guard let tank = users[i].tank else { continue }
            tank.removeFromParentNode()
            if i < users.count {
                users[i].tank = nil
            }
        }
    }
    
    func muzzleParameters() -> (muzzlePosition: Vector3, muzzleVelocity: Vector3) {
        // get location of muzzle
        let tankNode = boardDrawer.tankNodes[gameModel.board.currentPlayer]
        guard let muzzleNode = tankNode.childNode(withName: "muzzle", recursively: true)
            else { return (Vector3(),Vector3()) }
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
        let muzzlePosition = boardDrawer.toModelSpace(position)
        let muzzleVelocity = boardDrawer.toModelScale(velocity)
        
        return (muzzlePosition, muzzleVelocity)
    }
    
    func launchProjectile() {
        NSLog("\(#function) started")

        // get muzzle position and velocity
        let (muzzlePosition, muzzleVelocity) = muzzleParameters()
        
        let fireResult = gameModel.fire(muzzlePosition: muzzlePosition, muzzleVelocity: muzzleVelocity)
        
        // record result for AIs
        let tank = gameModel.getTank(forPlayer: gameModel.board.currentPlayer)
        if let ai = gameModel.board.players[fireResult.playerID].ai,
            let impact = fireResult.trajectory.last {
            // player is an AI
            ai.recordResult(gameModel: gameModel, azimuth: tank.azimuth, altitude: tank.altitude, velocity: tank.velocity,
                              impactX: impact.x, impactY: impact.y, impactZ: impact.z)
        }

        if humanLeft > 0 {
            boardDrawer.timeScaling = 3
        }
        
        currTraj.removeFromParentNode()
        boardDrawer.animateResult(fireResult: fireResult, from: self)
        roundChanged = fireResult.newRound
        
        NSLog("\(#function) finished")
    }
    
    
//    func animationDidStart(_ anim: CAAnimation) {
//        NSLog("Animation started")
//    }
//    
//    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
//        NSLog("Animation stopped (finished: \(finished))\n\n\n")
//        //NSLog("\tbegan at: \(animation.beginTime), with duration: \(animation.duration)")
//
//        finishTurn()
//    }
    
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
            let (azi, alt, vel) = ai.fireParameters(gameModel: gameModel, players: gameModel.board.players)
            NSLog("ai firing parameters, azi,alt,vel: (\(azi),\(alt),\(vel))")
            gameModel.setTankAim(azimuth: azi, altitude: alt)
            gameModel.setTankPower(power: vel)
            let tank = gameModel.board.players[gameModel.board.currentPlayer].tank
            NSLog("ai firing parameters, azi,alt,vel: (\(tank.azimuth),\(tank.altitude),\(tank.velocity)) (updated)")
            updateUI()
            launchProjectile()
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
            currentUser = gameModel.board.currentPlayer
        }

        NSLog("\(#function) finished")
    }
    
    func enableUI() {
        exitButton.isEnabled = true
        exitButton.isHidden = false
        fireButton.isHidden = false
        fireButton.isEnabled = true
        skipButton.isHidden = true
        skipButton.isEnabled = false
        powerSlider.isHidden = false
        powerSlider.isEnabled = true
        screenDraggingGesture.isEnabled = true
        manualTrainButton.isEnabled = true
        manualTrainButton.isHidden = false
        hudStackView.isHidden = false
        playerNameLabel.isHidden = false
        playerScoreLabel.isHidden = false
        roundLabel.isHidden = false
    }
    
    func disableUI() {
        // don't mess with exit button here!
        fireButton.isHidden = true
        fireButton.isEnabled = false
        if humanLeft == 0 {
            skipButton.isEnabled = true
            skipButton.isHidden = false
        }
        powerSlider.isHidden = true
        powerSlider.isEnabled = false
        screenDraggingGesture.isEnabled = false
        manualTrainButton.isEnabled = false
        manualTrainButton.isHidden = true
        hudStackView.isHidden = false
        playerNameLabel.isHidden = false
        playerScoreLabel.isHidden = false
        roundLabel.isHidden = false
    }
    
    func updateUI() {
        guard boardPlaced else { return }

        //NSLog("\(#function) started")
        if roundChanged {
            NSLog("round change detected")
            if gameModel.board.currentRound > gameModel.board.totalRounds {
                NSLog("round \(gameModel.board.currentRound) > \(gameModel.board.totalRounds), game over!")
                gameOver = true
                gameModel.gameStarted = false
                performSegue(withIdentifier: "Game Over", sender: nil)
                return
            }
            NSLog("Starting round \(gameModel.board.currentRound) of \(gameModel.board.currentRound).")
            removeTanks()
            addTanks()
            roundChanged = false
            
            // save game at start of each new round
            if let saveStateController = saveStateController as? MenuViewController {
                saveStateController.saveStateFile()
            }

        }
        
        // make sure power slider matches player
        let currentPower = gameModel.board.players[gameModel.board.currentPlayer].tank.velocity
        powerSlider.minimumValue = 0
        powerSlider.maximumValue = gameModel.maxPower
        powerSlider.setValue(currentPower, animated: false)
        
        let gameBoard = gameModel.board
        let player = gameBoard.players[gameBoard.currentPlayer]
        if let _ = player.ai {
            // player is an AI
        } else {
            // determine minimal rotation
            let currAngle = board.eulerAngles.y
            let destAngle = users[gameModel.board.currentPlayer].rotation
            let currAngleClean = atan2(sin(currAngle),cos(currAngle))
            let destAngleClean = atan2(sin(destAngle),cos(destAngle))
            var angleDiff = destAngleClean - currAngleClean
            if angleDiff > Float.pi {
                angleDiff -= 2*Float.pi
            } else if angleDiff < -Float.pi {
                angleDiff += 2*Float.pi
            }
            NSLog("old angle was \(users[gameModel.board.currentPlayer].rotation), board at \(board.eulerAngles.y)")
            users[gameModel.board.currentPlayer].rotation = board.eulerAngles.y + angleDiff
            NSLog("new angle is \(users[gameModel.board.currentPlayer].rotation), diff is \(angleDiff)")

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
        }
        
        playerNameLabel.text = "\(player.name)"
        playerScoreLabel.text = "Score:\n\(player.score)"
        roundLabel.text = "Round:\n\(gameBoard.currentRound) of \(gameBoard.totalRounds)"

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
            var showAimGuide = false
            var showWind = false
            if gameModel.board.currentPlayer == i {
                color = UIColor.gray
                showAimGuide = true
                showWind = true
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
        }
        
        updateHUD()
        
        // show previous trajectory for user
        prevTraj.removeFromParentNode()
        prevTraj = SCNNode()
        addTrajectory(trajectory: player.prevTrajectory, toNode: prevTraj, color: UIColor.yellow)
        board.addChildNode(prevTraj)
        
        // update board
        boardDrawer.updateBoard()
   
        if let _ = gameModel.board.players[gameModel.board.currentPlayer].ai {
            // player is an AI
            disableUI()
        } else {
            // player is human
            enableUI()
        }
        
        //NSLog("\(#function) finished")
    }
    
    func drawCurrentTrajectory() {
        currTraj.removeFromParentNode()
        currTraj = SCNNode()
        
        let (muzzlePosition, muzzleVelocity) = muzzleParameters()
        let playerTraj = gameModel.computeTrajectory(muzzlePosition: muzzlePosition,
                                                     muzzleVelocity: muzzleVelocity,
                                                     withTimeStep: 1/3.0)
        addTrajectory(trajectory: playerTraj, toNode: currTraj, color: UIColor.lightGray)
        board.addChildNode(currTraj)
    }
    
    func addTrajectory(trajectory: [Vector3], toNode: SCNNode, color: UIColor) {
        let segments = 20
        if trajectory.count > 2 {
            var prevPos: Vector3 = trajectory.first!
            for i in 1..<segments {
                let newIndex = Int(Float(i) * Float(trajectory.count) / Float(segments))
                let newPos = trajectory[newIndex]
                
                let joint = SCNNode(geometry: SCNSphere(radius: CGFloat(0.25*tankScale)))
                joint.geometry?.firstMaterial?.diffuse.contents = color
                joint.position = boardDrawer.fromModelSpace(newPos)
                toNode.addChildNode(joint)
                
                addCylinder(from: prevPos, to: newPos, toNode: toNode, color: color)
                prevPos = newPos
            }
            addCylinder(from: prevPos, to: trajectory.last!, toNode: toNode, color: color)
        }
        
    }
    
    func addCylinder(from: Vector3, to: Vector3, toNode: SCNNode, color: UIColor) {
        let cylinder = SCNNode()
        
        //NSLog("Adding cylinder from \(from) to \(to).")
        
        let length = gameModel.distance(from: from, to: to)
        cylinder.geometry = SCNCylinder(radius: CGFloat(0.25*tankScale), height: CGFloat(length))
        cylinder.geometry?.firstMaterial?.diffuse.contents = color
        
        // get orientation
        let viewTo = boardDrawer.fromModelSpace(to)
        let viewFrom = boardDrawer.fromModelSpace(from)
        let diff = SCNVector3(viewTo.x - viewFrom.x, viewTo.y - viewFrom.y, viewTo.z - viewFrom.z)
        
        let angle1 = atan2(diff.y, sqrt(diff.z*diff.z + diff.x*diff.x))
        let angle2 = atan2(diff.z, diff.x)
        //NSLog("diff: \(diff), angles: \(angle1*180/Float.pi),\(angle2*180/Float.pi)")
        
        cylinder.eulerAngles.z = Float.pi / 2 - angle1
        
        let gimble = SCNNode()
        gimble.addChildNode(cylinder)
        gimble.eulerAngles.y = Float.pi - angle2
        
        // get position of cylinder's gimble
        let sum = vectorAdd(to, from)
        let mid = vectorScale(sum, by: 0.5)
        gimble.position = boardDrawer.fromModelSpace(mid)
        
        toNode.addChildNode(gimble)
    }

    func updateHUD() {
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
