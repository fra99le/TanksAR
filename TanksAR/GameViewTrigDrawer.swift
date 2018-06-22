//
//  GameViewTrigDrawer.swift
//  TanksAR
//
//  Created by Fraggle on 6/21/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation
import SceneKit

class GameViewTrigDrawer : GameViewDrawer {
 
    var surface = SCNNode()
    
    override func addBoard() {
        updateBoard()
    }
    
    override func removeBoard() {
        NSLog("\(#function) started")
        board.removeFromParentNode()
        NSLog("\(#function) finished")
    }

    override func updateBoard() {
        
        let edgeSize = CGFloat(gameModel.board.boardSize / numPerSide)

        // draw board surface
        var vertices: [SCNVector3] = []
        //var normals: [SCNVector3] = []
        var indices: [CInt] = []
        var pos: CInt = 0
        for i in 0..<numPerSide {
            let isEven = ((i % 2) == 0)
            
            if !isEven {
                let x = CGFloat(i)*edgeSize
                let z = CGFloat(0)*edgeSize
                let y = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(z)))
                
                vertices.append(SCNVector3(x - CGFloat(gameModel.board.boardSize/2),
                                           y,
                                           z - CGFloat(gameModel.board.boardSize/2)))
            }
            
            for j in 0..<numPerSide {
                
                let x = CGFloat(i)*edgeSize
                var z: CGFloat = 0
                if isEven {
                    z = CGFloat(j)*edgeSize
                } else {
                    z = (CGFloat(j)+0.5)*edgeSize
                }
                let y = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(z)))

                vertices.append(SCNVector3(x - CGFloat(gameModel.board.boardSize/2),
                                           y,
                                           z - CGFloat(gameModel.board.boardSize/2)))
                
                if i < numPerSide-1 {
                    indices.append(pos)
                    indices.append(pos+1)
                    indices.append(pos+CInt(numPerSide)+2)
                    
                    indices.append(pos)
                    indices.append(pos+CInt(numPerSide)+2)
                    indices.append(pos+CInt(numPerSide)+1)
                    pos += 1
                }
            }
            
            if isEven {
                let x = CGFloat(i)*edgeSize
                let z = CGFloat(numPerSide-1)*edgeSize
                let y = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(z)))
                
                vertices.append(SCNVector3(x - CGFloat(gameModel.board.boardSize/2),
                                           y,
                                           z - CGFloat(gameModel.board.boardSize/2)))
            }
        }
        
        // create geometry for surface
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let elements = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource], elements: [elements])
        geometry.firstMaterial?.diffuse.contents = UIColor.green
        
        // add surface to scene
        surface = SCNNode(geometry: geometry)
        board.addChildNode(surface)
        
        // draw board edges and base
        for i in 0..<numPerSide {
            // top edge
            
            // right edge
            
            // bottom edge
            
            // left edge
        }
        
        // remove any temporary animation objects
    }

    override func animateResult(fireResult: FireResult, from: GameViewController) {
        NSLog("\(#function) started")
        var currTime: Double = 0
        
        // wait for animations to end
        let delay = SCNAction.sequence([.wait(duration: currTime)])
        board.runAction(delay,
                        completionHandler: { DispatchQueue.main.async { from.finishTurn() } })
        
        NSLog("\(#function) finished")
    }

}
