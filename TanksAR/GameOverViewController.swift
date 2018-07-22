//
//  GameOverViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/13/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import UIKit

class GameOverViewController: UIViewController, UITextFieldDelegate {
    
    var highScores: HighScoreController!
    
    @IBOutlet weak var playerNameStack: UIStackView!
    @IBOutlet weak var playerNameLabel: UILabel!
    @IBOutlet weak var playerScoreLabel: UILabel!
    @IBOutlet weak var playerNameField: UITextField!
    
    var currentPlayerID: Int = 0
    
    @IBOutlet weak var newHighSchoolLabel: UILabel!
    @IBOutlet weak var resultsStack: UIStackView!
    @IBOutlet weak var playerLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    
    var players: [Player] = []
    var gameConfig: GameConfig = GameConfig()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        highScores = HighScoreController()
        playerNameField.delegate = self
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

    // see: https://medium.com/@KaushElsewhere/how-to-dismiss-keyboard-in-a-view-controller-of-ios-3b1bfe973ad1
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }

    @IBAction func playerNameChanged(_ sender: UITextField) {
        NSLog("\(#function) started")
        if let newName = sender.text {
            NSLog("newName: \(newName)")
            players[currentPlayerID].name = newName
            players[currentPlayerID].didSetName = true
        }
        updateUI()
        NSLog("\(#function) finished")
    }
    
    func updateUI() {
        NSLog("\(#function) started")
        // check to see is any names need to be entered
        let minScore = highScores.scores[highScores.maxShown-1].score
        for playerID in 0..<players.count {
            let player = players[playerID]
            
            if player.score > minScore && (!player.didSetName || player.name == "") {
                playerNameStack.isHidden = false
                resultsStack.isHidden = true
                
                playerNameLabel.text = player.name
                playerScoreLabel.text = "\(player.score)"
                playerNameField.text = ""
                playerNameField.resignFirstResponder()
                currentPlayerID = playerID
                
                //playerNameField.becomeFirstResponder()
                NSLog("\(#function) finished early (line \(#line))")
                return
            }
        }
        
        // record scores
        NSLog("Recording scores.")
        var winnerName: String = ""
        var winnerScore: Int64 = Int64.min
        for player in players {
            let score = HighScore(name: player.name,
                                  score: player.score,
                                  date: Date(),
                                  numHumans: gameConfig.numHumans,
                                  numAIs: gameConfig.numAIs,
                                  numRounds: gameConfig.numRounds)
            highScores.addHighScore(score: score)
            
            if score.score > winnerScore {
                winnerName = score.name
                winnerScore = score.score
            }
        }

        // if all names entered, show results
        NSLog("Showing game results.")
        playerNameStack.isHidden = true
        resultsStack.isHidden = false
        newHighSchoolLabel.isHidden = !(winnerScore > minScore)
        playerLabel.text = "\(winnerName) wins!"
        scoreLabel.text = "Score: \(winnerScore)"
        NSLog("\(#function) finished")
    }
    
    func reorderedNames() -> [String] {
        var ret: [String] = []
        
        // sort players by score (ascensing)
        let sortedPlayers = players.sorted(by: {a, b in
            if a.score < b.score {
                return true
            }
            return false
        })
        
        // add each human's name to a list
        for player in sortedPlayers {
            if player.ai == nil && player.name != "" {
                NSLog("Adding \(player.name) to playerNames (score=\(player.score))")
                if player.didSetName {
                    ret.append(player.name)
                } else {
                    ret.append("")
                }
            }
        }
        
        return ret
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let dest = segue.destination as? GameViewController {
            NSLog("Switching to game via \(segue.identifier!) segue.")
            if segue.identifier == "playAgain" {
                NSLog("\(#function) starting \(dest.gameConfig.numRounds) round game with \(dest.gameConfig.numHumans) humans and \(dest.gameConfig.numAIs) Als.")
                gameConfig.playerNames = reorderedNames()
                dest.gameConfig = gameConfig
                dest.gameModel = GameModel()
                //dest.gameModel = TestGameModel()    // for debugging
                dest.gameOver = false
            } else {
                NSLog("Unknown segue identifier: \(segue.identifier!)")
            }
        }
    }

}
