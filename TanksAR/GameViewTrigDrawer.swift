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
    
    func surfaceNode(forSurface: ImageBuf, useNormals: Bool = false, withColors: ImageBuf?, colors: [Any] = [UIColor.green], isBottom: Bool = false) -> SCNNode {
        
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

//            // for debugging purposes
//            if isBottom {
//                geometry.firstMaterial?.diffuse.contents = UIColor.magenta
//            }
            
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
        
        edgeGeometry.firstMaterial?.diffuse.contents = UIColor.brown

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
        
        // remove all old drop surface(s)
        droppingNode.removeFromParentNode()
        droppingNode = SCNNode()
        board.addChildNode(droppingNode)

        if let morpher = surface.morpher {
            morpher.targets = [surface.geometry!]
        }
        fluidNode.removeFromParentNode()
        
        NSLog("\(#function) finished")
    }
    
    override func animateExplosion(fireResult: FireResult, at: CFTimeInterval, index: Int = 0) -> CFTimeInterval {
        var adjustedResult = fireResult
        // make explosion slightly larger to obscure terrain modification
        adjustedResult.explosionRadius *= 1.05
        return super.animateExplosion(fireResult: adjustedResult, at: at, index: index)
    }
    
    override func animateResult(fireResult: FireResult, from: GameViewController) {
        animateResult(fireResult: fireResult, from: from, useNormals: false, colors: [UIColor.green])
    }
    
    func animateResult(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green]) {

        NSLog("\(#function) started")
        let startTime: CFTimeInterval = 0
        var currTime = startTime
        let timeStep = CFTimeInterval(fireResult.timeStep / Float(timeScaling))

        // prepare for explosion(s)
        explosionsNode.removeFromParentNode()
        explosionsNode = SCNNode()
        board.addChildNode(explosionsNode)
        
        // prepare for dropping bits
        droppingNode.removeFromParentNode()
        droppingNode = SCNNode()
        board.addChildNode(droppingNode)
        
        // animate shells' trajectories
        let (firstImpact, _) = animateShells(fireResult: fireResult, at: currTime)
        currTime = firstImpact

        // create temporary crater caps
        let (combinedBottom, combinedBottomColor) = animateCraterCaps(fireResult: fireResult, from: from, at: startTime)
        
        // setup reveal of the new bottom surface
        newBottomSurface.removeFromParentNode()
        newBottomSurface = surfaceNode(forSurface: combinedBottom,
                                       useNormals: false,
                                       withColors: combinedBottomColor,
                                       colors: colors,
                                       isBottom: true)
        newBottomSurface.isHidden = true
        board.addChildNode(newBottomSurface)
        
        surface.name = "The Surface"
        let revealTime = firstImpact + explosionTime
        let hideOldSurface = SCNAction.sequence([.wait(duration: revealTime),
                                                 .hide()])
        let showNewSurface = SCNAction.sequence([.wait(duration: revealTime),
                                                 .unhide()])
        surface.runAction(hideOldSurface)
        newBottomSurface.runAction(showNewSurface)
        NSLog("new bottom surface revealed at time \(revealTime).")
        
        // setup reveal of new edges
        let newEdgeGeometry = edgeGeometry(forSurface: fireResult.detonationResult[0].bottomBuf)
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

        let weaponStyle = fireResult.weaponStyle
        for index in 0..<fireResult.detonationResult.count {
            let hitTime = timeStep * Double(fireResult.trajectories[index].count)
            
            // board surface animation
            if weaponStyle == .explosive || weaponStyle == .generative || weaponStyle == .mirv {
                let localTime = animateExplosion(fireResult: fireResult, at: hitTime, index: index)
                currTime = max(currTime, animateDropSurface(fireResult: fireResult, from: from, useNormals: useNormals, colors: colors, at: localTime, index: index))
            } else if fireResult.weaponStyle == .mud || fireResult.weaponStyle == .napalm {
                currTime = max(currTime, animateFluidFill(fireResult: fireResult, from: from, at: hitTime, index: index))
            }
            NSLog("projectile \(index): board settled at time \(currTime).")
        }

        // deal with round transitions
        currTime = animateRoundResult(fireResult: fireResult, at: currTime)
        
        // wait for animations to end
        let delay = SCNAction.sequence([.wait(duration: currTime)])
        board.runAction(delay, completionHandler: { DispatchQueue.main.async { from.finishTurn() } })
        
        NSLog("\(#function) finished")
    }
    
    func animateCraterCaps(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green], at time: CFTimeInterval, index: Int = 0) -> (ImageBuf,ImageBuf) {
        NSLog("\(#function) started")
        let timeStep = CFTimeInterval(fireResult.timeStep / Float(timeScaling))
        
        // sort detonations by time
        let sortedDetonations = fireResult.detonationResult.sorted(by: {lhs, rhs in
            return lhs.timeIndex < rhs.timeIndex
        })
        
        // combine bottoms and create caps
//        NSLog("\(#function): combining detonations into single combinedBottom map")
//        let combinedBottom = ImageBuf(fireResult.old)
//        let combinedBottomColor = ImageBuf(fireResult.oldColor)
//        for detination in sortedDetonations {
//            let (xOffset, yOffset) = detination.bottomBuf.getOffset()
//            for j in 0..<detination.bottomBuf.height {
//                for i in 0..<detination.bottomBuf.width {
//                    let old = gameModel.getElevation(fromMap: combinedBottom, longitude: i+xOffset, latitude: j+yOffset)
//                    let bottom = gameModel.getElevation(fromMap: detination.bottomBuf, longitude: i, latitude: j)
//                    if bottom < old {
//                        gameModel.setElevation(forMap: combinedBottom, longitude: i+xOffset, latitude: j+yOffset, to: bottom)
//                        //NSLog("\(#function): \(i),\(j): set bottom to \(bottom)")
//
//                        let bottomColorIdx = gameModel.getColorIndex(forMap: detination.bottomColor, longitude: i, latitude: j)
//                        gameModel.setColorIndex(forMap: combinedBottomColor, longitude: i+xOffset, latitude: j+yOffset, to: bottomColorIdx)
//                    }
//                }
//            }
//        }
//        NSLog("\(#function): combined detinations into single bottom")
        let combinedBottom = sortedDetonations.last!.bottomBuf
        let combinedBottomColor = sortedDetonations.last!.bottomColor

        for k in 0..<sortedDetonations.count {
            NSLog("\t\(#function): handling detonation \(k), timeIndex: \(sortedDetonations[k].timeIndex) -> \(Double(sortedDetonations[k].timeIndex) * timeStep)")
            let detination = sortedDetonations[k]
            
//            if k == 0 {
//                NSLog("no need to cap first crater, but 1..<count will cause an error.")
//                continue
//            }

            // check which vertices need to be included this round
            var vertexChanges = [[Bool]](repeating: [], count: numPerSide+1)
            var numChanged = 0
            for j in 0...numPerSide {
                vertexChanges[j] = [Bool](repeating:false, count: numPerSide+1)
                for i in 0...numPerSide {
                    let x = CGFloat(i)*edgeSize
                    let y = CGFloat(j)*edgeSize

                    let bottom = gameModel.getElevation(fromMap: combinedBottom, longitude: Int(x), latitude: Int(y))
                    let current = gameModel.getElevation(fromMap: detination.bottomBuf, longitude: Int(x), latitude: Int(y))
                    
                    if bottom < current {
                        vertexChanges[j][i] = true
                        NSLog("\(i),\(j): bottom: \(bottom), current: \(current)")
                        numChanged += 1
                    } else {
                        let bottomNormal = gameModel.getNormal(fromMap: combinedBottom, longitude: Int(x), latitude: Int(y))
                        let currentNormal = gameModel.getNormal(fromMap: detination.bottomBuf, longitude: Int(x), latitude: Int(y))
                        if bottomNormal.x != currentNormal.x ||
                            bottomNormal.y != currentNormal.y ||
                            bottomNormal.z != currentNormal.z {
                            vertexChanges[j][i] = true
                            NSLog("\(i),\(j): bottomNormal: \(bottomNormal), currentNormal: \(currentNormal), diff: \(vectorDiff(bottomNormal, currentNormal))")
                            numChanged += 1
                        }
                    }
                }
            }
            NSLog("\t\(#function): finished vertexChanges, (numChanged: \(numChanged))")

            NSLog("\t\(#function): starting surface creation")
            var capVertices: [SCNVector3] = []
            var capTexCoords: [CGPoint] = []
            var capNormals: [SCNVector3] = []
            var capIndices: [[CInt]] = [[CInt]](repeating: [], count: colors.count)
            var pos: CInt = 0
            for i in 0...numPerSide {
                for j in 0...numPerSide {
                    let x = CGFloat(i)*edgeSize
                    let y = CGFloat(j)*edgeSize
                    let z = CGFloat(gameModel.getElevation(fromMap: fireResult.old, longitude: Int(x), latitude: Int(y)))
                    let n = gameModel.getNormal(fromMap: fireResult.old, longitude: Int(x), latitude: Int(y))
                    
                    let modelCoordinates = Vector3(x,y,z)
                    let viewCoordinates = fromModelSpace(modelCoordinates)
                    //NSLog("\(i),\(j) -> model coordinates \(modelCoordinates) -> view coordinates \(viewCoordinates)")
                    
                    capVertices.append(viewCoordinates)
                    capTexCoords.append(toMapSpace(x: x, y: y))
                    capNormals.append(fromModelScale(n))
                    
                    if i < numPerSide && j < numPerSide &&
                        (vertexChanges[j][i] || vertexChanges[j][i+1] || vertexChanges[j+1][i+1]) {
                        let cx = Int(CGFloat(i) * edgeSize + 1.0/3.0 * edgeSize)
                        let cy = Int(CGFloat(j) * edgeSize + 2.0/3.0 * edgeSize)
                        
                        var colorIndex = 0
                        colorIndex = gameModel.getColorIndex(forMap: detination.bottomColor, longitude: cx, latitude: cy) % capIndices.count
                        
                        capIndices[colorIndex].append(pos)
                        capIndices[colorIndex].append(pos+1)
                        capIndices[colorIndex].append(pos+CInt(numPerSide)+2)
                    }
                    
                    if i < numPerSide && j < numPerSide &&
                        (vertexChanges[j][i] || vertexChanges[j+1][i+1] || vertexChanges[j+1][i]) {
                        let cx = Int(CGFloat(i) * edgeSize + 2.0/3.0 * edgeSize)
                        let cy = Int(CGFloat(j) * edgeSize + 1.0/3.0 * edgeSize)
                        
                        var colorIndex = 0
                        colorIndex = gameModel.getColorIndex(forMap: fireResult.oldColor, longitude: cx, latitude: cy) % capIndices.count
                        
                        capIndices[colorIndex].append(pos)
                        capIndices[colorIndex].append(pos+CInt(numPerSide)+2)
                        capIndices[colorIndex].append(pos+CInt(numPerSide)+1)
                    }
                    pos += 1
                    
                }
            }
            for capIndexArr in capIndices {
                NSLog("\t\(#function): \(capIndexArr.count) surface vertices in index")
            }

            // create actual surface
            let capSurfaceNode = SCNNode()
            let capVertexSource = SCNGeometrySource(vertices: capVertices)
            let capTexSource = SCNGeometrySource(textureCoordinates: capTexCoords)
            
            // create geometry for surface
            for i in 0..<colors.count {
                let elements = SCNGeometryElement(indices: capIndices[i], primitiveType: .triangles)
                var sources = [capVertexSource, capTexSource]
                if useNormals {
                    let normalSource = SCNGeometrySource(normals: capNormals)
                    sources.append(normalSource)
                }
                let geometry = SCNGeometry(sources: sources, elements: [elements])
                geometry.firstMaterial?.diffuse.contents = colors[i]
                
                // for debugging purposes
                //geometry.firstMaterial?.diffuse.contents = UIColor.magenta
                
                let coloredNode = SCNNode(geometry: geometry)
                capSurfaceNode.addChildNode(coloredNode)
            }

            // animate appearance/disappearange
            let appearTime = Double(sortedDetonations[k].timeIndex) * timeStep + explosionTime
            var appearActions: [SCNAction] = [.wait(duration: appearTime),
                                            .unhide()]
            NSLog("\t\(#function): crater cap \(k) appears at time \(appearTime)")
            if k < sortedDetonations.count-1 {
                let disappearTime = Double(sortedDetonations[k+1].timeIndex) * timeStep + explosionTime
                let disappearActions: [SCNAction] = [.wait(duration: disappearTime-appearTime),
                                                     .hide(),
                                                     .removeFromParentNode()]
                appearActions.append(contentsOf: disappearActions)
                NSLog("\t\t\tand disappears at time \(disappearTime)")

            }
            capSurfaceNode.isHidden = true
            capSurfaceNode.runAction(SCNAction.sequence(appearActions))

            // add to scene
            droppingNode.addChildNode(capSurfaceNode)
            
            NSLog("\t\(#function): finished with detonation \(k)")
        }
        NSLog("\(#function): finished")

        return (combinedBottom, combinedBottomColor)
    }
    
    func animateDropSurface(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green], at time: CFTimeInterval, index: Int = 0) -> CFTimeInterval {
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
                    let top = gameModel.getElevation(fromMap: fireResult.detonationResult[index].topBuf,
                                                     longitude: Int(x), latitude: Int(y))
                    let middle = gameModel.getElevation(fromMap: fireResult.detonationResult[index].middleBuf,
                                                        longitude: Int(x), latitude: Int(y))
                    let bottom = gameModel.getElevation(fromMap: fireResult.detonationResult[index].bottomBuf,
                                                        longitude: Int(x), latitude: Int(y))
                    let new = gameModel.getElevation(fromMap: fireResult.final,
                                                     longitude: Int(x), latitude: Int(y))
                    // NSLog("\(#function) i,j: \(i),\(j), k: \(k), current: \(current), top: \(top), middle: \(middle), bottom: \(bottom)")
                    
                    if useNormals {
                        // check normals before and after for each vertex
                        let preNorm = gameModel.getNormal(fromMap: fireResult.detonationResult[index].topBuf,
                                                          longitude: Int(x), latitude: Int(y))
                        let postNorm = gameModel.getNormal(fromMap: fireResult.final,
                                                           longitude: Int(x), latitude: Int(y))
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
                    let colorIndex = gameModel.getColorIndex(forMap: fireResult.detonationResult[index].topColor,
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

                    let explosionZ = CGFloat((fireResult.trajectories[index].last?.z)!)
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
                        let z1_0 = gameModel.getElevation(fromMap: fireResult.detonationResult[index].topBuf,
                                                          longitude: Int(x1_0), latitude: Int(y1_0))
                        let v1_0 = Vector3(x1_0, y1_0, CGFloat(z1_0))
                        
                        let x2_0 = xArr[dropIdxs[0]]
                        let y2_0 = yArr[dropIdxs[0]]
                        let z2_0 = gameModel.getElevation(fromMap: fireResult.detonationResult[index].middleBuf,
                                                          longitude: Int(x2_0), latitude: Int(y2_0))
                        let v2_0 = Vector3(x2_0, y2_0, CGFloat(z2_0))
                        
                        let x3_0 = xArr[dropIdxs[1]]
                        let y3_0 = yArr[dropIdxs[1]]
                        let z3_0 = gameModel.getElevation(fromMap: fireResult.detonationResult[index].topBuf,
                                                          longitude: Int(x3_0), latitude: Int(y3_0))
                        let v3_0 = Vector3(x3_0, y3_0, CGFloat(z3_0))
                        
                        let x4_0 = xArr[dropIdxs[1]]
                        let y4_0 = yArr[dropIdxs[1]]
                        let z4_0 = gameModel.getElevation(fromMap: fireResult.detonationResult[index].middleBuf,
                                                          longitude: Int(x4_0), latitude: Int(y4_0))
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
                        let z2_1 = gameModel.getElevation(fromMap: fireResult.detonationResult[index].bottomBuf,
                                                          longitude: Int(x2_1), latitude: Int(y2_1))
                        let v2_1 = Vector3(x2_1, y2_1, CGFloat(z2_1))
                        
                        let x3_1 = xArr[dropIdxs[1]]
                        let y3_1 = yArr[dropIdxs[1]]
                        let z3_1 = gameModel.getElevation(fromMap: fireResult.final, longitude: Int(x3_1), latitude: Int(y3_1))
                        let v3_1 = Vector3(x3_1, y3_1, CGFloat(z3_1))
                        
                        let x4_1 = xArr[dropIdxs[1]]
                        let y4_1 = yArr[dropIdxs[1]]
                        let z4_1 = gameModel.getElevation(fromMap: fireResult.detonationResult[index].bottomBuf,
                                                          longitude: Int(x4_1), latitude: Int(y4_1))
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
                            norm0 = gameModel.getNormal(fromMap: fireResult.detonationResult[index].topBuf,
                                                        longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                            norm1 = gameModel.getNormal(fromMap: fireResult.final, longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                        } else if displaceArr[k] {
                            z0 = bottomArr[k]
                            z1 = bottomArr[k]
                            var norm0surf = fireResult.detonationResult[index].bottomBuf
                            if topArr[k] == bottomArr[k] {
                                // if displacement was upwards (i.e. .generative),
                                // norm0 should be from .top.
                                norm0surf = fireResult.detonationResult[index].topBuf
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
                            norm0 = gameModel.getNormal(fromMap: fireResult.detonationResult[index].middleBuf,
                                                        longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                            norm1 = gameModel.getNormal(fromMap: fireResult.detonationResult[index].bottomBuf,
                                                        longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                        } else if displaceArr[k] {
                            z0 = bottomArr[k]
                            z1 = bottomArr[k]
                            
                            norm0 = gameModel.getNormal(fromMap: fireResult.detonationResult[index].bottomBuf,
                                                        longitude: Int(xArr[k]), latitude: Int(yArr[k]))
                            norm1 = gameModel.getNormal(fromMap: fireResult.detonationResult[index].bottomBuf,
                                                        longitude: Int(xArr[k]), latitude: Int(yArr[k]))
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
                droppingNode.addChildNode(dropSurface)

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
    
    var previousPuddleEnd: Int = 0
    var previousPipeEnd: Int = 0
    var currentZ: Float = 0
    var puddleSet: [Bool] = []
    var bottomFilledTo: [Int:Float] = [:]
    var puddleVertexSource: SCNGeometrySource!
    var puddleTexSource: SCNGeometrySource!
    var puddleNormalSource: SCNGeometrySource!

    func animateFluidFill(fireResult: FireResult, from: GameViewController, useNormals: Bool = false, colors: [Any] = [UIColor.green], at time: CFTimeInterval, index: Int = 0) -> CFTimeInterval {
        var currTime = time
        
        if fireResult.detonationResult[index].fluidPath.count <= 1 {
            NSLog("\(#function): fluid path \(index) too short, giving up.")
            return time
        }
        
        //NSLog("fillRate: \(fillRate), drainRate: \(drainRate)")
        
        // Defnitions:
        // puddle: region between a local maximum and the previous point with the same elevation.
        // drain path: region between a local maximum and the next local minimum.
        
        //NSLog("\(#function) fluid path has length \(fireResult.fluidPath.count), and initial volume of \(fireResult.fluidRemaining[0]).")
        
        // find puddle sets and drain paths (in model space)
        let path = fireResult.detonationResult[index].fluidPath
        let puddles = findPuddles(in: path)

        // initialize variables for tracking animation
        previousPipeEnd = 0
        previousPuddleEnd = 0
        puddleSet = [Bool](repeating: false, count: gameModel.board.boardSize * gameModel.board.boardSize)
        
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

        fluidNode = SCNNode()
        board.addChildNode(fluidNode)
        currentZ = path[0].z
        setupPuddleSurface()
        
        for i in 0..<puddles.count {
            //NSLog("animating puddle \(i+1) of \(puddles.count)")
            let puddle  = puddles[i]

            //animateDrainPath(for: puddle)
            currTime = animateDrainPath(for: puddle, from: fireResult, using: color, at: currTime)
            
            // animate puddle rising
            currTime = animatePuddleRising(for: puddle, from: fireResult, using: color, at: currTime)
        }
        NSLog("fluid filling finished at time \(currTime), \(currTime - time)s to drain volume of \(fireResult.detonationResult[index].fluidRemaining.first!)")
        
        return currTime
    }
    
    func animateDrainPath(for puddle: PuddleInfo, from result: FireResult, using color: UIColor, at time: CFTimeInterval, index: Int = 0) -> CFTimeInterval {
        //NSLog("puddle from \(puddle.start) to \(puddle.end) has area of \(puddle.end - puddle.start), minPos = \(puddle.minPos).")
        let drainRate : Float = 5000
        //let puddleStart = puddle.start
        let path = result.detonationResult[index].fluidPath
        let remaining = result.detonationResult[index].fluidRemaining
        var currTime = time
        let puddleBottom = puddle.minPos
        let drainStart = previousPipeEnd
        
        // animate path from previous puddle's end to current puddle's minPos,
        // but only if the previous puddle doesn't share a bottom point (i.e. it is a different puddle)
        if drainStart < puddleBottom &&
            path[drainStart].z > path[puddleBottom].z {
            //NSLog("\tanimating path from position \(drainStart) to \(puddleBottom).")
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
                        //NSLog("\t\tpuddle minZ = \(puddle.minZ), maxZ = \(puddle.maxZ)")
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
                    let fluidUsed = remaining[drainStart] - remaining[pathPos]
                    let drainTime = min(0.5, Double(fluidUsed / drainRate))
                    //NSLog("\tdrained \(fluidUsed) in \(drainTime) seconds (pipe length: \(pipeLength)).")
                    currTime = pipeStartTime + drainTime
                }
                
                // make sure to hit the end, in the event it would be overshot
                let nextPos = pathPos + pathStep
                if nextPos > puddleBottom && pathPos < puddleBottom {
                    pathPos = puddleBottom
                } else {
                    pathPos += pathStep
                }
                
                previousPipeEnd = pipeEnd
            }
            currentZ = path[puddleBottom].z
        }

        return currTime
    }
    
    func setupPuddleSurface() {
        // populate most of puddle surface sources
        var vertices: [SCNVector3] = []
        var texCoords: [CGPoint] = []
        var normals: [SCNVector3] = []
        var pos: CInt = 0
        let n = Vector3(CGFloat(0),CGFloat(0),CGFloat(1))
        let z = CGFloat(0)
        for i in 0...numPerSide {
            for j in 0...numPerSide {
                
                let x = CGFloat(i)*edgeSize
                let y = CGFloat(j)*edgeSize
                
                let viewCoordinates = fromModelSpace(Vector3(x,y,z))
                vertices.append(viewCoordinates)
                texCoords.append(toMapSpace(x: x, y: y))
                normals.append(fromModelScale(n))
                
                pos += 1
            }
        }
        puddleVertexSource = SCNGeometrySource(vertices: vertices)
        puddleTexSource = SCNGeometrySource(textureCoordinates: texCoords)
        puddleNormalSource = SCNGeometrySource(normals: normals)
    }
    
    func animatePuddleRising(for puddle: PuddleInfo, from result: FireResult, using color: UIColor, at time: CFTimeInterval, index: Int = 0) -> CFTimeInterval {
        let path = result.detonationResult[index].fluidPath
        let remaining = result.detonationResult[index].fluidRemaining
        var currTime = time
        let puddleEnd = puddle.end
        
        var fillRate: Float = 1000
        let maxFillTime: CFTimeInterval = 20
        fillRate = max(fillRate, remaining[0] / Float(maxFillTime))
        
        //let puddleVolume = fireResult.fluidRemaining[puddle.minPos] - fireResult.fluidRemaining[puddle.end]
        //NSLog("\tanimating puddle with volume \(puddleVolume) rising from \(puddle.minZ) to \(puddle.maxZ).")
        // build quick lookup set
        // build dictionary for faster checking for inclusion in puddle
        for i in previousPuddleEnd...puddleEnd {
            let point = path[i]
            let coord = Int(point.y) * gameModel.board.boardSize + Int(point.x)
            puddleSet[coord] = true
        }
        
        // determine triangles to include in puddle surface
        var indices: [CInt] = []
        var pos: CInt = 0
        let nextIJ = [[0,0], [0,edgeSize], [edgeSize,0], [edgeSize,edgeSize]]
        for i in 0...numPerSide {
            for j in 0...numPerSide {
                
                // can't simply change loop bounds, as pos needs to be counted for the final iteration
                if i < numPerSide && j < numPerSide {
                    let x = CGFloat(i)*edgeSize
                    let y = CGFloat(j)*edgeSize
                    
                    // check to see if trigs are needed in puddle set
                    var useTrigs = false
                    for ij in nextIJ {
                        let xij = Int(x + ij[0])
                        let yij = Int(y + ij[1])
                        let coord = yij * gameModel.board.boardSize + xij
                        
                        //NSLog("i,j: \(i),\(j) + nextIJ: \(ij[0]),\(ij[1]) -> coord: \(coord)")
                        if puddleSet[coord] {
                            useTrigs = true
                        }
                    }
                    
                    if useTrigs {
                        indices.append(pos)
                        indices.append(pos+1)
                        indices.append(pos+CInt(numPerSide)+2)
                        
                        indices.append(pos)
                        indices.append(pos+CInt(numPerSide)+2)
                        indices.append(pos+CInt(numPerSide)+1)
                    }
                    
                }
                pos += 1
            }
        }
        //NSLog("\(vertices.count) surface vertices, \(indices.count) surface indices, pos=\(pos)")
        
        // create geometry for puddle surface
        let elements = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let sources: [SCNGeometrySource] = [puddleVertexSource, puddleTexSource, puddleNormalSource]
        let geometry = SCNGeometry(sources: sources, elements: [elements])
        geometry.firstMaterial?.diffuse.contents = color
        let puddleNode = SCNNode(geometry: geometry)
        puddleNode.isHidden = true
        puddleNode.castsShadow = false
        
        // determine start elevation/position and fill time
        var risePos = puddle.minPos
        if let _ = bottomFilledTo[puddle.minPos] {
            risePos = previousPuddleEnd
        }
        bottomFilledTo[puddle.minPos] = path[puddle.end].z
        
        // add a bunch of move(to:duration:) actions for non-linear rise
        var previousRisePos = risePos
        let minRise = max(fillRate / 60, 1)
        puddleNode.position = SCNVector3(0,currentZ,0)
        var fillActions: [SCNAction] = []
        //fillActions.reserveCapacity(Int((path[puddle.end].z - minZ) / minRise)+10)
        fillActions.append(contentsOf: [.wait(duration: currTime),
                                        .unhide()])
        while risePos <= puddle.end {
            if previousRisePos < risePos {
                let fillVolume = remaining[previousRisePos] - remaining[risePos]
                let fillTime = Double(fillVolume / fillRate)
                let nextZ = path[risePos].z
                fillActions.append(contentsOf: [.move(to: SCNVector3(0,nextZ,0), duration: TimeInterval(fillTime))])
                //NSLog("\tfill volume: \(fillVolume) rises from elevation \(currentZ) to \(nextZ), fill time: \(fillTime) (currTime: \(currTime))")
                currTime += fillTime
            }
            currentZ = path[risePos].z
            
            previousRisePos = risePos
            while remaining[previousRisePos] - remaining[risePos] < minRise {
                risePos += 1
                if risePos >= puddle.end {
                    break
                }
            }
        }
        // finish filling, if needed
        if previousRisePos < puddle.end {
            let fillVolume = remaining[previousRisePos] - remaining[puddle.end]
            let fillTime = Double(fillVolume / fillRate)
            fillActions.append(contentsOf: [.move(to: SCNVector3(0,path[puddle.end].z,0), duration: TimeInterval(fillTime))])
            //NSLog("\tfinal fill volume: \(fillVolume), fill time: \(fillTime)")
            currTime += fillTime
        }
        //NSLog("finished series of filling moves, \(fillActions.count) actions.")
        currentZ = path[puddle.end].z
        
        // run animation
        let fillAction = SCNAction.sequence(fillActions)
        puddleNode.runAction(fillAction)
        fluidNode.addChildNode(puddleNode)
        
        // update per puddle info
        previousPuddleEnd = puddleEnd
        previousPipeEnd = puddleEnd

        return currTime
    }
}

