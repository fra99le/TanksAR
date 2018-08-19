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

// Note: when fluid weapons are fired by buried tanks, they jump to the surface, this seems wrong.

struct OrderedElevation : Comparable {
    var elevation: Float
    var order: Int
    
    static func < (lhs: OrderedElevation, rhs: OrderedElevation) -> Bool {
        if lhs.elevation == rhs.elevation {
            return lhs.order < rhs.order
        }
        return lhs.elevation < rhs.elevation
    }
    
    static func == (lhs: OrderedElevation, rhs: OrderedElevation) -> Bool {
        return lhs.elevation == rhs.elevation && lhs.order == rhs.order
    }
}

struct MapCoordinate : Hashable {
    var x: Int
    var y: Int
}

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

    var description: String {
        return "(\(x),\(y),\(z))"
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

func vectorLength(_ v: Vector3) -> Float {
    let length = sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
    return length
}

func vectorNormalize(_ v: Vector3) -> Vector3 {
    let length = vectorLength(v)
    if length == 0 {
        return Vector3()
    }
    
    return vectorScale(v, by: 1/length)
}

func vectorCross(_ v1: Vector3, _ v2: Vector3) -> Vector3 {
        //      | i  j  k  |
        //  det | x1 y1 z1 |
        //      | x2 y2 z2 |
        var i, j, k: Float;
        
        i = v1.y * v2.z - v1.z * v2.y;
        j = v1.z * v2.x - v1.x * v2.z;
        k = v1.x * v2.y - v1.y * v2.x;
        
        let ret = Vector3( i, j, k);
        
        return ret;
}

struct Tank : Codable {
    var position: Vector3
    var azimuth: Float // in degrees
    var altitude: Float // in degrees
    var velocity: Float // in m/s
}

struct PlayerStats: Codable {
    var shotsFired: Int = 0
    var kills: Int = 0
    var suicides: Int = 0
    var maxKillsPerShot: Int = 0
    var pointsSpent: Int64 = 0
    var maxPoints: Int64 = 0
}

struct Player : Codable {
    var tank: Tank = Tank(position: Vector3(), azimuth: 0, altitude: 0, velocity: 0)
    var name: String = "Unknown"
    var didSetName = false
    var credit: Int64 = 5000
    var score: Int64 = 0
    var weaponID: Int = 0
    var weaponSizeID: Int = 0
    var hitPoints: Float = 1000
    var ai: PlayerAI? = nil
    var prevTrajectory: [Vector3] = []
    var useTargetingComputer: Bool = false // this needs to be pricy to enable
    var usedComputer: Bool = false

    var stats: PlayerStats = PlayerStats()
    
    // need to add shielding info
}

struct GameBoard : Codable {
    var boardSize: Int = 0
    var surface: ImageBuf = ImageBuf()
    var bedrock: ImageBuf = ImageBuf()
    var colors: ImageBuf = ImageBuf()
    
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

struct DetonationResult {
    var topBuf: ImageBuf
    var middleBuf: ImageBuf
    var bottomBuf: ImageBuf
    var topColor: ImageBuf
    var bottomColor: ImageBuf
    var fluidPath: [Vector3]
    var fluidRemaining: [Float]
    var timeIndex: Int
    
    // coordinates of detonation
    var minX: Int
    var maxX: Int
    var minY: Int
    var maxY: Int
}

struct FireResult {
    var playerID: Int = 0
    
    var timeStep: Float = 1
    var trajectories: [[Vector3]] = []
    var explosionRadius: Float = 100
    var weaponStyle: WeaponStyle
    var detonationResult: [DetonationResult]
    
    // data needed to animate board
    var old: ImageBuf
    var final: ImageBuf

    // data needed for color updates
    var oldColor: ImageBuf
    var finalColor: ImageBuf
    
    var newRound: Bool
    var roundWinner: String?
    var humanLeft: Int = 0
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
    var gameOver: Bool = false
    let gravity = Float(-9.80665)
    let computerCost = 2000
    
    var weaponsList = [
        Weapon(name: "Standard", sizes: [WeaponSize(name: "N/A", size: 35, cost: 100)], style: .explosive),
        Weapon(name: "Nuke", sizes: [WeaponSize(name: "baby", size: 75, cost: 1000),
                                     WeaponSize(name: "regular", size: 150, cost: 2000),
                                     WeaponSize(name: "heavy", size: 300, cost: 3000) ], style: .explosive),
        Weapon(name: "Dirty Bomb", sizes: [WeaponSize(name: "baby", size: 75, cost: 1000),
                                     WeaponSize(name: "regular", size: 150, cost: 2000),
                                     WeaponSize(name: "heavy", size: 300, cost: 3000) ], style: .generative),
        Weapon(name: "Mud", sizes: [WeaponSize(name: "baby", size: 75, cost: 1000),
                                            WeaponSize(name: "regular", size: 150, cost: 2000),
                                            WeaponSize(name: "heavy", size: 300, cost: 3000)], style: .mud),
        Weapon(name: "Napalm", sizes: [WeaponSize(name: "baby", size: 75, cost: 1000),
                                            WeaponSize(name: "regular", size: 150, cost: 2000),
                                            WeaponSize(name: "heavy", size: 300, cost: 3000)], style: .napalm),
        Weapon(name: "MIRV", sizes: [WeaponSize(name: "linear", size: 5, cost: 500),
                                     WeaponSize(name: "linear", size: 6, cost: 500),
                                       WeaponSize(name: "cross", size: 9, cost: 900),
                                       WeaponSize(name: "ring", size: 13, cost: 1200),
                                       WeaponSize(name: "crosshairs", size: 17, cost: 1700),
                                       WeaponSize(name: "wheel", size: 21, cost: 2100),
                                       WeaponSize(name: "grid", size: 25, cost: 2500)], style: .mirv),

        ]
    
    func generateBoard() {
        NSLog("\(#function) started")
        
        // seed the random number generator
        let time = UInt32(NSDate().timeIntervalSinceReferenceDate)
        srand48(Int(time))
        
        board.boardSize = 1025
        board.surface.setSize(width: board.boardSize, height: board.boardSize)
        board.bedrock.setSize(width: board.boardSize, height: board.boardSize)
        board.colors.setSize(width: board.boardSize, height: board.boardSize) // 0=grass, 1=dirt
        
//        // for debugging
//        // mark board with direction information
//        for i in 0...board.boardSize / 2 {
//            for j in 0...20 {
//                setColorIndex(longitude: i, latitude: j, to: 1)
//            }
//        }
        
        // Note: drawing random lines on the board before diamond-square might allow for seeing lines of mountains or valleys
        board.surface.fillUsingDiamondSquare(withMinimum: 10.0/255.0, andMaximum: 255.0/255.0)
        //board.bedrock.fillUsingDiamondSquare(withMinimum: 5.0/255.0, andMaximum: 10.0/255.0)
        
        // set wind
        board.windDir = Float(drand48() * 360)
        board.windSpeed = Float(pow(drand48(),2)) * maxWindSpeed
        
        NSLog("\(#function) finished")
    }
    
    func startGame(withConfig: GameConfig) {
        let config = withConfig
        let totalPlayers = config.numHumans+config.numAIs
        board.players = [Player](repeating: Player(), count: totalPlayers)
        board.currentPlayer = 0

        board.currentRound = 1
        board.totalRounds = config.numRounds
        NSLog("\(#function) starting \(board.totalRounds) round game.")
        
        // set player names and initial credit
        let numPlayers = config.numHumans
        for i in 0..<totalPlayers {
            board.players[i].credit = config.credit
            
            board.players[i].didSetName = false
            if i < numPlayers {
                if i < config.playerNames.count && config.playerNames[i] != "" {
                    board.players[i].name = config.playerNames[i]
                    board.players[i].didSetName = true
                } else  {
                    board.players[i].name = "Player \(i+1)"
                }
            } else {
                board.players[i].name = "Al \(i-numPlayers+1)"
                board.players[i].didSetName = true
            }
            NSLog("player \(i)'s name is \(board.players[i].name)")
        }

        // add AI objects to AI players
        for i in numPlayers..<totalPlayers {
            board.players[i].ai = PlayerAI()
        }

        startRound() // will set gameStarted
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
        
        if board.totalRounds == 0 {
            // unlimited rounds mode always starts with 'player 1'
            board.currentPlayer = 0
        }
        
        gameStarted = true
    }
    
    func getNormal(longitude: Int, latitude: Int, sampleDist: Int = 10) -> Vector3 {
        return getNormal(fromMap: board.surface, longitude: longitude, latitude:latitude, sampleDist: sampleDist)
    }

    func getNormal(fromMap: ImageBuf, longitude: Int, latitude: Int, sampleDist: Int = 10) -> Vector3 {
        // offsets are in closwise order as seen from positive 'z'
        let offsets = [
            [-1,-1],
            [0,-1],
            [1,-1],
            [1,0],
            [1,1],
            [0,1],
            [-1,1],
            [-1,0]
        ]
        var sumVect = Vector3()
        var count = 0
        let centerElevation = getElevation(fromMap: fromMap, longitude: longitude, latitude: latitude)
        for i in 0..<offsets.count {
            let x1 = longitude + sampleDist * offsets[i][0]
            let y1 = latitude + sampleDist * offsets[i][1]
            let nextI = (i + 1) % offsets.count
            let x2 = longitude + sampleDist * offsets[nextI][0]
            let y2 = latitude + sampleDist * offsets[nextI][1]

            guard x1 >= 0 else { continue }
            guard y1 >= 0 else { continue }
            guard x1 < fromMap.width else { continue }
            guard y1 < fromMap.height else { continue }
            guard x2 >= 0 else { continue }
            guard y2 >= 0 else { continue }
            guard x2 < fromMap.width else { continue }
            guard y2 < fromMap.height else { continue }

            let otherElevation1 = getElevation(fromMap: fromMap, longitude: x1, latitude: y1)
            let otherElevation2 = getElevation(fromMap: fromMap, longitude: x2, latitude: y2)

            let v1 = Vector3(Float(x1-longitude), Float(y1-latitude), otherElevation1-centerElevation)
            let v2 = Vector3(Float(x2-longitude), Float(y2-latitude), otherElevation2-centerElevation)

            sumVect = vectorAdd(sumVect, vectorCross(v1, v2))
            count += 1
        }
        
        let normal = vectorNormalize(vectorScale(sumVect, by: 1.0/Float(count)))
        return normal
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
    
    func getColorIndex(longitude: Int, latitude: Int) -> Int {
        return getColorIndex(forMap: board.colors, longitude: longitude, latitude: latitude)
    }
    
    func getColorIndex(forMap: ImageBuf, longitude: Int, latitude: Int) -> Int {
        guard longitude >= 0 else { return -1 }
        guard longitude < forMap.width else { return -1 }
        guard latitude >= 0 else { return -1 }
        guard latitude < forMap.height else { return -1 }
        
        let pixel = forMap.getPixel(x: longitude, y: latitude)

        return Int(pixel)
    }
    

    func getColor(longitude: Int, latitude: Int) -> UIColor {
        return getColor(forMap: board.colors, longitude: longitude, latitude: latitude)
    }
    
    func getColor(forMap: ImageBuf, longitude: Int, latitude: Int,
                  with colors: [UIColor] = [UIColor.green, UIColor.brown, UIColor.gray, UIColor.red]) -> UIColor {
        let index = getColorIndex(forMap: forMap, longitude: longitude, latitude: latitude)
        
        return colors[index % colors.count]
    }
    
    func setColorIndex(longitude: Int, latitude: Int, to: Int) {
        return setColorIndex(forMap: board.colors, longitude: longitude, latitude: latitude, to: to)
    }
    
    func setColorIndex(forMap: ImageBuf, longitude: Int, latitude: Int, to: Int) {
        guard longitude >= 0 else { return }
        guard longitude < forMap.width else { return }
        guard latitude >= 0 else { return }
        guard latitude < forMap.height else { return }
        
        forMap.setPixel(x: longitude, y: latitude, value: CGFloat(to))
    }

    func colorMap(with colors: [UIColor] = [UIColor.green, UIColor.brown, UIColor.gray, UIColor.red]) -> UIImage {
        return colorMap(forMap: board.colors, with: colors)
    }
    
    func colorMap(forMap: ImageBuf, with colors: [UIColor] = [UIColor.green, UIColor.brown, UIColor.gray, UIColor.red]) -> UIImage {
        NSLog("\(#function) started")
        let startTime : CFAbsoluteTime = CFAbsoluteTimeGetCurrent();
        
        let bitsPerComponent:Int = 8
        let bitsPerPixel:Int = 32

        var pixelColors: [PixelData] = []
        let colors = [UIColor.green, UIColor.brown, UIColor.gray, UIColor.red]
        for color in colors {
            guard let colorComponents = color.cgColor.components else { continue }
            var pixelColor: PixelData!
            if colorComponents.count == 4 {
                pixelColor = PixelData(a: UInt8(colorComponents[3] * 255),
                                       r: UInt8(colorComponents[0] * 255),
                                       g: UInt8(colorComponents[1] * 255),
                                       b: UInt8(colorComponents[2] * 255))
            } else if colorComponents.count == 2 {
                pixelColor = PixelData(a: UInt8(colorComponents[1] * 255),
                                       r: UInt8(colorComponents[0] * 255),
                                       g: UInt8(colorComponents[0] * 255),
                                       b: UInt8(colorComponents[0] * 255))
            } else {
                NSLog("Unhandled case, colorComponents has \(colorComponents.count) elements. \(colorComponents)")
            }
            pixelColors.append(pixelColor)
        }
        
        assert(forMap.pixels.count == Int(forMap.width * forMap.height))
        
        // see: http://blog.human-friendly.com/drawing-images-from-pixel-data-in-swift
        var pixelArray = [PixelData](repeating: PixelData(a: 255, r:0, g: 0, b: 0), count: forMap.width*forMap.height)
        
        //NSLog("\(#function): Converting \(width)x\(height) image to a UIImage using CGDataProvider.")
        //NSLog("copying data into pixelArray")
        for i in 0 ..< forMap.pixels.count {
            let colorIdx = Int(forMap.pixels[i])
            pixelArray[i] = pixelColors[colorIdx % pixelColors.count]
        }
        //NSLog("finished copying data to pixelArray")
        
        //var data = pixelArray // Copy to mutable []
        guard let providerRef = CGDataProvider(
            data: NSData(bytes: &pixelArray, length: pixelArray.count * MemoryLayout<PixelData>.size)
            ) else { return UIImage() }
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        let cgim = CGImage(
            width: forMap.width,
            height: forMap.height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: forMap.width * (bitsPerPixel / bitsPerComponent),
            space: rgbColorSpace,
            bitmapInfo: bitmapInfo,
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
        
        let image = UIImage(cgImage: cgim!)
        
        NSLog("\(#function) finished")
        NSLog("\(#function): took " + String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime));
        
        return image
    }
    
    func normalMap() -> UIImage {
        return normalMap(forMap: board.surface)
    }
    
    func normalMap(forMap: ImageBuf) -> UIImage {
        NSLog("\(#function) started")
        let startTime : CFAbsoluteTime = CFAbsoluteTimeGetCurrent();

        // see: http://blog.human-friendly.com/drawing-images-from-pixel-data-in-swift
        UIGraphicsBeginImageContextWithOptions(CGSize(width: forMap.width, height: forMap.height), true, 1);
        
        var image = UIImage()
        if let context = UIGraphicsGetCurrentContext() {
            for i in 0 ..< forMap.width {
                for j in 0 ..< forMap.height {
                    let normal = vectorNormalize(getNormal(fromMap: forMap,
                                                           longitude: i,
                                                           latitude: j,
                                                           sampleDist: 1))
                    
                    // this needs to be in scene view space, not model space
                    context.setFillColor(red: CGFloat(normal.x),
                                         green: CGFloat(normal.z),
                                         blue: CGFloat(normal.y),
                                         alpha: 1.0)
                    
                    context.fill(CGRect(x: CGFloat(i), y: CGFloat(j), width: 1, height: 1))
                }
            }
            
            image = UIGraphicsGetImageFromCurrentImageContext()!;
        }
        
        UIGraphicsEndImageContext();
        
        NSLog("\(#function) finished")
        NSLog("\(#function): took " + String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime));
        
        return image
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
        var weaponSize = weapon.sizes[player.weaponSizeID].size
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
        var trajectories: [[Vector3]] = []
        if weapon.style == .mirv {
            trajectories = computeMirvTrajectories(muzzlePosition: muzzlePosition,
                                                 muzzleVelocity: muzzleVelocity,
                                                 withTimeStep: timeStep,
                                                 pattern: Int(weaponSize))
            weaponSize = weaponsList[0].sizes[0].size // MIRVs are each standard explosives
        } else {
            trajectories = [computeTrajectory(muzzlePosition: muzzlePosition,
                                           muzzleVelocity: muzzleVelocity,
                                           withTimeStep: timeStep)]
        }

        // previous trajectory should be the primary projectile
        board.players[board.currentPlayer].prevTrajectory = trajectories.first!

        // sort trajectories by length for easier animation
        let sortedTrajectories = trajectories.sorted(by: {lhs, rhs in
            return lhs.count < rhs.count
        })
        trajectories = sortedTrajectories

        // update stats
        board.players[board.currentPlayer].stats.shotsFired += 1
        board.players[board.currentPlayer].stats.pointsSpent += Int64(weaponCost)
        
        // update board with new values
        let sizeID = board.players[board.currentPlayer].weaponSizeID
        let old = ImageBuf(board.surface)
        let oldColor = ImageBuf(board.colors)

        // deal with impact(s)
        let blastRadius = weaponSize
        var detonationResults: [DetonationResult] = []
        for trajectory in trajectories {
            let detonationResult = applyExplosion(for: trajectory, withRadius: blastRadius, andStyle: weapon.style)
            detonationResults.append(detonationResult)

            let impactPosition = trajectory.last!
            if weapon.style == .explosive {
                damageCheckForExplosion(at: impactPosition, fromWeapon: weapon, withSize: sizeID)
            } else if weapon.style == .mirv {
                damageCheckForExplosion(at: impactPosition, fromWeapon: weaponsList[0], withSize: 0)
            } else if weapon.style == .napalm {
                damageCheckForFluid(at: impactPosition, fromWeapon: weapon, with: detonationResult.fluidPath)
            }
        }
        
        // record final state of the board
        let final = ImageBuf(board.surface)
        let finalColor = ImageBuf(board.colors)
        
        let (roundEnded, roundWinner, _, humansLeft) = roundCheck()
        
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
                                            trajectories: trajectories,
                                            explosionRadius: blastRadius,
                                            weaponStyle: weapon.style,
                                            detonationResult: detonationResults,
                                            old: old,
                                            final: final,
                                            oldColor: oldColor,
                                            finalColor: finalColor,
                                            newRound: roundEnded,
                                            roundWinner: roundWinner,
                                            humanLeft: humansLeft)
        
        if board.totalRounds > 0 || !roundEnded {
            board.currentPlayer = (board.currentPlayer + 1) % board.players.count
            while !roundEnded && board.players[board.currentPlayer].hitPoints <= 0 {
                NSLog("skipping downed player \(board.currentPlayer)")
                board.currentPlayer = (board.currentPlayer + 1) % board.players.count
            }
        }
        print("Player \(board.currentPlayer) now active.")
        
        NSLog("\(#function) finished")

        return result
    }
    
    func computeMirvTrajectories(muzzlePosition: Vector3, muzzleVelocity: Vector3, withTimeStep: Float, pattern: Int, ignoreTanks: Bool = false) -> [[Vector3]] {
        
        var ret: [[Vector3]] = []
        
        // compute main trajectory
        let primary = computeTrajectory(muzzlePosition: muzzlePosition, muzzleVelocity: muzzleVelocity, withTimeStep: withTimeStep)
        ret.append(primary)
        
        // find apex
        var apexPos = 0
        var prevZ: Float = -1
        for i in 0..<primary.count {
            if primary[i].z < prevZ {
                apexPos = i-1
                break
            }
            prevZ = primary[i].z
        }
        let apexPosition = primary[apexPos]
        let apexVelocity = vectorScale(vectorDiff(primary[apexPos+1], primary[apexPos]), by: 1/withTimeStep)
        
        // create 'array' of patterns
        // [0,0] is implicitly in each one as 'primary'
        // [1,0] is in the direction of apexVelocity
        let patterns: [Int: [[Float]]] = [5: [[-2,0], [-1,0], [1,0], [2,0]],
                        6: [[0,-2], [0,-1], [0,1], [0,2]],
                        9: [[-2,0], [-1,0], [1,0], [2,0], [0,-2], [0,-1], [0,1], [0,2]],
                        13: [[2,0], [1.847,0.765], [1.414,1.414], [0.765,1.847],
                             [0,2], [-0.765,1.847], [-1.414,1.414], [-1.847,0.765],
                             [-2,0], [-1.847,-0.765],[-1.414,-1.414],[-0.765,-1.847],
                             [0,-2], [0.765,-1.847], [1.414,-1.414], [1.847,-0.765]],
                        17: [[2,0], [1.847,0.765], [1.414,1.414], [0.765,1.847],
                             [0,2], [-0.765,1.847], [-1.414,1.414], [-1.847,0.765],
                             [-2,0], [-1.847,-0.765],[-1.414,-1.414],[-0.765,-1.847],
                             [0,-2], [0.765,-1.847], [1.414,-1.414], [1.847,-0.765],
                             [-1,0], [1,0], [0,-1], [0,1]],
                        21: [[2,0], [1.847,0.765], [1.414,1.414], [0.765,1.847],
                             [0,2], [-0.765,1.847], [-1.414,1.414], [-1.847,0.765],
                             [-2,0], [-1.847,-0.765],[-1.414,-1.414],[-0.765,-1.847],
                             [0,-2], [0.765,-1.847], [1.414,-1.414], [1.847,-0.765],
                             [0.7071,0.7071], [-0.7071,0.7071], [-0.7071,-0.7071], [0.7071,-0.7071],
                             [-1,0], [1,0], [0,-1], [0,1]],
                        25: [[-2,-2], [-1,-2], [0,-2], [1,-2], [2,-2],
                             [-2,-1], [-1,-1], [0,-1], [1,-1], [2,-1],
                             [-2,0], [-1,0], /*[0,0],*/ [1,0], [2,0],
                             [-2,1], [-1,1], [0,1], [1,1], [2,1],
                             [-2,2], [-1,2], [0,2], [1,2], [2,2],]
                        ]
        
        guard let patternOffsets = patterns[pattern] else { return ret }
        
        // determine rotation needed
        let angle = atan2(apexVelocity.y,apexVelocity.x)
        
        // compute additional trajectories
        // be sure to align pattern with apexVelocity's x,y vector
        for offset in patternOffsets {
            // rotate offsets to match apexVelocity
            let rotatedOffset = [offset[0] * cos(angle) - offset[1] * sin(angle),
                                 offset[0] * sin(angle) + offset[1] * cos(angle)]
            
            // adjust velocity
            let scaleFactor: Float = 10
            let orientedOffset = Vector3(scaleFactor*rotatedOffset[0],scaleFactor*rotatedOffset[1],0)
            let adjustedVelocity = vectorAdd(apexVelocity, orientedOffset)
            let secondary = computeTrajectory(muzzlePosition: apexPosition, muzzleVelocity: adjustedVelocity, withTimeStep: withTimeStep)
            var fullSecondary = Array(primary.prefix(apexPos-1))
            fullSecondary.append(contentsOf: secondary)
            
//            // for debugging purposes
//            let prevLength = ret.last!.count
//            while fullSecondary.count < prevLength + 60 {
//                fullSecondary.append(fullSecondary.last!)
//            }
            
            ret.append(fullSecondary)
        }
        
        return ret
    }
    
    func computeTrajectory(muzzlePosition: Vector3, muzzleVelocity: Vector3, withTimeStep: Float, ignoreTanks: Bool = false) -> [Vector3] {
        let timeStep = withTimeStep
    
        // record use of targeting computer
        if board.players[board.currentPlayer].useTargetingComputer {
            board.players[board.currentPlayer].usedComputer = true
        }
        
        // compute wind components
        let windX = cos(board.windDir * (Float.pi / 180)) * board.windSpeed
        let windY = sin(board.windDir * (Float.pi / 180)) * board.windSpeed
        let terminalSpeed: Float = 100
        //NSLog("wind: \(board.windSpeed) m/s @ \(board.windDir)º, which is x,y = \(windX),\(windY) m/s")
        
        // compute trajectory
        var trajectory: [Vector3] = [muzzlePosition]
        var airborn = true
        let p0 = muzzlePosition // p_0
        let v0 = muzzleVelocity // v_0
        let vInf = Vector3(windX, windY, -terminalSpeed)
        let k: Float = -0.5 * gravity / terminalSpeed
        //NSLog("p_0: \(p0), v_0: \(v0), vInf: \(vInf), k: \(k)")
        
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
            
            if !ignoreTanks {
                for player in board.players {
                    let tank = player.tank
                    guard player.hitPoints > 0 else  { continue }
                    
                    let dist = distance(from: tank.position, to: position)
                    if dist < tankSize {
                        // hit a tank
                        airborn = false
                    }
                }
            }
            
            //prevPosition = position
            
            if iterCount > 10000 {
                break
            }
            iterCount += 1
            
        }
        //NSLog("shell took \(timeStep*Float(iterCount))s (\(iterCount) iterations) to land")
        //NSLog("trajectory: \(trajectory)")
        
        return trajectory
    }
    
    func applyExplosion(for trajectory: [Vector3], withRadius: Float, andStyle: WeaponStyle = .explosive) -> DetonationResult {
        NSLog("\(#function) started (radius: \(withRadius), style:\(andStyle), trajectory length: \(trajectory.count))")
        let impactPosition = trajectory.last!
        let at = impactPosition
        let topBuf = ImageBuf()
        let middleBuf = ImageBuf()
        let bottomBuf = ImageBuf()
        let topColor = ImageBuf()
        let bottomColor = ImageBuf()
        var fluidPath: [Vector3] = []
        var fluidRemaining: [Float] = []
        var minX: Int = 0
        var maxX: Int = 1
        var minY: Int = 0
        var maxY: Int = 1
        
        //NSLog("\(#function) starting explosion computation at \(at) with radius \(withRadius) and style \(andStyle).")
        let style = andStyle
        
        minX = max(0, min(board.surface.width, Int(at.x - withRadius)))
        maxX = max(0, min(board.surface.width, Int(at.x + withRadius)))
        minY = max(0, min(board.surface.height, Int(at.y - withRadius)))
        maxY = max(0, min(board.surface.height, Int(at.y + withRadius)))

        NSLog("\(#function): starting image buffer copies")
        topBuf.crop(board.surface, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
        middleBuf.copy(topBuf)
        bottomBuf.copy(topBuf)
        
        topColor.crop(board.colors, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
        bottomColor.copy(topColor)
        NSLog("\(#function): finished image buffer copies")

        // update things in the radius of the explosion
        if style == .explosive || style == .generative || style == .mirv {
            
            NSLog("appling to range (\(minX),\(minY)) to (\(maxX),\(maxY)), \(maxX-minX+1)x\(maxY-minY+1).")
            
            for j in minY...maxY {
                for i in minX...maxX {
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
                    
                    if style == .explosive || style == .mirv {
                        let top = currElevation
                        let middle = expTop
                        let bottom = min(currElevation, expBottom)
                        
                        setElevation(forMap: topBuf, longitude: i, latitude: j, to: top)
                        setElevation(forMap: middleBuf, longitude: i, latitude: j, to: middle)
                        setElevation(forMap: bottomBuf, longitude: i, latitude: j, to: bottom)
                        //NSLog("\(#function): \(i),\(j): set bottom to \(bottom)")
                        
                        // update elevation map
                        let newElevation = min(currElevation, bottom + max(0,top-middle))
                        setElevation(longitude: i, latitude: j, to: newElevation)
                        
                        // update color map
                        if expTop > currElevation && expBottom < currElevation {
                            // explosion pokes out of the ground, mark crater below
                            setColorIndex(longitude: i, latitude: j, to: 1) // make crater brown
                        }
                        if expBottom < currElevation {
                            // set color for bottom below any dropping blocks
                            setColorIndex(forMap: bottomColor, longitude: i, latitude: j, to: 1)
                        }
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
                        
                        // update colors
                        if expTop > currElevation {
                            // dirt will be the new top
                            setColorIndex(longitude: i, latitude: j, to: 1) // make dirt piles brown
                            setColorIndex(forMap: topColor, longitude: i, latitude: j, to: 1)
                        }
                        if expTop > currElevation && expBottom < currElevation {
                            // dirt is on top, and won't fall
                            setColorIndex(forMap: bottomColor, longitude: i, latitude: j, to: 1)
                        }
                    }
                }
            }
        } else if style == .napalm || style == .mud {
            let volume = 4.0/3.0 * Double.pi * pow(Double(withRadius),3)
            let (path, remaining) = fluidFill(startX: at.x, startY: at.y, totalVolume: volume, andStyle: style)
            fluidPath = path
            fluidRemaining = remaining
        } else {
            NSLog("\(#function) doesn't handle \(andStyle) style.")
        }
        
        NSLog("\(#function) finished")

        return DetonationResult(topBuf: topBuf, middleBuf: middleBuf, bottomBuf: bottomBuf,
                                topColor: topColor, bottomColor: bottomColor,
                                fluidPath: fluidPath,
                                fluidRemaining: fluidRemaining,
                                timeIndex: trajectory.count,
                                minX: minX, maxX: maxX,
                                minY: minY, maxY: maxY)
    }
    
    func unpackDetonation(_ detonation: DetonationResult, from: FireResult) -> DetonationResult {
        // copy/update full map images to use
        let fireResult = from
        let topBuf = ImageBuf(fireResult.old)
        let middleBuf = ImageBuf(fireResult.old)
        let bottomBuf = ImageBuf(fireResult.old)
        let topColor = ImageBuf(fireResult.oldColor)
        let bottomColor = ImageBuf(fireResult.oldColor)
        let timeIndex = detonation.timeIndex
        
        // coordinates of detonation
        let minX = detonation.minX
        let maxX = detonation.maxX
        let minY = detonation.minY
        let maxY = detonation.maxY
        
        // update full sized images with bits that changed
        topBuf.paste(detonation.topBuf)
        middleBuf.paste(detonation.middleBuf)
        bottomBuf.paste(detonation.bottomBuf)
        topColor.paste(detonation.topColor)
        bottomColor.paste(detonation.bottomColor)
        
        return DetonationResult(topBuf: topBuf, middleBuf: middleBuf, bottomBuf: bottomBuf,
                                topColor: topColor, bottomColor: bottomColor,
                                fluidPath: [], fluidRemaining: [], timeIndex: timeIndex,
                                minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }
    
    func fluidFill(startX: Float, startY: Float, totalVolume: Double, andStyle: WeaponStyle = WeaponStyle.napalm) -> ([Vector3], [Float]) {
        NSLog("\(#function) started with totalVolume: \(totalVolume)")
        
        // trace path of fluid (these get returned for animation purposes)
        var fullPath: [Vector3] = []
        var remaining: [Float] = []
        
        // track state needed
        var remainingVolume = totalVolume
        var queue = PriorityQueue<Pair<OrderedElevation, MapCoordinate>>()
        var fringe = [Bool](repeatElement(false, count: board.boardSize * board.boardSize))

        // set start point
        let startCoord = MapCoordinate(x: Int(startX), y: Int(startY))
        let startElevation = getElevation(longitude: startCoord.x, latitude: startCoord.y)
        let initialKey = OrderedElevation(elevation: startElevation, order: 0)
        queue.enqueue(Pair(key: initialKey, value: startCoord))
        
        var previousElevation = startElevation
        
        // need a priority queue of edge pixels ordered by height
        var puddleStack = Stack<Pair<Int,Float>>()
        while remainingVolume > 0 && queue.count > 0 {
            // get lowest pixel from queue
            guard let lowest = queue.dequeue() else { remainingVolume = 0; continue }
            var lowestElevation = lowest.key.elevation

            // enqueue neighboring pixels
            for j in -1...1 {
                for i in -1...1 {
                    guard (i != 0 || j != 0) else { continue }
                    
                    let x = lowest.value.x + i
                    let y = lowest.value.y + j
                    
                    guard (x>=0) &&
                          (y>=0) &&
                          (x<board.boardSize) &&
                          (y<board.boardSize) else { continue }
                    
                    let fringeCoord = x + y * board.boardSize
                    let enqueuedAlready = fringe[fringeCoord]
                    if !enqueuedAlready {
                        let elevation = getElevation(longitude: x, latitude: y)
                        let key = OrderedElevation(elevation: elevation, order: lowest.key.order + 1)
                        let coordinate = MapCoordinate(x: x, y: y)
                        queue.enqueue(Pair(key: key, value: coordinate))
                        fringe[fringeCoord] = true
                        //NSLog("\(#function): added \(coordinate.x),\(coordinate.y) to fringe with elevation \(elevation)")
                    }
                }
            }
            
            // record newest low point
            fullPath.append(Vector3(Float(lowest.value.x), Float(lowest.value.y), lowestElevation))
            remaining.append(Float(remainingVolume))
            
            if lowestElevation < previousElevation {
                //NSLog("\(#function): moved down to \(lowest.key) at \(lowest.value.x),\(lowest.value.y)")
                // if puddle set is non-empty, update surface accordingly
                let volumeAdded = max(1, previousElevation - lowestElevation)
                remainingVolume -= Double(volumeAdded)
                
                // push new elevation/position onto stack
                puddleStack.push(Pair<Int,Float>(key: fullPath.count-1, value: lowestElevation))
            } else {
                //NSLog("\(#function): filled up to \(lowest.key) at \(lowest.value.x),\(lowest.value.y)")
                // new value is higher, so level is rising
                // increase level to lowest edge pixel
                // its neighbors were added to queue already
                
                // current area is all points between fullPath.last and nearest previous point with same elevation
                var currentArea: Double = 0
                while puddleStack.count > 0 && puddleStack.top!.value < lowestElevation {
                    // pop off stack until the top is above current elevation
                    _ = puddleStack.pop()
                }
                if puddleStack.count > 0 {
                    currentArea = Double(fullPath.count - puddleStack.top!.key)
                } else {
                    currentArea = Double(fullPath.count)
                }
                
                // compute volume used in level rise
                let volumeAdded = currentArea * Double(lowestElevation - previousElevation)
                if volumeAdded > remainingVolume {
                    // no enough liquid to reach next point
                    // adjust lowestElevation to the real final value
                    lowestElevation = Float(Double(previousElevation) + remainingVolume / currentArea)
                    fullPath.removeLast()
                }
                
                // update volume left
                remainingVolume -= volumeAdded
                
                // add new coordinate to area total
                currentArea += 1
            }

            previousElevation = lowestElevation

            //NSLog("\(#function): remaining volume now \(remainingVolume), previousElevation: \(previousElevation)")
        }
        if queue.count == 0 {
            // entire queue exhausted, so entire board must be burried
            previousElevation += Float(remainingVolume / Double(fullPath.count))
            remainingVolume = 0
        }
        NSLog("\(#function): path length: \(fullPath.count)")
        
        // go through path backwards to find the level that each point will fill to updating actual surface
        var maxLevel = previousElevation
        for i in 1...fullPath.count {
            let pos = fullPath.count - i
            let currPos = fullPath[pos]
            maxLevel = max(maxLevel,currPos.z)
            let currLevel = getElevation(longitude: Int(currPos.x), latitude: Int(currPos.y))

            if andStyle == .mud {
                setElevation(longitude: Int(currPos.x), latitude: Int(currPos.y), to: max(currLevel+1,maxLevel))
                setColorIndex(longitude: Int(currPos.x), latitude: Int(currPos.y), to: 1) // mud/dirt color
            } else if andStyle == .napalm {
                setElevation(longitude: Int(currPos.x), latitude: Int(currPos.y), to: currLevel-1)
                setColorIndex(longitude: Int(currPos.x), latitude: Int(currPos.y), to: 2) // scorched color
            } else {
                NSLog("\(#function): Unknown style encountered! \(andStyle)")
            }
        }

        NSLog("path has length \(fullPath.count)")

        NSLog("\(#function) finished")
        
        return (fullPath, remaining)
    }

    func distance(from: Vector3, to: Vector3) -> Float {
        let xDiff = from.x - to.x
        let yDiff = from.y - to.y
        let zDiff = from.z - to.z
        
        return sqrt(xDiff*xDiff + yDiff*yDiff + zDiff*zDiff)
    }
    
    func damageCheckForExplosion(at: Vector3, fromWeapon: Weapon, withSize: Int) {
        NSLog("\(#function) started")

        var totalKills = 0
        for i in 0..<board.players.count {
            let player = board.players[i]
            
            let tank = player.tank
            let tankPos = tank.position
            //NSLog("\ttank at \(tankPos)")
            
            // skip eliminated tanks
            if player.hitPoints <= 0 {
                continue
            }
            
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
                if board.players[i].hitPoints <= 0 {
                    applyKill(board.currentPlayer, killed: i, did: damage)
                    totalKills += 1
                }
            }
        }
        board.players[board.currentPlayer].stats.maxKillsPerShot = max(totalKills, board.players[board.currentPlayer].stats.maxKillsPerShot)
        
        NSLog("\(#function) finished")
    }

    func damageCheckForFluid(at: Vector3, fromWeapon: Weapon, with path: [Vector3]) {
        NSLog("\(#function) started")
        let fluidBaseDamage: Float = 50

        // check each player to see if they take damage
        var totalKills = 0
        for i in 0..<board.players.count {
            var totalDamage: Float = 0
            for point in path {
                let tank = board.players[i].tank
                
                let dist = distance(from: tank.position, to: point)
                if dist < tankSize && board.players[i].hitPoints > 0 {
                    let damage = min(fluidBaseDamage / pow(max(1,dist),2.0), board.players[i].hitPoints)
                    totalDamage += damage
                    
                    board.players[i].hitPoints -= damage
                    if board.players[i].hitPoints == 0 {
                        NSLog("\t\tPlayer \(board.currentPlayer) killed player \(i)")
                        applyKill(board.currentPlayer, killed: i, did: damage)
                        totalKills += 1
                    }
                }
            }
            NSLog("\tplayer \(i) took \(totalDamage) points of damage.")
        }
        board.players[board.currentPlayer].stats.maxKillsPerShot = max(totalKills, board.players[board.currentPlayer].stats.maxKillsPerShot)

        NSLog("\(#function) finished")
    }
    
    func applyKill(_ player: Int, killed: Int, did damage: Float) {
        let i = killed

        if board.currentPlayer != i {
            board.players[board.currentPlayer].stats.kills += 1
            board.players[board.currentPlayer].score += Int64(damage)
            if board.players[i].hitPoints <= 0 {
                board.players[board.currentPlayer].score += 1000
            }
            NSLog("\tplayer \(board.currentPlayer) score now \(board.players[board.currentPlayer].score)")
            
            // update max points stat
            board.players[board.currentPlayer].stats.maxPoints = max(board.players[board.currentPlayer].stats.maxPoints,
                                                                     board.players[board.currentPlayer].score)
        } else {
            // player killed themself, distribute points across other players
            board.players[board.currentPlayer].stats.suicides += 1
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
    
    func skipRound() {
        NSLog("\(#function): skipping to end of round")
        
        var roundEnded = false
        while !roundEnded {
            if drand48() < 0.25 {
                let currentPlayer = board.currentPlayer
                var nextPlayer = (currentPlayer + 1) % board.players.count
                while board.players[nextPlayer].hitPoints <= 0 {
                    nextPlayer = (nextPlayer + 1) % board.players.count
                }
                let target = board.players[nextPlayer].tank.position

                let aboveTank = Vector3(target.x, target.y, target.z + 50)
                let straightDown = Vector3(CGFloat(0.0),0.0,-10.0)
                let result = fire(muzzlePosition: aboveTank, muzzleVelocity: straightDown)
                roundEnded = result.newRound
            }
        }
    }
    
    func roundCheck() -> (Bool, String?, String, Int) {

        // check for round winner before checking/starting new round
        // and check for remaining human players
        var playersLeft = 0
        var humansLeft = 0
        var roundWinner: String? = nil
        var winnerName: String = board.players[0].name
        var winnerPoints: Int64 = board.players[0].score
        for player in board.players {
            if player.hitPoints > 0 {
                roundWinner = player.name
                playersLeft += 1

                if player.score > winnerPoints {
                    winnerName = player.name
                    winnerPoints = player.score
                }
                
                if player.ai == nil {
                    // not an AI
                    NSLog("\(player.name) is still alive with \(player.hitPoints) hit points")
                    humansLeft += 1
                }
            }
        }
        NSLog("\(playersLeft), players left, \(humansLeft) of those are humans.")
        if let winner = roundWinner {
            NSLog("\(winner) winning with \(winnerPoints) points.")
        }
        
        var roundEnded = playersLeft <= 1 // normal round end condition
        
        // handle unlimited rounds
        roundEnded = roundEnded || (board.totalRounds == 0 && (humansLeft <= 0 || humansLeft == playersLeft))

        if roundEnded {
            // apply round bonuses
            NSLog("Round ended")
            for i in 0..<board.players.count {
                let player = board.players[i]
                if player.score > 0 {
                    board.players[i].score = Int64(Double(board.players[i].score) * 1.1)
                    NSLog("\tPlayer \(i) score now \(board.players[i].score)")
                }
                board.players[i].prevTrajectory = []
            }
            
            // update current round
            board.currentRound += 1
            
            // check for game over condition
            if (board.totalRounds > 0 && board.currentRound > board.totalRounds) ||
                (board.totalRounds == 0 && humansLeft == 0) {
                gameOver = true
            } else {
                startRound()
            }
        }
        
        return (roundEnded, roundWinner, winnerName, humansLeft)
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
    
//    func getWinner() -> (name: String, score: Int64) {
//        var maxScore = board.players[0].score - 1
//        var winner = ""
//        for i in 0..<board.players.count {
//            if board.players[i].score > maxScore {
//                maxScore = board.players[i].score
//                winner = board.players[i].name
//            }
//        }
//        
//        return (winner, maxScore)
//    }
    
}
