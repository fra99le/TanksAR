//
//  GameViewController.swift
//  FakeARtillery
//
//  Created by Bryan Franklin on 9/9/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        viewIsLoaded = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    var gameModel = GameModel()
    var networkGameController: NetworkedGameController!
    var viewIsLoaded = false
    var uiEnabled = false
    
    @IBOutlet weak var mapImageView: UIImageView!
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var fireButton: UIButton!
    
    @IBAction func fireButtonTapped(_ sender: UIButton) {
        NSLog("\(#function)")
        if let networkController = networkGameController {
            networkController.playerAiming(isFiring: true)
        }
        launchProjectile()
        updateUI()
        updateInfo("Fired Projectile")
    }
    
    @IBOutlet var screenDraggingGesture: UIPanGestureRecognizer!
    @IBAction func screenDragged(_ sender: UIGestureRecognizer) {
        NSLog("\(#function)")
        guard let gesture = sender as? UIPanGestureRecognizer else { return }
        guard gameModel.gameStarted else { return }
        //guard boardDrawer.tankNodes.count > 0 else { return }
        
        NSLog("Screen dragged \(gesture).")
        NSLog("velocity: \(gesture.velocity(in: nil)), translation: \(gesture.translation(in: nil))")
        // determine player
        let playerID = networkGameController.myPlayerID
        //let tankNode = boardDrawer.tankNodes[playerID]
        
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
        
        // find/adjust tank model's aiming
        //guard let turretNode = tankNode.childNode(withName: "turret", recursively: true) else { return }
        //guard let hingeNode = tankNode.childNode(withName: "barrelHinge", recursively: true) else { return }
        //turretNode.eulerAngles.y = newAzimuth * (Float.pi/180)
        //hingeNode.eulerAngles.x = newAltitude * (Float.pi/180)
        //NSLog("newAzimuth: \(newAzimuth), newAltitude: \(newAltitude)")
        
        if gesture.state == .ended {
            gameModel.setTankAim(azimuth: newAzimuth, altitude: newAltitude, for: playerID)
            if let networkController = networkGameController {
                networkController.playerAiming()
            }
            updateHUD()
        } else {
            // hack to allow realtime updating of HUD
            gameModel.setTankAim(azimuth: newAzimuth, altitude: newAltitude, for: playerID)
            if let networkController = networkGameController {
                networkController.playerAiming()
            }
            updateHUD()
            gameModel.setTankAim(azimuth: currAzimuth, altitude: currAltitude, for: playerID)
        }
    }

    @IBOutlet weak var powerSlider: UISlider!
    @IBAction func powerSliderChanged(_ sender: UISlider) {
        guard gameModel.gameStarted else { return }

        let playerID = networkGameController.myPlayerID
        gameModel.setTankPower(power: sender.value, for: playerID)
        updateInfo("Power Changed")
        if let networkController = networkGameController {
            networkController.playerAiming()
        }
        updateHUD()
    }
    
    func launchProjectile() {
        NSLog("\(#function) started")
        
        // get muzzle position and velocity
        let playerID = gameModel.board.currentPlayer
        let (muzzlePosition, muzzleVelocity) = gameModel.muzzleParameters(forPlayer: playerID)
        NSLog("tank at: \(gameModel.board.players[playerID].tank.position)")
        NSLog("tank is: \(gameModel.board.players[playerID].tank)")
        NSLog("\(#function): position: \(muzzlePosition), velocity: \(muzzleVelocity)")

        let fireResult = gameModel.fire(muzzlePosition: muzzlePosition, muzzleVelocity: muzzleVelocity)
        NSLog("\(#function): impact at \(String(describing: fireResult.trajectories.first?.last!))")
        
        // record result for AIs
        let tank = gameModel.getTank(forPlayer: gameModel.board.currentPlayer)
        if let ai = gameModel.board.players[fireResult.playerID].ai,
            let impact = gameModel.board.players[fireResult.playerID].prevTrajectory.last {
            // player is an AI
            _ = ai.recordResult(gameModel: gameModel, azimuth: tank.azimuth, altitude: tank.altitude, velocity: tank.velocity,
                                impactX: impact.x, impactY: impact.y, impactZ: impact.z)
        } else {
            // this is a human, remove previous trajectory from board
            //prevTraj.isHidden = true
            //prevTraj.removeFromParentNode()
        }
//        humanLeft = fireResult.humanLeft
//
//        if fireResult.humanLeft > 0 {
//            boardDrawer.timeScaling = 3
//        }
//
//        currTraj.isHidden = true
//        currTraj.removeFromParentNode()
//        boardDrawer.animateResult(fireResult: fireResult, from: self)
//        roundChanged = fireResult.newRound
//
//        if gameConfig.numRounds == 0 && fireResult.humanLeft == 0 {
//            roundChanged = true
//        }
        updateInfo("Projectile Launched")

        NSLog("\(#function) finished")
    }
    
    func enableUI() {
        uiEnabled = true
        updateUI()
        updateInfo("UI Enabled")
    }
    
    func disableUI() {
        uiEnabled = false
        updateUI()
        updateInfo("UI Disabled")
    }
    
    func updateInfo(_ msg: String) {
        DispatchQueue.main.async {
            self.infoLabel.text = "Info \(self.networkGameController.myPlayerID): \(msg)"
        }
    }

    func updateUI() {
        NSLog("\(#file) \(#function)")
        guard viewIsLoaded else { return }
        
        NSLog("\(#function) uiEnabled=\(uiEnabled)")
        let model = gameModel
        powerSlider.maximumValue = model.maxPower
        if mapImageView != nil {
            let image = model.board.surface.asUIImage()
            DispatchQueue.main.async {
                self.mapImageView.image = image
            }
        }
        
        updateHUD()
    }
    
    func updateHUD() {
        NSLog("\(#file) \(#function)")
        guard viewIsLoaded else { return }
        guard gameModel.gameStarted else { return }

        if let networkController = networkGameController {
            let myPlayerID = networkController.myPlayerID
            let myPlayer = gameModel.board.players[myPlayerID].name
            let myTank = gameModel.board.players[myPlayerID].tank
            let playerID = gameModel.board.currentPlayer
            let player = gameModel.board.players[playerID].name
            let tank = gameModel.board.players[playerID].tank
            updateInfo("Enabled: \(uiEnabled)\nMe:\t\(myPlayer), Traversal: \(myTank.azimuth)º, Elevation: \(myTank.altitude)º, Power: \(myTank.velocity) m/s\nPlayer:\t\(player), Traversal: \(tank.azimuth)º, Elevation: \(tank.altitude)º, Power: \(tank.velocity) m/s")
            NSLog("\(#file) \(#function) currentPlayer: \(self.gameModel.board.currentPlayer), myPlayerID: \(networkController.myPlayerID)")

            DispatchQueue.main.async {
                self.uiEnabled = myPlayerID == playerID
                self.powerSlider.isEnabled = self.uiEnabled
                self.fireButton.isEnabled = self.uiEnabled
            }
            NSLog("\(#function) uiEnabled=\(uiEnabled)")
        }
    }
    
    func updateDrawer() {
        // does nothing
    }
}
