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
