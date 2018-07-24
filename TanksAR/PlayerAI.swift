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
    var nelderMead = NelderMead(dimensions: 3)
    var data: [Sample] = []
    var firstShot = true
    var lastTarget = -1
    
    // needs to be called between rounds (i.e. when tanks move)
    func reset() {
        data = []
        nelderMead = NelderMead(dimensions: 3)
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
    
    func getNextPlayerID(gameModel: GameModel) -> Int {
        let board = gameModel.board
        let currentPlayer = board.currentPlayer

        // find a player with positive hit points
        var nextPlayer = (currentPlayer + 1) % board.players.count
        while board.players[nextPlayer].hitPoints <= 0 {
            nextPlayer = (nextPlayer + 1) % board.players.count
        }

        return nextPlayer
    }
    
    func recordResult(gameModel: GameModel, azimuth: Float, altitude: Float, velocity: Float,
                      impactX: Float, impactY: Float, impactZ: Float) -> Float {
        let (xVel, yVel, zVel) = fromSpherical(azi: azimuth, alt: altitude, velocity: velocity)
        //let (azi2, alt2, vel2) = toSpherical(xVel: xVel, yVel: yVel, zVel: zVel)
        //NSLog("\(#function): \(azimuth),\(altitude),\(velocity) -> linear -> \(azi2),\(alt2),\(vel2)")

        let newSample = Sample(azimuth: azimuth, altitude: altitude, velocity: velocity,
                               velocityX: xVel, velocityY: yVel, velocityZ: zVel,
                               impactX: impactX, impactY: impactY, impactZ: impactZ)
        data.append(newSample)

        // compute next point
        // pick target player
        let nextPlayer = getNextPlayerID(gameModel: gameModel)
        //NSLog("\(#function): \(gameModel.board.players[gameModel.board.currentPlayer].name) targetting player \(nextPlayer) (\(gameModel.board.players[nextPlayer].name))")
        let targetPlayer = gameModel.board.players[nextPlayer]
        let targetTank = targetPlayer.tank
        
        // get dist to target
        let dist = distToTank(from: newSample, toTank: targetTank)
        //NSLog("\(#function): last round for AI was \(dist) units from target (\(targetTank.position)) -> (\(impactX),\(impactY),\(impactZ))")
        nelderMead.addResult(parameters:[xVel,yVel,zVel], value: dist)
        
        return dist
    }
    
    func fireParameters(gameModel: GameModel, players: [Player]) -> (azimuth: Float, altitude: Float, velocity: Float) {
        // pick parameters using Nelder-Mead algorithm
        // see: https://en.wikipedia.org/wiki/Nelder–Mead_method
        // also: http://www.scholarpedia.org/article/Nelder-Mead_algorithm

        let model = gameModel
        let nextPlayer = getNextPlayerID(gameModel: model)

        if nextPlayer != lastTarget {
            reset()
        }
        lastTarget = nextPlayer
        
        // fill initial simplex
        //NSLog("\(#function): data: \(data)")
        if firstShot {
            let targetTank = model.board.players[nextPlayer].tank
            let myTank = model.board.players[model.board.currentPlayer].tank
            
            //NSLog("tank at \(myTank.position), target at \(targetTank.position).")
            // tank positions are in model space
            let targetDir = atan2(myTank.position.x - targetTank.position.x,
                                  myTank.position.y - targetTank.position.y) * (180 / Float.pi)
            //NSLog("targetDir = \(targetDir)")
            //let azimuth = Float(targetDir + Float(drand48() * 10) - 5)
            let azimuth = targetDir

            let altitude = Float(drand48() * 50) + 30
            let power = Float(drand48() * 70) + 30
            //NSLog("\(#function): firing at random, azi,alt,pow: (\(azimuth),\(altitude),\(power))")
            
            let (xVel, yVel, zVel) = fromSpherical(azi: azimuth, alt: altitude, velocity: power)
            nelderMead.setSeed([xVel,yVel,zVel])
            firstShot = false
        }
        
        // get next sample point
        let ret = nelderMead.nextPoint()
        
        // convert new sample to polar coordinates
        var (retAzi, retAlt, retVel) = toSpherical(xVel: ret[0], yVel: ret[1], zVel: ret[2])
        retVel = min(retVel, gameModel.maxPower)
        let (retXvel, retYvel, retZvel) = fromSpherical(azi: retAzi, alt: retAlt, velocity: retVel)
        NSLog("returning firing parameters (azi,alt,vel) = \(retAzi),\(retAlt),\(retVel), or as vectors (x,y,z) = \(retXvel),\(retYvel),\(retZvel))")
        
        return (retAzi, retAlt, retVel)
    }
    
    func fireParameters(gameModel: GameModel, players: [Player], num: Int = 1) -> (azimuth: Float, altitude: Float, velocity: Float) {
        
        // get next point
        var nextParams = fireParameters(gameModel: gameModel, players: players)
        
        var minDist: Float = 1_000_000
        for i in 0..<num {
            //NSLog("nextParams: \(nextParams)")
            // get muzzle velocity
            let tank = gameModel.getTank(forPlayer: gameModel.board.currentPlayer)
            let power = nextParams.velocity
            let azi = nextParams.azimuth * (Float.pi/180)
            let alt = nextParams.altitude * (Float.pi/180)
            
            let xVel = -power * sin(azi) * cos(alt)
            let yVel = -power * cos(azi) * cos(alt)
            let zVel = power * sin(alt)
            
            //NSLog("tank angles: \(tank.azimuth),\(tank.altitude)")
            let velocity = Vector3(xVel, yVel, zVel)
            let muzzleVelocity = velocity

            // Note: This position is very wrong, and could be leading to incorrect solutions.
            let tankHeight: Float = 14.52 // 0.625+0.827 = 1.452 * tankScale
            let barrelLength: Float = 20
            var muzzlePosition = tank.position
            muzzlePosition.x += -sin(azi) * cos(alt) * barrelLength
            muzzlePosition.y += -cos(azi) * cos(alt) * barrelLength
            muzzlePosition.z += tankHeight + sin(alt) * barrelLength
            
            // compute result
            //NSLog("computing trajectory for muzzlePosition: \(muzzlePosition) and muzzleVelocity: \(muzzleVelocity)")
            let trajectory = gameModel.computeTrajectory(muzzlePosition: muzzlePosition,
                                                         muzzleVelocity: muzzleVelocity,
                                                         withTimeStep: 0.02,
                                                         ignoreTanks: true)
            let impact = trajectory.last!
            //NSLog("impact at \(impact), \(trajectory.count) iterations.")
            
            // add it's result
            let dist = recordResult(gameModel: gameModel, azimuth: nextParams.azimuth, altitude: nextParams.altitude, velocity: nextParams.velocity,
                         impactX: impact.x, impactY: impact.y, impactZ: impact.z)
            
            minDist = min(minDist,dist)
            if dist < 1 {
                NSLog("dist down to \(dist) after \(i) of \(num) iterations.")
                return nextParams
            } else if i > 100 {
                NSLog("dist is \(dist) after \(i) of \(num) iterations (minimum was \(minDist)).")
            }
            
            nextParams = fireParameters(gameModel: gameModel, players: players)
        }
        NSLog("Exhausted \(num) iterations finding firing solution!!!  Minimum distance found was \(minDist).")
        
        return nextParams
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
