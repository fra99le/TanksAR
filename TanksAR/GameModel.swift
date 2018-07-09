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

struct Vector3 : Codable {
    var x: Float
    var y: Float
    var z: Float

    init() {
        self.x = 0
        self.y = 0
        self.z = 0
    }

    init(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) {
        self.x = Float(x)
        self.y = Float(y)
        self.z = Float(z)
    }

}

func vectorAdd(_ v1: Vector3, _ v2: Vector3) -> Vector3 {
    return Vector3(v1.x+v2.x, v1.y+v2.y, v1.z+v2.z)
}

func vectorDiff(_ v1: Vector3, _ v2: Vector3) -> Vector3 {
    return Vector3(v1.x-v2.x, v1.y-v2.y, v1.z-v2.z)
}

func vectorScale(_ v1: Vector3, by: Float) -> Vector3 {
    return Vector3(v1.x*by, v1.y*by, v1.z*by)
}

struct Tank : Codable {
    var position: Vector3
    var azimuth: Float // in degrees
    var altitude: Float // in degrees
    var velocity: Float // in m/s
}

struct Player : Codable {
    var tank: Tank = Tank(position: Vector3(), azimuth: 0, altitude: 0, velocity: 0)
    var name: String = "Unknown"
    var credit: Int64 = 5000
    var score: Int64 = 0
    var weaponID: Int = 0
    var weaponSizeID: Int = 0
    var hitPoints: Float = 1000
    var ai: PlayerAI? = nil
    var prevTrajectory: [Vector3] = []
    var useTargetingComputer: Bool = false // this needs to be pricy to enable
    var usedComputer: Bool = false

    // need to add shielding info
}

struct GameBoard : Codable {
    var boardSize: Int = 0
    var surface: ImageBuf = ImageBuf()
    var bedrock: ImageBuf = ImageBuf()
    
    // vector to encode windspeed
    var windSpeed: Float = 0
    var windDir: Float = 0
    
    // player
    var players: [Player] = []
    var currentPlayer: Int = 0
    
    // game progress
    var totalRounds = 1
    var currentRound = 1
}

struct HighScore : Codable {
    var name: String = "Unknown"
    var score: Int64 = 0
}

enum WeaponStyle : String, Codable {
    case explosive, generative, mud, napalm, mirv
}

struct WeaponSize : Codable {
    var name: String
    var size: Float
    var cost: Int
}
struct Weapon : Codable {
    var name: String
    var sizes: [WeaponSize]
    var style: WeaponStyle
}

struct FireResult {
    var playerID: Int = 0
    
    var timeStep: Float = 1
    var trajectory: [Vector3] = []
    var explosionRadius: Float = 100
    
    // need data to update map
    var old: ImageBuf
    var top: ImageBuf
    var middle: ImageBuf
    var bottom: ImageBuf

    var newRound: Bool
    var roundWinner: String?
}

// Note: For the model x,y are surface image coordinates, and z is elevation
// In GameViewController y and z are swapped.

class GameModel : Codable {
    // game board
    var board: GameBoard = GameBoard()
    let tankSize: Float = 25
    let maxPower: Float = 250
    let maxWindSpeed: Float = 20  // up to ~45 mph
    let elevationScale: Float = 2.0
    var gameStarted: Bool = false
    let gravity = Float(-9.80665)
    let computerCost = 2000
    
    var weaponsList = [
        Weapon(name: "Standard", sizes: [WeaponSize(name: "N/A", size: 35, cost: 10)], style: .explosive),
        Weapon(name: "Nuke", sizes: [WeaponSize(name: "baby", size: 75, cost: 1000),
                                     WeaponSize(name: "regular", size: 150, cost: 2000),
                                     WeaponSize(name: "heavy", size: 300, cost: 3000) ], style: .explosive),
        Weapon(name: "Dirty Bomb", sizes: [WeaponSize(name: "baby", size: 75, cost: 1000),
                                     WeaponSize(name: "regular", size: 150, cost: 2000),
                                     WeaponSize(name: "heavy", size: 300, cost: 3000) ], style: .generative)
        // still need MIRVs and liquid weapons
        ]
    
    // high-score data
    let highScores: [HighScore] = []
    
    func generateBoard() {
        NSLog("\(#function) started")
        
        // seed the random number generator
        let time = UInt32(NSDate().timeIntervalSinceReferenceDate)
        srand48(Int(time))
        
        board.boardSize = 1025
        board.surface.setSize(width: board.boardSize, height: board.boardSize)
        board.bedrock.setSize(width: board.boardSize, height: board.boardSize)
        
        board.surface.fillUsingDiamondSquare(withMinimum: 10.0/255.0, andMaximum: 255.0/255.0)
        //board.bedrock.fillUsingDiamondSquare(withMinimum: 5.0/255.0, andMaximum: 10.0/255.0)
        
        // set wind
        board.windDir = Float(drand48() * 360)
        board.windSpeed = Float(pow(drand48(),2)) * maxWindSpeed
        
        NSLog("\(#function) finished")
    }
    
    func startGame(numPlayers: Int, numAIs: Int = 0, rounds: Int) {
        let totalPlayers = numPlayers+numAIs
        board.players = [Player](repeating: Player(), count: totalPlayers)
        board.currentPlayer = 0

        board.currentRound = 1
        board.totalRounds = rounds
        NSLog("\(#function) starting \(board.totalRounds) round game.")
        
        // set player names
        for i in 0..<totalPlayers {
            if i < numPlayers {
                board.players[i].name = "Player \(i+1)"
            } else {
                board.players[i].name = "Al \(i-numPlayers+1)"
            }
            NSLog("player \(i)'s name is \(board.players[i].name)")
        }

        // add AI objects to AI players
        for i in numPlayers..<totalPlayers {
            board.players[i].ai = PlayerAI()
        }

        startRound()
        gameStarted = true
    }

    func resetAIs() {
        let totalPlayers = board.players.count

        // add AI objects to AI players
        for i in 0..<totalPlayers {
            guard let ai = board.players[i].ai else { continue }
            ai.reset()
        }
    }

    func startRound() {
        generateBoard()
        placeTanks()
        resetAIs()
        
        for i in 0..<board.players.count {
            board.players[i].hitPoints = 1000
        }
    }
    
    func getElevation(longitude: Int, latitude: Int) -> Float {
        return getElevation(fromMap: board.surface, longitude: longitude, latitude: latitude)
    }

    func getElevation(fromMap: ImageBuf, longitude: Int, latitude: Int) -> Float {
        guard longitude >= 0 else { return -1 }
        guard longitude < fromMap.width else { return -1 }
        guard latitude >= 0 else { return -1 }
        guard latitude < fromMap.height else { return -1 }

        let pixel = fromMap.getPixel(x: longitude, y: latitude)
        let elevation = Float(pixel*255)
        //let elevation = Float(10*( (longitude+latitude)%2 ) + 50)
        
        //print("Elevation at \(longitude),\(latitude) is \(elevation).")
        return elevation * elevationScale
    }

    func setElevation(longitude: Int, latitude: Int, to: Float) {
        setElevation(forMap: board.surface, longitude: longitude, latitude: latitude, to: to)
    }
    
    func setElevation(forMap: ImageBuf, longitude: Int, latitude: Int, to: Float) {
        guard longitude >= 0 else { return }
        guard longitude < forMap.width else { return }
        guard latitude >= 0 else { return }
        guard latitude < forMap.height else { return }
        
        let newElevation = max(0,to / 255) / elevationScale
        
        forMap.setPixel(x: longitude, y: latitude, value: CGFloat(newElevation))
        //print("Elevation at \(longitude),\(latitude) is now \(newElevation*255).")
    }
    
    func placeTanks(withMargin: Int = 50, minDist: Int = 100) {
        NSLog("\(#function) started")
        var tanksPlaced = 0
        var attemptsLeft = 10
        
        while tanksPlaced < board.players.count && attemptsLeft > 0 {
            tanksPlaced = 0
            attemptsLeft -= 1

            for i in 0..<board.players.count {
                
                var x: Float = 0
                var y: Float = 0
                var tankElevation: Float = 0
                var remainingAttempts = 20
                var validLocation = false
                while !validLocation && remainingAttempts > 0 {
                    x = Float(drand48() * Double(board.surface.width-withMargin*2) + Double(withMargin))
                    y = Float(drand48() * Double(board.surface.height-withMargin*2) + Double(withMargin))
                    tankElevation = getElevation(longitude: Int(x), latitude: Int(y))
                    
                    // measure distance to other tanks
                    var closestTank = Float(minDist + 1)
                    for j in 0..<i {
                        let tankDist = distance(from: Vector3(x,y,tankElevation),
                                                to: board.players[j].tank.position)
                        if tankDist < closestTank {
                            closestTank = tankDist
                        }
                    }
                    
                    // check validity of location
                    if closestTank > Float(minDist) {
                        validLocation = true
                    } else {
                        remainingAttempts -= 1
                    }
                }
                
                if validLocation {
                    board.players[i].tank = Tank(position: Vector3(x, y, tankElevation),
                                                 azimuth: 0, altitude: 45, velocity: 100)
                    tanksPlaced += 1
                }
            }
        }

        for i in 0..<board.players.count {
            // flatten area around tanks
            let tank = board.players[i].tank
            flattenAreaAt(longitude: Int(tank.position.x), latitude: Int(tank.position.y), withRadius: Int(tankSize * 1.1))
        }
    
        NSLog("\(#function) started")
    }
    
    func flattenAreaAt(longitude: Int, latitude: Int, withRadius: Int) {
        let min_x = (longitude<withRadius) ? 0 : longitude-withRadius
        let max_x = (longitude+withRadius>=board.surface.width) ? board.surface.width-1 : longitude+withRadius
        let min_y = (latitude<withRadius) ? 0 : latitude-withRadius
        let max_y = (latitude+withRadius>=board.surface.height) ? board.surface.height-1 : latitude+withRadius

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
        let rad = azimuth * (Float.pi / 180)
        var cleanAzimuth = atan2(sin(rad),cos(rad)) * (180 / Float.pi)
        if cleanAzimuth < 0 {
            cleanAzimuth = 360 + cleanAzimuth
        }
        cleanAzimuth = Float(Int(cleanAzimuth * 100 + 0.5)) / Float(100)
        board.players[board.currentPlayer].tank.azimuth = cleanAzimuth
        board.players[board.currentPlayer].tank.altitude = max(0,min(altitude,180))
        //NSLog("tank for player \(board.currentPlayer) set to \(board.players[board.currentPlayer].tank.azimuth)º,\(board.players[board.currentPlayer].tank.altitude)º")
    }

    func setTankPower(power: Float) {
        guard power >= 0 else { return }

        board.players[board.currentPlayer].tank.velocity = min(power,maxPower)
    }

    func fire(muzzlePosition: Vector3, muzzleVelocity: Vector3) -> FireResult {
        NSLog("\(#function) started")

        let timeStep = Float(1)/Float(60)
        
        // charge points
        let player = board.players[board.currentPlayer]
        let weapon = weaponsList[player.weaponID]
        let weaponSize = weapon.sizes[player.weaponSizeID].size
        let weaponCost = weapon.sizes[player.weaponSizeID].cost +
                                    ((player.useTargetingComputer || player.usedComputer) ? computerCost : 0)
        if weaponCost >= player.credit {
            board.players[board.currentPlayer].score -= Int64(weaponCost) - player.credit
            board.players[board.currentPlayer].credit = 0
        } else {
            board.players[board.currentPlayer].credit -= Int64(weaponCost)
        }
        board.players[board.currentPlayer].usedComputer = false
        board.players[board.currentPlayer].useTargetingComputer = false
        
        NSLog("firing \(weapon.name) with size \(weaponSize) and style \(weapon.style).")
        let trajectory = computeTrajectory(muzzlePosition: muzzlePosition, muzzleVelocity: muzzleVelocity, withTimeStep: timeStep)

        // deal with impact
        let impactPosition = trajectory.last!
        let blastRadius = weaponSize
        
        board.players[board.currentPlayer].prevTrajectory = trajectory
        
        // update board with new values
        let sizeID = board.players[board.currentPlayer].weaponSizeID
        let old = ImageBuf()
        old.copy(board.surface)
        let (top, middle, bottom) = applyExplosion(at: impactPosition, withRadius: weaponSize, andStyle: weapon.style)
        damageCheck(at: impactPosition, fromWeapon: weapon, withSize: sizeID)
        
        // check for round winner before checking/starting new round
        var roundWinner: String? = nil
        for player in board.players {
            if player.hitPoints > 0 {
                roundWinner = player.name
            }
        }

        let roundEnded = roundCheck()
        
        if !roundEnded {
            // update tank elevations
            for i in 0..<board.players.count {
                let oldPos = board.players[i].tank.position
                let newElevation = getElevation(longitude: Int(oldPos.x), latitude: Int(oldPos.y))
                if newElevation < oldPos.z {
                    board.players[i].tank.position = Vector3(oldPos.x,oldPos.y, newElevation)
                }
            }
        }
        
        // check to see if current weapon is affordable
        adjustWeapon()
        
        let result: FireResult = FireResult(playerID: board.currentPlayer,
                                            timeStep: timeStep,
                                            trajectory: trajectory,
                                            explosionRadius: blastRadius,
                                            old: old,
                                            top: top,
                                            middle: middle,
                                            bottom: bottom,
                                            newRound: roundEnded,
                                            roundWinner: roundWinner)
        
        board.currentPlayer = (board.currentPlayer + 1) % board.players.count
        while !roundEnded && board.players[board.currentPlayer].hitPoints <= 0 {
            NSLog("skipping downed player )\(board.currentPlayer)")
            board.currentPlayer = (board.currentPlayer + 1) % board.players.count
        }
        print("Player \(board.currentPlayer) now active.")
        
        NSLog("\(#function) finished")

        return result
    }
    
    func computeTrajectory(muzzlePosition: Vector3, muzzleVelocity: Vector3, withTimeStep: Float) -> [Vector3] {
        let timeStep = withTimeStep
    
        // record use of targeting computer
        if board.players[board.currentPlayer].useTargetingComputer {
            board.players[board.currentPlayer].usedComputer = true
        }
        
        // compute wind components
        let windX = cos(board.windDir * (Float.pi / 180)) * board.windSpeed
        let windY = sin(board.windDir * (Float.pi / 180)) * board.windSpeed
        let terminalSpeed: Float = 100
        NSLog("wind: \(board.windSpeed) m/s @ \(board.windDir)º, which is x,y = \(windX),\(windY) m/s")
        
        // compute trajectory
        var trajectory: [Vector3] = [muzzlePosition]
        var airborn = true
        let p0 = muzzlePosition // p_0
        let v0 = muzzleVelocity // v_0
        let vInf = Vector3(windX, windY, -terminalSpeed)
        let k: Float = -0.5 * gravity / terminalSpeed
        NSLog("p_0: \(p0), v_0: \(v0), vInf: \(vInf), k: \(k)")
        
        var iterCount = 0
        var t: Float = 0
        //var prevPosition = p0
        while airborn {
            
            // For information on effects of wind,
            // see: http://www.decarpentier.nl/downloads/AnalyticalBallisticTrajectoriesWithApproximatelyLinearDrag-GJPdeCarpentier.pdf
            let vDiff = vectorDiff(v0, vInf)
            let term1 = vectorScale(vDiff, by: 1/(2 * k) * (1 - exp(-2 * k * t)))
            
            let term2 = vectorScale(vInf, by: t)
            
            let term3 = p0
            
            let position = vectorAdd(vectorAdd(term1, term2), term3)
            
            //print("computing trajectory: pos=\(position)")
            //let velocity = vectorScale(vectorDiff(position,prevPosition), by: 1/timeStep)
            //print("computing trajectory: pos=\(position), vel=\(velocity)")
            
            // record position
            trajectory.append(position)
            
            t += timeStep
            
            //            // update position
            //            // NOTE: the model should do all calculations in model space, not view space
            //            p0.x += v0.x * timeStep
            //            p0.y += v0.y * timeStep
            //            p0.z += v0.z * timeStep + 0.5 * gravity * (timeStep*timeStep)
            //
            //            // update velocity
            //            v0.z += gravity * timeStep
            
            // check for impact
            let distAboveLand = position.z - getElevation(longitude: Int(position.x), latitude: Int(position.y))
            if position.z<0 || distAboveLand<0 {
                airborn = false
            }
            
            for i in 0..<board.players.count {
                let player = board.players[i]
                
                let tank = player.tank
                guard board.players[i].hitPoints > 0 else  { continue }
                
                let dist = distance(from: tank.position, to: position)
                if dist < tankSize {
                    // hit a tank
                    airborn = false
                }
            }
            
            //prevPosition = position
            
            if iterCount > 10000 {
                break
            }
            iterCount += 1
            
        }
        NSLog("shell took \(timeStep*Float(iterCount))s (\(iterCount) iterations) to land")
        //NSLog("trajectory: \(trajectory)")
        
        return trajectory
    }
    
    func applyExplosion(at: Vector3, withRadius: Float, andStyle: WeaponStyle = .explosive) -> (ImageBuf, ImageBuf, ImageBuf) {
        NSLog("\(#function) started")
        let topBuf = ImageBuf()
        let middleBuf = ImageBuf()
        let bottomBuf = ImageBuf()
        NSLog("starting image buffer copies")
        topBuf.copy(board.surface)
        middleBuf.copy(board.surface)
        bottomBuf.copy(board.surface)

        NSLog("\(#function) starting explosion computation at \(at) with radius \(withRadius) and style \(andStyle).")
        let style = andStyle
        
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
                let expTop = at.z + vertSize
                let expBottom = at.z - vertSize
                
                if style == .explosive  {
                    let top = currElevation
                    let middle = expTop
                    let bottom = min(currElevation, expBottom)
                    
                    setElevation(forMap: topBuf, longitude: i, latitude: j, to: top)
                    setElevation(forMap: middleBuf, longitude: i, latitude: j, to: middle)
                    setElevation(forMap: bottomBuf, longitude: i, latitude: j, to: bottom)
                    
                    // update actual map
                    let newElevation = min(currElevation, bottom + max(0,top-middle))
                    setElevation(longitude: i, latitude: j, to: newElevation)
                } else if style == .generative {
                    let top = expTop
                    let middle = expBottom
                    var bottom = currElevation
                    
                    // update actual map
                    var newElevation = currElevation
                    if middle > currElevation {
                        newElevation = currElevation + (top - middle) // new chunk is elevated
                    } else if top > currElevation {
                        newElevation = top // new chunk crosses old surface
                        bottom = top // top is new final surface
                    } else if top <= currElevation {
                        newElevation = currElevation // new chunk below old surface
                    } else {
                        newElevation = currElevation * 1.1
                        //NSLog("Unconsidered case, this is wierd! top: \(top), middle: \(middle), bottom: \(bottom), curr: \(currElevation)")
                    }
//                    if( newElevation != currElevation) {
//                        NSLog("generative level change: \(currElevation) -> \(newElevation) at \(i),\(j)")
//                    }
                    setElevation(forMap: topBuf, longitude: i, latitude: j, to: top)
                    setElevation(forMap: middleBuf, longitude: i, latitude: j, to: middle)
                    setElevation(forMap: bottomBuf, longitude: i, latitude: j, to: bottom)
                    setElevation(longitude: i, latitude: j, to: newElevation)
                } else {
                    NSLog("\(#function) doesn't handle \(andStyle) style.")
                }
            }

        }
        NSLog("\(#function) finished")

        return (topBuf, middleBuf, bottomBuf)
    }
    
    func distance(from: Vector3, to: Vector3) -> Float {
        let xDiff = from.x - to.x
        let yDiff = from.y - to.y
        let zDiff = from.z - to.z
        
        return sqrt(xDiff*xDiff + yDiff*yDiff + zDiff*zDiff)
    }
    
    func damageCheck(at: Vector3, fromWeapon: Weapon, withSize: Int) {
        NSLog("\(#function) started")

        for i in 0..<board.players.count {
            let player = board.players[i]
            
            let tank = player.tank
            let tankPos = tank.position
            //NSLog("\ttank at \(tankPos)")
            
            let dist = distance(from: tankPos, to: at)
            NSLog("\t tank \(i) dist = \(dist)")
            let weaponSize = fromWeapon.sizes[withSize].size
            if dist < (weaponSize + tankSize) && board.players[i].hitPoints > 0 {
                NSLog("\t\tPlayer \(board.currentPlayer) hit player \(i)")
                let effectiveDist = min(1,dist-tankSize)
                NSLog("\t\teffectiveDist: \(effectiveDist)")
                let damage = min(board.players[i].hitPoints,
                                 (weaponSize * weaponSize) / (effectiveDist * effectiveDist))
                NSLog("\t\tdamage: \(damage)")
                board.players[i].hitPoints = max(0, board.players[i].hitPoints -  damage)
                
                if board.currentPlayer != i {
                    board.players[board.currentPlayer].score += Int64(damage)
                    if board.players[i].hitPoints <= 0 {
                        board.players[board.currentPlayer].score += 1000
                    }
                    NSLog("\tplayer \(board.currentPlayer) score now \(board.players[board.currentPlayer].score)")
                } else {
                    // player killed themself, distribute poinrts across other players
                    var playersLeft: Float = 0
                    for player in board.players {
                        if player.hitPoints > 0 {
                            playersLeft += 1
                        }
                    }
                    
                    let pointsPer = damage / playersLeft
                    for i in 0..<board.players.count {
                        if board.players[i].hitPoints > 0 {
                            board.players[i].score += Int64(pointsPer)
                        }
                    }
                }
            }
        }
        
        NSLog("\(#function) finished")
    }

    func roundCheck() -> Bool {
        var playersLeft = 0
        for player in board.players {
            if player.hitPoints > 0 {
                playersLeft += 1
            }
        }
        
        let newRound = playersLeft <= 1
        if newRound {
            // apply round bonuses
            NSLog("Round ended")
            for i in 0..<board.players.count {
                let player = board.players[i]
                if player.score > 0 {
                    board.players[i].score = Int64(Double(board.players[i].score) * 1.1)
                    NSLog("\tPlayer \(0) score now \(board.players[i].score)")
                }
                board.players[i].prevTrajectory = []
            }
            board.currentRound += 1
            startRound()
        }
        
        return newRound
    }
    
    func adjustWeapon() {
        // adjust weapon if current one is unaffordable
        let player = board.players[board.currentPlayer]
        let score = player.score
        let credit = player.credit

        var weaponID = player.weaponID
        var weaponSizeID = player.weaponSizeID
        var weapon = weaponsList[weaponID]
        
        while weaponSizeID > 0 && weapon.sizes[weaponSizeID].cost > (score + credit) {
            NSLog("Player can no longer afford current weapon size.")
            weaponSizeID -= 1
        }
        
        if weaponID > 0 && weapon.sizes[weaponSizeID].cost > (score + credit) {
            NSLog("Player can no longer afford current weapon.")
            weaponID = 0
        }
        
        board.players[board.currentPlayer].weaponID = weaponID
        board.players[board.currentPlayer].weaponSizeID = weaponSizeID
    }
    
    func getWinner() -> (name: String, score: Int64) {
        var maxScore = board.players[0].score - 1
        var winner = ""
        for i in 0..<board.players.count {
            if board.players[i].score > maxScore {
                maxScore = board.players[i].score
                winner = board.players[i].name
            }
        }
        
        return (winner, maxScore)
    }
    
    func fluidFill(startX: Int, startY: Int, totalVolume: Float) {
        NSLog("\(#function) started")

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
        NSLog("\(#function) started")

    }
}
