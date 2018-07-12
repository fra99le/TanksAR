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
    var dropSurface = SCNNode()
    var edgeNode = SCNNode()
    
    override func addBoard() {
        updateBoard()
    }
    
    override func removeBoard() {
        NSLog("\(#function) started")
        board.removeFromParentNode()
        NSLog("\(#function) finished")
    }
   
    func toMapSpace(x: CGFloat, y: CGFloat) -> CGPoint {
        // convert model space (0,0) -> (boardSize-1,boardSize-1) to map space (0,0) -> (1,1)
        let boardSize = CGFloat(gameModel.board.boardSize)
        return CGPoint(x: x / (boardSize-1),
                       y: y / (boardSize-1))
    }
    
    func surfaceGeometry() -> SCNGeometry {
        return surfaceGeometry(forSurface: gameModel.board.surface)
    }
    
    func surfaceGeometry(forSurface: ImageBuf) -> SCNGeometry {
        let edgeSize = CGFloat(gameModel.board.boardSize / numPerSide)
        
        // draw board surface
        var vertices: [SCNVector3] = []
        var texCoords: [CGPoint] = []
        //var normals: [SCNVector3] = []
        var indices: [CInt] = []
        var pos: CInt = 0
        for i in 0...numPerSide {
            for j in 0...numPerSide {
                
                let x = CGFloat(i)*edgeSize
                let y = CGFloat(j)*edgeSize
                let z = CGFloat(gameModel.getElevation(fromMap: forSurface, longitude: Int(x), latitude: Int(y)))
                
                let viewCoordinates = fromModelSpace(Vector3(x,y,z))
                vertices.append(viewCoordinates)
                texCoords.append(toMapSpace(x: x, y: y))

                if i < numPerSide && j < numPerSide {
                    indices.append(pos)
                    indices.append(pos+1)
                    indices.append(pos+CInt(numPerSide)+2)
                    
                    indices.append(pos)
                    indices.append(pos+CInt(numPerSide)+2)
                    indices.append(pos+CInt(numPerSide)+1)
                }
                pos += 1
            }
        }
        NSLog("\(vertices.count) surface vertices, \(indices.count) surface indices, pos=\(pos)")
        
        // create geometry for surface
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let texSource = SCNGeometrySource(textureCoordinates: texCoords)
        let elements = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [vertexSource, texSource], elements: [elements])
        geometry.firstMaterial?.diffuse.contents = UIColor.green

        return geometry
    }
    
    func edgeGeometry() -> SCNGeometry {
        // draw board edges and base
        let edgeSize = CGFloat(gameModel.board.boardSize / numPerSide)
        var edgeVerts: [SCNVector3] = []
        var edgeIndices: [CInt] = []
        var pos: CInt = 0
        
        for i in 0...numPerSide {
            // top edge (+y)
            let x = CGFloat(numPerSide-i)*edgeSize
            let y = CGFloat(numPerSide)*edgeSize
            let z = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(y)))
            edgeVerts.append(fromModelSpace(Vector3(x,y,0)))
            edgeVerts.append(fromModelSpace(Vector3(x,y,z)))

            // create indices
            if i < numPerSide {
                edgeIndices.append(pos)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+2)
                
                edgeIndices.append(pos+2)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+3)
            }
            pos += 2
        }
        
        for i in 0...numPerSide {
            // bottom edge (y=0)
            let x = CGFloat(i)*edgeSize
            let y = CGFloat(0)*edgeSize
            let z = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(y)))
            edgeVerts.append(fromModelSpace(Vector3(x,y,0)))
            edgeVerts.append(fromModelSpace(Vector3(x,y,z)))

            // create indices
            if i < numPerSide {
                edgeIndices.append(pos)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+2)
                
                edgeIndices.append(pos+2)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+3)
            }
            pos += 2
        }
        
        for i in 0...numPerSide {
            // left edge (x=0)
            let x = CGFloat(0)*edgeSize
            let y = CGFloat(numPerSide-i)*edgeSize
            let z = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(y)))
            edgeVerts.append(fromModelSpace(Vector3(x,y,0)))
            edgeVerts.append(fromModelSpace(Vector3(x,y,z)))

            // create indices
            if i < numPerSide {
                edgeIndices.append(pos)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+2)
                
                edgeIndices.append(pos+2)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+3)
            }
            pos += 2
        }
        
        for i in 0...numPerSide {
            // right edge (+x)
            let x = CGFloat(numPerSide)*edgeSize
            let y = CGFloat(i)*edgeSize
            let z = CGFloat(gameModel.getElevation(longitude: Int(x), latitude: Int(y)))
            edgeVerts.append(fromModelSpace(Vector3(x,y,0)))
            edgeVerts.append(fromModelSpace(Vector3(x,y,z)))
            
            // create indices
            if i < numPerSide {
                edgeIndices.append(pos)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+2)
                
                edgeIndices.append(pos+2)
                edgeIndices.append(pos+1)
                edgeIndices.append(pos+3)
            }
            pos += 2
        }
        
        NSLog("\(edgeVerts.count) edge vertices, \(edgeIndices.count) edge indices, pos=\(pos)")

        let edgeElements = SCNGeometryElement(indices: edgeIndices, primitiveType: .triangles)
        let edgeSource = SCNGeometrySource(vertices: edgeVerts)
        let edgeGeometry = SCNGeometry(sources: [edgeSource], elements: [edgeElements])
        
        edgeGeometry.firstMaterial?.diffuse.contents = UIColor.green

        return edgeGeometry
    }
    
    override func updateBoard() {
        NSLog("\(#function) started")
        
        // (re)create surface
        surface.removeFromParentNode()
        let surfaceShape = surfaceGeometry()
        surface = SCNNode(geometry: surfaceShape)
        board.addChildNode(surface)
        
        // (re)create edges
        edgeNode.removeFromParentNode()
        let edgeShape = edgeGeometry()
        edgeNode = SCNNode(geometry: edgeShape)
        board.addChildNode(edgeNode)
        
        // remove any temporary animation objects
        dropSurface.isHidden = true
        dropSurface.removeFromParentNode()
        if let morpher = surface.morpher {
            morpher.targets = [surface.geometry!]
        }
        
        NSLog("\(#function) finished")
    }
    
    override func animateExplosion(fireResult: FireResult, at: CFTimeInterval) -> CFTimeInterval {
        var adjustedResult = fireResult
        // make explosion slightly larger to obscure terrain modification
        adjustedResult.explosionRadius *= 1.05
        return super.animateExplosion(fireResult: adjustedResult, at: at)
    }
    
    override func animateResult(fireResult: FireResult, from: GameViewController) {
        NSLog("\(#function) started")
        var currTime: CFTimeInterval = 0
        
        currTime = animateShell(fireResult: fireResult, at: currTime)
        currTime = animateExplosion(fireResult: fireResult, at: currTime)
        
        let edgeSize = CGFloat(gameModel.board.boardSize / numPerSide)
        
        // draw dropping surfaces
        var dropVertices0: [SCNVector3] = []
        var dropVertices1: [SCNVector3] = []
        var dropIndices: [CInt] = []
        //var dropNormals: [SCNVector3] = []
        var dropNeeded = false
        for i in 0...numPerSide {
            for j in 0...numPerSide {
                let xArr = [CGFloat(i)*edgeSize, CGFloat(i)*edgeSize, CGFloat(i+1)*edgeSize, CGFloat(i+1)*edgeSize]
                let yArr = [CGFloat(j)*edgeSize, CGFloat(j+1)*edgeSize, CGFloat(j+1)*edgeSize, CGFloat(j)*edgeSize]
                var currentArr: [CGFloat] = []
                var topArr: [CGFloat] = []
                var middleArr: [CGFloat] = []
                var bottomArr: [CGFloat] = []
                var dropArr: [Bool] = []
                var displaceArr: [Bool] = []
                for k in 0...3 {
                    let x = xArr[k]
                    let y = yArr[k]
                    
                    // get elevations for each vertex
                    let current = gameModel.getElevation(fromMap: fireResult.old, longitude: Int(x), latitude: Int(y))
                    let top = gameModel.getElevation(fromMap: fireResult.top, longitude: Int(x), latitude: Int(y))
                    let middle = gameModel.getElevation(fromMap: fireResult.middle, longitude: Int(x), latitude: Int(y))
                    let bottom = gameModel.getElevation(fromMap: fireResult.bottom, longitude: Int(x), latitude: Int(y))
                    // NSLog("\(#function) i,j: \(i),\(j), k: \(k), current: \(current), top: \(top), middle: \(middle), bottom: \(bottom)")
                    
                    // record elevations for each point
                    currentArr.append(CGFloat(current))
                    topArr.append(CGFloat(top))
                    middleArr.append(CGFloat(middle))
                    bottomArr.append(CGFloat(bottom))
                    
                    // record booleans for different animation conditions
                    dropArr.append(top > middle && middle > bottom)
                    displaceArr.append(bottom != current)
                }
                
                // check for and add complete triangle for dropping portion
                for p in [[0,1,2], [0,2,3]] {
                    
                    // check how many points are dropping
                    var dropIdxs: [Int] = []
                    var noDropIdxs: [Int] = []
                    var displaceIdxs: [Int] = []
                    var noDisplaceIdxs: [Int] = []
                    var neitherIdxs: [Int] = []
                    for idx in p {
                        if dropArr[idx] {
                            dropIdxs.append(idx)
                        } else {
                            noDropIdxs.append(idx)
                        }
                        if displaceArr[idx] {
                            displaceIdxs.append(idx)
                        } else {
                            noDisplaceIdxs.append(idx)
                        }
                        if !dropArr[idx] && !displaceArr[idx] {
                            neitherIdxs.append(idx)
                        }
                    }
                    if dropIdxs.count > 0 {
                        dropNeeded = true
                    }
                    
                    let numDropping = dropIdxs.count
                    let numDisplaced = displaceIdxs.count
                    if numDropping == 3 {
                        // entire triangle is dropping
                        // add both top and middle
                        for k in p {
                            dropVertices0.append(fromModelSpace(Vector3(xArr[k], yArr[k], topArr[k])))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[k], yArr[k],
                                                                           bottomArr[k] + (topArr[k]-middleArr[k]))))
                            dropIndices.append(CInt(dropVertices0.count-1))
                        }
                        for k in p {
                            dropVertices0.append(fromModelSpace(Vector3(xArr[k], yArr[k], middleArr[k])))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[k], yArr[k], bottomArr[k])))
                            dropIndices.append(CInt(dropVertices0.count-1))
                        }
                    } else if numDropping == 2 {
                        // check to see if dropping vertices should be connected
                        let noDrop = noDropIdxs[0]
                        if displaceArr[noDrop] {
                            var index = CInt(dropVertices0.count)

                            // 3rd vertex is unaffected, so attach other two via a triangle
                            // top side
                            for k in dropIdxs {
                                dropVertices0.append(fromModelSpace(Vector3(xArr[k], yArr[k], topArr[k])))
                                dropVertices1.append(fromModelSpace(Vector3(xArr[k], yArr[k],
                                                                               bottomArr[k] + (topArr[k]-middleArr[k]))))
                            }
                            dropVertices0.append(fromModelSpace(Vector3(xArr[noDrop], yArr[noDrop],
                                                                           currentArr[noDrop])))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[noDrop], yArr[noDrop],
                                                                           currentArr[noDrop])))
 
                            // face one
                            dropIndices.append(index)
                            dropIndices.append(index+2)
                            dropIndices.append(index+1)
                            
                            // face two
                            dropIndices.append(index)
                            dropIndices.append(index+1)
                            dropIndices.append(index+2)

                            // bottom side
                            index = CInt(dropVertices0.count)
                            for k in dropIdxs {
                                dropVertices0.append(fromModelSpace(Vector3(xArr[k], yArr[k], middleArr[k])))
                                dropVertices1.append(fromModelSpace(Vector3(xArr[k], yArr[k], bottomArr[k])))
                            }
                            dropVertices0.append(fromModelSpace(Vector3(xArr[noDrop], yArr[noDrop],
                                                                           currentArr[noDrop])))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[noDrop], yArr[noDrop],
                                                                           currentArr[noDrop])))

                            // face one
                            dropIndices.append(index)
                            dropIndices.append(index+2)
                            dropIndices.append(index+1)
                            
                            //face two
                            dropIndices.append(index)
                            dropIndices.append(index+1)
                            dropIndices.append(index+2)
                            
                        } else {
                            // 3rd vertex displaced, so leave unattached.
                            // instead attach four moving vertices (top to middle) via triangles
                            let index = CInt(dropVertices0.count)
                            let idx1 = dropIdxs[0]
                            let idx2 = dropIdxs[1]
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], topArr[idx1])))
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], middleArr[idx1])))
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], topArr[idx2])))
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], middleArr[idx2])))
                            
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1] + (topArr[idx1]-middleArr[idx1]))))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1])))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], bottomArr[idx2] + (topArr[idx2]-middleArr[idx2]))))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], bottomArr[idx2])))
                            
                            // triangle one
                            dropIndices.append(index)
                            dropIndices.append(index+2)
                            dropIndices.append(index+1)
                            
                            // triangle one (other side)
                            dropIndices.append(index)
                            dropIndices.append(index+1)
                            dropIndices.append(index+2)
                            
                            // triangle two
                            dropIndices.append(index)
                            dropIndices.append(index+2)
                            dropIndices.append(index+3)

                            // triangle two (other side)
                            dropIndices.append(index)
                            dropIndices.append(index+3)
                            dropIndices.append(index+2)
                        }
                    } else if numDropping == 1  && numDisplaced == 0 {
                        // check to see if dropping vertex should be connected
                        let idx1 = noDropIdxs[0]
                        let idx2 = noDropIdxs[1]
                        let idx3 = dropIdxs[0]
                        if !displaceArr[idx1] && !displaceArr[idx2] {
                            // two vertices are unaffected, so attach other one via a triangle
                            
                            // add top triangle
                            var index = CInt(dropVertices0.count)
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1])))
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], bottomArr[idx2])))
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx3], yArr[idx3], topArr[idx3])))
                            
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1])))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], bottomArr[idx2])))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx3], yArr[idx3],
                                                                           bottomArr[idx3] + (topArr[idx3]-middleArr[idx3]))))
                            
                            dropIndices.append(index)
                            dropIndices.append(index+2)
                            dropIndices.append(index+1)

                            dropIndices.append(index)
                            dropIndices.append(index+1)
                            dropIndices.append(index+2)

                            // add bottom triangle
                            index = CInt(dropVertices0.count)
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1])))
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], bottomArr[idx2])))
                            dropVertices0.append(fromModelSpace(Vector3(xArr[idx3], yArr[idx3], middleArr[idx3])))
                            
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1])))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], bottomArr[idx2])))
                            dropVertices1.append(fromModelSpace(Vector3(xArr[idx3], yArr[idx3], bottomArr[idx3])))
                            
                            dropIndices.append(index)
                            dropIndices.append(index+2)
                            dropIndices.append(index+1)
                            
                            dropIndices.append(index)
                            dropIndices.append(index+1)
                            dropIndices.append(index+2)

                        } else {
                            // two vertices are displaced, so leave unattached.
                            // this entire case is handled by the deformation of the final surface (i.e. bottom) layer.
                        }
                        
                    } else if numDropping == 1  && numDisplaced == 1 {
                        // one of each type, use new position for displaced vertex, and animate dropping vertex
                        let idx1 = displaceIdxs[0]
                        let idx2 = neitherIdxs[0]
                        let idx3 = dropIdxs[0]
                        
                        // use new position for displaced vertex, and animate dropping vertex
                        // add top triangle
                        var index = CInt(dropVertices0.count)
                        dropVertices0.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1])))
                        dropVertices0.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], bottomArr[idx2])))
                        dropVertices0.append(fromModelSpace(Vector3(xArr[idx3], yArr[idx3], topArr[idx3])))
                        
                        dropVertices1.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1])))
                        dropVertices1.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], topArr[idx2])))
                        dropVertices1.append(fromModelSpace(Vector3(xArr[idx3], yArr[idx3],
                                                                       bottomArr[idx3] + (topArr[idx3]-middleArr[idx3]))))
                        
                        dropIndices.append(index)
                        dropIndices.append(index+2)
                        dropIndices.append(index+1)
                        
                        dropIndices.append(index)
                        dropIndices.append(index+1)
                        dropIndices.append(index+2)

                        // add bottom triangle
                        index = CInt(dropVertices0.count)
                        dropVertices0.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1])))
                        dropVertices0.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], bottomArr[idx2])))
                        dropVertices0.append(fromModelSpace(Vector3(xArr[idx3], yArr[idx3], middleArr[idx3])))
                        
                        dropVertices1.append(fromModelSpace(Vector3(xArr[idx1], yArr[idx1], bottomArr[idx1])))
                        dropVertices1.append(fromModelSpace(Vector3(xArr[idx2], yArr[idx2], bottomArr[idx2])))
                        dropVertices1.append(fromModelSpace(Vector3(xArr[idx3], yArr[idx3], bottomArr[idx3])))
                        
                        dropIndices.append(index)
                        dropIndices.append(index+2)
                        dropIndices.append(index+1)
                        
                        dropIndices.append(index)
                        dropIndices.append(index+1)
                        dropIndices.append(index+2)

                    }
                }
            }
        }
        NSLog("\(dropVertices0.count) drop vertices, \(dropIndices.count) drop indices")
        
        // setup reveal of the new bottom surface
        let bottomGeometry = surfaceGeometry()
        bottomGeometry.firstMaterial = surface.geometry?.firstMaterial
        surface.name = "The Surface"
        surface.morpher = SCNMorpher()
        surface.morpher?.targets = [surface.geometry!, bottomGeometry]
        
        // setup reveal of new edges
        let newEdgeGeometry = edgeGeometry()
        newEdgeGeometry.firstMaterial = edgeNode.geometry?.firstMaterial
        edgeNode.name = "The Edge"
        edgeNode.morpher = SCNMorpher()
        edgeNode.morpher?.targets = [edgeNode.geometry!, newEdgeGeometry]
        
        // add actions to reveal new surface and edges
        let resurfaceActions = [.wait(duration: currTime),
                                SCNAction.customAction(duration: 0, action: {node, time in
                                    if time == 0 && (node.morpher?.targets.count)! >= 2 {
                                        // must used setWeight, array notation will crash
                                        node.morpher?.setWeight(1, forTargetAt: 1)
                                    }
                                })]
        let resurface = SCNAction.sequence(resurfaceActions)
        surface.runAction(resurface)
        let reEdge = SCNAction.sequence(resurfaceActions)
        edgeNode.runAction(reEdge)

        // setup dropping surface
        if dropNeeded {
            // create geometry for surface
            let dropSource0 = SCNGeometrySource(vertices: dropVertices0)
            let dropSource1 = SCNGeometrySource(vertices: dropVertices1)
            let elements = SCNGeometryElement(indices: dropIndices, primitiveType: .triangles)
            let dropGeometry0 = SCNGeometry(sources: [dropSource0], elements: [elements])
            let dropGeometry1 = SCNGeometry(sources: [dropSource1], elements: [elements])
            dropGeometry0.firstMaterial?.diffuse.contents = UIColor.green
            dropGeometry1.firstMaterial?.diffuse.contents = UIColor.green
            dropGeometry0.firstMaterial?.isDoubleSided = true
            dropGeometry1.firstMaterial?.isDoubleSided = true

            // add drop surface to scene
            dropSurface.removeFromParentNode()
            dropSurface = SCNNode(geometry: dropGeometry0)
            dropSurface.isHidden = true
            dropSurface.name = "The Drop Surface"
            dropSurface.morpher = SCNMorpher()
            dropSurface.morpher?.targets = [dropGeometry0, dropGeometry1]
            board.addChildNode(dropSurface)
            
            // animate collapse
            let collapseActions = [.wait(duration: currTime),
                                   .unhide(),
                                   SCNAction.customAction(duration: dropTime, action: {node, time in
                                    if (node.morpher?.targets.count)! >= 2 {
                                        // must used setWeight, array notation will crash
                                        let progress = time/CGFloat(self.dropTime)
                                        node.morpher?.setWeight(pow(progress,2), forTargetAt: 1)
                                    }
                                   })]
            let collapse = SCNAction.sequence(collapseActions)
            dropSurface.runAction(collapse)
        }
        NSLog("drop/bottom surface appear at time \(currTime)")
        if dropNeeded {
            currTime += dropTime
        }
        NSLog("board settled at time \(currTime).")
        
        // deal with round transitions
        currTime = animateRoundResult(fireResult: fireResult, at: currTime)
        
        // wait for animations to end
        let delay = SCNAction.sequence([.wait(duration: currTime)])
        board.runAction(delay,
                        completionHandler: { DispatchQueue.main.async { from.finishTurn() } })
        
        NSLog("\(#function) finished")
    }
    
}
