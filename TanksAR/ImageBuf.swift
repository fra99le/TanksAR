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
    
    func getPixel(x: Int, y: Int) -> Pixel {
        let offset = x + y*width
        guard offset >= 0 && offset < pixels.count else { return Pixel(r: 0, g: 0, b: 0, a: 0) }
        guard x < width && x >= 0 else { return Pixel(r: 0, g: 0, b: 0, a: 0) }

        return pixels[offset]
    }
    
    func setPixel(x: Int, y: Int, r: Double, g: Double, b: Double, a: Double) {
        setPixel(x: x, y: y, value: Pixel(r: CGFloat(r), g: CGFloat(g), b: CGFloat(b), a: CGFloat(a)))
    }
 
    func setPixel(x: Int, y: Int, value: Pixel) {
        let offset = x + y*width
        guard offset >= 0 && offset < pixels.count else { return }
        guard x < width && x >= 0 else { return }

        pixels[offset] = value
    }
    
    func copy(_ source: ImageBuf) {
        setSize(width: source.width, height: source.width)
    
        for i in 0..<source.pixels.count {
                pixels[i] = source.pixels[i]
        }
    }
    
    func isPowerOfTwo(_ number: Int) -> Bool {
        return (number&(number-1)) == 0
    }
    
    // see: https://en.wikipedia.org/wiki/Diamond-square_algorithm
    // also: https://stackoverflow.com/questions/7549883/smoothing-issue-with-diamond-square-algorithm
    func doDiamondSquare() {
        guard isPowerOfTwo(width-1) else { return }
        guard isPowerOfTwo(height-1) else { return }

        // randomly assign corners
        setPixel(x: 0, y: 0, r: drand48(), g: 0, b: 0, a: 1.0)
        setPixel(x: 0, y: height-1, r: drand48(), g: 0, b: 0, a: 1.0)
        setPixel(x: width-1, y: 0, r: drand48(), g: 0, b: 0, a: 1.0)
        setPixel(x: width-1, y: height-1, r: drand48(), g: 0, b: 0, a: 1.0)

        // make recursive call
        doDiamondSquare(left: 0, right: width-1, top: 0, bottom: height-1)
    }
    
    func doDiamondSquare(left: Int, right: Int, top: Int, bottom: Int) {
        if (right-1) <= left || (bottom-1) <= top { return }
        
        // compute center location
        let centerX = (left + right) / 2
        let centerY = (top + bottom) / 2
        let size = centerX - left
        
        // compute center (diamond step)
        diamondStep(x: centerX, y: centerY, size: size)
        
        // compute edge centers (square step)
        squareStep(x: centerX, y: top, size: size) // top
        squareStep(x: left, y: centerY, size: size) // left
        squareStep(x: centerX, y: bottom, size: size) // bottom
        squareStep(x: right, y: centerY, size: size) // right
        
        // perform recursions
        doDiamondSquare(left: left, right: centerX, top: top, bottom: centerY) // upper left
        doDiamondSquare(left: centerX, right: right, top: top, bottom: centerY) // upper left
        doDiamondSquare(left: left, right: centerX, top: centerY, bottom: bottom) // lower left
        doDiamondSquare(left: centerX, right: right, top: centerY, bottom: bottom) // lower right
    }
    
    func median(of: [Float]) -> Float {
        let sorted = of.sorted()

        let middle = sorted.count/2
        if sorted.count % 2 == 0 {
            return (sorted[middle]+sorted[middle+1])/2
        } else {
            return sorted[middle]
        }
    }
    
    func diamondSquareStep(x: Int, y: Int, size: Int, pattern: [[Int]]) {
        var sum: CGFloat = 0.0
        var count = 0
        //var values: [Float] = []

        for offsets in pattern {
            let nx = x + size * offsets[0]
            let ny = y + size * offsets[1]
            
            guard nx >= 0 else { continue }
            guard nx < width else { continue }
            guard ny >= 0 else { continue }
            guard ny < height else { continue }
            
            let r = getPixel(x: nx, y: ny).r
            //values.append(Float(r))
            sum += r
            count += 1
        }
        
        let avg = sum / CGFloat(count)

        let randomScale = CGFloat(size) / CGFloat(width)
        let noise = randomScale * CGFloat(drand48()) - (randomScale/2)
        //let noise = CGFloat(0)
        let value = avg + noise
        //let value = CGFloat(median(of: values)) + noise
        
        setPixel(x: x, y: y, value: Pixel(r: value, g: 0, b: 0, a: value))
    }
    
    func diamondStep(x: Int, y: Int, size: Int) {
        diamondSquareStep(x: x, y: y, size: size,
                    pattern: [[-1, -1], [1,-1], [-1,1], [1,1]]);
    }

    func squareStep(x: Int, y: Int, size: Int) {
        diamondSquareStep(x: x, y: y, size: size,
                    pattern: [[0, -1], [-1, 0], [0, 1], [1,0]]);
    }

    func fillUsingDiamondSquare(withMinimum: Float, andMaximum: Float) {
        guard isPowerOfTwo(width-1) else { return }
        guard isPowerOfTwo(height-1) else { return }
        
        // apply diamond-square algorithm
        doDiamondSquare()

        // find min/max values
        let pixel = getPixel(x: 0, y: 0)
        var minValue = pixel.r
        var maxValue = pixel.r
        for i in 0..<pixels.count {
            let r = pixels[i].r
            minValue = (minValue>r) ? r : minValue
            maxValue = (maxValue<r) ? r : maxValue
        }

        // rescale to min/max values
        if maxValue-minValue >= 1 &&
            minValue<CGFloat(withMinimum) &&
            maxValue>CGFloat(andMaximum) {
            for i in 0..<pixels.count {
                let r = pixels[i].r
                
                let nv = ( CGFloat(andMaximum - withMinimum) / CGFloat(maxValue-minValue) ) * CGFloat(r-minValue) + CGFloat(withMinimum)
                pixels[i] = Pixel(r: nv, g: 0, b: 0, a: nv)
            }
        }
    }
    
    func asUIImage() -> UIImage {
        // see: http://blog.human-friendly.com/drawing-images-from-pixel-data-in-swift
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, 1);

        NSLog("Converting \(width)x\(height) image to a UIImage.")
        var image = UIImage()
        if let context = UIGraphicsGetCurrentContext() {
            for i in 0 ..< width {
                for j in 0 ..< height {
                    let pixel = getPixel(x: i, y: j)

                    context.setFillColor(red: pixel.r, green: pixel.g, blue: pixel.b, alpha: pixel.a)

                    context.fill(CGRect(x: CGFloat(i), y: CGFloat(j), width: 1, height: 1))
                }
            }
            
            image = UIGraphicsGetImageFromCurrentImageContext()!;
        }

        UIGraphicsEndImageContext();
        
        return image
    }
}
