//
//  ViewController.swift
//  FakeARtillery
//
//  Created by Bryan Franklin on 9/4/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit

class NetworkSetupViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        networkedGameController = NetworkedGameController(gameViewController: self)
        networkedGameController.setExpectedPlayers(numPlayers: 10)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        NSLog("\(#file) \(#function)")
        super.viewWillAppear(animated)
        networkedGameController.viewController = self
        updateUI()
    }
    
    var networkedGameController: NetworkedGameController!
    var gameModel = GameModel()
    var playerNames: [String] = []
    var gameState: GameState!

    @IBAction func browseButtonTapped(_ sender: UIButton) {
        NSLog("\(#file) \(#function)")
        networkedGameController.browseHosts(from: self)
    }
    
    @IBOutlet weak var advertiseButton: UIButton!
    var isAdvertising = false
    @IBAction func advertiseButtonTapped(_ sender: UIButton) {
        NSLog("\(#file) \(#function)")

        if !isAdvertising {
            networkedGameController.advertiseGame(name: "Fake Game")
            isAdvertising = true
        } else {
            networkedGameController.stopAdvertising()
            isAdvertising = false
        }
        updateUI()
    }
    
    @IBOutlet weak var peersStack: UIStackView!
    @IBOutlet weak var expectedPeersLabel: UILabel!
    @IBOutlet weak var peersStepper: UIStepper!
    @IBAction func peersStepperChanged(_ sender: UIStepper) {
        NSLog("\(#file) \(#function)")
        networkedGameController.setExpectedPlayers(numPlayers: Int(sender.value))
        updateUI()
    }
    
    @IBOutlet weak var startButton: UIButton!
    @IBAction func startButtonTapped(_ sender: Any) {
        NSLog("\(#file) \(#function)")
        networkedGameController.stopAdvertising()
        
        if networkedGameController.connectionState == .connected {
            //performSegue(withIdentifier: "startSegue", sender: nil)
            performSegue(withIdentifier: "startFakeClient", sender: nil)
        }
    }
    
    func playerJoined(displayName: String) {
        NSLog("\(#function)")
        
        if !playerNames.contains(displayName) {
            playerNames.append(displayName)
        }
        
        NSLog("\(networkedGameController.numConnected) players connected, need \(gameState.config.numHumans) to launch game.")
        
        updateUI()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let dest = segue.destination as? GameViewController {
            NSLog("\(#file) \(#function) setting up model, network controller and view controller.")
            dest.gameModel = self.gameModel
            dest.networkGameController = networkedGameController
            networkedGameController.viewController = dest
        }

    }
    
    @IBOutlet weak var numConnectedLabel: UILabel!
    func updateUI() {
        NSLog("\(#file) \(#function)")
        
        switch networkedGameController.connectionState {
        case .notConnected:
            NSLog("state is 'not connected'")
        case .connecting:
            NSLog("state is 'connecting'")
        case .connected:
            NSLog("state is 'connected'")
        @unknown default:
            NSLog("Unknown connection state \(networkedGameController.connectionState)")
            fatalError()
        }
        NSLog("\(networkedGameController.networkController.mcSession.connectedPeers.count) peers connected")
       
        if !isAdvertising {
            advertiseButton.setTitle("Advertise", for: .normal)
        } else {
            advertiseButton.setTitle("Stop Advertising", for: .normal)
        }
        peersStepper.isEnabled = isAdvertising
        
        expectedPeersLabel.text = " \(networkedGameController.numConnected) of \(networkedGameController.totalPlayers) "
        
        NSLog("\(networkedGameController.numConnected) of \(networkedGameController.totalPlayers) players connected.")
        if networkedGameController.numConnected == networkedGameController.totalPlayers {
            startButton.isEnabled = true
            performSegue(withIdentifier: "startFakeClient", sender: nil)
        } else {
            startButton.isEnabled = false
        }
        
        networkedGameController.setExpectedPlayers(numPlayers: networkedGameController.totalPlayers)
    }
    
    // make this a target for unwinding segues
    @IBAction func unwindToMainMenu(unwindSegue: UIStoryboardSegue) {
    }
}

