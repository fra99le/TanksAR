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
    var numPerSide: Int = 0
    var shellNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    var explosionNode: SCNNode? = nil // may need to be an array if simultaneous turns are allowed
    let timeScaling = 3

//    func GameViewDrawer(model: GameModel, boardNode: SCNNode, size: Int) {
//        gameModel = model
//        board = boardNode
//        numPerSide = size
//    }
    
    // these should be abstract methods
    func addBoard() {    }
    func removeBoard() {    }
    func updateBoard() {    }
    func animateResult(fireResult: FireResult, from: GameViewController) {    }
    
    func animateShell(fireResult: FireResult, at: CFTimeInterval) -> CFTimeInterval {
        var currTime = at
        
        // create shell object
        if let oldShell = shellNode {
            oldShell.removeFromParentNode()
        }
        shellNode = SCNNode(geometry: SCNSphere(radius: 10))
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
        }
        currTime += 1
        NSLog("explosion ended at time \(currTime).")
        return currTime
    
    }
    
    
    // helper methods
    func toModelSpace(_ position: SCNVector3) -> SCNVector3 {
        return SCNVector3(x: position.x + Float(gameModel.board.boardSize/2),
                          y: position.z + Float(gameModel.board.boardSize/2),
                          z: position.y)
    }
    
    func fromModelSpace(_ position: SCNVector3) -> SCNVector3 {
        return SCNVector3(x: position.x - Float(gameModel.board.boardSize/2),
                          y: position.z,
                          z: position.y - Float(gameModel.board.boardSize/2))
    }
    
    func toModelScale(_ vector: SCNVector3) -> SCNVector3 {
        let ret = SCNVector3(vector.x,vector.z,vector.y)
        return ret
    }
    
    func fromModelScale(_ vector: SCNVector3) -> SCNVector3 {
        let ret = SCNVector3(vector.x,vector.z,vector.y)
        return ret
    }
    
}
