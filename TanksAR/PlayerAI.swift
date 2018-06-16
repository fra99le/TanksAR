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
    
    // component vectors
    var velocityX: Float
    var velocityY: Float
    var velocityZ: Float
    
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
    
    func fromSpherical(azi: Float, alt: Float, velocity: Float) -> (x: Float, y: Float, z: Float) {
        let azimuth = azi * (Float.pi / 180)
        let altitude = alt * (Float.pi / 180)
        let xVel = -velocity * sin(azimuth) * cos(altitude)
        let yVel = velocity * sin(altitude)
        let zVel = -velocity * cos(azimuth) * cos(altitude)

        return (xVel, yVel, zVel)
    }

    func toSpherical(xVel: Float, yVel: Float, zVel: Float) -> (azimuth: Float, altitude: Float, velocity: Float) {
        let horiz = sqrt( xVel*xVel + zVel*zVel )
        let retAzi = (180 / Float.pi) * atan2(-xVel, -zVel)
        let retAlt = (180 / Float.pi) * atan2(yVel, horiz)
        let retVel = sqrt( horiz*horiz + yVel*yVel )

        return (retAzi, retAlt, retVel)
    }
    
    func recordResult(azimuth: Float, altitude: Float, velocity: Float,
                      impactX: Float, impactY: Float, impactZ: Float) {
        let (xVel, yVel, zVel) = fromSpherical(azi: azimuth, alt: altitude, velocity: velocity)
        let (azi2, alt2, vel2) = toSpherical(xVel: xVel, yVel: yVel, zVel: zVel)
        NSLog("\(#function): \(azimuth),\(altitude),\(velocity) -> linear -> \(azi2),\(alt2),\(vel2)")
        let newSample = Sample(azimuth: azimuth, altitude: altitude, velocity: velocity,
                               velocityX: xVel, velocityY: yVel, velocityZ: zVel,
                               impactX: impactX, impactY: impactY, impactZ: impactZ)
        data.append(newSample)

        // update recent buffer
        lastFour.append(newSample)
    }
    
    func fireParameters(players: [Player]) -> (azimuth: Float, altitude: Float, velocity: Float) {
        // pick parameters using Nelder-Mead algorithm
        // see: https://en.wikipedia.org/wiki/Nelder–Mead_method
        // also: http://www.scholarpedia.org/article/Nelder-Mead_algorithm
        
        // fill initial simplex
        print("lastFour: \(lastFour)")
        if lastFour.count < 4 {
            let azimuth = Float(drand48() * 360)
            let altitude = Float(drand48() * 50) + 30
            let power = Float(drand48() * 70) + 30
            
            NSLog("\(#function): firing at random, (\(lastFour.count) samples), (\(azimuth),\(altitude),\(power))")
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
        var sumX = Float(0)
        var sumY = Float(0)
        var sumZ = Float(0)
        for sample in lastFour {
            sumX += sample.velocityX
            sumY += sample.velocityY
            sumZ += sample.velocityZ
        }
        let meanX = sumX / 3
        let meanY = sumY / 3
        let meanZ = sumZ / 3

        // take furthest and form a vector
        let deltaX = meanX - furthest.velocityX
        let deltaY = meanY - furthest.velocityY
        let deltaZ = meanZ - furthest.velocityZ

        // find new x,y,z to sample by following vector 2x from furthest
        let retX = furthest.velocityX + 2 * deltaX
        let retY = furthest.velocityY + 2 * deltaY
        let retZ = furthest.velocityZ + 2 * deltaZ
        print("next sample (x,y,z) = (\(retX),\(retY),\(retZ))")
        
        // convert new sample to polar coordinates
        let (retAzi, retAlt, retVel) = toSpherical(xVel: retX, yVel: retY, zVel: retZ)
        
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
