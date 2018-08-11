//
//  GameViewBlockDrawer.swift
//  TanksAR
//
//  Created by Fraggle on 6/22/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

class GameViewBlockDrawer : GameViewDrawer {

    var boardBlocks: [[SCNNode]] = []
    var boardSurfaces: [[SCNNode]] = []
    var dropBlocks: [SCNNode] = []
    var fluidNode: SCNNode = SCNNode()
    let drainRate: Float = 500
    var fillRate: Float = 1000
    
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
                board.addChildNode(boardBlocks[i][j])
            }
        }
        updateBoard()
        //mapImage.image = gameModel.board.surface.asUIImage()
        
        NSLog("\(#function) finished")
    }
    
    override func removeBoard() {
        NSLog("\(#function) started")
        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                boardBlocks[i][j].removeFromParentNode()
            }
        }
        boardBlocks = []
        boardSurfaces = []
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
                }
                blockSurface.position.y = Float(yPos) + 0.5
                
                // update color
                let color = gameModel.getColor(longitude: Int(xPos), latitude: Int(zPos))
                blockNode.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
//                if i != 0 && j != 0 && i < numPerSide-1 && j < numPerSide-1 {
//                    blockNode.geometry?.firstMaterial?.diffuse.contents = color
//                }
                blockSurface.geometry?.firstMaterial?.diffuse.contents = color
            }
        }
        
        // remove any dropBlocks that may still be around
        for block in dropBlocks {
            block.removeFromParentNode()
        }
        fluidNode.removeFromParentNode()
        //NSLog("\(#function) finished")
    }

    override func animateResult(fireResult: FireResult, from: GameViewController) {
        NSLog("\(#function) started")
        
        // time for use in animations
        var currTime: CFTimeInterval = 0
        
        currTime = animateShell(fireResult: fireResult, at: currTime)
        if fireResult.weaponStyle == .explosive || fireResult.weaponStyle == .generative {
            currTime = animateExplosion(fireResult: fireResult, at: currTime)
        }

        if fireResult.weaponStyle == .explosive || fireResult.weaponStyle == .generative {
            currTime = animateDropSurface(fireResult: fireResult, from: from, at: currTime)
        } else if fireResult.weaponStyle == .napalm || fireResult.weaponStyle == .mud {
            currTime = animateFluidFill(fireResult: fireResult, from: from, at: currTime)
        }
        
        // deal with round transitions
        currTime = animateRoundResult(fireResult: fireResult, at: currTime)
        
        // wait for animations to end
        let delay = SCNAction.sequence([.wait(duration: currTime)])
        board.runAction(delay, completionHandler: { DispatchQueue.main.async { from.finishTurn() } })
        
        NSLog("\(#function) finished")
    }

    func animateDropSurface(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green], at time: CFTimeInterval) -> CFTimeInterval {
        var currTime = time

        // animate board update
        var dropNeeded = false
        for block in dropBlocks {
            block.removeFromParentNode()
        }
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
                let current = gameModel.getElevation(fromMap: fireResult.old,
                                                     longitude: Int(modelPos.x), latitude: Int(modelPos.y))
                let top = gameModel.getElevation(fromMap: fireResult.top,
                                                 longitude: Int(modelPos.x), latitude: Int(modelPos.y))
                let middle = gameModel.getElevation(fromMap: fireResult.middle,
                                                    longitude: Int(modelPos.x), latitude: Int(modelPos.y))
                let bottom = gameModel.getElevation(fromMap: fireResult.bottom,
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
                    board.addChildNode(dropBlock)
                    dropBlocks.append(dropBlock)
                    
                    let dropBlockSurface = SCNNode(geometry: SCNBox(width: blockGeometry.width,
                                                                    height: 1,
                                                                    length: blockGeometry.length,
                                                                    chamferRadius: 0))
                    dropBlockSurface.position.y = (top-middle)/2 + 0.5
                    dropBlockSurface.geometry?.firstMaterial = surfaceGeometry.firstMaterial
                    dropBlock.addChildNode(dropBlockSurface)
                    
                    var finalPosition = dropBlock.position
                    finalPosition.y = bottom + (top-middle)/2
                    
                    let dropAction = SCNAction.sequence([.wait(duration: currTime),
                                                         .unhide(),
                                                         .move(to: finalPosition, duration: dropTime)])
                    dropBlock.runAction(dropAction)
                }
                
                // check to see if shortening is needed
                if  bottom != current {
                    // height adjustment needed
                    //NSLog("(\(i),\(j)) height change needed, \(current) -> \(bottom), top: \(top), middle: \(middle), bottom: \(bottom)")
                    
                    // create new block
                    let shortBlock = SCNNode(geometry: SCNBox(width: blockGeometry.width, height: CGFloat(bottom), length: blockGeometry.length, chamferRadius: 0))
                    shortBlock.position = boardBlock.position
                    shortBlock.position.y = bottom / 2
                    shortBlock.isHidden = true
                    shortBlock.geometry?.firstMaterial = blockGeometry.firstMaterial
                    dropBlocks.append(shortBlock)
                    board.addChildNode(shortBlock)
                    
                    let shortenAction = SCNAction.sequence([.wait(duration: currTime),
                                                            .unhide()])
                    shortBlock.runAction(shortenAction)
                    
                    let hideTallAction = SCNAction.sequence([.wait(duration: currTime),
                                                             .hide()])
                    boardBlocks[i][j].runAction(hideTallAction)
                }
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

    func animateFluidFill(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green], at time: CFTimeInterval) -> CFTimeInterval {
        var currTime = time
        
        let path = fireResult.fluidPath
        let remaining = fireResult.fluidRemaining
        let puddles = findPuddles(in: path)
        let drainEdgeSize = edgeSize / 5
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
        
        fluidNode.removeFromParentNode()
        fluidNode = SCNNode()
        for puddle in puddles {
            // animate drain paths
            var prevDrainX = 0
            var prevDrainY = 0
            var blockDrainStart = 0
            var blockDrainEnd = 0
            if drainStart < puddle.minPos {
                for i in drainStart...puddle.minPos {
                    let point = path[i]
                    
                    let drainBlockX = Int(CGFloat(Int(CGFloat(point.x) / drainEdgeSize)) * drainEdgeSize + drainEdgeSize/2)
                    let drainBlockY = Int(CGFloat(Int(CGFloat(point.y) / drainEdgeSize)) * drainEdgeSize + drainEdgeSize/2)
                    
                    let blockX = Int(CGFloat(Int(CGFloat(point.x) / edgeSize)) * edgeSize + edgeSize/2)
                    let blockY = Int(CGFloat(Int(CGFloat(point.y) / edgeSize)) * edgeSize + edgeSize/2)
                    let blockElevation = gameModel.getElevation(fromMap: fireResult.old, longitude: Int(blockX), latitude: Int(blockY))
                    
                    if drainBlockX != prevDrainX || drainBlockY != prevDrainY {
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
                    
                    prevDrainX = drainBlockX
                    prevDrainY = drainBlockY
                }
                currentZ = path[puddle.minPos].z
            }
            
            // animate puddle fills
            fillRate = 1000.0
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
            let fillHeight = Double(finalElevation - startElevation)

            for i in 0..<numPerSide {
                for j in 0..<numPerSide {
                    // determine location of segment
                    let xPos = CGFloat(i)*edgeSize + edgeSize/2
                    let zPos = CGFloat(j)*edgeSize + edgeSize/2
                    let elevation = gameModel.getElevation(fromMap: fireResult.old, longitude: Int(xPos), latitude: Int(zPos))
                    
                    let coord = Int(zPos) * gameModel.board.boardSize + Int(xPos)
                    if puddleSet[coord] && finalElevation >= elevation {
                        // create short block that will be animated to be taller
                        let fillBlockGeometry = SCNBox(width: edgeSize, height: 0, length: edgeSize, chamferRadius: 0)
                        let fillBlock = SCNNode(geometry: fillBlockGeometry)
                        fillBlock.position = fromModelSpace(Vector3(xPos,zPos,CGFloat(elevation)))
                        fillBlockGeometry.height = 0
                        fillBlockGeometry.firstMaterial?.diffuse.contents = color
                        
                        let fillAction = SCNAction.sequence([.wait(duration: currTime),
                                                             .customAction(duration: fillTime, action: {node, elapsedTime in
                                                                let progress = Double(elapsedTime) / fillTime
                                                                let geometry = node.geometry as! SCNBox
                                                                node.position.y = Float(Double(startElevation) + progress * (fillHeight / 2))
                                                                geometry.height = CGFloat(progress * fillHeight)
                                                             })])
                        fillBlock.runAction(fillAction)
                        fluidNode.addChildNode(fillBlock)
                    }
                }
            }
            currentZ = finalElevation
            currTime += fillTime
            
            drainStart = puddle.end
            previousPuddleEnd = puddle.end
        }
        board.addChildNode(fluidNode)
        NSLog("finished fluid fill at time \(currTime)")
        
        return currTime
    }
    
}
