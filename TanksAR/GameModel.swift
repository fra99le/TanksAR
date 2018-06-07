//
//  GameModel.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

// Note: Game model has the origin at one corner.

import Foundation
import UIKit

struct Tank {
    var lon: Float
    var lat: Float
    var elev: Float
    var azimuth: Float
    var altitude: Float
    var velocity: Float
}

struct Player {
    var tank: Tank!
    var name: String = "Unknown"
    var score: Int64 = 0
}

struct GameBoard {
    var boardSize: Int = 0
    var surface: ImageBuf = ImageBuf()
    var bedrock: ImageBuf = ImageBuf()
    
    // player
    var players: [Player] = []
    var currentPlayer: Int = 0
}

struct HighScore {
    var name: String = "Unknown"
    var score: Int64 = 0
}

// Note: For the model x,y are surface image coordinates, and z is elevation
// In GameViewController y and z are swapped.

class GameModel {
    // game board
    var board: GameBoard = GameBoard()
    
    // high-score data
    let highScores: [HighScore] = []
    
    func generateBoard() {
        board.boardSize = 1025
        board.surface.setSize(width: board.boardSize, height: board.boardSize)
        board.bedrock.setSize(width: board.boardSize, height: board.boardSize)
        
        board.surface.fillUsingDiamondSquare(withMinimum: 50, andMaximum: 200)
        board.bedrock.fillUsingDiamondSquare(withMinimum: 5, andMaximum: 40)
    }
    
    func startGame(numPlayers: Int) {
        board.players = [Player](repeating: Player(), count: numPlayers)
        board.currentPlayer = 0
        
        placeTanks()
    }
    
    func getElevation(longitude: Int, latitude: Int) -> Int {
        let (red: r, green: _, blue: _, alpha: _) = board.surface.getPixel(x: longitude, y: latitude)
        let elevation = Int(r*255)
        print("Elevation at \(longitude),\(latitude) is \(elevation).")
        return elevation
    }
    
    func placeTanks(withMargin: Int = 50, minDist: Int = 10) {
        for i in 0..<board.players.count {
            let x = drand48() * Double(board.surface.width-withMargin*2) + Double(withMargin)
            let y = drand48() * Double(board.surface.height-withMargin*2) + Double(withMargin)

            let tankElevation = getElevation(longitude: Int(x), latitude: Int(y))
            board.players[i].tank = Tank(lon: Float(x), lat: Float(y), elev: Float(tankElevation),
                                         azimuth: 0, altitude: Float(Double.pi/4), velocity: 10)
        
            // flatten area around tanks
            let tank = board.players[i].tank!
            flattenAreaAt(longitude: Int(tank.lon), latitude: Int(tank.lat), withRadius: 100)
        }
    }
    
    func flattenAreaAt(longitude: Int, latitude: Int, withRadius: Int) {
        let min_x = (longitude<withRadius) ? 0 : longitude-withRadius
        let max_x = (longitude+withRadius>board.surface.width) ? 0 : longitude+withRadius
        let min_y = (latitude<withRadius) ? 0 : latitude-withRadius
        let max_y = (latitude+withRadius>board.surface.height) ? board.surface.height-1 : latitude+withRadius

        let elevation = getElevation(longitude: longitude, latitude: latitude)
        for j in min_y...max_y {
            for i in min_x...max_x {
                let xDiff = longitude - i
                let yDiff = latitude - j
                let dist = sqrt(Double(xDiff*xDiff + yDiff*yDiff))
                if( dist < Double(withRadius)) {
                    board.surface.setPixel(x: i, y: j, r: Double(elevation), g: 0, b: 0, a: 1.0)
                }
            }
        }
    }
}
