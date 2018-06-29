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
    var dropBlocks: [SCNNode] = []

    override func addBoard() {
        NSLog("\(#function) started")
        
        // use cubes until I can sort out actual Meshes.
        
        // keep references to each block
        boardBlocks = Array(repeating: Array(repeating: SCNNode(), count: numPerSide), count: numPerSide)
        let edgeSize = CGFloat(gameModel.board.boardSize / numPerSide)
        
        for i in 0..<numPerSide {
            for j in 0..<numPerSide {
                // create block
                let blockNode = SCNNode(geometry: SCNBox(width: edgeSize, height: 1, length: edgeSize, chamferRadius: 0))
                boardBlocks[i][j] = blockNode
                blockNode.position.y = -1 // make sure update will happen initially
                
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
        board.removeFromParentNode()
        NSLog("\(#function) finished")
    }
    
    
    override func updateBoard() {
        //NSLog("\(#function) started")
        let edgeSize = CGFloat(gameModel.board.boardSize / numPerSide)
        
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
                blockNode.isHidden = false
                blockNode.opacity = 1.0
                
                if blockNode.position.y != Float(yPos) {
                    //NSLog("block at \(i),\(j) is \(blockNode)")
                    blockNode.position = SCNVector3(xPos-CGFloat(gameModel.board.boardSize/2),
                                                    yPos,
                                                    zPos-CGFloat(gameModel.board.boardSize/2))
                    if let geometry = blockNode.geometry as? SCNBox {
                        geometry.width = edgeSize
                        geometry.height = ySize
                        geometry.length = edgeSize
                    }
                }
                
                // update color
                blockNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            }
        }
        
        // remove any dropBlocks that may still be around
        for block in dropBlocks {
            block.removeFromParentNode()
        }
        //NSLog("\(#function) finished")
    }

    override func animateResult(fireResult: FireResult, from: GameViewController) {
        NSLog("\(#function) started")
        
        // time for use in animations
        var currTime: CFTimeInterval = 0
        
        currTime = animateShell(fireResult: fireResult, at: currTime)
        currTime = animateExplosion(fireResult: fireResult, at: currTime)
        
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
                let blockGeometry = boardBlock.geometry as! SCNBox
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
                                                             height: CGFloat(top-middle),
                                                             length: blockGeometry.length, chamferRadius: 0))
                    dropBlock.position = boardBlock.position
                    dropBlock.position.y = (top+middle)/2
                    dropBlock.geometry?.firstMaterial = blockGeometry.firstMaterial
                    dropBlock.isHidden = true
                    board.addChildNode(dropBlock)
                    dropBlocks.append(dropBlock)
                    
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
        
        // deal with round transitions
        currTime = animateRoundResult(fireResult: fireResult, at: currTime)
        
        // wait for animations to end
        let delay = SCNAction.sequence([.wait(duration: currTime)])
        board.runAction(delay, completionHandler: { DispatchQueue.main.async { from.finishTurn() } })
        
        NSLog("\(#function) finished")
    }

}
