//
//  ImageBuf.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation
import UIKit

class ImageBuf {
    var width: Int = 0
    var height: Int = 0
    var pixels: [CGFloat] = []
    let noiseLevel: Float = 10
    //let noiseLevel: Float = 0
    
    func setSize(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = [CGFloat](repeating: CGFloat(0), count: width*height)
    }
    
    func getPixel(x: Int, y: Int) -> CGFloat {
        let offset = x + y*width
        guard offset >= 0 && offset < pixels.count else { return 0 }
        guard x < width && x >= 0 else { return 0 }

        return pixels[offset]
    }
    
    func setPixel(x: Int, y: Int, value: Double) {
        setPixel(x: x, y: y, value: CGFloat(value))
    }
 
    func setPixel(x: Int, y: Int, value: CGFloat) {
        let offset = x + y*width
        guard offset >= 0 && offset < pixels.count else { return }
        guard x < width && x >= 0 else { return }

        pixels[offset] = value
    }
    
    func copy(_ source: ImageBuf) {
        width = source.width
        height = source.height
        pixels = source.pixels
    }
    
    func smooth() {
        
    }
    
    // see: http://www.lighthouse3d.com/opengl/terrain/index.php?mpd2
    
    func isPowerOfTwo(_ number: Int) -> Bool {
        return (number&(number-1)) == 0
    }
    
    // see: https://en.wikipedia.org/wiki/Diamond-square_algorithm
    // also: https://stackoverflow.com/questions/7549883/smoothing-issue-with-diamond-square-algorithm
    func doDiamondSquare() {
        guard isPowerOfTwo(width-1) else { return }
        guard isPowerOfTwo(height-1) else { return }

        NSLog("\(#function) started")

        // randomly assign corners
        setPixel(x: 0, y: 0, value: drand48() * Double(noiseLevel) - Double(0.5 * noiseLevel))
        setPixel(x: 0, y: height-1, value: drand48() * Double(noiseLevel) - Double(0.5 * noiseLevel))
        setPixel(x: width-1, y: 0, value: drand48() * Double(noiseLevel) - Double(0.5 * noiseLevel))
        setPixel(x: width-1, y: height-1, value: drand48() * Double(noiseLevel) - Double(0.5 * noiseLevel))

        // make recursive call
        doDiamondSquare(left: 0, right: width-1, top: 0, bottom: height-1)
        
        NSLog("\(#function) finished")

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
    
    enum DiamondSquare {
        case diamond, square
    }
    
    func diamondSquareStep(x: Int, y: Int, size: Int, mode: DiamondSquare) {
        var sum: CGFloat = 0.0
        var count = 0
        //var values: [Float] = []

        var pattern: [[Int]] = []
        switch mode {
        case .diamond:
            pattern = [[-1, -1], [1,-1], [-1,1], [1,1]]
        case .square:
            pattern = [[0, -1], [-1, 0], [0, 1], [1,0]]
        }
        // check for already computed values
        let curr = getPixel(x: x, y: y)
        if curr != 0 {
            return
        }
        
        for offsets in pattern {
            let nx = x + size * offsets[0]
            let ny = y + size * offsets[1]
            
            guard nx >= 0 else { continue }
            guard nx < width else { continue }
            guard ny >= 0 else { continue }
            guard ny < height else { continue }
            
            let value = getPixel(x: nx, y: ny)
            //values.append(Float(r))
            sum += value
            count += 1
        }
        
        let avg = Double(sum) / Double(count)

        let sizeRatio = 2 * Double(size) / Double(width)
        let randomScale = Double(noiseLevel) * pow(sizeRatio, 1)
        let noise = randomScale * (drand48()*randomScale - randomScale/2)
        //let noise = CGFloat(0)
        let value = avg + noise
        
        setPixel(x: x, y: y, value: CGFloat(value))
    }
    
    func diamondStep(x: Int, y: Int, size: Int) {
        diamondSquareStep(x: x, y: y, size: size, mode: .diamond);
    }

    func squareStep(x: Int, y: Int, size: Int) {
        diamondSquareStep(x: x, y: y, size: size, mode: .square);
    }

    func fillUsingDiamondSquare(withMinimum: Float, andMaximum: Float) {
        NSLog("\(#function) started")

        guard isPowerOfTwo(width-1) else { return }
        guard isPowerOfTwo(height-1) else { return }
        
        // apply diamond-square algorithm
        doDiamondSquare()

        // find min/max values
        var minValue = pixels[0]
        var maxValue = minValue
        for i in 1..<pixels.count {
            let value = pixels[i]
            minValue = (minValue>value) ? value : minValue
            maxValue = (maxValue<value) ? value : maxValue
        }
        NSLog("\(#function): min/max values are \(minValue) and \(maxValue)")
        NSLog("\(#function): requested min/max values are \(withMinimum) and \(andMaximum)")

        // rescale to min/max values
        let min = CGFloat(withMinimum)
        let max = CGFloat(andMaximum)
        if maxValue-minValue >= 0.01 {
            for i in 0..<pixels.count {
                let r = pixels[i]
                
                let normalized = (r-minValue) / (maxValue-minValue)
                let nv = ( normalized * (max-min) ) + min
                //let nv = ( CGFloat(andMaximum - withMinimum) / CGFloat(maxValue-minValue) ) * CGFloat(r-minValue) + CGFloat(withMinimum)
                pixels[i] = nv
            }
        }

        NSLog("\(#function) finished")
    }
    
    func asUIImage() -> UIImage {
        NSLog("\(#function) started")

        // see: http://blog.human-friendly.com/drawing-images-from-pixel-data-in-swift
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, 1);

        NSLog("Converting \(width)x\(height) image to a UIImage.")
        var image = UIImage()
        if let context = UIGraphicsGetCurrentContext() {
            for i in 0 ..< width {
                for j in 0 ..< height {
                    let pixel = getPixel(x: i, y: j)
//                    if pixel > 1.0 {
//                        NSLog("pixel value for \(i),\(j) is \(pixel)")
//                    }
                    context.setFillColor(red: pixel, green: pixel, blue: pixel, alpha: 1.0)

                    context.fill(CGRect(x: CGFloat(i), y: CGFloat(j), width: 1, height: 1))
                }
            }
            
            image = UIGraphicsGetImageFromCurrentImageContext()!;
        }

        UIGraphicsEndImageContext();
        
        NSLog("\(#function) finished")

        return image
    }
}
