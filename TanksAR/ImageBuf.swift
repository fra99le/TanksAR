//
//  ImageBuf.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation
import UIKit

struct Pixel {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat
}

class ImageBuf {
    var width: Int = 0
    var height: Int = 0
    var pixels: [Pixel] = []
    
    func setSize(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = [Pixel](repeating: Pixel(r: 0, g: 0, b: 0, a: 0), count: width*height)
    }
    
    func getPixel(x: Int, y: Int) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let offset = x + y*width
        
        let pixel = pixels[offset]
        let r = pixel.r
        let g = pixel.g
        let b = pixel.b
        let a = pixel.a
        
        return (r, g, b, a)
    }
    
    func setPixel(x: Int, y: Int, r: Double, g: Double, b: Double, a: Double) {
        setPixel(x: x, y: y, r: CGFloat(r), g: CGFloat(g), b: CGFloat(b), a: CGFloat(a))
    }
 
    func setPixel(x: Int, y: Int, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let offset = x + y*width
        
        let pixel = Pixel(r: r, g: g, b: b, a: a)
        pixels[offset] = pixel
    }
    
    func copy(_ source: ImageBuf) {
        //NSLog("image copy start")
        setSize(width: source.width, height: source.width)
    
        for i in 0..<source.pixels.count {
                pixels[i] = source.pixels[i]
        }
        //NSLog("image copy end")
    }
    
    func isPowerOfTwo(_ number: Int) -> Bool {
        return (number&(number-1)) == 0
    }
    
    // see: https://en.wikipedia.org/wiki/Diamond-square_algorithm
    func doDiamondSquare() {
        // randomly assign corners
        setPixel(x: 0, y: 0, r: drand48(), g: drand48(), b: drand48(), a: 1.0)
        setPixel(x: 0, y: height-1, r: drand48(), g: drand48(), b: drand48(), a: 1.0)
        setPixel(x: width-1, y: 0, r: drand48(), g: drand48(), b: drand48(), a: 1.0)
        setPixel(x: width-1, y: height-1, r: drand48(), g: drand48(), b: drand48(), a: 1.0)

        // make recursive call
        doDiamondSquare(x1: 0,y1: 0, x2: width-1, y2: height-1)
    }
    
    func doDiamondSquare(x1: Int, y1: Int, x2: Int, y2: Int) {
        if (x2-1) <= x1 || (y2-1) <= y1 { return }
        
        let scale = 0.1
        
        // compute center
        let (red: r1, green: _, blue: _, alpha: _) = getPixel(x: x1, y: y1)
        let (red: r2, green: _, blue: _, alpha: _) = getPixel(x: x2, y: y1)
        let (red: r3, green: _, blue: _, alpha: _) = getPixel(x: x1, y: y2)
        let (red: r4, green: _, blue: _, alpha: _) = getPixel(x: x2, y: y2)
        let xc = (x1 + x2) / 2
        let yc = (y1 + y2) / 2
        let sum = (r1+r2+r3+r4)
        let randomAdd = CGFloat(drand48()*scale)
        let average = sum / 4
        let rc = average + randomAdd
        setPixel(x: xc, y: yc, r: rc, g: rc, b: rc, a: 1.0)

        // compute edge centers
        let te = (r1 + rc + r2) / 3.0 + CGFloat(drand48()*scale)
        let le = (r1 + rc + r3) / 3.0 + CGFloat(drand48()*scale)
        let re = (r4 + rc + r2) / 3.0 + CGFloat(drand48()*scale)
        let be = (r3 + rc + r4) / 3.0 + CGFloat(drand48()*scale)
        setPixel(x: xc, y: y1, r: te, g: te, b: te, a: 1.0)
        setPixel(x: x1, y: yc, r: le, g: le, b: le, a: 1.0)
        setPixel(x: x2, y: yc, r: re, g: re, b: re, a: 1.0)
        setPixel(x: xc, y: y2, r: be, g: be, b: be, a: 1.0)

        // perform recursions
        doDiamondSquare(x1: x1, y1: y1, x2: xc, y2: yc)
        doDiamondSquare(x1: xc, y1: y1, x2: x2, y2: yc)
        doDiamondSquare(x1: x1, y1: yc, x2: xc, y2: y2)
        doDiamondSquare(x1: xc, y1: yc, x2: x2, y2: y2)
    }
    
    func normalize() {
        
    }
    
    func fillUsingDiamondSquare(withMinimum: Float, andMaximum: Float) {
        guard isPowerOfTwo(width-1) else { return }
        guard isPowerOfTwo(height-1) else { return }
        
        // apply diamond-square algorithm
        doDiamondSquare()

        // find min/max values
        let (red: r, green: _, blue: _, alpha: _) = getPixel(x: 0, y: 0)
        var minValue = r
        var maxValue = r
        for j in 0..<height {
            for i in 0..<width {
                let (red: r, green: _, blue: _, alpha: _) = getPixel(x: i, y: j)
                minValue = (minValue>r) ? r : minValue
                maxValue = (maxValue<r) ? r : maxValue
            }
        }

        // normalize to min/max values
        if maxValue-minValue >= 1 &&
            minValue<CGFloat(withMinimum) &&
            maxValue>CGFloat(andMaximum) {
            for j in 0..<height {
                for i in 0..<width {
                    let (red: r, green: _, blue: _, alpha: _) = getPixel(x: i, y: j)
                    
                    //let nv = (andMaximum - withMinimum) * (r-minValue) / (maxValue-minValue) + withMinimum
                    let nv = ( CGFloat(andMaximum - withMinimum) / CGFloat(maxValue-minValue) ) * CGFloat(r-minValue) + CGFloat(withMinimum)
                    setPixel(x: i, y: j, r: nv, g: 0, b: 0, a: nv)
                }
            }
        }
    }
    
}
