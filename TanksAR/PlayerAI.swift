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
struct Sample : Codable {
    // input
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

class PlayerAI : Codable {
    var gameModel:GameModel? = nil
    var nelderMead = NelderMead(dimensions: 3)
    var data: [Sample] = []
    var firstShot = true
    
    init(model: GameModel) {
        reset(model: model)
    }
    
    // needs to be called between rounds (i.e. when tanks move)
    func reset(model: GameModel) {
        data = []
        nelderMead = NelderMead(dimensions: 3)
        gameModel = model
        firstShot = true
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
    
    func getNextPlayerID() -> Int {
        guard let model = gameModel else { return 0 }

        let currentPlayer = model.board.currentPlayer
        var nextPlayer = (currentPlayer + 1) % model.board.players.count
        while model.board.players[nextPlayer].hitPoints <= 0 {
            nextPlayer = (nextPlayer + 1) % model.board.players.count
        }
        return nextPlayer
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

        // compute next point
        // pick target player
        guard let model = gameModel else { return }
        let nextPlayer = getNextPlayerID()
        let targetPlayer = model.board.players[nextPlayer]
        let targetTank = targetPlayer.tank
        
        // get dist to target
        let dist = distToTank(from: newSample, toTank: targetTank)
        NSLog("\(#function): last round for AI was \(dist) units from target")
        nelderMead.addResult(parameters:[xVel,yVel,zVel], value: dist)
    }
    
    func fireParameters(players: [Player]) -> (azimuth: Float, altitude: Float, velocity: Float) {
        // pick parameters using Nelder-Mead algorithm
        // see: https://en.wikipedia.org/wiki/Nelder–Mead_method
        // also: http://www.scholarpedia.org/article/Nelder-Mead_algorithm
        
        // fill initial simplex
        //NSLog("\(#function): data: \(data)")
        if firstShot {
            var azimuth = Float(drand48() * 360)
            if let model = gameModel {
                let nextPlayer = getNextPlayerID()
                let targetTank = model.board.players[nextPlayer].tank
                let myTank = model.board.players[model.board.currentPlayer].tank
                
                NSLog("tank at \(myTank.position), target at \(targetTank.position).")
                // tank positions are in model space
                let targetDir = atan2(myTank.position.x - targetTank.position.x,
                                      myTank.position.y - targetTank.position.y) * (180 / Float.pi)
                NSLog("targetDir = \(targetDir)")
                //azimuth = Float(targetDir + Float(drand48() * 10) - 5)
                azimuth = targetDir
            }
            let altitude = Float(drand48() * 50) + 30
            let power = Float(drand48() * 70) + 30
            NSLog("\(#function): firing at random, azi,alt,pow: (\(azimuth),\(altitude),\(power))")
            
            let (xVel, yVel, zVel) = fromSpherical(azi: azimuth, alt: altitude, velocity: power)
            nelderMead.setSeed([xVel,yVel,zVel])
            firstShot = false
        }
        
        // get next sample point
        let ret = nelderMead.nextPoint()
        
        // convert new sample to polar coordinates
        let (retAzi, retAlt, retVel) = toSpherical(xVel: ret[0], yVel: ret[1], zVel: ret[2])
        let (retXvel, retYvel, retZvel) = fromSpherical(azi: retAzi, alt: retAlt, velocity: retVel)
        NSLog("returning firing parameters (azi,alt,vel) = \(retAzi),\(retAlt),\(retVel), or as vectors (x,y,z) = \(retXvel),\(retYvel),\(retZvel))")
        
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
