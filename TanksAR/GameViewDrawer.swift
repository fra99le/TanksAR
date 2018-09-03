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

struct PuddleInfo {
    var start: Int = -1
    var end: Int = -1
    var minPos: Int = -1
    var removable = false
    var hideable = false
}

class GameViewDrawer {

    var gameModel: GameModel! = nil
    var sceneView: ARSCNView! = nil
    var board: SCNNode = SCNNode()
    var tankNodes: [SCNNode] = []
    var tankScale: Float = 10
    var numPerSide: Int = 0
    var shellsNode =  SCNNode()
    var explosionsNode = SCNNode()
    var droppingNode = SCNNode()
    var fluidNode: SCNNode = SCNNode()
    var timeScaling: Double = 3
    //var timeScaling: Double = 0.5 // for debugging purposes
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
    
    func animateShells(fireResult: FireResult, at: CFTimeInterval) -> (CFTimeInterval, CFTimeInterval) {
        var currTime = at
        let timeStep = CFTimeInterval(fireResult.timeStep / Float(timeScaling))
        //NSLog("\(#function) started")

        // create shell object
        shellsNode.removeFromParentNode()
        shellsNode = SCNNode()
        board.addChildNode(shellsNode)
        
        // get split time
        var splitIndex = 0
        if fireResult.trajectories.count > 1 {
            var i = 0
            while fireResult.trajectories[0][i].x == fireResult.trajectories[1][i].x &&
                fireResult.trajectories[0][i].y == fireResult.trajectories[1][i].y {
                    i += 1
            }
            splitIndex = i
        }
        let splitTime = timeStep * CFTimeInterval(splitIndex)
        
        var shortestTraj = fireResult.trajectories.first!.count
        var longestTraj = fireResult.trajectories.last!.count
        for i in 0..<fireResult.trajectories.count {
            let trajectory = fireResult.trajectories[i]
            let shell = SCNNode(geometry: SCNSphere(radius: 5))
            
            shortestTraj = min(shortestTraj,trajectory.count)
            longestTraj = max(longestTraj,trajectory.count)

            guard let firstPosition = trajectory.first else { continue }
            
            shell.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
            // convert back to view coordinates
            shell.position = fromModelSpace(firstPosition)
            shell.isHidden = true
            shellsNode.addChildNode(shell)
            
            var appearTime: CFTimeInterval!
            var startPos: Int!
            if i == 0 {
                appearTime = 0
                startPos = 0
            } else {
                appearTime = splitTime
                startPos = splitIndex
            }
            
            // make shell appear
            var shellActions: [SCNAction] = [.wait(duration: appearTime),
                                             .unhide()]
            
            // make shell move
            for j in startPos..<trajectory.count {
                let currPosition = trajectory[j]
                // convert currPostion to AR space
                let arPosition = fromModelSpace(currPosition)
                shellActions.append(contentsOf: [.move(to: arPosition, duration: timeStep)])
            }
            currTime = at + timeStep * CFTimeInterval(trajectory.count)
            shellActions.append(contentsOf: [.hide()])
            let shellAnimation = SCNAction.sequence(shellActions)
            shell.runAction(shellAnimation)
        
            NSLog("shell \(i) landed at time \(currTime).")
        }

        let firstImpact = at + Double(shortestTraj) * timeStep
        let lastImpact = at + Double(longestTraj) * timeStep
        
        //NSLog("\(#function) finished")
        return (firstImpact, lastImpact)
    }
    
    func addTrajectory(trajectory: [Vector3], toNode: SCNNode, color: UIColor) {
        let segments = 20
        NSLog("Started adding trajectory with \(segments) segments")
        if trajectory.count > 2 {
            var prevPos: Vector3 = trajectory.first!
            for i in 1..<segments {
                let newIndex = Int(Float(i) * Float(trajectory.count) / Float(segments))
                let newPos = trajectory[newIndex]
                
                let jointName = "\(i) joint"
                if let joint = toNode.childNode(withName: jointName, recursively: false) {
                    joint.geometry?.firstMaterial?.diffuse.contents = color
                    joint.position = fromModelSpace(newPos)
                } else {
                    NSLog("\(#function): Creating \(jointName)")
                    let joint = SCNNode(geometry: SCNSphere(radius: CGFloat(0.25*tankScale)))
                    joint.geometry?.firstMaterial?.diffuse.contents = color
                    joint.position = fromModelSpace(newPos)
                    joint.name = jointName
                    toNode.addChildNode(joint)
                }
                addCylinder(from: prevPos, to: newPos, toNode: toNode, color: color, named: "\(i) edge")
                prevPos = newPos
            }
            addCylinder(from: prevPos, to: trajectory.last!, toNode: toNode, color: color, named: "final edge")
        }
        NSLog("Finished adding trajectory.")
        
    }
    
    func addCylinder(from: Vector3, to: Vector3, toNode: SCNNode, color: UIColor, named: String = "edge") {
        var cylinder = SCNNode()
        var gimble = SCNNode()
        
        let gimbleName = "\(named) gimble"
        if let gim = toNode.childNode(withName: gimbleName, recursively: false) {
            gimble = gim
        } else {
            NSLog("\(#function): Adding \(gimbleName)")
            gimble.name = gimbleName
            toNode.addChildNode(gimble)
        }
        if let cyl = gimble.childNode(withName: named, recursively: false) {
            cylinder = cyl
        } else {
            NSLog("\(#function): Adding \(named)")
            cylinder.name = named
            gimble.addChildNode(cylinder)
        }
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
        
        gimble.eulerAngles.y = Float.pi - angle2
        
        // get position of cylinder's gimble
        let sum = vectorAdd(to, from)
        let mid = vectorScale(sum, by: 0.5)
        gimble.position = fromModelSpace(mid)
    }
    
    func animateExplosion(fireResult: FireResult, at: CFTimeInterval, index: Int = 0) -> CFTimeInterval {
        var currTime = at

        guard let lastPosition = fireResult.trajectories[index].last else { return currTime }

        let explosion = SCNNode(geometry: SCNSphere(radius: 1))        
        explosion.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
        // convert back to view coordinates
        explosion.position = fromModelSpace(lastPosition)
        explosion.isHidden = true
        explosion.castsShadow = false
        explosionsNode.addChildNode(explosion)
        
        let explosionActions = SCNAction.sequence([.wait(duration: currTime),
                                                   .unhide(),
                                                   .scale(to: CGFloat(fireResult.explosionRadius), duration: explosionTime),
                                                   .scale(to: 0, duration: explosionReceedTime),
                                                   .hide()])
        explosion.runAction(explosionActions)
        
//        // check for tanks that need to be hidden
//        for i in 0..<gameModel.board.players.count {
//            let player = gameModel.board.players[i]
//            if player.hitPoints <= 0 {
//                let tankNode = tankNodes[i]
//                let hideAction = SCNAction.sequence([.wait(duration: currTime+explosionTime),
//                                                     .hide()])
//                tankNode.runAction(hideAction)
//            }
//        }
        
        currTime += explosionTime
        NSLog("\(index): explosion at \(lastPosition) reached maximum radius at time \(currTime) and ended at \(currTime+explosionReceedTime).")
        
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
    
    func combineBottoms(fireResult: FireResult, from: GameViewController) -> (ImageBuf,ImageBuf,[Int]) {

        // sort detonations by time
        let sortedDetonations = fireResult.detonationResult.sorted(by: {lhs, rhs in
            return lhs.timeIndex < rhs.timeIndex
        })

        //NSLog("\(#function): combining detonations into single combinedBottom map")
        var minI: Int = numPerSide
        var maxI: Int = 0
        var minJ: Int = numPerSide
        var maxJ: Int = 0
        let combinedBottom = ImageBuf(fireResult.old)
        let combinedBottomColor = ImageBuf(fireResult.oldColor)
        let margin = 2
        for i in 0..<sortedDetonations.count {
            let detonation = sortedDetonations[i]
            combinedBottom.paste(detonation.bottomBuf)
            combinedBottomColor.paste(detonation.bottomColor)
            //NSLog("\tadded \(detonation.bottomBuf.width)x\(detonation.bottomBuf.height) update to combinedBottom")
            
            // update extents
            minI = min(minI, max(0, min(numPerSide, Int(CGFloat(detonation.minX) / edgeSize) - margin)))
            minJ = min(minJ, max(0, min(numPerSide, Int(CGFloat(detonation.minY) / edgeSize) - margin)))
            maxI = max(maxI, max(0, min(numPerSide, Int(CGFloat(detonation.maxX) / edgeSize) + margin)))
            maxJ = max(maxJ, max(0, min(numPerSide, Int(CGFloat(detonation.maxY) / edgeSize) + margin)))
        }
        //NSLog("\(#function): combined detonations into single bottom")

        return (combinedBottom, combinedBottomColor, [minI,maxI,minJ,maxJ])
    }
    
    func findPuddles(in path: [Vector3]) -> [PuddleInfo] {
        NSLog("\(#function) starting")
        let minPuddleSize = Int(pow(edgeSize,2))
        //let minPuddleSize = -1
        //let minPuddleHeight: Float = 5
        let minPuddleHeight: Float = -1
        
        var previousElevation = path[0].z
        var wasFilling = false
        var puddles: [PuddleInfo] = []
        var puddleStack = Stack<Pair<Int,Float>>()
        var minPosStack = Stack<Pair<Int,Float>>()
        
        NSLog("looking for puddles, path length is \(path.count)")
        for i in 0..<path.count {
            let elevation = path[i].z
            
            if elevation == previousElevation {
                // skip large flat regions when animating drain paths
                // if they're important puddle filling animation will cover them
                continue
            }
            
            if elevation < previousElevation {
                
                // push new elevation/position onto stack
                if wasFilling {
                    puddleStack.push(Pair<Int,Float>(key: i-1, value: previousElevation))
                    minPosStack.push(Pair<Int,Float>(key: i-1, value: previousElevation))
                }
                puddleStack.push(Pair<Int,Float>(key: i, value: elevation))
                minPosStack.push(Pair<Int,Float>(key: i, value: elevation))
                
                // draining
                if wasFilling {
                    wasFilling = false
                    
                    // create new puddle
                    var puddleInfo = PuddleInfo(start: i, end: i-1, minPos: i,
                                                removable: false, hideable: false)
                    
                    // get start and minPos of puddle
                    //NSLog("starting stack search, puddleStack.top.value: \(puddleStack.top!.value),  previousElevation: \(previousElevation)")
                    while puddleStack.count > 0 && puddleStack.top!.value <= previousElevation {
                        //NSLog("looking for elevation \(elevation), at \(puddleStack.top!.value) (pos: \(puddleStack.top!.key)), bottom at \(minPosStack.top!.value) (pos: \(minPosStack.top!.key))")
                        // pop off stack until the top is above current elevation
                        _ = puddleStack.pop()
                        let minPosPair = minPosStack.pop()
                        if minPosStack.count > 0 && minPosPair!.value < minPosStack.top!.value {
                            // replace top of stack with deeper minPos
                            _ = minPosStack.pop()
                            minPosStack.push(minPosPair!)
                        }
                    }
                    if puddleStack.count > 0 {
                        //NSLog("found elevation \(elevation), at \(puddleStack.top!.value) (pos: \(puddleStack.top!.key)), bottom at \(minPosStack.top!.value) (pos: \(minPosStack.top!.key))")
                        
                        puddleInfo.start = puddleStack.top!.key + 1
                        puddleInfo.minPos = minPosStack.top!.key
                    } else {
                        //NSLog("gave up looking for elevation \(elevation), puddleStack empty (\(puddleStack.count))")
                        puddleInfo.start = 0
                        puddleInfo.minPos = 0
                        if let lastPuddle = puddles.last {
                            // since stack is empty, were climbing out of the previous (first?) puddle
                            puddleInfo.start = lastPuddle.start
                            puddleInfo.minPos = lastPuddle.minPos
                        }
                    }
                    
                    puddles.append(puddleInfo)
                }
            } else {
                // filling
                wasFilling = true
            }
            
            previousElevation = elevation
        }
        NSLog("\(#function): \(puddles.count) puddle sets")
        
        // filter puddles so "strictly" overlapping puddles are eliminated
        NSLog("starting to filter \(puddles.count) puddles")
        // remove all tiny puddles
        var i = 0
        while i < puddles.count
            && puddles.count > 1 {
                //find super small puddles
                let puddle = puddles[i]
                let puddleSize = puddle.end - puddle.start
                let puddleHeight = path[puddle.end].z - path[puddle.minPos].z
                if  puddleSize <  minPuddleSize
                    || puddleHeight < minPuddleHeight {
                    puddles.remove(at: i)
                    continue
                }
                i += 1
        }
        NSLog("\(puddles.count) puddles remaining after small puddle filtering")
        
        for i in 0..<(puddles.count-1) {
            let puddle = puddles[i]
            let puddleBottom = puddle.minPos
            
            let nextPuddle = puddles[i+1]
            let nextPuddleBottom = nextPuddle.minPos
            
            // whenever puddle_{i+1} is has the same buttom, mark puddle_i for removal
            // if size increase is big enough, puddle_{i+1) will have a different bottom
            if puddleBottom == nextPuddleBottom {
                puddles[i].removable = true
            }
        }
        
        // remove tagged puddles
        i = 0
        while i < puddles.count {
            if puddles[i].removable {
                puddles.remove(at: i)
                continue
            }
            i += 1
        }
        NSLog("\(puddles.count) puddles remaining after filtering")
        
        NSLog("\(#function) finished")
        
        return puddles
    }
}
