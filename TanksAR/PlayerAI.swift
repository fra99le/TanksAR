//
//  PlayerAI.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/12/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation
import SceneKit

// inputs and resulting distance to an individual opponent
struct Sample {
    // input
    // NOTE: features should probably be component vectors of muzzle velocity
    var azimuth: Float
    var altitude: Float
    var velocity: Float
    
    // result
    var impactX: Float
    var impactY: Float
    var impactZ: Float
}

class PlayerAI {
    var gameModel:GameModel? = nil
    var data: [Sample] = []
    var lastFour: [Sample] = []
    
    init(model: GameModel) {
        reset(model: model)
    }
    
    // needs to be called between rounds (i.e. when tanks move)
    func reset(model: GameModel) {
        data = []
        gameModel = model
    }
    
    func recordResult(azimuth: Float, altitude: Float, velocity: Float,
                      impactX: Float, impactY: Float, impactZ: Float) {
        let newSample = Sample(azimuth: azimuth, altitude: altitude, velocity: velocity,
                               impactX: impactX, impactY: impactY, impactZ: impactZ)
        data.append(newSample)

        // update recent buffer
        lastFour.append(newSample)
    }
    
    func fireParameters(players: [Player]) -> (azimuth: Float, altitude: Float, velocity: Float) {
        // pick parameters using Nelder-Mead algorithm
        // see: https://en.wikipedia.org/wiki/Nelder–Mead_method
        
        // fill initial simplex
        if lastFour.count < 4 {
            let azimuth = Float(drand48() * 360)
            let altitude = Float(drand48() * 90)
            let power = Float(drand48() * 100)
            
            return (azimuth, altitude, power)
        }
        
        // compute next point
        // pick target player
        guard let model = gameModel else { return (0, 45, 25) }
        let currentPlayer = model.board.currentPlayer
        let nextPlayer = (currentPlayer + 1) % model.board.players.count
        let targetPlayer = model.board.players[nextPlayer]
        
        // find furthest sample
        var maxDist = Float(-1)
        var furthestIndex = 0
        for i in 0..<lastFour.count {
            let dist = distToTank(from: lastFour[i], toTank: targetPlayer.tank)
            if( dist > maxDist ) {
                maxDist = dist
                furthestIndex = i
            }
        }
        let furthest = lastFour.remove(at: furthestIndex)

        // compute simplex relative target player
        // take three closest and average them
        var sumAzi = Float(0)
        var sumAlt = Float(0)
        var sumVel = Float(0)
        for sample in lastFour {
            sumAzi += sample.azimuth
            sumAlt += sample.altitude
            sumVel += sample.velocity
        }
        let meanAzi = sumAzi / 3
        let meanAlt = sumAlt / 3
        let meanVel = sumVel / 3

        // take furthest and form a vector
        let deltaAzi = meanAzi - furthest.azimuth
        let deltaAlt = meanAlt - furthest.altitude
        let deltaVel = meanVel - furthest.velocity

        // get new guess by following vector 1.5x from furthest
        let retAzi = furthest.azimuth + 1.5 * deltaAzi
        let retAlt = furthest.altitude + 1.5 * deltaAlt
        let retVel = furthest.velocity + 1.5 * deltaVel

        return (retAzi, retAlt, retVel)
    }
    
    func distToTank(from: Sample, toTank: Tank) -> Float {
        let xDiff = from.impactX - toTank.position.x
        let yDiff = from.impactY - toTank.position.y
        let zDiff = from.impactZ - toTank.position.z
        let dist = sqrt(xDiff*xDiff + yDiff*yDiff + zDiff*zDiff)

        return dist
    }
    
//    func playerIsMe(player: Player) -> Bool {
//        guard let ai = player.ai else { return false }
//        return ai == self
//    }
    
}
