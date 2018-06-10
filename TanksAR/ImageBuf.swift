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
        pixels = [Pixel](repeating: Pixel(r: 1, g: 1, b: 1, a: 1), count: width*height)
    }
    
    func getPixel(x: Int, y: Int) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let offset = x + y*width
        guard offset >= 0 && offset < pixels.count else { return (0,0,0,0) }
        
        let pixel = pixels[offset]
        let r = pixel.r
        let g = pixel.g
        let b = pixel.b
        let a = pixel.a
        
//        NSLog("getPixel(\(x),\(y)) -> \(r),\(g),\(b),\(a)")
        return (r, g, b, a)
    }
    
    func setPixel(x: Int, y: Int, r: Double, g: Double, b: Double, a: Double) {
        setPixel(x: x, y: y, r: CGFloat(r), g: CGFloat(g), b: CGFloat(b), a: CGFloat(a))
    }
 
    func setPixel(x: Int, y: Int, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let offset = x + y*width
        guard offset >= 0 && offset < pixels.count else { return }

//        NSLog("setPixel(\(x),\(y)) <- \(r),\(g),\(b),\(a)")

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
        guard isPowerOfTwo(width-1) else { return }
        guard isPowerOfTwo(height-1) else { return }

        // randomly assign corners
        setPixel(x: 0, y: 0, r: drand48(), g: 0, b: 0, a: 1.0)
        setPixel(x: 0, y: height-1, r: drand48(), g: 0, b: 0, a: 1.0)
        setPixel(x: width-1, y: 0, r: drand48(), g: 0, b: 0, a: 1.0)
        setPixel(x: width-1, y: height-1, r: drand48(), g: 0, b: 0, a: 1.0)

        // make recursive call
        doDiamondSquare(x1: 0, y1: 0, x2: width-1, y2: height-1)
    }
    
    func doDiamondSquare(x1: Int, y1: Int, x2: Int, y2: Int) {
        if (x2-1) <= x1 || (y2-1) <= y1 { return }
        
        // compute center location
        let xc = (x1 + x2) / 2
        let yc = (y1 + y2) / 2
        let size = xc - x1
//        if size > 200 {
//            NSLog("center of \(x1),\(y1) and \(x2),\(y2) is \(xc),\(yc)")
//        } else {
//            NSLog("Returning for debugging purposes")
//            return
//        }
        
        // compute center (diamond step)
        diamondStep(x: xc, y: yc, size: size)
        
        // compute edge centers (square step)
        squareStep(x: xc, y: y1, size: size)
        squareStep(x: x1, y: yc, size: size)
        squareStep(x: xc, y: y2, size: size)
        squareStep(x: x2, y: yc, size: size)
        
        // perform recursions
        doDiamondSquare(x1: x1, y1: y1, x2: xc, y2: yc)
        doDiamondSquare(x1: xc, y1: y1, x2: x2, y2: yc)
        doDiamondSquare(x1: x1, y1: yc, x2: xc, y2: y2)
        doDiamondSquare(x1: xc, y1: yc, x2: x2, y2: y2)
    }
    
    func diamondSquareStep(x: Int, y: Int, size: Int, pattern: [[Int]]) {
        var sum: CGFloat = 0.0
        var count = 0
        let randomScale = CGFloat(size) / CGFloat(width)

        for offsets in pattern {
            let x = x + size * offsets[0]
            let y = y + size * offsets[1]
            
//            NSLog("trying to sample \(x),\(y)")
            guard x >= 0 else { continue }
            guard x < width else { continue }
            guard y >= 0 else { continue }
            guard y < height else { continue }
            
            let (red: r, green: _, blue: _, alpha: _) = getPixel(x: x, y: y)
            sum += r
            count += 1
        }
        
        let avg = sum / CGFloat(count)
        let noise = randomScale * CGFloat(drand48()) - (randomScale/2)
        let value = avg + noise
//        NSLog("\(avg) = \(sum) / \(count), noise=\(noise)")
        
        setPixel(x: x, y: y, r: value, g: 0, b: 0, a: value)
    }
    
    func diamondStep(x: Int, y: Int, size: Int) {
        diamondSquareStep(x: x, y: y, size: size,
                    pattern: [[-1, -1], [-1,1], [1,-1], [1,1]]);
    }

    func squareStep(x: Int, y: Int, size: Int) {
        diamondSquareStep(x: x, y: y, size: size,
                    pattern: [[0, -1], [-1,0], [1,0], [0,1]]);
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
