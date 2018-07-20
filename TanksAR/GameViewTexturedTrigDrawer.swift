//
//  GameViewTexturedTrigDrawer.swift
//  TanksAR
//
//  Created by Fraggle on 7/12/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation
import SceneKit

class GameViewTexturedTrigDrawer : GameViewTrigDrawer {
   
    var ambientLight = SCNNode()
    var ecliptic = SCNNode()
    var sun = SCNNode()
    
    override func setupLighting() {
        sceneView.autoenablesDefaultLighting = false
        
        // add an ambient light
        ambientLight.removeFromParentNode()
        ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = SCNLight.LightType.ambient
        ambientLight.light!.color = UIColor(white: 0.25, alpha: 1.0)
        board.addChildNode(ambientLight)
        
        // create an eccliptic for repositioning the sun
        ecliptic = SCNNode()
        ecliptic.eulerAngles.x = -Float.pi * (3.0/8.0)
        sceneView.scene.rootNode.addChildNode(ecliptic)
        
        // add the sun
        sun.removeFromParentNode()
        sun = SCNNode()
        let sunLight = SCNLight()
        sunLight.name = "The Sun"
        sunLight.type = .directional
        sunLight.castsShadow = true
        sunLight.temperature = 5900
        // see: https://stackoverflow.com/questions/44975457/does-shadow-for-directional-light-even-work-in-scenekit
        sunLight.orthographicScale = 4000
        sunLight.automaticallyAdjustsShadowProjection = true
        sun.light = sunLight
        // sun.eulerAngles.x = -Float.pi
        //sun.eulerAngles.x = -Float.pi * (3.0/8.0) + 0.001
        // sun.eulerAngles.y = Float.pi
        ecliptic.addChildNode(sun)
        
        // animate direction of the sun
        //let riseAndSet = SCNAction.repeatForever(.rotateBy(x: 0, y: CGFloat(2 * Float.pi), z: 0, duration: 10))
        let riseAndSet = SCNAction.repeatForever(.rotateBy(x: CGFloat(-Float.pi / 4), y: CGFloat(Float.pi / 4), z: 0, duration: 300))
        sun.runAction(riseAndSet)
    }
    
    override func surfaceNode(forSurface: ImageBuf, useNormals: Bool = false, withColors: ImageBuf?, colors: [Any] = [UIColor.green]) -> SCNNode {
        let colorImage = gameModel.colorMap(forMap: withColors!)
        let node = super.surfaceNode(forSurface: forSurface, useNormals: true, withColors: withColors, colors: [colorImage])
        
        // computing the normal map is very very slow, it's also not right
        //let normalMap = gameModel.normalMap(forMap: forSurface)
        //node.geometry.firstMaterial?.normal.contents = normalMap

        return node
    }
    
    func surfaceNode(forSurface: ImageBuf, withColors: ImageBuf) -> SCNNode {
        return self.surfaceNode(forSurface: forSurface, useNormals: true, withColors: withColors, colors: [UIColor.green])
    }
    
    override func updateBoard() {
        NSLog("\(#function) started")
        
        // (re)create ambient light
        // https://www.raywenderlich.com/83748/beginning-scene-kit-tutorial
        ambientLight.removeFromParentNode()
        ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = SCNLight.LightType.ambient
        ambientLight.light!.color = UIColor(white: 0.25, alpha: 1.0)
        board.addChildNode(ambientLight)
        
        // (re)create surface
        surface.removeFromParentNode()
        surface = surfaceNode(forSurface: gameModel.board.surface, useNormals: true, withColors: gameModel.board.colors, colors: [gameModel.colorMap()])
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
        newBottomSurface.isHidden = true
        newBottomSurface.removeFromParentNode()
        
        // make tanks look 'metalic'
        for tank in tankNodes {
            let diffuse = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            let metalness = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
            tank.geometry?.firstMaterial?.diffuse.contents = diffuse
            tank.geometry?.firstMaterial?.metalness.contents = metalness
            if let turret = tank.childNode(withName: "turret", recursively: true) {
                turret.geometry?.firstMaterial?.diffuse.contents = diffuse
                turret.geometry?.firstMaterial?.metalness.contents = metalness
            }
            if let barrel = tank.childNode(withName: "barrel", recursively: true) {
                barrel.geometry?.firstMaterial?.diffuse.contents = diffuse
                barrel.geometry?.firstMaterial?.metalness.contents = metalness
            }
        }
        
        showLights()
        
        NSLog("\(#function) finished")
    }
    
    override func animateResult(fireResult: FireResult, from: GameViewController) {
        super.animateResult(fireResult: fireResult, from: from, useNormals: true, colors: [gameModel.colorMap(forMap: fireResult.topColor)])
    }
    
}
