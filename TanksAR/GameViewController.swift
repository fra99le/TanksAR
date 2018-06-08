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

class GameViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var boardPlaced = false
    var boardSize: Float = 1.0
    var candidatePlanes: [SCNNode] = []
    var board: SCNNode? = nil
    var gameModel = GameModel()
    var tankNodes: [SCNNode] = []
    var trajNode: SCNNode? = nil
    
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
        
        print("plane extents are \(planeAnchor.extent.x),\(planeAnchor.extent.z).")
        let geometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        node.geometry = geometry
        
        node.eulerAngles.x = -Float.pi / 2
        node.opacity = 0.25
        
        return node
    }

    @IBOutlet var placeBoardGesture: UITapGestureRecognizer!
    @IBAction func screenTapped(_ sender: UIGestureRecognizer) {
        let touchLocation = sender.location(in: sceneView)
        print("Screen tapped at \(touchLocation)")
        let hitTestResult = sceneView.hitTest(touchLocation, types: [.existingPlaneUsingGeometry])
        
        for result in hitTestResult {
            if !boardPlaced {
                if (result.anchor as? ARPlaneAnchor) != nil {
                    placeBoard(result)
                    break
                }
            } else {
                print("Board already placed")
            }
        }
    }

    @IBOutlet var screenDraggingGesture: UIPanGestureRecognizer!
    @IBAction func screenDragged(_ sender: UIGestureRecognizer) {
        guard let gesture = sender as? UIPanGestureRecognizer else { return }
        guard tankNodes.count > 0 else { return }
        
        print("Screen dragged \(gesture).")
        print("velocity: \(gesture.velocity(in: nil)), translation: \(gesture.translation(in: nil))")
        // determine player
        let player = gameModel.board.currentPlayer
        let tankNode = tankNodes[player]
        
        // get tank aiming values from model
        let tank = gameModel.getTank(forPlayer: player)
        let currAzimuth = tank.azimuth
        let currAltitude = tank.altitude
        print("currAzimuth: \(currAzimuth), currAltitude: \(currAltitude)")

        // update values
        let translation = gesture.translation(in: nil)
        let newAzimuth = currAzimuth + Float(translation.x)
        let newAltitude = currAltitude - Float(translation.y)

        // find/adjust tank model's aiming
        guard let turretNode = tankNode.childNode(withName: "turret", recursively: true) else { return }
        guard let hingeNode = tankNode.childNode(withName: "barrelHinge", recursively: true) else { return }
        turretNode.eulerAngles.y = newAzimuth * (Float.pi/180)
        hingeNode.eulerAngles.x = newAltitude * (Float.pi/180)
        print("newAzimuth: \(newAzimuth), newAltitude: \(newAltitude)")
        
        if gesture.state == .ended {
            gameModel.setTankAim(azimuth: newAzimuth, altitude: newAltitude)
        }
    }

    @IBAction func powerChanged(_ sender: UISlider) {
        gameModel.setTankPower(power: sender.value)
        print("set tank power to \(sender.value)")
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
        
        print("Placing board at \(withExtentOf)")
        print("plane extents are \(withExtentOf.extent.x),\(withExtentOf.extent.z).")

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

            print("Adding tank at \(tankNode.position)")
            board?.addChildNode(tankNode)
            tankNodes.append(tankNode)
        }
    }
    
    func addBoard() {
        // use cubes until I can sort out actual Meshes.
        let numPerSide = 50
        
        let edgeSize = CGFloat(gameModel.board.boardSize / numPerSide)
        
        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                // determine location of segment
                let xPos = CGFloat(i)*edgeSize + edgeSize/2
                let zPos = CGFloat(j)*edgeSize + edgeSize/2
                let elevation = gameModel.getElevation(longitude: Int(xPos), latitude: Int(zPos))
                let yPos = CGFloat(elevation/2)
                let ySize = CGFloat(elevation)

                // create a cube
                let blockNode = SCNNode()
                let geometry = SCNBox(width: edgeSize, height: ySize, length: edgeSize, chamferRadius: 0)
                blockNode.position = SCNVector3(xPos-CGFloat(gameModel.board.boardSize/2),
                                                yPos,
                                                zPos-CGFloat(gameModel.board.boardSize/2))

                geometry.firstMaterial?.diffuse.contents = UIColor.green
                blockNode.geometry = geometry

                // add to board
                board?.addChildNode(blockNode)
            }
        }
    }
    
    // MARK: UI elements
    @IBAction func fireButtonPressed(_ sender: UIButton) {
        print("Fire button pressed")
        launchProjectile()
        updateUI()
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
        print("tank angles: \(tank.azimuth),\(tank.altitude)")
        print("angles in radians: \(azi),\(alt)")
        print("velocity: \(xVel),\(yVel),\(zVel)")
        print("position: \(position)")
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
        print("view pos: \(position)")
        print("view vel: \(velocity)")
        print("model pos: \(muzzlePosition)")
        print("model vel: \(muzzleVelocity)")

        let fireResult = gameModel.fire(muzzlePosition: muzzlePosition, muzzleVelocity: muzzleVelocity)
        
        // show trajectory
        if let oldTraj = trajNode {
            oldTraj.removeFromParentNode()
            trajNode = nil
        }
        trajNode = SCNNode()
        for position in fireResult.trajectory {
            let posNode = SCNNode(geometry: SCNSphere(radius: 10))
            posNode.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            // convert back to view coordinates
            posNode.position.x = position.x - Float(gameModel.board.boardSize/2)
            posNode.position.y = position.z
            posNode.position.z = position.y - Float(gameModel.board.boardSize/2)
            trajNode?.addChildNode(posNode)
            //print("trajectory position: \(position)")
        }
        board?.addChildNode(trajNode!)
    }
    
    func updateUI() {
        guard boardPlaced else { return }

        // make sure power slider matches player
        let currentPower = gameModel.board.players[gameModel.board.currentPlayer].tank.velocity
        powerSlider.setValue(currentPower, animated: false)
        
        // update all tanke turrets

    }
}
