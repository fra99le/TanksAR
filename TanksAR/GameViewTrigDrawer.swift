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
    var newBottomSurface = SCNNode()
    var dropSurfaces: [SCNNode] = []
    var fluidNode: SCNNode = SCNNode()
    var edgeNode = SCNNode()
    var normalSampleDist = 10
    
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
    
    func surfaceNode() -> SCNNode {
        return surfaceNode(useNormals: false)
    }

    func surfaceNode(useNormals: Bool = false) -> SCNNode {
        return surfaceNode(forSurface: gameModel.board.surface, useNormals: useNormals, withColors: gameModel.board.colors)
    }
    
    func surfaceNode(forSurface: ImageBuf, useNormals: Bool = false, withColors: ImageBuf?, colors: [Any] = [UIColor.green]) -> SCNNode {
        
        // draw board surface
        var vertices: [SCNVector3] = []
        var texCoords: [CGPoint] = []
        var normals: [SCNVector3] = []
        var indices: [[CInt]] = [[CInt]](repeating: [], count: colors.count)
        var pos: CInt = 0
        for i in 0...numPerSide {
            for j in 0...numPerSide {
                
                let x = CGFloat(i)*edgeSize
                let y = CGFloat(j)*edgeSize
                let z = CGFloat(gameModel.getElevation(fromMap: forSurface, longitude: Int(x), latitude: Int(y)))
                let n = gameModel.getNormal(fromMap: forSurface, longitude: Int(x), latitude: Int(y))
                
                let modelCoordinates = Vector3(x,y,z)
                let viewCoordinates = fromModelSpace(modelCoordinates)
                //NSLog("\(i),\(j) -> model coordinates \(modelCoordinates) -> view coordinates \(viewCoordinates)")
                
                vertices.append(viewCoordinates)
                texCoords.append(toMapSpace(x: x, y: y))
                normals.append(fromModelScale(n))

                if i < numPerSide && j < numPerSide {
                    let cx = Int(CGFloat(i) * edgeSize + 1.0/3.0 * edgeSize)
                    let cy = Int(CGFloat(j) * edgeSize + 2.0/3.0 * edgeSize)

                    var colorIndex = 0
                    if let colorMap = withColors {
                        colorIndex = gameModel.getColorIndex(forMap: colorMap, longitude: cx, latitude: cy) % indices.count
                    }
                    
                    indices[colorIndex].append(pos)
                    indices[colorIndex].append(pos+1)
                    indices[colorIndex].append(pos+CInt(numPerSide)+2)
                }
                
                if i < numPerSide && j < numPerSide {
                    let cx = Int(CGFloat(i) * edgeSize + 2.0/3.0 * edgeSize)
                    let cy = Int(CGFloat(j) * edgeSize + 1.0/3.0 * edgeSize)
                    
                    var colorIndex = 0
                    if let colorMap = withColors {
                        colorIndex = gameModel.getColorIndex(forMap: colorMap, longitude: cx, latitude: cy) % indices.count
                    }
                    
                    indices[colorIndex].append(pos)
                    indices[colorIndex].append(pos+CInt(numPerSide)+2)
                    indices[colorIndex].append(pos+CInt(numPerSide)+1)
                }
                pos += 1
            }
        }
        NSLog("\(vertices.count) surface vertices, \(indices.count) surface indices, pos=\(pos)")

        // create geometry for surface
        let surfaceNode = SCNNode()
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let texSource = SCNGeometrySource(textureCoordinates: texCoords)

        // create geometry for surface
        for i in 0..<colors.count {
            let elements = SCNGeometryElement(indices: indices[i], primitiveType: .triangles)
            var sources = [vertexSource, texSource]
            if useNormals {
                let normalSource = SCNGeometrySource(normals: normals)
                sources.append(normalSource)
            }
            let geometry = SCNGeometry(sources: sources, elements: [elements])
            geometry.firstMaterial?.diffuse.contents = colors[i]
            
            let coloredNode = SCNNode(geometry: geometry)
            surfaceNode.addChildNode(coloredNode)
        }

        return surfaceNode
    }
    
    func edgeGeometry() -> SCNGeometry {
        return edgeGeometry(forSurface: gameModel.board.surface)
    }
    
    func edgeGeometry(forSurface: ImageBuf) -> SCNGeometry {
        // draw board edges and base
        var edgeVerts: [SCNVector3] = []
        var edgeIndices: [CInt] = []
        var pos: CInt = 0
        
        for i in 0...numPerSide {
            // top edge (+y)
            let x = CGFloat(numPerSide-i)*edgeSize
            let y = CGFloat(numPerSide)*edgeSize
            let z = CGFloat(gameModel.getElevation(fromMap: forSurface, longitude: Int(x), latitude: Int(y)))
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
            let z = CGFloat(gameModel.getElevation(fromMap: forSurface, longitude: Int(x), latitude: Int(y)))
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
            let z = CGFloat(gameModel.getElevation(fromMap: forSurface, longitude: Int(x), latitude: Int(y)))
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
            let z = CGFloat(gameModel.getElevation(fromMap: forSurface, longitude: Int(x), latitude: Int(y)))
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
        
        normalSampleDist = gameModel.board.boardSize / (2 * numPerSide)
        NSLog("GameViewTrigDrawer: normalSampleDist: \(normalSampleDist)")
        
        // (re)create surface
        surface.removeFromParentNode()
        surface = surfaceNode()
        board.addChildNode(surface)
        
        // (re)create edges
        edgeNode.removeFromParentNode()
        let edgeShape = edgeGeometry()
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
        fluidNode.removeFromParentNode()
        
        NSLog("\(#function) finished")
    }
    
    override func animateExplosion(fireResult: FireResult, at: CFTimeInterval) -> CFTimeInterval {
        var adjustedResult = fireResult
        // make explosion slightly larger to obscure terrain modification
        adjustedResult.explosionRadius *= 1.05
        return super.animateExplosion(fireResult: adjustedResult, at: at)
    }
    
    override func animateResult(fireResult: FireResult, from: GameViewController) {
        animateResult(fireResult: fireResult, from: from, useNormals: false, colors: [UIColor.green])
    }
    
    func animateResult(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green]) {

        NSLog("\(#function) started")
        var currTime: CFTimeInterval = 0
        
        // explosion
        currTime = animateShell(fireResult: fireResult, at: currTime)
        if fireResult.weaponStyle == .explosive || fireResult.weaponStyle == .generative {
            currTime = animateExplosion(fireResult: fireResult, at: currTime)
        }
        
        // setup reveal of the new bottom surface
        newBottomSurface.removeFromParentNode()
        newBottomSurface = surfaceNode(forSurface: fireResult.bottom, useNormals: false, withColors: fireResult.bottomColor, colors: colors)
        newBottomSurface.isHidden = true
        board.addChildNode(newBottomSurface)
        
        surface.name = "The Surface"
        let hideOldSurface = SCNAction.sequence([.wait(duration: currTime),
                                                 .hide()])
        let showNewSurface = SCNAction.sequence([.wait(duration: currTime),
                                                 .unhide()])
        surface.runAction(hideOldSurface)
        newBottomSurface.runAction(showNewSurface)
        
        // setup reveal of new edges
        let newEdgeGeometry = edgeGeometry(forSurface: fireResult.bottom)
        newEdgeGeometry.firstMaterial = edgeNode.geometry?.firstMaterial
        edgeNode.name = "The Edge"
        edgeNode.morpher = SCNMorpher()
        edgeNode.morpher?.targets = [edgeNode.geometry!, newEdgeGeometry]
        
        // add actions to reveal new surface and edges
        let reEdgeActions = [.wait(duration: currTime),
                             SCNAction.customAction(duration: 0, action: {node, time in
                                if time == 0 && (node.morpher?.targets.count)! >= 2 {
                                    // must used setWeight, array notation will crash
                                    node.morpher?.setWeight(1, forTargetAt: 1)
                                }
                             })]
        let reEdge = SCNAction.sequence(reEdgeActions)
        edgeNode.runAction(reEdge)

        // board surface animation
        if fireResult.weaponStyle == .explosive || fireResult.weaponStyle == .generative {
            currTime = animateDropSurface(fireResult: fireResult, from: from, useNormals: useNormals, colors: colors, at: currTime)
        } else if fireResult.weaponStyle == .mud || fireResult.weaponStyle == .napalm {
            currTime = animateFluidFill(fireResult: fireResult, from: from, at: currTime)
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
    
    func animateDropSurface(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green], at time: CFTimeInterval) -> CFTimeInterval {
        var currTime = time
        
        // for debugging purposes only!
        //        let dropCases = [[3,0,0],
        //                         [0,3,0], // weird
        //                         [0,0,3],
        //                         [2,1,0],
        //                         [2,0,1],
        //                         [1,2,0],
        //                         [0,2,1], // broken (has false, false, false)
        //                         [1,0,2],
        //                         [0,1,2],
        //                         [1,1,1]]
        //        var showOnly = dropCases[gameModel.board.currentRound-1]
        //        NSLog("ROUND \(gameModel.board.currentRound): \(showOnly)")
        

        // draw dropping surfaces
        var dropVertices0: [SCNVector3] = []
        var dropVertices1: [SCNVector3] = []
        var dropNormals0: [SCNVector3] = []
        var dropNormals1: [SCNVector3] = []
        var dropTexCoords: [CGPoint] = []
        var dropIndices: [[CInt]] = [[CInt]](repeating: [], count: colors.count)
        var dropNeeded = false
        for i in 0...numPerSide {
            for j in 0...numPerSide {
                
                // get elevation for all four vertices (i.e. both triangles)
                let xArr = [CGFloat(i)*edgeSize, CGFloat(i)*edgeSize, CGFloat(i+1)*edgeSize, CGFloat(i+1)*edgeSize]
                let yArr = [CGFloat(j)*edgeSize, CGFloat(j+1)*edgeSize, CGFloat(j+1)*edgeSize, CGFloat(j)*edgeSize]
                var currentArr: [CGFloat] = []
                var topArr: [CGFloat] = []
                var middleArr: [CGFloat] = []
                var bottomArr: [CGFloat] = []
                var newArr: [CGFloat] = []
                var dropArr: [Bool] = []
                var displaceArr: [Bool] = []
                var unchangedArr: [Bool] = []
                var normalChanged: [Bool] = []
                for k in 0...3 {
                    let x = xArr[k]
                    let y = yArr[k]
                    
                    // get elevations for each vertex
                    let current = gameModel.getElevation(fromMap: fireResult.old, longitude: Int(x), latitude: Int(y))
                    let top = gameModel.getElevation(fromMap: fireResult.top, longitude: Int(x), latitude: Int(y))
                    let middle = gameModel.getElevation(fromMap: fireResult.middle, longitude: Int(x), latitude: Int(y))
                    let bottom = gameModel.getElevation(fromMap: fireResult.bottom, longitude: Int(x), latitude: Int(y))
                    let new = gameModel.getElevation(fromMap: fireResult.final, longitude: Int(x), latitude: Int(y))
                    // NSLog("\(#function) i,j: \(i),\(j), k: \(k), current: \(current), top: \(top), middle: \(middle), bottom: \(bottom)")
                    
                    if useNormals {
                        // check normals before and after for each vertex
                        let preNorm = gameModel.getNormal(fromMap: fireResult.top, longitude: Int(x), latitude: Int(y))
                        let postNorm = gameModel.getNormal(fromMap: fireResult.final, longitude: Int(x), latitude: Int(y))
                        normalChanged.append(preNorm.x != postNorm.x || preNorm.y != postNorm.y || preNorm.z != postNorm.z)
                    }
                   
                    // record elevations for each point
                    currentArr.append(CGFloat(current))
                    topArr.append(CGFloat(top))
                    middleArr.append(CGFloat(middle))
                    bottomArr.append(CGFloat(bottom))
                    newArr.append(CGFloat(new))
                    
                    // record booleans for different animation conditions
                    let isDropping = top >= middle && middle > bottom
                    let isUnchanged = new == current
                    let isDisplaced = !isDropping && !isUnchanged
                    dropArr.append(isDropping)
                    unchangedArr.append(isUnchanged)
                    displaceArr.append(isDisplaced)
                    
                    // exactly one must be true
                    assert( (isDropping  && !isUnchanged && !isDisplaced)
                            || (!isDropping && isUnchanged && !isDisplaced)
                            || (!isDropping && !isUnchanged && isDisplaced) )
                }
                
                // deal with both sub-triangles
                for p in [[0,1,2], [0,2,3]] {
                    
                    // check how many points are dropping
                    var dropIdxs: [Int] = []
                    var displaceIdxs: [Int] = []
                    var unchangedIdxs: [Int] = []
                    var normChangeIdxs: [Int] = []
                    for idx in p {
                        if dropArr[idx] {
                            dropIdxs.append(idx)
                            dropNeeded = true
                        }
                        if displaceArr[idx] {
                            displaceIdxs.append(idx)
                        }
                        if !dropArr[idx] && !displaceArr[idx] {
                            unchangedIdxs.append(idx)
                        }
                        if useNormals && normalChanged[idx] {
                            normChangeIdxs.append(idx)
                        }
                    }
                    
                    // determine color index
                    let colorX = Int((xArr[p[0]] + xArr[p[1]] + xArr[p[2]]) / 3)
                    let colorY = Int((yArr[p[0]] + yArr[p[1]] + yArr[p[2]]) / 3)
                    let colorIndex = gameModel.getColorIndex(forMap: fireResult.topColor,
                                                             longitude: colorX,
                                                             latitude: colorY) % colors.count
                    
                    let numDropping = dropIdxs.count
                    let numDisplaced = displaceIdxs.count
                    let numUnchanged = unchangedIdxs.count
                    let numNormChanged = normChangeIdxs.count
                    assert (numDropping+numDisplaced+numUnchanged == 3)
                    
                    // enumeration of possible triangles:
                    // (d=drops, i=displaced, u=unchanged)
                    // n: d,i,u
                    // 0: 3,0,0    all drop (easiest drop case)
                    // 1: 0,3,0    newBottomSurface
                    // 2: 0,0,3    nothing happens (except to the normals)
                    // 3: 2,1,0    convert to 3,0,0
                    // 4: 2,0,1    one remains attached
                    // 5: 1,2,0    convert to 3,0,0
                    // 6: 0,2,1    newBottomSurface
                    // 7: 1,0,2    two remain attached
                    // 8: 0,1,2    newBottomSurface
                    // 9: 1,1,1    one of each
                    
                    // for debugging
//                    showOnly = dropCases[2]
//                    //NSLog("MANUALLY SET: \(showOnly)")
//                    if !(numDropping==showOnly[0] && numDisplaced==showOnly[1] && numUnchanged==showOnly[2]) {
//                        //NSLog("SKIPPING \(numDropping),\(numDisplaced),\(numUnchanged)")
//                        continue
//                    }
                    //NSLog("GOT HERE!!!! \(numDropping),\(numDisplaced),\(numUnchanged)")

                    // NOTE: Should try recording a distribution here, so make sure all cases are covered by TestGameModel

                    if numDropping == 0 && (!useNormals || numNormChanged == 0) {
                        // nothing dropping, why animate it?
                        // Unless of course the normals will be affected by nearby points.
                        continue
                    }
                    
                    if numUnchanged == 3 && (!useNormals || numNormChanged == 0) {
                        // 0,0,3
                        // nothing happened, why animate it?
                        // Unless of course the normals will be affected by nearby points.
                        continue
                    }

                    let explosionZ = CGFloat((fireResult.trajectory.last?.z)!)
                    if numDisplaced == 3 && (bottomArr[displaceIdxs[0]] < explosionZ) {
                        // 0,3,0
                        // All changes happen behind the explosion, why animate it?
                        // Unless of course the normals will be affected by nearby points.
                        continue
                    }

                    if (numDropping == 1 && numUnchanged == 2) &&
                        (bottomArr[unchangedIdxs[0]] < explosionZ) {
                        // 1,0,2
                        // this is a detached edge of the dropping surface
                        continue
                    } else if (numDropping == 2 && numUnchanged == 1) &&
                        (bottomArr[unchangedIdxs[0]] < explosionZ) {
                        // 2,0,1
                        
                        // if the unchanged point is above the explosion,
                        // then it is save to attach the dropping points to it.
                        // if the unchanged point is below the dropping one,
                        // it is probably disconnected.
                        
                        // need to cap edge for 2,0,1 case
                        
                        // initial position
                        let x1_0 = xArr[dropIdxs[0]]
                        let y1_0 = yArr[dropIdxs[0]]
                        let z1_0 = gameModel.getElevation(fromMap: fireResult.top, longitude: Int(x1_0), latitude: Int(y1_0))
                        let v1_0 = Vector3(x1_0, y1_0, CGFloat(z1_0))
                        
                        let x2_0 = xArr[dropIdxs[0]]
                        let y2_0 = yArr[dropIdxs[0]]
                        let z2_0 = gameModel.getElevation(fromMap: fireResult.middle, longitude: Int(x2_0), latitude: Int(y2_0))
                        let v2_0 = Vector3(x2_0, y2_0, CGFloat(z2_0))
                        
                        let x3_0 = xArr[dropIdxs[1]]
                        let y3_0 = yArr[dropIdxs[1]]
                        let z3_0 = gameModel.getElevation(fromMap: fireResult.top, longitude: Int(x3_0), latitude: Int(y3_0))
                        let v3_0 = Vector3(x3_0, y3_0, CGFloat(z3_0))
                        
                        let x4_0 = xArr[dropIdxs[1]]
                        let y4_0 = yArr[dropIdxs[1]]
                        let z4_0 = gameModel.getElevation(fromMap: fireResult.middle, longitude: Int(x4_0), latitude: Int(y4_0))
                        let v4_0 = Vector3(x4_0, y4_0, CGFloat(z4_0))
                        
                        let x5_0 = (x2_0 + x4_0) / 2
                        let y5_0 = (y2_0 + y4_0) / 2
                        let z5_0 = (z2_0 + z4_0) / 2
                        let v5_0 = Vector3(x5_0, y5_0, CGFloat(z5_0))
                        
                        let normal0_0 = Vector3(xArr[unchangedIdxs[0]]-x5_0,
                                                yArr[unchangedIdxs[0]]-y5_0,
                                                0)
                        
                        // final position
                        let x1_1 = xArr[dropIdxs[0]]
                        let y1_1 = yArr[dropIdxs[0]]
                        let z1_1 = gameModel.getElevation(fromMap: fireResult.final, longitude: Int(x1_1), latitude: Int(y1_1))
                        let v1_1 = Vector3(x1_1, y1_1, CGFloat(z1_1))
                        
                        let x2_1 = xArr[dropIdxs[0]]
                        let y2_1 = yArr[dropIdxs[0]]
                        let z2_1 = gameModel.getElevation(fromMap: fireResult.bottom, longitude: Int(x2_1), latitude: Int(y2_1))
                        let v2_1 = Vector3(x2_1, y2_1, CGFloat(z2_1))
                        
                        let x3_1 = xArr[dropIdxs[1]]
                        let y3_1 = yArr[dropIdxs[1]]
                        let z3_1 = gameModel.getElevation(fromMap: fireResult.final, longitude: Int(x3_1), latitude: Int(y3_1))
                        let v3_1 = Vector3(x3_1, y3_1, CGFloat(z3_1))
                        
                        let x4_1 = xArr[dropIdxs[1]]
                        let y4_1 = yArr[dropIdxs[1]]
                        let z4_1 = gameModel.getElevation(fromMap: fireResult.bottom, longitude: Int(x4_1), latitude: Int(y4_1))
                        let v4_1 = Vector3(x4_1, y4_1, CGFloat(z4_1))
                        
                        let x5_1 = xArr[unchangedIdxs[0]]
                        let y5_1 = yArr[unchangedIdxs[0]]
                        let z5_1 = gameModel.getElevation(fromMap: fireResult.final, longitude: Int(x5_1), latitude: Int(y5_1))
                        let v5_1 = Vector3(x5_1, y5_1, CGFloat(z5_1))
                        
                        let normal0_1 = gameModel.getNormal(longitude: Int(x1_1), latitude: Int(y1_1))
                        let normal1_1 = gameModel.getNormal(longitude: Int(x3_1), latitude: Int(y3_1))
                        let normal2_1 = gameModel.getNormal(longitude: Int(x5_1), latitude: Int(y5_1))
                        
                        // add vertices
                        let baseIdx = dropVertices0.count
                        dropVertices0.append(fromModelSpace(v1_0))
                        dropVertices0.append(fromModelSpace(v2_0))
                        dropVertices0.append(fromModelSpace(v3_0))
                        dropVertices0.append(fromModelSpace(v4_0))
                        dropVertices0.append(fromModelSpace(v5_0))
                        
                        dropVertices1.append(fromModelSpace(v1_1))
                        dropVertices1.append(fromModelSpace(v2_1))
                        dropVertices1.append(fromModelSpace(v3_1))
                        dropVertices1.append(fromModelSpace(v4_1))
                        dropVertices1.append(fromModelSpace(v5_1))
                        
                        dropNormals0.append(fromModelScale(normal0_0))
                        dropNormals0.append(fromModelScale(normal0_0))
                        dropNormals0.append(fromModelScale(normal0_0))
                        dropNormals0.append(fromModelScale(normal0_0))
                        dropNormals0.append(fromModelScale(normal0_0))
                        
                        dropNormals1.append(fromModelScale(normal0_1))
                        dropNormals1.append(fromModelScale(normal0_1))
                        dropNormals1.append(fromModelScale(normal1_1))
                        dropNormals1.append(fromModelScale(normal1_1))
                        dropNormals1.append(fromModelScale(normal2_1))
                        
                        dropTexCoords.append(toMapSpace(x: xArr[dropIdxs[0]], y: yArr[dropIdxs[0]]))
                        dropTexCoords.append(toMapSpace(x: xArr[dropIdxs[0]], y: yArr[dropIdxs[0]]))
                        dropTexCoords.append(toMapSpace(x: xArr[dropIdxs[1]], y: yArr[dropIdxs[1]]))
                        dropTexCoords.append(toMapSpace(x: xArr[dropIdxs[1]], y: yArr[dropIdxs[1]]))
                        dropTexCoords.append(toMapSpace(x: xArr[unchangedIdxs[0]], y: yArr[unchangedIdxs[0]]))
                        
                        // assign vertices to triangles
                        dropIndices[colorIndex].append(CInt(baseIdx))
                        dropIndices[colorIndex].append(CInt(baseIdx+1))
                        dropIndices[colorIndex].append(CInt(baseIdx+4))
                        
                        dropIndices[colorIndex].append(CInt(baseIdx))
                        dropIndices[colorIndex].append(CInt(baseIdx+4))
                        dropIndices[colorIndex].append(CInt(baseIdx+2))
                        
                        dropIndices[colorIndex].append(CInt(baseIdx+1))
                        dropIndices[colorIndex].append(CInt(baseIdx+3))
                        dropIndices[colorIndex].append(CInt(baseIdx+4))
                        
                        dropIndices[colorIndex].append(CInt(baseIdx+2))
                        dropIndices[colorIndex].append(CInt(baseIdx+4))
                        dropIndices[colorIndex].append(CInt(baseIdx+3))
                        
                        // skip normal triangle creation
                        continue
                    }
                    
                    if (numDropping == 2 && numDisplaced == 1)
                        || (numDropping == 1 && numDisplaced == 2)
                        || (numDropping == 1 && numDisplaced == 1 && numUnchanged == 1) {
                        // 2,1,0 -> 3,0,0
                        // 1,2,0 -> 3,0,0
                        // 1,1,1 -> 2,0,1
                        
                        // rewrite displaced vertices as dropping with middle==top
                        for idx in displaceIdxs {
                            middleArr[idx] = topArr[idx]
                            displaceArr[idx] = false
                            dropArr[idx] = true
                        }
                    }
                    
                    // add top triangle
                    for k in p {
                        var z0 = topArr[k]
                        var z1 = topArr[k]
                        var norm0 = Vector3()
                        var norm1 = Vector3()
                        
                        if dropArr[k] {
                            z0 = topArr[k]
                            z1 = bottomArr[k] + (topArr[k] - middleArr[k])
                            norm0 = gameModel.getNormal(fromMap: fireResult.top, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                            norm1 = gameModel.getNormal(fromMap: fireResult.final, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                        } else if displaceArr[k] {
                            z0 = bottomArr[k]
                            z1 = bottomArr[k]
                            var norm0surf = fireResult.bottom
                            if topArr[k] == bottomArr[k] {
                                // if displacement was upwards (i.e. .generative),
                                // norm0 should be from .top.
                                norm0surf = fireResult.top
                            }
                            norm0 = gameModel.getNormal(fromMap: norm0surf, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                            norm1 = gameModel.getNormal(fromMap: fireResult.final, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                        } else if unchangedArr[k] {
                            z0 = currentArr[k]
                            z1 = newArr[k]
                            norm0 = gameModel.getNormal(fromMap: fireResult.old, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                            norm1 = gameModel.getNormal(fromMap: fireResult.final, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                        } else {
                            NSLog("This is bad (line \(#line)), i,j=\(i),\(j); k=\(k), \(dropArr[k]), \(displaceArr[k]), \(unchangedArr[k])")
                            NSLog("\(currentArr[k]) -> \(topArr[k]) > \(middleArr[k]) > \(bottomArr[k]) -> \(newArr[k])")
                        }

                        var slightOffset0 = Vector3()
                        var slightOffset1 = Vector3()
                        if useNormals && normalChanged[k] {
                            // slightly raise points where normals change, so it doens't interfere with newBottom
                            let offset0 = vectorNormalize(norm0)
                            let offset1 = vectorNormalize(norm1)
                            slightOffset0 = vectorScale(offset0, by: 0.1)
                            slightOffset1 = vectorScale(offset1, by: 0.1)
                        }
                        let vertex0 = vectorAdd(Vector3(xArr[k], yArr[k], z0), slightOffset0)
                        let vertex1 = vectorAdd(Vector3(xArr[k], yArr[k], z1), slightOffset1)
                        dropVertices0.append(fromModelSpace(vertex0))
                        dropVertices1.append(fromModelSpace(vertex1))
                        
                        dropNormals0.append(fromModelScale(norm0))
                        dropNormals1.append(fromModelScale(norm1))
                        
                        dropTexCoords.append(toMapSpace(x: xArr[k], y: yArr[k]))
                        dropIndices[colorIndex].append(CInt(dropVertices0.count-1))
                    }
                    
                    // add middle triangle
                    for k in p {
                        var z0 = middleArr[k]
                        var z1 = middleArr[k]
                        var norm0 = Vector3()
                        var norm1 = Vector3()
                        
                        if dropArr[k] {
                            z0 = middleArr[k]
                            z1 = bottomArr[k]
                            norm0 = gameModel.getNormal(fromMap: fireResult.middle, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                            norm1 = gameModel.getNormal(fromMap: fireResult.bottom, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                        } else if displaceArr[k] {
                            z0 = bottomArr[k]
                            z1 = bottomArr[k]
                            
                            norm0 = gameModel.getNormal(fromMap: fireResult.bottom, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                            norm1 = gameModel.getNormal(fromMap: fireResult.bottom, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                        } else if unchangedArr[k] {
                            z0 = currentArr[k]
                            z1 = newArr[k]
                            norm0 = gameModel.getNormal(fromMap: fireResult.old, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                            norm1 = gameModel.getNormal(fromMap: fireResult.final, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                        } else {
                            NSLog("This is bad (line \(#line)), i,j=\(i),\(j); k=\(k), \(dropArr[k]), \(displaceArr[k]), \(unchangedArr[k])")
                            NSLog("\(currentArr[k]) -> \(topArr[k]) > \(middleArr[k]) > \(bottomArr[k]) -> \(newArr[k])")
                        }
                        
                        dropVertices0.append(fromModelSpace(Vector3(xArr[k], yArr[k], z0)))
                        dropVertices1.append(fromModelSpace(Vector3(xArr[k], yArr[k], z1)))
                        
                        dropNormals0.append(fromModelScale(vectorScale(norm0, by: -1)))
                        dropNormals1.append(fromModelScale(vectorScale(norm1, by: -1)))
                        
                        dropTexCoords.append(toMapSpace(x: xArr[k], y: yArr[k]))
                        dropIndices[colorIndex].append(CInt(dropVertices0.count-1))
                    }
                }
            }
        }

        // setup dropping surface
        if dropNeeded {
            // create geometry for surface
            let dropSource0 = SCNGeometrySource(vertices: dropVertices0)
            let dropSource1 = SCNGeometrySource(vertices: dropVertices1)
            let dropTexSource = SCNGeometrySource(textureCoordinates: dropTexCoords)
            
            // animate collapse
            let collapseActions = [.wait(duration: currTime),
                                   .unhide(),
                                   SCNAction.customAction(duration: dropTime, action: {node, time in
                                    if (node.morpher?.targets.count)! >= 2 {
                                        // must used setWeight(_:forTarget), array notation will crash
                                        let progress = time/CGFloat(self.dropTime)
                                        node.morpher?.setWeight(pow(progress,2), forTargetAt: 1)
                                    }
                                   })
//                                ,
//                                   SCNAction.customAction(duration: dropTime, action: {node, time in
//                                    if (node.morpher?.targets.count)! >= 2 {
//                                        // must used setWeight(_:forTarget), array notation will crash
//                                        let progress = time/CGFloat(self.dropTime)
//                                        node.morpher?.setWeight(1-pow(progress,2), forTargetAt: 1)
//                                    }
//                                   })
            ]
            
            // remove all old drop surface(s)
            for node in dropSurfaces {
                node.removeFromParentNode()
            }
            dropSurfaces.removeAll()
            
            // create new drop surface(s)
            for i in 0..<colors.count {
                let elements = SCNGeometryElement(indices: dropIndices[i], primitiveType: .triangles)
                var sources0 = [dropSource0, dropTexSource]
                var sources1 = [dropSource1, dropTexSource]
                if useNormals {
                    sources0.append(SCNGeometrySource(normals: dropNormals0))
                    sources1.append(SCNGeometrySource(normals: dropNormals1))
                }
                
                let dropGeometry0 = SCNGeometry(sources: sources0, elements: [elements])
                let dropGeometry1 = SCNGeometry(sources: sources1, elements: [elements])
                dropGeometry0.firstMaterial?.diffuse.contents = colors[i]
                dropGeometry1.firstMaterial?.diffuse.contents = colors[i]
                dropGeometry0.firstMaterial?.isDoubleSided = true
                dropGeometry1.firstMaterial?.isDoubleSided = true

                // for debugging
//                dropGeometry0.firstMaterial?.diffuse.contents = UIColor.magenta
//                dropGeometry1.firstMaterial?.diffuse.contents = UIColor.magenta

                // add drop surface to scene
                let dropSurface = SCNNode(geometry: dropGeometry0)
                dropSurface.isHidden = true
                dropSurface.name = "Drop Surface \(i)"
                dropSurface.morpher = SCNMorpher()
                dropSurface.morpher?.targets = [dropGeometry0, dropGeometry1]
                board.addChildNode(dropSurface)
                dropSurfaces.append(dropSurface)
                
                let collapse = SCNAction.sequence(collapseActions)
                dropSurface.runAction(collapse)
            }
        }
        NSLog("drop/bottom surface appear at time \(currTime)")
        if dropNeeded {
            currTime += dropTime
            //currTime += dropTime
        }
        
        return currTime
    }
    
    func animateFluidFill(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green], at time: CFTimeInterval) -> CFTimeInterval {
        var currTime = time
        let fillRate: Float = 1000
        
        // Defnitions:
        // puddle: region between a local maximum and the previous point with the same elevation.
        // drain path: region between a local maximum and the next local minimum.
        
        //NSLog("\(#function) fluid path has length \(fireResult.fluidPath.count), and initial volume of \(fireResult.fluidRemaining[0]).")
        
        var puddles: [PuddleInfo] = []
        let minPuddleSize = Int(pow(edgeSize,2))
        //let minPuddleSize = -1
        let minPuddleHeight: Float = 5
        //let minPuddleHeight: Float = -1

        // find puddle sets and drain paths (in model space)
        let path = fireResult.fluidPath
        var previousElevation = path[0].z
        var wasFilling = false
        for i in 0..<path.count {
            let elevation = path[i].z
            
            if elevation == previousElevation {
                // skip large flat regions when animating drain paths
                // if they're important puddle filling animation will cover them
                continue
            }
            
            if elevation < previousElevation {
                // draining
                if wasFilling {
                    wasFilling = false

                    // create new puddle
                    var puddleInfo = PuddleInfo(start: i, end: i-1, minPos: i,
                                                minZ: elevation, maxZ: previousElevation)

                    // scan back to previous point with same elevation
                    var searchStartPos = i - 1
                    if let lastPuddle = puddles.last,
                        previousElevation > lastPuddle.maxZ {
                        // expanding on puddle
                        // jump to previous puddle's entry point
                        searchStartPos = lastPuddle.start + 1
                        puddleInfo.minPos = lastPuddle.minPos
                        puddleInfo.minZ = lastPuddle.minZ
                    }
                    var pos = searchStartPos - 1
                    while pos >= 0 && path[pos].z <= previousElevation {
                        //NSLog("searching for elevation \(previousElevation), path[\(pos)].z = \(path[pos].z)")
                        if path[pos].z < puddleInfo.minZ {
                            puddleInfo.minZ = path[pos].z
                            puddleInfo.minPos = pos
                        }
                        
                        pos -= 1
                    }
                    puddleInfo.start = pos+1

                    puddles.append(puddleInfo)
                }
            } else {
                // filling
                wasFilling = true
            }

            previousElevation = elevation
        }
        NSLog("\(#function): \(puddles.count) puddle sets")
        
        // animate drain paths and puddles filling
        var color: UIColor!
        if fireResult.weaponStyle == .mud {
            color = UIColor.brown
        } else if fireResult.weaponStyle == .napalm {
            color = UIColor.red
        } else {
            color = UIColor.black
        }
        
        // for debugging purposes
//        color = UIColor.magenta
        
        var previousEnd = 0
        var bottomFilledTo: [Int:Float] = [:]

        fluidNode = SCNNode()
        board.addChildNode(fluidNode)
        var puddleSet: [MapCoordinate:Float] = [:]
        for i in 0..<puddles.count {
            NSLog("animating puddle \(i+1) of \(puddles.count)")
            let puddle  = puddles[i]

            // skip super small puddles
            let puddleSize = puddle.end - puddle.start
            let puddleHeight = puddle.maxZ - puddle.minZ
            if  puddleSize <  minPuddleSize
                || puddleHeight < minPuddleHeight {
                NSLog("skipping small puddle")
                continue
            }

            // check for redundant puddles
            if i+1 < puddles.count {
                let nextPuddle = puddles[i+1]
                if nextPuddle.start <= puddle.start &&
                    nextPuddle.end >= puddle.end {
                    // next puddle covers this one
                    NSLog("skipping redundant puddle (next puddle covers it)")
                    continue
                }
            }

            //NSLog("puddle from \(puddle.start) to \(puddle.end) has area of \(puddle.end - puddle.start), minPos = \(puddle.minPos).")
            //let puddleStart = puddle.start
            let puddleEnd = puddle.end
            let puddleBottom = puddle.minPos
            let drainStart = previousEnd

            // animate path from previous puddle's end to current puddle's minPos,
            // but only if the previous puddle doesn't share a bottom point (i.e. it is a different puddle)
            if drainStart < puddleBottom &&
                path[drainStart].z > path[puddleBottom].z {
                NSLog("\tanimating path from position \(drainStart) to \(puddleBottom).")
                let pathStep = Int(edgeSize)
                var lastPos = drainStart
                var pathPos = drainStart + pathStep
                let pipeStartTime = currTime
                var previousPipeEnd = path[lastPos]
                while pathPos <= puddleBottom {
                    let pipeStart = previousPipeEnd
                    let pipeEnd = path[pathPos]
                    if pipeEnd.z < pipeStart.z {
                        let pipeLength = vectorLength(vectorDiff(pipeEnd, pipeStart))
                        //NSLog("\tadding pipe from \(pipeStart) to \(pipeEnd) length \(pipeLength)")
                        // Note: use excessive length to log additional data about the situation
                        if pipeLength > Float(10*pathStep) {
                            NSLog("\twhile adding pipe from \(pipeStart) to \(pipeEnd) length \(pipeLength)")
                            NSLog("\t\ta long pipe detected")
                            NSLog("\t\tpipe from position \(lastPos) to \(pathPos)")
                            NSLog("\t\talong path from positions \(drainStart) to \(puddleBottom).")
                            NSLog("\t\twhich are points \(path[drainStart]) and \(path[puddleBottom]).")
                            NSLog("\t\tpuddle minZ = \(puddle.minZ), maxZ = \(puddle.maxZ)")
                            for i in -10...10 {
                                NSLog("\t\t\tpath[pathPos\(i>=0 ? "+" : "")\(i)]: \(path[pathPos+i])")
                            }
                        }
                        
                        let appearNode = SCNNode()
                        addCylinder(from: pipeStart, to: pipeEnd, toNode: appearNode, color: color)
                        fluidNode.addChildNode(appearNode)
                        
                        let appearAction = SCNAction.sequence([.wait(duration: currTime),
                                                               .unhide()])
                        appearNode.isHidden = true
                        appearNode.runAction(appearAction)

                        lastPos = pathPos
                        
                        // compute fluid use
                        let fluidUsed = fireResult.fluidRemaining[drainStart] - fireResult.fluidRemaining[pathPos]
                        currTime = pipeStartTime + Double(fluidUsed / fillRate)
                    }
                    
                    pathPos += pathStep
                    previousPipeEnd = pipeEnd
                }
            }
            
            // animate puddle rising
            let puddleVolume = fireResult.fluidRemaining[puddle.minPos] - fireResult.fluidRemaining[puddle.end]
            //NSLog("\tanimating puddle with volume \(puddleVolume) rising from \(puddle.minZ) to \(puddle.maxZ).")
            // build quick lookup set
            // need to build dictionary for faster checking for inclusion in puddle
            for i in previousEnd...puddleEnd {
                let point = path[i]
                let coord = MapCoordinate(x: Int(point.x), y: Int(point.y))
                puddleSet[coord] = point.z
            }
            
            // draw puddle surface
            var vertices: [SCNVector3] = []
            var texCoords: [CGPoint] = []
            var normals: [SCNVector3] = []
            var indices: [CInt] = []
            var pos: CInt = 0
            for i in 0...numPerSide {
                for j in 0...numPerSide {
                    
                    let x = CGFloat(i)*edgeSize
                    let y = CGFloat(j)*edgeSize
                    let z = CGFloat(0)
                    let n = Vector3(CGFloat(0),CGFloat(1),CGFloat(0))
                    
                    let viewCoordinates = fromModelSpace(Vector3(x,y,z))
                    vertices.append(viewCoordinates)
                    texCoords.append(toMapSpace(x: x, y: y))
                    normals.append(fromModelScale(n))

                    // check to see if trigs are needed in puddle set
                    var includeTrig = false
                    for ij in [[0,0], [0,1], [1,0], [1,1]] {
                        let coord = MapCoordinate(x: Int(x + CGFloat(ij[0])*edgeSize),
                                                  y: Int(y + CGFloat(ij[1])*edgeSize))
                        if let _ = puddleSet[coord] {
                            includeTrig = true
                            break
                        }
                    }
                    
                    if i < numPerSide && j < numPerSide &&
                        includeTrig {
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
            //NSLog("\(vertices.count) surface vertices, \(indices.count) surface indices, pos=\(pos)")
            
            // create geometry for puddle surface
            let vertexSource = SCNGeometrySource(vertices: vertices)
            let texSource = SCNGeometrySource(textureCoordinates: texCoords)
            let elements = SCNGeometryElement(indices: indices, primitiveType: .triangles)
            var sources = [vertexSource, texSource]
            if useNormals {
                let normalSource = SCNGeometrySource(normals: normals)
                sources.append(normalSource)
            }
            let geometry = SCNGeometry(sources: sources, elements: [elements])
            geometry.firstMaterial?.diffuse.contents = color
            let puddleNode = SCNNode(geometry: geometry)
            puddleNode.isHidden = true
            
            // determine start elevation/position and fill time
            //var origFillVolume = (fireResult.fluidRemaining[puddleBottom] - fireResult.fluidRemaining[puddleEnd])
            var risePos = puddle.minPos
            if let _ = bottomFilledTo[puddle.minPos] {
                risePos = previousEnd
                //origFillVolume = (fireResult.fluidRemaining[previousEnd] - fireResult.fluidRemaining[puddleEnd])
            }
            bottomFilledTo[puddle.minPos] = puddle.maxZ
            let minZ = path[risePos].z
            
            
            // add a bunch of move(to:duration:) actions for non-linear rise
            var previousRisePos = risePos
            let minRise = max(fillRate / 60, 1)
            puddleNode.position = SCNVector3(0,minZ,0)
            var fillActions: [SCNAction] = []
            //fillActions.reserveCapacity(Int((puddle.maxZ - minZ) / minRise)+10)
            fillActions.append(contentsOf: [.wait(duration: currTime),
                                            .unhide()])
            while risePos <= puddle.end {
                if previousRisePos < risePos {
                    let fillVolume = fireResult.fluidRemaining[previousRisePos] - fireResult.fluidRemaining[risePos]
                    let fillTime = Double(fillVolume / fillRate)
                    let nextZ = path[risePos].z
                    fillActions.append(contentsOf: [.move(to: SCNVector3(0,nextZ,0), duration: TimeInterval(fillTime))])
                    //NSLog("\tfill volume: \(fillVolume), fill time: \(fillTime)")
                    currTime += fillTime
                }
                
                previousRisePos = risePos
                while fireResult.fluidRemaining[previousRisePos] - fireResult.fluidRemaining[risePos] < minRise {
                    risePos += 1
                    if risePos >= puddle.end {
                        break
                    }
                }
            }
            if previousRisePos < risePos {
                let fillVolume = fireResult.fluidRemaining[previousRisePos] - fireResult.fluidRemaining[risePos]
                let fillTime = Double(fillVolume / fillRate)
                fillActions.append(contentsOf: [.move(to: SCNVector3(0,puddle.maxZ,0), duration: TimeInterval(fillTime))])
                //NSLog("\tfinal fill volume: \(fillVolume), fill time: \(fillTime)")
                currTime += fillTime
            }
            //NSLog("\tfill volume: \(origFillVolume), fill time: \(fillTime)")
            //NSLog("finished series of filling moves, \(fillActions.count) actions.")
            
            if i+1 < puddles.count {
                let nextPuddle = puddles[i+1]
                if puddle.minPos == nextPuddle.minPos {
                    // next puddle will superseed this one, so hide it, and remove it
                    let hideActions: [SCNAction] = [.hide(),
                                                    .removeFromParentNode()]
                    fillActions.append(contentsOf: hideActions)
                }
            }
            let fillAction = SCNAction.sequence(fillActions)
            puddleNode.runAction(fillAction)
            fluidNode.addChildNode(puddleNode)
            
            
            // update per puddle info
            previousEnd = puddleEnd
        }
        NSLog("fluid filling finished at time \(currTime), \(currTime - time)s to drain volume of \(fireResult.fluidRemaining.first!)")
        
        return currTime
    }
}

struct PuddleInfo {
    var start: Int = -1
    var end: Int = -1
    var minPos: Int = -1
    var minZ: Float = -1.0
    var maxZ: Float = -1.0
}
