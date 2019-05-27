//
//  GameViewBlockDrawer.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/22/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import SceneKit
import ARKit

class GameViewBlockDrawer : GameViewDrawer {

    var boardBlocks: [[SCNNode]] = []
    var boardSurfaces: [[SCNNode]] = []
    var boardSurface = SCNNode()
    var newBottom = SCNNode()
    let drainRate: Float = 5000
    var fillRate: Float = 5000
    
    override func addBoard() {
        NSLog("\(#function) started")
        
        // use cubes until I can sort out actual Meshes.
        
        // keep references to each block
        boardBlocks = Array(repeating: Array(repeating: SCNNode(), count: numPerSide), count: numPerSide)
        boardSurfaces = Array(repeating: Array(repeating: SCNNode(), count: numPerSide), count: numPerSide)

        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                // create block
                let blockGeometry = SCNBox(width: edgeSize, height: 1, length: edgeSize, chamferRadius: 0)
                let blockNode = SCNNode(geometry: blockGeometry)
                boardBlocks[i][j] = blockNode
                blockNode.position.y = -1 // make sure update will happen initially
                
                // add surface plane to block
                let surfaceGeometry = SCNBox(width: edgeSize, height: 1, length: edgeSize, chamferRadius: 0)
                let blockSurface = SCNNode(geometry: surfaceGeometry)
                boardSurfaces[i][j] = blockSurface
                blockNode.addChildNode(blockSurface)
                
                // add to board
                boardSurface.addChildNode(boardBlocks[i][j])
            }
        }
        board.addChildNode(boardSurface)
        updateBoard()
        
        NSLog("\(#function) finished")
    }
    
    override func removeBoard() {
        NSLog("\(#function) started")
        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                boardSurfaces[i][j].removeFromParentNode()
                boardBlocks[i][j].removeFromParentNode()
            }
        }
        boardBlocks = []
        boardSurfaces = []
        boardSurface.removeFromParentNode()
        boardSurface = SCNNode()
        board.removeFromParentNode()
        NSLog("\(#function) finished")
    }
    
    
    override func updateBoard() {
        //NSLog("\(#function) started")
        if boardBlocks.count == 0 {
            addBoard()
        }
        
        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                // determine location of segment
                let xPos = CGFloat(i)*edgeSize + edgeSize/2
                let zPos = CGFloat(j)*edgeSize + edgeSize/2
                let elevation = gameModel.getElevation(longitude: Int(xPos), latitude: Int(zPos))
                let yPos = CGFloat(elevation/2)
                let ySize = CGFloat(elevation)
                
                // update cube
                let blockNode = boardBlocks[i][j]
                let blockSurface = boardSurfaces[i][j]
                blockNode.isHidden = false
                blockNode.opacity = 1.0
                
                //NSLog("block at \(i),\(j) is \(blockNode)")
                blockNode.position = SCNVector3(xPos-CGFloat(gameModel.board.boardSize/2),
                                                yPos-0.5,
                                                zPos-CGFloat(gameModel.board.boardSize/2))
                if let geometry = blockNode.geometry as? SCNBox {
                    geometry.width = edgeSize
                    geometry.height = ySize-1
                    geometry.length = edgeSize
                    blockSurface.position.y = Float(geometry.height / 2) + 0.5
                }
                if let geometry = blockSurface.geometry as? SCNBox {
                    geometry.width = edgeSize * 1.01
                    geometry.height = 1.0
                    geometry.length = edgeSize * 1.01
                }
                
                // update color
                let color = gameModel.getColor(longitude: Int(xPos), latitude: Int(zPos))
                blockNode.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
                blockSurface.geometry?.firstMaterial?.diffuse.contents = color
            }
        }
        boardSurface.isHidden = false
        
        // remove any dropBlocks that may still be around
        droppingNode.removeFromParentNode()
        droppingNode = SCNNode()
        fluidNode.isHidden = true
        fluidNode.removeFromParentNode()
        fluidNode = SCNNode()
        newBottom.isHidden = true
        newBottom.removeFromParentNode()
        //NSLog("\(#function) finished")
    }

    override func animateResult(fireResult: FireResult, from: GameViewController) {
     
        NSLog("\(#function) started")
        let startTime: CFTimeInterval = 0
        var currTime = startTime
        let timeStep = CFTimeInterval(fireResult.timeStep / Float(timeScaling))

        // sort detonations by time
        let sortedDetonations = fireResult.detonationResult.sorted(by: {lhs, rhs in
            return lhs.timeIndex < rhs.timeIndex
        })
        
        // prepare for explosion(s)
        explosionsNode.removeFromParentNode()
        explosionsNode = SCNNode()
        board.addChildNode(explosionsNode)
        
        // prepare for dropping bits
        droppingNode.removeFromParentNode()
        droppingNode = SCNNode()
        board.addChildNode(droppingNode)
        
        // prepare for replacement bottom surface
        newBottom.removeFromParentNode()
        newBottom = SCNNode()
        board.addChildNode(newBottom)
        
        // animate shells' trajectories
        let (firstImpact, _) = animateShells(fireResult: fireResult, at: currTime)
        currTime = firstImpact
        
        // create new bottom surface
        //currTime = animateNewBottom(fireResult: fireResult, from: from, at: firstImpact) // seems fine
        
        // cap craters
        currTime = animateCraterCaps(fireResult: fireResult, from: from, at: firstImpact)
        
        let weaponStyle = fireResult.weaponStyle
        for index in 0..<sortedDetonations.count {
            let hitTime = timeStep * Double(sortedDetonations[index].timeIndex)
            
            if weaponStyle == .explosive || weaponStyle == .generative || weaponStyle == .mirv {
                let localTime = animateExplosion(fireResult: fireResult, at: hitTime, index: index)
                currTime = max(currTime, animateDropSurface(fireResult: fireResult, from: from, at: localTime, index: index)) // seems fine
            } else if fireResult.weaponStyle == .napalm || fireResult.weaponStyle == .mud {
                currTime = max(currTime, animateFluidFill(fireResult: fireResult, from: from, at: hitTime, index: index))
            }
        }
        
        // deal with round transitions
        currTime = animateRoundResult(fireResult: fireResult, at: currTime)
        
        // wait for animations to end
        let delay = SCNAction.sequence([.wait(duration: currTime)])
        board.runAction(delay, completionHandler: { DispatchQueue.main.async { from.finishTurn() } })
        
        NSLog("\(#function) finished")
    }

    func animateNewBottom(fireResult: FireResult, from: GameViewController, at time: CFTimeInterval) -> CFTimeInterval {
        let currTime = time
        
        // combine bottom image maps from all detonations
        // combine bottoms and create caps
        let (combinedBottom, combinedColor, _) = combineBottoms(fireResult: fireResult, from: from)

        // build new bottom surface
        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                // determine location of segment
                let xPos = CGFloat(i)*edgeSize + edgeSize/2
                let zPos = CGFloat(j)*edgeSize + edgeSize/2
                let elevation = gameModel.getElevation(fromMap: combinedBottom, longitude: Int(xPos), latitude: Int(zPos))
                let yPos = CGFloat(elevation/2)
                let ySize = CGFloat(elevation)
                
                // update cube
                let blockNode = SCNNode(geometry: SCNBox(width: edgeSize, height: 1, length: edgeSize, chamferRadius: 0))
                newBottom.addChildNode(blockNode)
                let blockSurface = SCNNode(geometry: SCNBox(width: edgeSize, height: 1, length: edgeSize, chamferRadius: 0))
                blockNode.addChildNode(blockSurface)
                blockNode.isHidden = false

                //NSLog("block at \(i),\(j) is \(blockNode)")
                blockNode.position = SCNVector3(xPos-CGFloat(gameModel.board.boardSize/2),
                                                yPos-0.5,
                                                zPos-CGFloat(gameModel.board.boardSize/2))
                if let geometry = blockNode.geometry as? SCNBox {
                    geometry.width = edgeSize
                    geometry.height = ySize-1
                    geometry.length = edgeSize
                }
                blockSurface.position.y = Float(yPos) + 0.5
                
                // update color
                let color = gameModel.getColor(forMap: combinedColor, longitude: Int(xPos), latitude: Int(zPos))
                blockNode.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
                blockSurface.geometry?.firstMaterial?.diffuse.contents = color
                
//                // for debugging purposes
//                blockNode.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
//                blockSurface.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            }
        }
        newBottom.isHidden = true

        // swap the new surface in
        let unHideActions = SCNAction.sequence([.wait(duration: currTime),
                                          .unhide()])
        let hideActions = SCNAction.sequence([.wait(duration: currTime),
                                                .hide()])
        newBottom.runAction(unHideActions)
        boardSurface.runAction(hideActions)
        
        return currTime
    }
    
    func animateCraterCaps(fireResult: FireResult, from: GameViewController, at time: CFTimeInterval) -> CFTimeInterval {
        let currTime = time
        let timeStep = CFTimeInterval(fireResult.timeStep / Float(timeScaling))

        // sort detonations by time
        let sortedDetonations = fireResult.detonationResult.sorted(by: {lhs, rhs in
            return lhs.timeIndex < rhs.timeIndex
        })
        
        // combine bottoms and create caps
        let (combinedBottom, _, _) = combineBottoms(fireResult: fireResult, from: from)

        let currentBottom = ImageBuf(fireResult.old)
        let currentColor = ImageBuf(fireResult.oldColor)
        for k in 0..<sortedDetonations.count-1 {
            // update full sized map image for detonations
            currentBottom.paste(sortedDetonations[k].bottomBuf)
            currentColor.paste(sortedDetonations[k].bottomColor)

            for i in 0..<numPerSide {
                for j in 0..<numPerSide {
                    // determine location of segment
                    let xPos = CGFloat(i)*edgeSize + edgeSize/2
                    let zPos = CGFloat(j)*edgeSize + edgeSize/2
                    //let oldElevation = gameModel.getElevation(fromMap: fireResult.old, longitude: Int(xPos), latitude: Int(zPos))
                    let currElevation = gameModel.getElevation(fromMap: currentBottom, longitude: Int(xPos), latitude: Int(zPos))
                    let comboElevation = gameModel.getElevation(fromMap: combinedBottom, longitude: Int(xPos), latitude: Int(zPos))
                    
                    if currElevation != comboElevation {
                        //NSLog("detonation \(k) need cap at position \(i),\(j). \(oldElevation) -> \(currElevation) -> \(comboElevation)")
                        let yPos = CGFloat((currElevation+comboElevation)/2)
                        let ySize = CGFloat(currElevation-comboElevation)

                        // create cube(s)
                        let blockNode = SCNNode(geometry: SCNBox(width: edgeSize, height: 1, length: edgeSize, chamferRadius: 0))
                        newBottom.addChildNode(blockNode)
                        let blockSurface = SCNNode(geometry: SCNBox(width: edgeSize, height: 1, length: edgeSize, chamferRadius: 0))
                        blockNode.addChildNode(blockSurface)
                        blockNode.isHidden = false
                        
                        //NSLog("block at \(i),\(j) is \(blockNode)")
                        blockNode.position = SCNVector3(xPos-CGFloat(gameModel.board.boardSize/2),
                                                        yPos-0.5,
                                                        zPos-CGFloat(gameModel.board.boardSize/2))
                        if let geometry = blockNode.geometry as? SCNBox {
                            geometry.width = edgeSize
                            geometry.height = ySize-1
                            geometry.length = edgeSize
                        }
                        blockSurface.position.y = Float(ySize/2) + 0.5
                        
                        // update color
                        let color = gameModel.getColor(forMap: currentColor, longitude: Int(xPos), latitude: Int(zPos))
                        blockNode.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
                        blockSurface.geometry?.firstMaterial?.diffuse.contents = color
                        
//                        // for debugging purposes
//                        blockNode.geometry?.firstMaterial?.diffuse.contents = UIColor.magenta
//                        blockSurface.geometry?.firstMaterial?.diffuse.contents = UIColor.magenta

                        // hide/unhide actions
                        let appearTime = timeStep * Double(sortedDetonations[k].timeIndex)
                        let disappearTime = timeStep * Double(sortedDetonations[k+1].timeIndex)
                        let unHideAction = SCNAction.sequence([.wait(duration: appearTime),
                                                               .unhide()])
                        let hideAction = SCNAction.sequence([.wait(duration: disappearTime),
                                                               .hide(),
                                                               .removeFromParentNode()])
                        blockSurface.runAction(unHideAction)
                        blockSurface.runAction(hideAction)
                        blockNode.runAction(unHideAction)
                        blockNode.runAction(hideAction)
                    }
                }
            }

        }
        
        return currTime
    }
    
    func animateDropSurface(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green], at time: CFTimeInterval, index: Int = 0) -> CFTimeInterval {
        var currTime = time

        // animate board update
        var dropNeeded = false
        
        // stages:
        //  1. dropBlocks created, boardBlocks set to bottom height (immediate)
        //  2. dropBlocks drop over fixed interval
        //  3. dropBlocks dissappear, boardBlocks set to final height (immediate)
        for j in 0..<numPerSide {
            for i in 0..<numPerSide {
                let boardBlock = boardBlocks[i][j]
                let boardSurface = boardSurfaces[i][j]
                let blockGeometry = boardBlock.geometry as! SCNBox
                let surfaceGeometry = boardSurface.geometry as! SCNBox
                let modelPos = toModelSpace(boardBlock.position)
                
                // get elevations for block
                //let current = gameModel.getElevation(fromMap: fireResult.old, longitude: Int(modelPos.x), latitude: Int(modelPos.y))
                let top = gameModel.getElevation(fromMap: fireResult.detonationResult[index].topBuf,
                                                 longitude: Int(modelPos.x), latitude: Int(modelPos.y))
                let middle = gameModel.getElevation(fromMap: fireResult.detonationResult[index].middleBuf,
                                                    longitude: Int(modelPos.x), latitude: Int(modelPos.y))
                let bottom = gameModel.getElevation(fromMap: fireResult.detonationResult[index].bottomBuf,
                                                    longitude: Int(modelPos.x), latitude: Int(modelPos.y))
                
                // check to see if drop block is needed
                if top > middle && middle > bottom {
                    dropNeeded = true
                    //NSLog("(\(i),\(j)) will drop, top: \(top), middle: \(middle), bottom: \(bottom)")
                    // need to create and animate a drop block
                    let dropBlock = SCNNode(geometry: SCNBox(width: blockGeometry.width,
                                                             height: CGFloat(top-middle) - 1 ,
                                                             length: blockGeometry.length, chamferRadius: 0))
                    dropBlock.position = boardBlock.position
                    dropBlock.position.y = (top+middle)/2 - 0.5
                    dropBlock.geometry?.firstMaterial = blockGeometry.firstMaterial
                    dropBlock.isHidden = true
                    droppingNode.addChildNode(dropBlock)
                    
                    let dropBlockSurface = SCNNode(geometry: SCNBox(width: blockGeometry.width,
                                                                    height: 1,
                                                                    length: blockGeometry.length,
                                                                    chamferRadius: 0))
                    dropBlockSurface.position.y = (top-middle)/2 + 0.5
                    dropBlockSurface.geometry?.firstMaterial = surfaceGeometry.firstMaterial
                    dropBlock.addChildNode(dropBlockSurface)
                    
//                    // for debugging purposes
//                    dropBlock.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
//                    dropBlockSurface.geometry?.firstMaterial?.diffuse.contents = UIColor.blue

                    var finalPosition = dropBlock.position
                    finalPosition.y = bottom + (top-middle)/2
                    
                    let dropAction = SCNAction.sequence([.wait(duration: currTime),
                                                         .unhide(),
                                                         .move(to: finalPosition, duration: dropTime)])
                    dropBlock.runAction(dropAction)
                }
                
//                // check to see if shortening is needed
//                if  bottom != current {
//                    // height adjustment needed
//                    //NSLog("(\(i),\(j)) height change needed, \(current) -> \(bottom), top: \(top), middle: \(middle), bottom: \(bottom)")
//
//                    // create new block
//                    let shortBlock = SCNNode(geometry: SCNBox(width: blockGeometry.width, height: CGFloat(bottom), length: blockGeometry.length, chamferRadius: 0))
//                    shortBlock.position = boardBlock.position
//                    shortBlock.position.y = bottom / 2
//                    shortBlock.isHidden = true
//                    shortBlock.geometry?.firstMaterial = blockGeometry.firstMaterial
//                    droppingNode.addChildNode(shortBlock)
//
//                    let shortenAction = SCNAction.sequence([.wait(duration: currTime),
//                                                            .unhide()])
//                    shortBlock.runAction(shortenAction)
//
//                    let hideTallAction = SCNAction.sequence([.wait(duration: currTime),
//                                                             .hide()])
//                    boardBlocks[i][j].runAction(hideTallAction)
//                }
            }
        }
        NSLog("drop/short blocks appear at time \(currTime)")
        if dropNeeded {
            currTime += dropTime
        }
        NSLog("board settled at time \(currTime).")
        
        return currTime
    }
    
    var previousPuddleEnd: Int = 0
    var previousPipeEnd: Int = 0
    var currentZ: Float = 0
    var puddleSet: [Bool] = []
    var bottomFilledTo: [Int:Float] = [:]

    func animateFluidFill(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green], at time: CFTimeInterval, index: Int = 0) -> CFTimeInterval {
        var currTime = time
        
        let path = fireResult.detonationResult[index].fluidPath
        let remaining = fireResult.detonationResult[index].fluidRemaining
        let puddles = findPuddles(in: path)
        let subEdges = 3
        let drainEdgeSize = edgeSize / CGFloat(subEdges)
        var drainStart = 0
        
        // initialize variables for tracking animation
        previousPipeEnd = 0
        previousPuddleEnd = 0
        puddleSet = [Bool](repeating: false, count: gameModel.board.boardSize * gameModel.board.boardSize)
        
        // set color of fluid
        var color = UIColor.green
        if fireResult.weaponStyle == .mud {
            color = UIColor.brown
        } else if fireResult.weaponStyle == .napalm {
            color = UIColor.red
        }
        
        var fillLevels = [[PriorityQueue<Pair<Double,Float>>]](repeatElement([PriorityQueue<Pair<Double,Float>>](repeatElement(PriorityQueue<Pair<Double,Float>>(), count: numPerSide)), count: numPerSide))
        
        // for debugging purposes
        var minElevation: Float = 10000000
        var minElevI = 0
        var minElevJ = 0
        
        fluidNode.isHidden = true
        fluidNode.removeFromParentNode()
        fluidNode = SCNNode()
        var tracedSet = [Bool](repeating: false, count: subEdges * subEdges * gameModel.board.boardSize * gameModel.board.boardSize)

        var blockDrainStart = 0
        var drainBlocks = 0
        for puddle in puddles {
            // animate drain paths
            var blockDrainEnd = 0
            if drainStart < puddle.minPos {
                for i in drainStart...puddle.minPos {
                    let point = path[i]
                    
                    let drainBlockX = Int(CGFloat(Int(CGFloat(point.x) / drainEdgeSize)) * drainEdgeSize + drainEdgeSize/2)
                    let drainBlockY = Int(CGFloat(Int(CGFloat(point.y) / drainEdgeSize)) * drainEdgeSize + drainEdgeSize/2)
                    let drainPos = numPerSide * subEdges * drainBlockY + drainBlockX
                    
                    if !tracedSet[drainPos] {

                        let blockX = Int(CGFloat(Int(CGFloat(point.x) / edgeSize)) * edgeSize + edgeSize/2)
                        let blockY = Int(CGFloat(Int(CGFloat(point.y) / edgeSize)) * edgeSize + edgeSize/2)
                        let blockElevation = gameModel.getElevation(fromMap: fireResult.old, longitude: Int(blockX), latitude: Int(blockY))
                    
                        tracedSet[drainPos] = true
                        drainBlocks += 1
                        
                        blockDrainStart = blockDrainEnd
                        blockDrainEnd = i
                        
                        // add a block for the drain path
                        let drainBlock = SCNNode(geometry: SCNBox(width: drainEdgeSize, height: 1, length: drainEdgeSize, chamferRadius: 0))
                        drainBlock.position = fromModelSpace(Vector3(Float(drainBlockX), Float(drainBlockY), blockElevation+0.5))
                        drainBlock.isHidden = true
                        drainBlock.geometry?.firstMaterial?.diffuse.contents = color
                        fluidNode.addChildNode(drainBlock)
                        
                        // animate appearance of block
                        let appear = SCNAction.sequence([.wait(duration: currTime),
                                                         .unhide()])
                        drainBlock.runAction(appear)
                        
                        // update currTime
                        let drainVolume = remaining[blockDrainEnd] - remaining[blockDrainStart]
                        if drainVolume > 0 {
                            let drainTime = Double(drainVolume / drainRate)
                            currTime += drainTime
                        }
                        
                    }
                }
                currentZ = path[puddle.minPos].z
            }
            
            
            // animate puddle fills
            fillRate = 5000.0
            let maxFillTime: CFTimeInterval = 20.0
            fillRate = max(fillRate, remaining[0] / Float(maxFillTime))

            for i in previousPuddleEnd...puddle.end {
                let point = path[i]
                let coord = Int(point.y) * gameModel.board.boardSize + Int(point.x)
                puddleSet[coord] = true
            }

            let fillVolume = remaining[puddle.minPos] - remaining[puddle.end]
            let fillTime = Double(fillVolume / fillRate)
            let startElevation = max(currentZ, path[puddle.minPos].z)
            let finalElevation = path[puddle.end].z

            for i in 0..<numPerSide {
                for j in 0..<numPerSide {

                    // determine location of segment
                    let xPos = CGFloat(i)*edgeSize + edgeSize/2
                    let zPos = CGFloat(j)*edgeSize + edgeSize/2
                    let elevation = gameModel.getElevation(fromMap: fireResult.old, longitude: Int(xPos), latitude: Int(zPos))
                    
                    // for debugging purposes
                    if elevation < minElevation {
                        minElevI = i
                        minElevJ = j
                        minElevation = elevation
                    }

                    let coord = Int(zPos) * gameModel.board.boardSize + Int(xPos)
                    if puddleSet[coord] && finalElevation >= elevation {
                        // only record time indexed level for each fill block, animations will be handled later
                        fillLevels[i][j].enqueue(Pair<Double,Float>(key: currTime, value: startElevation))
                        fillLevels[i][j].enqueue(Pair<Double,Float>(key: currTime+fillTime, value: finalElevation))
                    }
                }
            }
            currentZ = finalElevation
            currTime += fillTime
            
            drainStart = puddle.end
            previousPuddleEnd = puddle.end
        } // puddles
        NSLog("\(drainBlocks) total drain blocks added.")
        
        // actually create fill blocks and animate them based on fillLevel values
        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                guard fillLevels[i][j].count > 0 else { continue }
                
                // determine location of segment
                let xPos = CGFloat(i)*edgeSize + edgeSize/2
                let zPos = CGFloat(j)*edgeSize + edgeSize/2
                let elevation = gameModel.getElevation(fromMap: fireResult.old, longitude: Int(xPos), latitude: Int(zPos))
                
                // create short block that will be animated to be taller
                //let fillBlockGeometry = SCNBox(width: edgeSize, height: 1, length: edgeSize, chamferRadius: 0)
                //let fillBlock = SCNNode(geometry: fillBlockGeometry)
                //fillBlock.position = fromModelSpace(Vector3(xPos,zPos,CGFloat(elevation)+0.5))
                //fillBlockGeometry.height = 0
                //fillBlockGeometry.firstMaterial?.diffuse.contents = color
                //fillBlock.isHidden = true
                
                // extract ordered list of fluid levels for this block
                var levelQueue = fillLevels[i][j]
                var levels: [Pair<Double,Float>] = []
                var lastLevel: Float = -1
                while levelQueue.count > 0 {
                    let pair = levelQueue.dequeue()!
                    if pair.value >= lastLevel {
                        levels.append(pair)
                        lastLevel = pair.value
                    }
                }
                
                var fillPos = 0
                let fillAction = SCNAction.customAction(duration: currTime, action: {node, elapsedTime in
                    
                    let currTime = Double(elapsedTime)
                    guard currTime >= levels[fillPos].key else { return }
                    
                    while fillPos < levels.count - 1 && currTime >= levels[fillPos+1].key {
                        // if this is too slow, reverse the array, and have it be stack-like
                        fillPos += 1
                    }
                    guard fillPos < levels.count - 1 else { return }
                    
                    // compute level needed at elapsedTime
                    let prevTime = levels[fillPos].key
                    let destTime = levels[fillPos+1].key
                    let timeDiff = destTime - prevTime
                    guard timeDiff > 0.001 else { return }
                    let prevLevel = levels[fillPos].value
                    let destLevel = levels[fillPos+1].value
                    let progress = (currTime - prevTime) / timeDiff
                    let fillLevel = Float(Double(destLevel - prevLevel) * progress) + prevLevel

                    if fillLevel >= elevation {
                        // cause block to appear when needed
                        //NSLog("setting color to \(color) for \(i),\(j)")
                        node.geometry?.firstMaterial?.diffuse.contents = color
                    }

                    // for debugging purposes
                    if i==minElevI && j==minElevJ {
                        // http://en.swifter.tips/output-format/
                        let f = "%0.3f"
                        NSLog("\(i),\(j): fillPos: \(fillPos), progress: \(f), time: \(f) -> \(f) -> \(f), level: \(f) -> \(f) -> \(f), levels: \(levels)",
                            progress, prevTime, currTime, destTime, prevLevel, fillLevel, destLevel)
                    }
                    
                    // set actual values for elapsedTime
                    let filledHeight = fillLevel - elevation
                    node.position.y = elevation/2 + filledHeight / 2 - 0.5
                    let geometry = node.geometry as! SCNBox
                    geometry.height = CGFloat(filledHeight) + 1
                })
                //fillBlock.runAction(fillAction)
                //fluidNode.addChildNode(fillBlock)
                // use block surface covers as the fill medium
                boardSurfaces[i][j].runAction(fillAction)
                
            }
        }
        
        board.addChildNode(fluidNode)
        NSLog("finished fluid fill at time \(currTime)")
        
        return currTime
    }
    
}
