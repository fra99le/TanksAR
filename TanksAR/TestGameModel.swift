//
//  TestGameModel.swift
//  TanksAR
//
//  Created by Fraggle on 7/16/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation

class TestGameModel : GameModel {
    
    func initializeBoard() {
        NSLog("\(#function) started")
        for i in 0..<board.boardSize {
            for j in 0..<board.boardSize {
                let cX = board.boardSize / 2
                let cY = board.boardSize / 2
                let dist = 100 * Int(max(abs(i-cX), abs(j-cY)) / 100)
                let elevation = 512 * Float(board.boardSize - 2*dist) / Float(board.boardSize)
                setElevation(longitude: i, latitude: j, to: elevation)
                setColorIndex(longitude: i, latitude: j, to: 0)
            }
        }
        NSLog("\(#function) finished")
    }
    
    override func generateBoard() {
        NSLog("\(#function) started")
        
        board.boardSize = 1025
        board.surface.setSize(width: board.boardSize, height: board.boardSize)
        board.bedrock.setSize(width: board.boardSize, height: board.boardSize)
        board.colors.setSize(width: board.boardSize, height: board.boardSize) // 0=grass, 1=dirt
        
        //board.surface.fillUsingDiamondSquare(withMinimum: 10.0/255.0, andMaximum: 255.0/255.0)
        //board.bedrock.fillUsingDiamondSquare(withMinimum: 5.0/255.0, andMaximum: 10.0/255.0)
        initializeBoard()
        
        NSLog("\(#function) finished")
    }
    
    override func startGame(numPlayers: Int, numAIs: Int = 0, rounds: Int) {
        // need two players to prevent triggering round changes
        // also, second player restores the board
        super.startGame(numPlayers: 2, numAIs: 0, rounds: 10)
        //board.currentRound = 6
    }
    
    override func fire(muzzlePosition: Vector3, muzzleVelocity: Vector3) -> FireResult {
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
        let trajectory: [Vector3] = []
        
        // deal with impact
        let blastRadius = weaponSize
        
        board.players[board.currentPlayer].prevTrajectory = trajectory
        
        // update board with new values
        let old = ImageBuf()
        let oldColor = ImageBuf()
        old.copy(board.surface)
        oldColor.copy(board.colors)
        let (top, middle, bottom, topColors, bottomColors) = applyExplosion(at: Vector3(), withRadius: weaponSize, andStyle: weapon.style)
        
        // check for round winner before checking/starting new round
        var roundWinner: String? = nil
        for player in board.players {
            if player.hitPoints > 0 {
                roundWinner = player.name
            }
        }
        
        var roundEnded = roundCheck()
        if board.currentPlayer == board.players.count - 1 {
            roundEnded = true
            board.currentRound += 1
        }
        
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
                                            weaponStyle: weapon.style,
                                            old: old,
                                            top: top,
                                            middle: middle,
                                            bottom: bottom,
                                            oldColor: oldColor,
                                            topColor: topColors,
                                            bottomColor: bottomColors,
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
    
    override func applyExplosion(at: Vector3, withRadius: Float, andStyle: WeaponStyle = .explosive) -> (ImageBuf, ImageBuf, ImageBuf, ImageBuf, ImageBuf) {
        NSLog("\(#function) started")
        let topBuf = ImageBuf()
        let middleBuf = ImageBuf()
        let bottomBuf = ImageBuf()
        let topColor = ImageBuf()
        let bottomColor = ImageBuf()
        let style = andStyle
        
        NSLog("starting image buffer copies")
        topBuf.copy(board.surface)
        middleBuf.copy(board.surface)
        bottomBuf.copy(board.surface)
        
        topColor.copy(board.colors)
        bottomColor.copy(board.colors)
        
        NSLog("\(#function) starting explosion computation at \(at) with radius \(withRadius) and style \(andStyle).")

        let cX = board.boardSize / 2
        let cY = board.boardSize / 2
        let ringRadius: Float = 350
        let pipeRadius: Float = 150
        let centerElevation: Float = 200
        
        // update things in the radius of the explosion
        for j in 0..<board.boardSize {
            for i in 0..<board.boardSize {
                let xDiff = Float(cX - i)
                let yDiff = Float(cY - j)
                
                let horizDist = sqrt(xDiff*xDiff + yDiff*yDiff)
                //guard withRadius >= horizDist else { continue }
                
                // get z component of torus at i,j
                // a^2 = c^2 - b^2
                // c = withRadius -> pipeRadius
                // b = horizDist -> horizDist - ringRadius
                let c = pipeRadius
                let b = horizDist - ringRadius
                let aSquared = c*c - b*b
                guard aSquared >= 0 else { continue }
                let vertSize = sqrt(aSquared)
                
                
                let currElevation = getElevation(longitude: i, latitude: j)
                let expTop = centerElevation + vertSize
                let expBottom = centerElevation - vertSize
                
                if style == .explosive  {
                    let top = currElevation
                    let middle = expTop
                    let bottom = min(currElevation, expBottom)
                    
                    setElevation(forMap: topBuf, longitude: i, latitude: j, to: top)
                    setElevation(forMap: middleBuf, longitude: i, latitude: j, to: middle)
                    setElevation(forMap: bottomBuf, longitude: i, latitude: j, to: bottom)
                    
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
                } else {
                    NSLog("\(#function) doesn't handle \(andStyle) style.")
                }
            }
            
        }

        
        NSLog("\(#function) finished")
        
        return (topBuf, middleBuf, bottomBuf, topColor, bottomColor)
    }
    
}
