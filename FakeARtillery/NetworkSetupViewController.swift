//
//  ViewController.swift
//  FakeARtillery
//
//  Created by Bryan Franklin on 9/4/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
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
        clientStarted = false
        updateUI()
    }
    
    var networkedGameController: NetworkedGameController!
    var gameModel = GameModel()
    var playerNames: [String] = []
    var gameState: GameState!
    var clientStarted = false
    
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
        
        if networkedGameController.connectionState == .connected && !clientStarted {
            performSegue(withIdentifier: "startFakeClient", sender: nil)
            clientStarted = true
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
    @IBOutlet weak var connectionStatusLabel: UILabel!
    func updateUI() {
        NSLog("\(#file) \(#function)")
        
        var statusString = "State: unknown"
        switch networkedGameController.connectionState {
        case .notConnected:
            statusString = "State: not connected"
        case .connecting:
            statusString = "State: connecting"
        case .connected:
            statusString = "State: connected"
        @unknown default:
            NSLog("Unknown connection state \(networkedGameController.connectionState)")
            fatalError()
        }
        NSLog("\(statusString)")
        connectionStatusLabel.text = statusString
        NSLog("\(networkedGameController.networkController.mcSession.connectedPeers.count) peers connected")
       
        if !isAdvertising {
            advertiseButton.setTitle("Advertise", for: .normal)
        } else {
            advertiseButton.setTitle("Stop Advertising", for: .normal)
        }
        peersStepper.isEnabled = isAdvertising
        
        expectedPeersLabel.text = " \(networkedGameController.numConnected) of \(networkedGameController.totalPlayers) "
        
        NSLog("\(networkedGameController.numConnected) of \(networkedGameController.totalPlayers) players connected.")
        if networkedGameController.numConnected == networkedGameController.totalPlayers  && !clientStarted  {
            startButton.isEnabled = true
            performSegue(withIdentifier: "startFakeClient", sender: nil)
            clientStarted = true
        } else {
            startButton.isEnabled = false
        }
        
        networkedGameController.setExpectedPlayers(numPlayers: networkedGameController.totalPlayers)
    }
    
    // make this a target for unwinding segues
    @IBAction func unwindToMainMenu(unwindSegue: UIStoryboardSegue) {
    }
}

