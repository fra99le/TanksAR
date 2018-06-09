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
import SceneKit

struct Tank {
    var position: SCNVector3
    var azimuth: Float // in degrees
    var altitude: Float // in degrees
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
    
    // vector to encode windspeed
    var wind: SCNVector3 = SCNVector3(0, 0, 0)
    
    // player
    var players: [Player] = []
    var currentPlayer: Int = 0
}

struct HighScore {
    var name: String = "Unknown"
    var score: Int64 = 0
}

struct FireResult {
    var timeStep: Float = 1
    var trajectory: [SCNVector3] = []
    var explosionRadius: Float = 100
    
    // need data to update map
    var mapUpdate: ImageBuf
}

enum ElevationMode {
    case top, middle, bottom, old, actual
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
        
        board.surface.fillUsingDiamondSquare(withMinimum: 50.0/255.0, andMaximum: 200.0/255.0)
        board.bedrock.fillUsingDiamondSquare(withMinimum: 5.0/255.0, andMaximum: 40.0/255.0)
    }
    
    func startGame(numPlayers: Int) {
        board.players = [Player](repeating: Player(), count: numPlayers)
        board.currentPlayer = 0
        
        placeTanks()
    }

    func getElevation(longitude: Int, latitude: Int, forMode: ElevationMode = .actual) -> Float {
        return getElevation(fromMap: board.surface, longitude: longitude, latitude: latitude, forMode: forMode)
    }

    func getElevation(fromMap: ImageBuf, longitude: Int, latitude: Int, forMode: ElevationMode = .actual) -> Float {
        guard longitude >= 0 else { return -1 }
        guard longitude < fromMap.width else { return -1 }
        guard latitude >= 0 else { return -1 }
        guard latitude < fromMap.height else { return -1 }

        let (red: r, green: g, blue: b, alpha: a) = fromMap.getPixel(x: longitude, y: latitude)
        var elevation = Float(r*255)
        switch forMode {
        case .top:
            elevation = Float(r * 255)
        case .middle:
            elevation = Float(g * 255)
        case .bottom:
            elevation = Float(b * 255)
        case .old:
            elevation = Float(a * 255)
        case .actual:
            elevation = Float(r * 255)
        }
        //print("Elevation at \(longitude),\(latitude) is \(elevation).")
        return elevation
    }

    func setElevation(longitude: Int, latitude: Int, to: Float, forMode: ElevationMode = .actual) {
        setElevation(forMap: board.surface, longitude: longitude, latitude: latitude, to: to, forMode: forMode)
    }
    
    func setElevation(forMap: ImageBuf, longitude: Int, latitude: Int, to: Float, forMode: ElevationMode = .actual) {
        guard longitude >= 0 else { return }
        guard longitude < forMap.width else { return }
        guard latitude >= 0 else { return }
        guard latitude < forMap.height else { return }
        
        let newElevation = max(0,to)
        var (red: r, green: g, blue: b, alpha: a) = forMap.getPixel(x: longitude, y: latitude)
        switch forMode {
        case .top:
            r = CGFloat(newElevation / 255)
        case .middle:
            g = CGFloat(newElevation / 255)
        case .bottom:
            b = CGFloat(newElevation / 255)
        case .old:
            a = CGFloat(newElevation / 255)
        case .actual:
            r = CGFloat(newElevation / 255)
            g = 0
            b = 0
            a = CGFloat(newElevation / 255)
        }
        forMap.setPixel(x: longitude, y: latitude, r: r, g: g, b: b, a: a)
        //print("Elevation at \(longitude),\(latitude) is now \(r*255),\(g*255),\(b*255),\(a*255).")
    }
    
    func placeTanks(withMargin: Int = 50, minDist: Int = 10) {
        for i in 0..<board.players.count {
            let x = Float(drand48() * Double(board.surface.width-withMargin*2) + Double(withMargin))
            let y = Float(drand48() * Double(board.surface.height-withMargin*2) + Double(withMargin))

            let tankElevation = getElevation(longitude: Int(x), latitude: Int(y))
            board.players[i].tank = Tank(position: SCNVector3(x: x, y: y, z: tankElevation),
                                         azimuth: 0, altitude: Float(Double.pi/4), velocity: 10)
        
            // flatten area around tanks
            let tank = board.players[i].tank!
            flattenAreaAt(longitude: Int(tank.position.x), latitude: Int(tank.position.y), withRadius: 100)
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
                    setElevation(longitude: i, latitude: j, to: elevation)
                }
            }
        }
    }
    
    func getTank(forPlayer: Int) -> Tank {
        return board.players[forPlayer].tank
    }
    
    func setTankAim(azimuth: Float, altitude: Float) {
        var cleanAzimuth = azimuth
        if azimuth > 360 {
            let remove = Float(floor(cleanAzimuth/360)*360)
            cleanAzimuth -= remove
        } else if azimuth < 0 {
            cleanAzimuth = -cleanAzimuth
            let remove = Float(floor((cleanAzimuth)/360)*360)
            cleanAzimuth -= remove
            cleanAzimuth = 360 - cleanAzimuth
        }
        board.players[board.currentPlayer].tank.azimuth = cleanAzimuth
        board.players[board.currentPlayer].tank.altitude = max(0,min(altitude,180))
    }

    func setTankPower(power: Float) {
        guard power >= 0 else { return }

        board.players[board.currentPlayer].tank.velocity = power
    }

    func fire(muzzlePosition: SCNVector3, muzzleVelocity: SCNVector3) -> FireResult {
        print("Fire isn't fully implemented, yet!")
        board.currentPlayer = (board.currentPlayer + 1) % board.players.count
        print("Player \(board.currentPlayer) now active.")

        let timeStep = Float(1)/Float(10)
        let gravity = Float(9.80665)
        
        // compute trajectory
        var trajectory: [SCNVector3] = []
        var airborn = true
        var position = muzzlePosition
        var velocity = muzzleVelocity

        var iterCount = 0
        while airborn {
            //print("computing trajectory: pos=\(position), vel=\(velocity)")
            // record position
            trajectory.append(position)
            
            // update position
            position.x += velocity.x * timeStep
            position.y += velocity.y * timeStep
            position.z += velocity.z * timeStep

            // update velocity
            velocity.z -= 0.5 * gravity * (timeStep*timeStep)
            
            // check for impact
            let distAboveLand = position.z - getElevation(longitude: Int(position.x), latitude: Int(position.y))
            if position.y<0 || distAboveLand<0 {
                airborn = false
            }
            if iterCount > 10000 {
                break
            }
            iterCount += 1
            
        }
        
        // deal with impact
        let impactPosition = position
        let blastRadius = Float(100)
        
        // update board with new values
        let updates = applyExplosion(at: impactPosition, withRadius: blastRadius)
        
        let result: FireResult = FireResult(timeStep: timeStep,
                                            trajectory: trajectory,
                                            explosionRadius: blastRadius,
                                            mapUpdate: updates)
        
        return result
    }
    
    func applyExplosion(at: SCNVector3, withRadius: Float) -> ImageBuf {
        let changeBuf = ImageBuf()
        changeBuf.copy(board.surface)

        // record old height in alpha channel
        for j in 0..<changeBuf.height {
            for i in 0..<changeBuf.width {
                let currElevation = getElevation(longitude: i, latitude: j)
                setElevation(forMap: changeBuf, longitude: i, latitude: j, to: currElevation, forMode: .old)
            }
        }
        
        // update things in the radius of the explosion
        for j in Int(at.y-withRadius)...Int(at.y+withRadius) {
            for i in Int(at.x-withRadius)...Int(at.x+withRadius) {
                let xDiff = at.x - Float(i)
                let yDiff = at.y - Float(j)
                
                let horizDist = sqrt(xDiff*xDiff + yDiff*yDiff)
                guard withRadius >= horizDist else { continue }
                
                // get z component of sphere at i,j
                // a^2 = c^2 - b^2
                // c = withRadius
                // b = horizDist
                let vertSize = sqrt(withRadius*withRadius - horizDist*horizDist)
                
                let currElevation = getElevation(longitude: i, latitude: j)
                let top = currElevation
                let mid = at.z + vertSize
                let lower = at.z - vertSize
                
                if top  > mid {
                    // column extends above explosion
                    setElevation(forMap: changeBuf, longitude: i, latitude: j, to: top, forMode: .top)
                    setElevation(forMap: changeBuf, longitude: i, latitude: j, to: mid, forMode: .middle)
                    setElevation(forMap: changeBuf, longitude: i, latitude: j, to: lower, forMode: .bottom)
                } else {
                    // no upper section as this point
                    setElevation(forMap: changeBuf, longitude: i, latitude: j, to: 0, forMode: .top)
                    setElevation(forMap: changeBuf, longitude: i, latitude: j, to: 0, forMode: .middle)
                    setElevation(forMap: changeBuf, longitude: i, latitude: j, to: lower, forMode: .bottom)
                }
                
                // update actual map
                let newElevation = lower + max(0,top-mid)
                setElevation(longitude: i, latitude: j, to: newElevation)
            }

        }
        NSLog("applyExplosion finished")
        
        return changeBuf
    }
    
    func fluidFill(startX: Int, startY: Int, totalVolume: Float) {
        var remainingVolume = totalVolume
        
        // need a priority queue of edge pixels ordered by height
        while remainingVolume > 0 {
            // get lowest pixel from queue
            
            // check neighboring pixels

            // if one is lower that current, replace queue with it

            // else (i.e. all are higher)
                // increase level to lowest edge pixel
                // add its neighbors to neighbor queue
                // compute volume used in level raise
                let volumeAdded = Float(1)
                // update volume left
                remainingVolume -= volumeAdded
        }
    }
}
