//
//  MenuViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit

// Note: different difficulty settings should be added

class MenuViewController: UIViewController {

    var gameConfig = GameConfig()
    var gameState: GameState? = nil
    let autoResume = false
    
    func loadSavedGame() {
        // try loading a game from saved state
        NSLog("\(#function): Checking for in-progress game state")
        if let gameState = loadStateFile() {
            NSLog("Loaded stored game.")
            if gameState.model.gameStarted {
                // make available to rest of the class
                self.gameState = gameState

                if autoResume {
                    // loaded a game, switch to it
                    NSLog("Continuing it.")
                    performSegue(withIdentifier: "resumeGame", sender: nil)
                    NSLog("should have performed segue.")
                } else {
                    NSLog("Enabling resume button")
                    // enable and show resume button
                    resumeGameButton.isHidden = false
                    resumeGameButton.isEnabled = true
                }
            } else {
                NSLog("No game in progress.")
            }
        } else {
            NSLog("No saved game file found.")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // see: https://stackoverflow.com/questions/24046164/how-do-i-get-a-reference-to-the-app-delegate-in-swift
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.saveController = self
        
        gameConfig = loadMenu()
        
        resumeGameButton.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSavedGame()
        updateUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    // make this a target for unwinding segues
    @IBAction func unwindToMainMenu(unwindSegue: UIStoryboardSegue) {
        if let source = unwindSegue.source as? GameViewController {
            source.unplaceBoard()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let dest = segue.destination as? GameViewController {
            NSLog("Switching to game via \(segue.identifier!) segue.")
            dest.saveStateController = self
            if segue.identifier == "resumeGame" {
                NSLog("...continuing game")
                dest.gameConfig = (self.gameState?.config)!
                dest.gameModel = (self.gameState?.model)!
                self.gameState = nil
            } else if segue.identifier == "startGame" {
                NSLog("\(#function) starting \(gameConfig.numRounds) round game with \(gameConfig.numHumans) humans and \(gameConfig.numAIs) Als.")
                dest.gameConfig = gameConfig;
                dest.gameModel = GameModel()
                //dest.gameModel = TestGameModel()    // for debugging
                dest.gameModel.gameOver = false
            } else {
                NSLog("Unknown segue identifier: \(segue.identifier!)")
            }
            self.gameState = nil
        }
        
        if let dest = segue.destination as? NetworkSetupViewController {
            NSLog("\(#function) starting \(gameConfig.numRounds) round networked game with \(gameConfig.numHumans) humans and \(gameConfig.numAIs) Als.")
            dest.gameState = GameState(model: GameModel(), config: gameConfig)
            //dest.gameState.model = TestGameModel()    // for debugging
            dest.gameState.model.gameOver = false
        }
    }
    
    @IBOutlet weak var humansNumLabel: UILabel!
    @IBOutlet weak var aisNumLabel: UILabel!
    @IBOutlet weak var roundsNumLabel: UILabel!
    @IBOutlet weak var eliminationLabel: UILabel!
    
    @IBOutlet weak var humansStepper: UIStepper!
    @IBOutlet weak var aisStepper: UIStepper!
    @IBOutlet weak var roundsStepper: UIStepper!

    @IBOutlet weak var modeButton: UIButton!
    @IBOutlet weak var networkGameSwitch: UISwitch!
    @IBOutlet weak var playGameButton: UIButton!
    @IBOutlet weak var resumeGameButton: UIButton!
    
    @IBAction func humansStepperTapped(_ sender: UIStepper) {
        gameConfig.numHumans = Int(sender.value)
        gameConfig.playerNames = []
        updateUI()
    }
    
    @IBAction func aisStepperTapped(_ sender: UIStepper) {
        gameConfig.numAIs = Int(sender.value)
        updateUI()
    }

    @IBAction func roundsStepperTapped(_ sender: UIStepper) {
        gameConfig.numRounds = Int(sender.value)
        updateUI()
    }
    
    @IBAction func networkGameSwitchToggled(_ sender: UISwitch) {
        gameConfig.networked = sender.isOn
        updateUI()
    }
    
    @IBAction func playGameTapped(_ sender: UIButton) {
        // check for in-progress game
        // present an alert if one is found
        if let model = gameState?.model,
            model.gameStarted {
            let alert = UIAlertController(title: "New Game?", message: "A game is currently in progress, and will be lost if you start a new game.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Default inaction"), style: .default, handler: { _ in
                NSLog("New game canceled.")
                self.updateUI()
                return
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Start New Game", comment: "Default action"), style: .default, handler: { _ in
                NSLog("Starting new game!")
                self.startGame()
            }))
            self.present(alert, animated: true, completion: nil)
        } else {
            startGame()
        }
    }
    
    func startGame() {
        NSLog("\(#function)")
        if networkGameSwitch.isOn {
            performSegue(withIdentifier: "startNetworkGame", sender: nil)
        } else {
            performSegue(withIdentifier: "startGame", sender: nil)
        }
    }

    @IBAction func modeTapped(_ sender: UIButton) {
        switch gameConfig.mode {
        case .texturedTrigs:
            gameConfig.mode = .coloredTrigs
        case .coloredTrigs:
            gameConfig.mode = .blocks
        case .blocks:
            gameConfig.mode = .texturedTrigs
        default:
            gameConfig.mode = .blocks
        }
        updateUI()
    }
    
    
    func updateUI() {
        saveMenu()

        humansStepper.value = Double(gameConfig.numHumans)
        aisStepper.value = Double(gameConfig.numAIs)
        roundsStepper.value = Double(gameConfig.numRounds)
        
        humansNumLabel.text = "\(gameConfig.numHumans)"
        aisNumLabel.text = "\(gameConfig.numAIs)"
        roundsNumLabel.text = "\(gameConfig.numRounds)"
        eliminationLabel.isHidden = true
        humansStepper.minimumValue = 0
        aisStepper.minimumValue = 0
        if gameConfig.numRounds == 0 {
            roundsNumLabel.text = "∞"
            eliminationLabel.isHidden = false
            humansStepper.minimumValue = 1
            aisStepper.minimumValue = 1
            if gameConfig.numHumans < 1 {
                gameConfig.numHumans = 1
                humansNumLabel.text = "1"
            }
            if gameConfig.numAIs < 1 {
                gameConfig.numAIs = 1
                aisNumLabel.text = "1"
            }
        }
        
        networkGameSwitch.isOn = gameConfig.networked
        
        var modeString = "Unknown"
        switch gameConfig.mode {
        case .blocks:
            modeString = "Super-Retro"
        case .plainTrigs:
            modeString = "Retro-er"
        case .coloredTrigs:
            modeString = "Retro"
        case .texturedTrigs:
            modeString = "Modern"
        }
        modeButton.setTitle(modeString, for: .normal)
        
        // require more than one player
        if gameConfig.numHumans + gameConfig.numAIs <= 1 {
            playGameButton.isEnabled = false
        } else {
            playGameButton.isEnabled = true
        }
        
        if let savedGame = gameState,
            savedGame.model.gameStarted {
            resumeGameButton.isEnabled = true
            resumeGameButton.isHidden = false
            playGameButton.setTitle("New Game", for: .normal)
        } else {
            resumeGameButton.isEnabled = false
            resumeGameButton.isHidden = true
            playGameButton.setTitle("Play Game", for: .normal)
        }
    }
    
    // MARK - Persistent State
    
    var savedStateURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let baseURL = documentsURL?.appendingPathComponent("ARtillery")
        let outputURL = baseURL?.appendingPathExtension("plist")
        return outputURL!
    }

    func saveStateFile() {
        NSLog("\(#function) started")

        // compress image data for fast/small enough encoding
        gameState?.model.board.surface.compress()
        gameState?.model.board.bedrock.compress()
        gameState?.model.board.colors.compress()
        
//        let encoder = JSONEncoder()
//        encoder.outputFormatting = .prettyPrinted
        let encoder = PropertyListEncoder()
        do {
            NSLog("\(#function) started encoding data")
            let encodedState = try encoder.encode(gameState)
            NSLog("\(#function) encoded data, size was \(encodedState.count)")
            //NSLog(String(data: encodedState, encoding: .utf8)!)
            try encodedState.write(to: savedStateURL)
            NSLog("\(#function) saved data")
        } catch  {
            NSLog("Unexpected error: \(error).")
        }

        // these lines restore the surface to usable format
        gameState?.model.board.surface.uncompress()
        gameState?.model.board.bedrock.uncompress()
        gameState?.model.board.colors.uncompress()

        NSLog("\(#function) finished")
    }
    
    func loadStateFile() -> GameState? {
        NSLog("\(#function) started")
        if let loadedData = try? Data(contentsOf: savedStateURL) {
            NSLog("\(#function) loaded data")
            let decoder = PropertyListDecoder()
            if let result = try? decoder.decode(GameState.self, from: loadedData) {
                NSLog("\(#function) decoded data")
                
                result.model.board.surface.uncompress()
                result.model.board.bedrock.uncompress()
                result.model.board.colors.uncompress()

                NSLog("\(#function): gameStarted = \(result.model.gameStarted)")

                NSLog("\(#function) finished")
                return result
            }
        }
        
        NSLog("\(#function) did nothing")
        return nil
    }
    
    func removeStateFile() {
        try? FileManager.default.removeItem(at: savedStateURL)
    }
    
    var savedMenuURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let baseURL = documentsURL?.appendingPathComponent("MainMenu")
        let outputURL = baseURL?.appendingPathExtension("plist")
        return outputURL!
    }
    
    func saveMenu() {
        NSLog("\(#function) started")
        
        let encoder = PropertyListEncoder()
        do {
            NSLog("\(#function) started encoding data")
            let encodedState = try encoder.encode(gameConfig)
            NSLog("\(#function) encoded data, size was \(encodedState.count)")
            //NSLog(String(data: encodedState, encoding: .utf8)!)
            try encodedState.write(to: savedMenuURL)
            NSLog("\(#function) saved data")
        } catch  {
            NSLog("Unexpected error: \(error).")
        }
        
        NSLog("\(#function) finished")
    }
    
    func loadMenu() -> GameConfig {
        NSLog("\(#function) started")
        if let loadedData = try? Data(contentsOf: savedMenuURL) {
            NSLog("\(#function) loaded data")
            let decoder = PropertyListDecoder()
            if let result = try? decoder.decode(GameConfig.self, from: loadedData) {
                NSLog("\(#function) decoded data")
                NSLog("\(#function) finished")
                NSLog("Loaded data: \(result)")
                return result
            }
        }
        
        NSLog("\(#function) did nothing")
        return GameConfig()
    }

}
