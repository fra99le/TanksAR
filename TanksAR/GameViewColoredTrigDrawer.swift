//
//  GameViewColoredTrigDrawer.swift
//  TanksAR
//
//  Created by Fraggle on 7/12/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation
import SceneKit

class GameViewColoredTrigDrawer : GameViewTrigDrawer {
    
    let colors = [UIColor.green, UIColor.brown]
    
    override func updateBoard() {
        NSLog("\(#function) started")
        
        // (re)create surface
        surface.removeFromParentNode()
        surface = surfaceNode(forSurface: gameModel.board.surface, useNormals: false, withColors: gameModel.board.colors, colors: colors)
        board.addChildNode(surface)
        
        // (re)create edges
        edgeNode.removeFromParentNode()
        let edgeShape = edgeGeometry(forSurface: gameModel.board.surface)
        edgeNode = SCNNode(geometry: edgeShape)
        board.addChildNode(edgeNode)
        
        // remove any temporary animation objects
        for dropSurface in dropSurfaces {
            dropSurface.isHidden = true
            dropSurface.removeFromParentNode()
        }
        if let morpher = surface.morpher {
            morpher.targets = [surface.geometry!]
        }
        
        newBottomSurface.removeFromParentNode()
        
        NSLog("\(#function) finished")
    }
    
    override func animateResult(fireResult: FireResult, from: GameViewController) {
        super.animateResult(fireResult: fireResult, from: from, useNormals: false, colors: colors)
    }
    
}
