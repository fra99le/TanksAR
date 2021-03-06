//
//  HighScoreController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 7/21/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

struct HighScore : Codable {
    var name: String = "Unknown"
    var score: Int64 = 0
    var date: Date = Date()
    var config: GameConfig = GameConfig()
    var stats: PlayerStats = PlayerStats()
}

class HighScoreController : Codable {
    var maxScores = 1000
    var maxShown = 10
    var scores: [HighScore] = []
    
    init() {
        // load current scores
        scores = loadScores()
    }
    
    func topScores(num: Int = 10) -> [HighScore] {
        // make sure list is long enough
        while scores.count < num {
            scores.append(HighScore())
        }

        // see: https://stackoverflow.com/questions/28527797/how-to-return-first-5-objects-of-array-in-swift
        let ret = Array(scores.prefix(min(num,scores.count)))
        
        return ret
    }
    
    func addHighScore(score: HighScore) {
        scores.append(score)
        
        // sort scores into descending order
        let sortedScores = scores.sorted(by: {a, b in
            if a.score > b.score {
                return true
            }
            if a.score == b.score &&
                a.date > b.date {
                return true
            }
            return false
        })
        scores = sortedScores
        
        if scores.count > maxScores {
            scores.removeLast(scores.count - maxScores)
        }
        
        saveScores()
    }
    
    var savedScoresURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let baseURL = documentsURL?.appendingPathComponent("HighScores")
        let outputURL = baseURL?.appendingPathExtension("plist")
        return outputURL!
    }
    
    func saveScores() {
        NSLog("\(#function) started")
        
        let encoder = PropertyListEncoder()
        do {
            NSLog("\(#function) started encoding data")
            let encodedState = try encoder.encode(scores)
            NSLog("\(#function) encoded data, size was \(encodedState.count)")
            //NSLog(String(data: encodedState, encoding: .utf8)!)
            try encodedState.write(to: savedScoresURL)
            NSLog("\(#function) saved data")
        } catch  {
            NSLog("Unexpected error: \(error).")
        }
        
        NSLog("\(#function) finished")
    }
    
    func loadScores() -> [HighScore] {
        NSLog("\(#function) started")
        if let loadedData = try? Data(contentsOf: savedScoresURL) {
            NSLog("\(#function) loaded data")
            let decoder = PropertyListDecoder()
            if let result = try? decoder.decode(Array<HighScore>.self, from: loadedData) {
                NSLog("\(#function) decoded data")
                NSLog("\(#function) finished")
                //NSLog("Loaded data: \(result)")
                return result
            } else  {
                NSLog("Decoding of high scores failed.")
            }
        }
        
        NSLog("\(#function) did nothing")
        return []
    }

}
