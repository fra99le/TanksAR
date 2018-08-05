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

// Note: Drawers should be responsible for adding/removing/updating the tanks
// Note: The 'users' array should also be in the Drawer

class GameViewDrawer {

    var gameModel: GameModel! = nil
    var sceneView: ARSCNView! = nil
    var board: SCNNode = SCNNode()
    var tankNodes: [SCNNode] = []
    var tankScale: Float = 10
    var numPerSide: Int = 0
    var shellNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    var explosionNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    var timeScaling: Double = 3
    let explosionTime: Double = 0.5
    let explosionReceedTime: Double = 0.25
    let dropTime: Double = 1.5
    //let dropTime: Double = 10 // for debugging purposes
    let roundResultTime: Double = 10
    var edgeSize: CGFloat { return CGFloat(Float(gameModel.board.boardSize-1) / Float(numPerSide)) }

    init(sceneView: ARSCNView, model: GameModel, node: SCNNode, numPerSide: Int, tankScale: Float) {
        gameModel = model
        board = node
        self.numPerSide = numPerSide
        self.sceneView = sceneView
        self.tankScale = tankScale
    }
    
    // these should be abstract methods, or equivilant
    func addBoard() { preconditionFailure("This method must be overridden") }
    func removeBoard() { preconditionFailure("This method must be overridden") }
    func updateBoard() { preconditionFailure("This method must be overridden") }
    func animateResult(fireResult: FireResult, from: GameViewController)
        { preconditionFailure("This method must be overridden") }
    
    func setupLighting() {
        sceneView.autoenablesDefaultLighting = true
    }
    
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
    
    func addTrajectory(trajectory: [Vector3], toNode: SCNNode, color: UIColor) {
        let segments = 20
        if trajectory.count > 2 {
            var prevPos: Vector3 = trajectory.first!
            for i in 1..<segments {
                let newIndex = Int(Float(i) * Float(trajectory.count) / Float(segments))
                let newPos = trajectory[newIndex]
                
                let joint = SCNNode(geometry: SCNSphere(radius: CGFloat(0.25*tankScale)))
                joint.geometry?.firstMaterial?.diffuse.contents = color
                joint.position = fromModelSpace(newPos)
                toNode.addChildNode(joint)
                
                addCylinder(from: prevPos, to: newPos, toNode: toNode, color: color)
                prevPos = newPos
            }
            addCylinder(from: prevPos, to: trajectory.last!, toNode: toNode, color: color)
        }
        
    }
    
    func addCylinder(from: Vector3, to: Vector3, toNode: SCNNode, color: UIColor) {
        let cylinder = SCNNode()
        
        //NSLog("Adding cylinder from \(from) to \(to).")
        
        let length = gameModel.distance(from: from, to: to)
        cylinder.geometry = SCNCylinder(radius: CGFloat(0.25*tankScale), height: CGFloat(length))
        cylinder.geometry?.firstMaterial?.diffuse.contents = color
        
        // get orientation
        let viewTo = fromModelSpace(to)
        let viewFrom = fromModelSpace(from)
        let diff = SCNVector3(viewTo.x - viewFrom.x, viewTo.y - viewFrom.y, viewTo.z - viewFrom.z)
        
        let angle1 = atan2(diff.y, sqrt(diff.z*diff.z + diff.x*diff.x))
        let angle2 = atan2(diff.z, diff.x)
        //NSLog("diff: \(diff), angles: \(angle1*180/Float.pi),\(angle2*180/Float.pi)")
        
        cylinder.eulerAngles.z = Float.pi / 2 - angle1
        
        let gimble = SCNNode()
        gimble.addChildNode(cylinder)
        gimble.eulerAngles.y = Float.pi - angle2
        
        // get position of cylinder's gimble
        let sum = vectorAdd(to, from)
        let mid = vectorScale(sum, by: 0.5)
        gimble.position = fromModelSpace(mid)
        
        toNode.addChildNode(gimble)
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
            explosionNode?.castsShadow = false
            board.addChildNode(explosion)
            
            let explosionActions = SCNAction.sequence([.wait(duration: currTime),
                                                       .unhide(),
                                                       .scale(to: CGFloat(fireResult.explosionRadius), duration: explosionTime),
                                                       .scale(to: 0, duration: explosionReceedTime),
                                                       .hide()])
            explosionNode?.runAction(explosionActions)

            // check for tanks that need to be hidden
            for i in 0..<gameModel.board.players.count {
                let player = gameModel.board.players[i]
                if player.hitPoints <= 0 {
                    let tankNode = tankNodes[i]
                    let hideAction = SCNAction.sequence([.wait(duration: currTime+explosionTime),
                                                         .hide()])
                    tankNode.runAction(hideAction)
                }
            }
        }
        currTime += explosionTime
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
        if gameModel.board.totalRounds == 0 && fireResult.humanLeft == 0 {
            message = "Game Over!\n\(gameModel.board.players[0].name) earned \(gameModel.board.players[0].score) points."
        } else if gameModel.board.currentRound > gameModel.board.totalRounds
            && gameModel.board.totalRounds>0 {
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
        NSLog("round transition messages is: \(message)")
        
        // create message and add it to board
        let textGeometry = SCNText(string: message, extrusionDepth: 2)
        textGeometry.alignmentMode = kCAAlignmentCenter
        let msgNode = SCNNode(geometry: textGeometry)
        let (min: boundingMin, max: boundingMax) = msgNode.boundingBox
        NSLog("bounding box: \(boundingMin) -> \(boundingMax)")
        msgNode.position = SCNVector3( -(boundingMax.x+boundingMin.x)/2,
                                       0,
                                       -(boundingMax.z+boundingMin.z)/2 )
        msgNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
        
        // find highest point on map
        var maxElevation: Float = -1
        for j in 0..<1025 {
            for i in 0..<1025 {
                let elevation = gameModel.getElevation(fromMap: fireResult.final, longitude: i, latitude: j)
                maxElevation = max(elevation, maxElevation)
            }
        }
        
        let spinNode = SCNNode()
        spinNode.position = fromModelSpace( Vector3(Float(gameModel.board.boardSize)/2,
                                                    Float(gameModel.board.boardSize)/2,
                                                    maxElevation+10) )
        spinNode.scale = SCNVector3(8,8,8)
        spinNode.isHidden = true

        spinNode.addChildNode(msgNode)
        board.addChildNode(spinNode)
        
        // animate message
        let actions = SCNAction.sequence([.wait(duration: currTime),
                                          .scale(to: 0, duration: 0),
                                          .unhide(),
                                          .scale(to: 8, duration: 1),
                                          .rotateBy(x: 0, y: -CGFloat(Float.pi * 4), z: 0, duration: roundResultTime-2),
                                          .scale(to: 0, duration: 1),
                                          .hide()])
        spinNode.runAction(actions)
        
        currTime += roundResultTime
        NSLog("round transition ends at time \(currTime).")

        return currTime
    }
    
    // helper methods
    func toModelSpace(_ position: SCNVector3) -> Vector3 {
        return Vector3(position.x + Float(gameModel.board.boardSize)/2,
                       position.z + Float(gameModel.board.boardSize)/2,
                       position.y)
    }
    
    func fromModelSpace(_ position: Vector3) -> SCNVector3 {
        return SCNVector3(x: position.x - Float(gameModel.board.boardSize)/2,
                          y: position.z,
                          z: position.y - Float(gameModel.board.boardSize)/2)
    }
    
    func toModelScale(_ vector: SCNVector3) -> Vector3 {
        let ret = Vector3(vector.x,vector.z,vector.y)
        return ret
    }
    
    func fromModelScale(_ vector: Vector3) -> SCNVector3 {
        let ret = SCNVector3(vector.x,vector.z,vector.y)
        return ret
    }
    
    func showLights() {
        var node: SCNNode = board
        var root: SCNNode = board
        // find root node
        while let parent = node.parent {
            root = parent
            node = parent
        }
        
        // traverse all nodes
        NSLog("\(#function) starting from root: \(root)")
        var queue = [root]
        while !queue.isEmpty {
            let node = queue.removeFirst()
            queue.append(contentsOf: node.childNodes)
            
            if let light = node.light {
                NSLog("\tfound light: \(light) in \(node) at \(node.position)")
            }
        }
        NSLog("\(#function) finished")
    }
}
