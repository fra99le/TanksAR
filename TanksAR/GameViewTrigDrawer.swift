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
    var topNode = SCNNode()
    var bottomNode = SCNNode()
    var leftNode = SCNNode()
    var rightNode = SCNNode()

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
                // No indices added!
                pos += 1
            }
            
            for j in 0..<numPerSide {
                
                let x = CGFloat(i)*edgeSize
                var z: CGFloat = 0
                if isEven {
                    y = CGFloat(j)*edgeSize
                } else {
                    z = (CGFloat(j)+0.5)*edgeSize
                }
                let y = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(z)))

                vertices.append(SCNVector3(x - CGFloat(gameModel.board.boardSize/2),
                                           y,
                                           z - CGFloat(gameModel.board.boardSize/2)))
                
                if isEven {
                    indices.append(pos)
                    indices.append(pos+1)
                    indices.append(pos+CInt(numPerSide)+2)

                    indices.append(pos)
                    indices.append(pos+CInt(numPerSide)+2)
                    indices.append(pos+CInt(numPerSide)+1)
                } else {
                    indices.append(pos-1)
                    indices.append(pos)
                    indices.append(pos+CInt(numPerSide))
                    
                    indices.append(pos)
                    indices.append(pos+CInt(numPerSide)+1)
                    indices.append(pos+CInt(numPerSide))
                }
                pos += 1
            }
            
            if isEven {
                let x = CGFloat(i)*edgeSize
                let z = CGFloat(numPerSide)*edgeSize
                let y = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(z)))
                
                vertices.append(SCNVector3(x - CGFloat(gameModel.board.boardSize/2),
                                           y,
                                           z - CGFloat(gameModel.board.boardSize/2)))
                // no indices added here!
                pos += 1
            }
        }
        
        // create geometry for surface
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let elements = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource], elements: [elements])
        geometry.firstMaterial?.diffuse.contents = UIColor.green
        
        // add surface to scene
        surface.removeFromParentNode()
        surface = SCNNode(geometry: geometry)
        board.addChildNode(surface)
        
        // draw board edges and base
        var topVerts: [SCNVector3] = []
        var bottomVerts: [SCNVector3] = []
        var leftVerts: [SCNVector3] = []
        var rightVerts: [SCNVector3] = []
        var edgeIndices: [CInt] = []
        pos = 0
        for i in 0...numPerSide {
            // top edge (+y)
            var x = CGFloat(numPerSide-i)*edgeSize
            var y = CGFloat(numPerSide)*edgeSize
            var z = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(y)))
            topVerts.append(fromModelSpace(SCNVector3(x,y,0)))
            topVerts.append(fromModelSpace(SCNVector3(x,y,z)))
            
            NSLog("i=\(i), x,y,z=\(x),\(y),\(z), vert: \(topVerts.last!)")
            
            // bottom edge (y=0)
            x = CGFloat(i)*edgeSize
            y = CGFloat(0)*edgeSize
            z = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(y)))
            bottomVerts.append(fromModelSpace(SCNVector3(x,y,0)))
            bottomVerts.append(fromModelSpace(SCNVector3(x,y,z)))

            // left edge (x=0)
            x = CGFloat(0)*edgeSize
            y = CGFloat(numPerSide-i)*edgeSize
            z = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(y)))
            leftVerts.append(fromModelSpace(SCNVector3(x,y,0)))
            leftVerts.append(fromModelSpace(SCNVector3(x,y,z)))

            // right edge (+x)
            x = CGFloat(numPerSide)*edgeSize
            y = CGFloat(i)*edgeSize
            z = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(y)))
            rightVerts.append(fromModelSpace(SCNVector3(x,y,0)))
            rightVerts.append(fromModelSpace(SCNVector3(x,y,z)))

            // create indices
            if i < numPerSide {
                edgeIndices.append(pos)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+2)
                
                edgeIndices.append(pos+2)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+3)
                pos += 2
            }
        }
        
        NSLog("\(topVerts.count) edge vertices, \(edgeIndices.count) edge indices, pos=\(pos)")
        // all sides have the same vertext ordering
        let edgeElements = SCNGeometryElement(indices: edgeIndices, primitiveType: .triangles)
        
        let topSource = SCNGeometrySource(vertices: topVerts)
        let bottomSource = SCNGeometrySource(vertices: bottomVerts)
        let leftSource = SCNGeometrySource(vertices: leftVerts)
        let rightSource = SCNGeometrySource(vertices: rightVerts)

        let topGeometry = SCNGeometry(sources: [topSource], elements: [edgeElements])
        let bottomGeometry = SCNGeometry(sources: [bottomSource], elements: [edgeElements])
        let leftGeometry = SCNGeometry(sources: [leftSource], elements: [edgeElements])
        let rightGeometry = SCNGeometry(sources: [rightSource], elements: [edgeElements])

        topGeometry.firstMaterial?.diffuse.contents = UIColor.green
        bottomGeometry.firstMaterial?.diffuse.contents = UIColor.green
        leftGeometry.firstMaterial?.diffuse.contents = UIColor.green
        rightGeometry.firstMaterial?.diffuse.contents = UIColor.green

        // remove old edges
        topNode.removeFromParentNode()
        bottomNode.removeFromParentNode()
        leftNode.removeFromParentNode()
        rightNode.removeFromParentNode()
        
        // create new edges
        topNode = SCNNode(geometry: topGeometry)
        bottomNode = SCNNode(geometry: bottomGeometry)
        leftNode = SCNNode(geometry: leftGeometry)
        rightNode = SCNNode(geometry: rightGeometry)

        // add new edges
        board.addChildNode(topNode)
        board.addChildNode(bottomNode)
        board.addChildNode(leftNode)
        board.addChildNode(rightNode)

        // remove any temporary animation objects
    }

    override func animateResult(fireResult: FireResult, from: GameViewController) {
        NSLog("\(#function) started")
        var currTime: CFTimeInterval = 0
        
        currTime = animateShell(fireResult: fireResult, at: currTime)
        currTime = animateExplosion(fireResult: fireResult, at: currTime)
        
        // wait for animations to end
        let delay = SCNAction.sequence([.wait(duration: currTime)])
        board.runAction(delay,
                        completionHandler: { DispatchQueue.main.async { from.finishTurn() } })
        
        NSLog("\(#function) finished")
    }

}
