//
//  GameViewDrawer.swift
//  TanksAR
//
//  Created by Fraggle on 6/22/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

class GameViewDrawer {

    var gameModel: GameModel! = nil
    var board: SCNNode = SCNNode()
    var tankNodes: [SCNNode] = []
    var numPerSide: Int = 0
    var shellNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    var explosionNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    var timeScaling: Double = 3
    let dropTime: Double = 1.5

//    func GameViewDrawer(model: GameModel, boardNode: SCNNode, size: Int) {
//        gameModel = model
//        board = boardNode
//        numPerSide = size
//    }
    
    init(model: GameModel, node: SCNNode, numPerSide: Int) {
        gameModel = model
        board = node
        self.numPerSide = numPerSide
    }
    
    // these should be abstract methods, or equivilant
    func addBoard() { preconditionFailure("This method must be overridden") }
    func removeBoard() { preconditionFailure("This method must be overridden") }
    func updateBoard() { preconditionFailure("This method must be overridden") }
    func animateResult(fireResult: FireResult, from: GameViewController)
        { preconditionFailure("This method must be overridden") }
    
    func animateShell(fireResult: FireResult, at: CFTimeInterval) -> CFTimeInterval {
        var currTime = at
        
        // create shell object
        if let oldShell = shellNode {
            oldShell.removeFromParentNode()
        }
        shellNode = SCNNode(geometry: SCNSphere(radius: 5))
        if let shell = shellNode,
            let firstPosition = fireResult.trajectory.first {
            shell.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            // convert back to view coordinates
            shell.position = fromModelSpace(firstPosition)
            shell.isHidden = true
            board.addChildNode(shellNode!)
            
            // make shell appear
            var shellActions: [SCNAction] = [.unhide()]
            
            // make shell move
            let timeStep = CFTimeInterval(fireResult.timeStep / Float(timeScaling))
            for currPosition in fireResult.trajectory {
                // convert currPostion to AR space
                let arPosition = fromModelSpace(currPosition)
                shellActions.append(contentsOf: [.move(to: arPosition, duration: timeStep)])
            }
            currTime = timeStep * CFTimeInterval(fireResult.trajectory.count)
            shellActions.append(contentsOf: [.hide()])
            let shellAnimation = SCNAction.sequence(shellActions)
            shellNode?.runAction(shellAnimation)
        }
        NSLog("shell landed at time \(currTime).")
        return currTime
    }
    
    func animateExplosion(fireResult: FireResult, at: CFTimeInterval) -> CFTimeInterval {
        var currTime = at

        // animate explosion
        if let oldExplosion = explosionNode {
            oldExplosion.removeFromParentNode()
        }
        explosionNode = SCNNode(geometry: SCNSphere(radius: 1))
        if let explosion = explosionNode,
            let lastPosition = fireResult.trajectory.last {
            explosion.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            // convert back to view coordinates
            explosion.position = fromModelSpace(lastPosition)
            explosion.isHidden = true
            board.addChildNode(explosion)
            
            let explosionActions = SCNAction.sequence([.wait(duration: currTime),
                                                       .unhide(),
                                                       .scale(to: CGFloat(fireResult.explosionRadius), duration: 1),
                                                       .scale(to: 1, duration: 1),
                                                       .hide()])
            explosionNode?.runAction(explosionActions)

            // check for tanks that need to be hidden
            for i in 0..<gameModel.board.players.count {
                let player = gameModel.board.players[i]
                if player.hitPoints <= 0 {
                    let tankNode = tankNodes[i]
                    let hideAction = SCNAction.sequence([.wait(duration: currTime+1),
                                                         .hide()])
                    tankNode.runAction(hideAction)
                }
            }
        }
        currTime += 1
        NSLog("explosion reached maximum radius at time \(currTime) and ended at \(currTime+1).")
        
        return currTime
    }
    
    func animateRoundResult(fireResult: FireResult, at: CFTimeInterval) -> CFTimeInterval {
        if !fireResult.newRound {
            // nothing to animate
            return at
        }
        
        var currTime = at
        var message = "Round Ended"
        var winner = "Unknown"
        var points: Int64 = -1
        if gameModel.board.currentRound > gameModel.board.totalRounds {
            // find winner
            for player in gameModel.board.players {
                if player.score > points {
                    points = player.score
                    winner = player.name
                }
            }

            message = "Game Over!\n\(winner) Wins\nwith \(points) points."
        } else {

            // get round number
            let lastRound = gameModel.board.currentRound - 1

            if let winner = fireResult.roundWinner {
                message = "\(winner) won round \(lastRound)!"
            } else {
                // if no winning player, get current leader
                for player in gameModel.board.players {
                    if player.score > points {
                        winner = player.name
                    }
                }
                message = "No winner in round \(lastRound)\n\(winner) currently winning."
            }
        }

        // create message and add it to board
        let textGeometry = SCNText(string: message, extrusionDepth: 2)
        textGeometry.alignmentMode = kCAAlignmentCenter
        let msgNode = SCNNode(geometry: textGeometry)
        let (min: min, max: max) = msgNode.boundingBox
        NSLog("bounding box: \(min) -> \(max)")
        msgNode.position = SCNVector3( -(max.x-min.x)/2, -(max.y-min.y)/2, -(max.z-min.z)/2)
        msgNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
        
        let spinNode = SCNNode()
        spinNode.position = SCNVector3(0,500,0)
        spinNode.scale = SCNVector3(8,8,8)
        spinNode.isHidden = true

        spinNode.addChildNode(msgNode)
        board.addChildNode(spinNode)
        
        // animate message
        let actions = SCNAction.sequence([.wait(duration: currTime),
                                          .scale(to: 0, duration: 0),
                                          .unhide(),
                                          .scale(to: 8, duration: 1),
                                          .rotateBy(x: 0, y: -CGFloat(Float.pi * 4), z: 0, duration: 8),
                                          .scale(to: 0, duration: 1),
                                          .hide()])
        spinNode.runAction(actions)
        
        currTime += 5
        NSLog("round transition ends at time \(currTime).")

        return currTime
    }
    
    // helper methods
    func toModelSpace(_ position: SCNVector3) -> Vector3 {
        return Vector3(position.x + Float(gameModel.board.boardSize/2),
                       position.z + Float(gameModel.board.boardSize/2),
                       position.y)
    }
    
    func fromModelSpace(_ position: Vector3) -> SCNVector3 {
        return SCNVector3(x: position.x - Float(gameModel.board.boardSize/2),
                          y: position.z,
                          z: position.y - Float(gameModel.board.boardSize/2))
    }
    
    func toModelScale(_ vector: SCNVector3) -> Vector3 {
        let ret = Vector3(vector.x,vector.z,vector.y)
        return ret
    }
    
    func fromModelScale(_ vector: Vector3) -> SCNVector3 {
        let ret = SCNVector3(vector.x,vector.z,vector.y)
        return ret
    }
    
}
