//
//  MenuViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import UIKit

struct GameState : Codable {
    var model : GameModel
    var config : GameConfig
}

class MenuViewController: UIViewController {

    var gameConfig = GameConfig(numHumans: 1, numAIs: 1, numRounds: 3, useBlocks: false)
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
                NSLog("\(#function) starting \(dest.gameConfig.numRounds) round game with \(dest.gameConfig.numHumans) humans and \(dest.gameConfig.numAIs) Als.")
                dest.gameConfig = gameConfig;
                dest.gameModel = GameModel()
                dest.gameOver = false
            } else {
                NSLog("Unknown segue identifier: \(segue.identifier!)")
            }
            self.gameState = nil
        }
    }
    
    @IBOutlet weak var humansNumLabel: UILabel!
    @IBOutlet weak var aisNumLabel: UILabel!
    @IBOutlet weak var roundsNumLabel: UILabel!

    @IBOutlet weak var humansStepper: UIStepper!
    @IBOutlet weak var aisStepper: UIStepper!
    @IBOutlet weak var roundsStepper: UIStepper!

    @IBOutlet weak var modeButton: UIButton!
    @IBOutlet weak var playGameButton: UIButton!
    @IBOutlet weak var resumeGameButton: UIButton!
    
    
    @IBAction func humansStepperTapped(_ sender: UIStepper) {
        gameConfig.numHumans = Int(sender.value)
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
    
    @IBAction func playGameTapped(_ sender: UIButton) {
        
    }

    @IBAction func modeTapped(_ sender: UIButton) {
        gameConfig.useBlocks = !gameConfig.useBlocks
        updateUI()
    }
    
    
    func updateUI() {
        humansStepper.value = Double(gameConfig.numHumans)
        aisStepper.value = Double(gameConfig.numAIs)
        roundsStepper.value = Double(gameConfig.numRounds)
        humansNumLabel.text = "\(gameConfig.numHumans)"
        aisNumLabel.text = "\(gameConfig.numAIs)"
        roundsNumLabel.text = "\(gameConfig.numRounds)"
        modeButton.setTitle(gameConfig.useBlocks ? "Super-Retro" : "Retro", for: .normal)
        
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
    
}
