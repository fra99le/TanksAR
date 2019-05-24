//
//  NetworkSetupViewController.swift
//  TanksAR
//
//  Created by Fraggle on 9/8/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import UIKit

class NetworkSetupViewController: UIViewController, UITextFieldDelegate {

    override func viewDidLoad() {
        NSLog("\(#function)")

        super.viewDidLoad()

        // Do any additional setup after loading the view.
        hostGameSwitch.isOn = false
        networkedGameController = NetworkedGameController(gameViewController: self)
        // based on: https://stackoverflow.com/questions/1247142/getting-an-iphone-apps-product-name-at-runtime
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") ?? "App name missing"
        gameName = "\(appName) on \(UIDevice.current.name)"
        nameField.text = gameName
        nameField.delegate = self
    }

    override func didReceiveMemoryWarning() {
        NSLog("\(#function)")

        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NSLog("\(#function)")

        super.viewWillAppear(animated)
        
        startingActivityStackView.isHidden = true
        setupScrollView.isHidden = false
        if gameState != nil {
            networkedGameController.setExpectedPlayers(numPlayers: gameState.config.numHumans)
        }
        
        updateUI()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        NSLog("\(#function)")
        
        super.prepare(for: segue, sender: sender)
        if let dest = segue.destination as? GameViewController {
            NSLog("Switching to game via \(segue.identifier!) segue.")
            
            if segue.identifier == "launchNetworkGame" {
                dest.gameConfig = self.gameState.config
                dest.gameModel = self.gameState.model
                dest.networkGameController = networkedGameController
                networkedGameController.viewController = dest
            } else {
                NSLog("Unknown segue identifier: \(segue.identifier!)")
            }
            self.gameState = nil
        }
    }
    
    var networkedGameController: NetworkedGameController!
    var gameName: String = "ARtillery Game"
    var playerNames: [String] = []
    var gameState: GameState!
    
    @IBOutlet weak var hostGameSwitch: UISwitch!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var joinGameButton: UIButton!
    @IBOutlet weak var playerCountLabel: UILabel!
    @IBOutlet weak var connectionStatusLabel: UILabel!
    
    @IBOutlet weak var setupScrollView: UIScrollView!
    @IBOutlet weak var startingActivityStackView: UIStackView!
    
    @IBAction func hostGameSwitchToggled(_ sender: UISwitch) {
        NSLog("\(#function)")

        if sender.isOn {
            NSLog("starting advertisment of \(gameName)")
            networkedGameController.advertiseGame(name: gameName)
        } else {
            networkedGameController.stopAdvertising()
        }
        
        updateUI()
    }
    
    @IBAction func nameFieldChanged(_ sender: UITextField) {
        NSLog("\(#function)")

        gameName = sender.text!
        networkedGameController.setGameName(to: gameName)
        
        updateUI()
    }
    
    @IBAction func joinGameButtonTapped(_ sender: Any) {
        NSLog("\(#function)")

        if networkedGameController.connectionState == .notConnected {
            networkedGameController.browseHosts(from: self)
        } else if networkedGameController.connectionState == .connected {
            networkedGameController.disconnect()
        }
        
        updateUI()
    }
    
    @IBAction func mainMenuButtonTapped(_ sender: UIButton) {
        networkedGameController.stopAdvertising()
        
        startingActivityStackView.isHidden = true
        setupScrollView.isHidden = false

        performSegue(withIdentifier: "unwindToMainMenu", sender: self)
    }
    
    func playerJoined(displayName: String) {
        NSLog("\(#function)")

        if !playerNames.contains(displayName) {
            playerNames.append(displayName)
        }
        
        NSLog("\(networkedGameController.numConnected) players connected, need \(gameState.config.numHumans) to launch game.")
   
        updateUI()
    }
    
    func updateUI() {
        NSLog("\(#function)")

        nameField.text = gameName
        if hostGameSwitch.isOn {
            nameField.isEnabled = true
            joinGameButton.isHidden = true
        } else {
            nameField.isEnabled = false
            joinGameButton.isHidden = false
        }
        
        connectionStatusLabel.text = networkedGameController.connectionStateString
        if networkedGameController.connectionState == .notConnected {
            joinGameButton.titleLabel?.text = "Join Game"
            joinGameButton.isEnabled = true
            hostGameSwitch.isEnabled = true
        } else if networkedGameController.connectionState == .connected {
            joinGameButton.titleLabel?.text = "Disconnect"
            joinGameButton.isEnabled = true
            hostGameSwitch.isEnabled = false
        } else {
            joinGameButton.isEnabled = false
        }
        joinGameButton.setNeedsLayout()
        
        if gameState != nil {
            playerCountLabel.text = "\(networkedGameController.numConnected) of \(gameState.config.numHumans)"

            if networkedGameController.numConnected == gameState.config.numHumans {
                //networkedGameController.stopAdvertising()
                if networkedGameController.isLeader {
                    networkedGameController.broadcastPlayerCount()
                }
                networkedGameController.viewController = nil
                NSLog("\(#function) trying to start game via launchNetworkGame segue")
                startingActivityStackView.isHidden = false
                setupScrollView.isHidden = true
                performSegue(withIdentifier: "launchNetworkGame", sender: nil)
            }
        }
            
    }

    // MARK: - UITextFieldDelegate
    // see: https://medium.com/@KaushElsewhere/how-to-dismiss-keyboard-in-a-view-controller-of-ios-3b1bfe973ad1
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }

}
