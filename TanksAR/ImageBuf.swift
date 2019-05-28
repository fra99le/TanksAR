//
//  ImageBuf.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import UIKit

// Note: textured drawer should have slightly noisy green and brown images.

// see: http://blog.human-friendly.com/drawing-images-from-pixel-data-in-swift
struct PixelData {
    var a:UInt8 = 255
    var r:UInt8
    var g:UInt8
    var b:UInt8
}

class ImageBuf : Codable {
    // dimensions of full (uncropped image)
    var width: Int = 0
    var height: Int = 0
    
    // portions contained in this image
    var minX: Int = 0
    var minY: Int = 0
    var maxX: Int = 0
    var maxY: Int = 0
    var isCropped: Bool {
        return minX>0 || minY>0 || maxX<width-1 || maxY<height-1
    }
    
    var pixels: [CGFloat] = []
    var pngBuffer: Data?
    var noiseLevel: Float = 10
    
    init() {
    }
    
    init(_ copyOf: ImageBuf) {
        copy(copyOf)
    }
    
    func setSize(width: Int, height: Int) {
        self.width = width
        self.height = height
        
        minX = 0
        minY = 0
        maxX = width - 1
        maxY = height - 1
        
        pixels = [CGFloat](repeating: CGFloat(0), count: width*height)
    }
    
    func getPixelOffset(_ x: Int, _ y: Int) -> Int? {
        guard x >= minX else { return nil }
        guard y >= minY else { return nil }
        guard x <= maxX else { return nil }
        guard y <= maxY else { return nil }

        let offsetX = x-minX
        let offsetY = y-minY
        let offsetWidth = maxX-minX+1
        
        let offset = offsetY*offsetWidth + offsetX
        return offset
    }

    func getPixel(x: Int, y: Int) -> CGFloat? {
        guard let offset = getPixelOffset(x,y) else { return nil }
        guard offset >= 0 && offset < pixels.count else { return nil }

        return pixels[offset]
    }
    
    func setPixel(x: Int, y: Int, value: Double) {
        setPixel(x: x, y: y, value: CGFloat(value))
    }
 
    func setPixel(x: Int, y: Int, value: CGFloat) {
        guard let offset = getPixelOffset(x,y) else { return }
        guard offset >= 0 && offset < pixels.count else { return }

        pixels[offset] = value
    }
    
    func copy(_ source: ImageBuf) {
        width = source.width
        height = source.height

        minX = source.minX
        minY = source.minY
        maxX = source.maxX
        maxY = source.maxY

        pixels = source.pixels
    }
    
    func differsFrom(_ other: ImageBuf) -> Bool {
        guard other.width == width else {
            NSLog("\(#function): widths differ. (\(width)!=\(other.width))")
            return true
        }
        guard other.height == height else {
            NSLog("\(#function): heights differ. (\(height)!=\(other.height))")
            return true
        }
        
        for j in 0..<height {
            for i in 0..<width {
                let pixel1 = getPixel(x: i, y: j)
                let pixel2 = other.getPixel(x: i, y: j)
                
                if pixel1 != pixel2 {
                    NSLog("\(#function): pixel (\(i),\(j)) differs. (\(pixel1!)!=\(pixel2!))")
                    return true
                }
            }
        }
        
        return false
    }
    
    func crop(_ source: ImageBuf, minX: Int, maxX: Int, minY: Int, maxY: Int) {
        //NSLog("\(#function): cropping region \(minX),\(minY) to \(maxX),\(maxY) from \(source.width)x\(source.height) image")
        self.width = source.width
        self.height = source.height
        
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
        
        pixels = [CGFloat](repeating: CGFloat(0), count: (maxX-minX+1)*(maxY-minY+1))
        
        for j in minY...maxY {
            for i in minX...maxX {
                if let value = source.getPixel(x: i, y: j) {
                    //NSLog("\t\(i),\(j): has value \(value)")
                    setPixel(x: i, y: j, value: value)
                }
            }
        }
        
//        // for debugging purposes
//        let dupe = ImageBuf(source)
//        dupe.paste(self)
//        if dupe.differsFrom(source) {
//            NSLog("\(#function): pasting back to source image failed!")
//        }
    }
    
    func paste(_ source: ImageBuf) {
        //NSLog("\(#function): pasting region \(source.minX),\(source.minY) to \(source.maxX),\(source.maxY) into \(width)x\(height) image")
        for j in source.minY...source.maxY {
            for i in source.minX...source.maxX {
                if let value = source.getPixel(x: i, y: j) {
                    //NSLog("\t\(i),\(j): has value \(value)")
                    setPixel(x: i, y: j, value: value)
                }
            }
        }
    }
    
    func smooth() {
        
    }
    
    func isPowerOfTwo(_ number: Int) -> Bool {
        return (number&(number-1)) == 0
    }
    
    // see: https://en.wikipedia.org/wiki/Diamond-square_algorithm
    // also: https://stackoverflow.com/questions/7549883/smoothing-issue-with-diamond-square-algorithm
    // perhaps: http://www.lighthouse3d.com/opengl/terrain/index.php?mpd2
    func doDiamondSquare(withMinimum: Float = 0, andMaximum: Float = 1) {
        guard isPowerOfTwo(width-1) else { return }
        guard isPowerOfTwo(height-1) else { return }

        NSLog("\(#function) started")

        noiseLevel = andMaximum - withMinimum
        var values: [Float] = []
        var minValue = 2*noiseLevel
        var maxValue = -2*noiseLevel

        // randomly assign corners
        for _ in 0..<5 {
            let value = Float(drand48() * Double(noiseLevel) - Double(0.5 * noiseLevel))
            minValue = min(minValue,value)
            maxValue = max(maxValue,value)
            values.append(value)
        }

        // rescale initial values to cover min-max range
        for i in 0..<5 {
            let newValue = (values[i] - minValue) * (andMaximum - withMinimum) / (maxValue - minValue) + withMinimum
            values[i] = newValue
        }
        NSLog("first five values: \(values) for range (\(withMinimum),\(andMaximum))")
        
        setPixel(x: 0, y: 0, value: CGFloat(values[0]))
        setPixel(x: 0, y: height-1, value: CGFloat(values[1]))
        setPixel(x: width-1, y: 0, value: CGFloat(values[2]))
        setPixel(x: width-1, y: height-1, value: CGFloat(values[3]))
        setPixel(x: width/2, y: height/2, value: CGFloat(values[4]))

        // iterative version
        var size = width-1
        while size > 1 {
            let halfSize = size/2

            // do diamonds
            var j = size / 2
            while j < height {
                var i = size / 2
                while i < width {
                    diamondSquareStep(x: i, y: j, size: halfSize, mode: .diamond)
                    i += size
                }
                j += size
            }

            // do squares
            j = 0
            while j <= (height-size) {
                var i = 0
                while i <= (width-size) {
                    diamondSquareStep(x: i+halfSize, y: j, size: halfSize, mode: .square)
                    diamondSquareStep(x: i, y: j+halfSize, size: halfSize, mode: .square)
                    diamondSquareStep(x: i+halfSize, y: j+size, size: halfSize, mode: .square)
                    diamondSquareStep(x: i+size, y: j+halfSize, size: halfSize, mode: .square)

                    i += size
                }
                j += size
            }

            size /= 2
        }
        
        NSLog("\(#function) finished")

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
        //NSLog("\(#function): x,y = \(x),\(y); size=\(size); mode=\(mode)")
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
        guard let curr = getPixel(x: x, y: y) else { return }
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
            
            let value = getPixel(x: nx, y: ny)!
            //values.append(Float(r))
            sum += value
            count += 1
        }
        
        let avg = Double(sum) / Double(count)

        let sizeRatio = 1 * Double(size) / Double(width)
        let randomScale = Double(noiseLevel) * pow(sizeRatio, 1)
        let noise = drand48()*randomScale - randomScale/2
        //let noise: Double = 0
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
        doDiamondSquare(withMinimum: withMinimum, andMaximum: andMaximum)

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
        if maxValue-minValue >= 0.0001 {
            for i in 0..<pixels.count {
                let r = pixels[i]
                
                let normalized = (r-minValue) / (maxValue-minValue)
                let nv = ( normalized * (max-min) ) + min
                pixels[i] = CGFloat(Int(nv*1_000_000+0.5)) / 1_000_000.0
            }
        }

        NSLog("\(#function) finished")
    }
    
    func valueToRGB(value: CGFloat) -> (r: UInt8, g: UInt8, b: UInt8) {
        let value = Int32(value * 1_000_000)
        let b = UInt8((value / 65536) % 256)
        let g = UInt8((value / 256) % 256)
        let r = UInt8(value % 256)

        return (r,g,b)
    }
    
    func valueFromRGB(r: UInt8, g: UInt8, b: UInt8) -> CGFloat {
        return CGFloat(Int32(b) * 65536 + Int32(g) * 256 + Int32(r)) / 1_000_000.0
    }
    
    func asUIImage() -> UIImage {
        //NSLog("\(#function) started")
        let startTime : CFAbsoluteTime = CFAbsoluteTimeGetCurrent();

        let bitsPerComponent:Int = 8
        let bitsPerPixel:Int = 32
        
        assert(pixels.count == Int(width * height))
        
        // see: http://blog.human-friendly.com/drawing-images-from-pixel-data-in-swift
        var pixelArray = [PixelData](repeating: PixelData(a: 255, r:0, g: 0, b: 0), count: width*height)

        //NSLog("copying data into pixelArray")
        if minX == 0 && minY == 0 && maxX == width-1 && maxY == height-1 {
            //NSLog("\(#function): Converting \(width)x\(height) image, without offsets, to a UIImage using CGDataProvider.")
            for i in 0 ..< pixels.count {
                //let (r, g, b) = valueToRGB(value: CGFloat(pixels[i]))
                let value = Int32(pixels[i] * 1_000_000)
                let b = UInt8((value / 65536) % 256)
                let g = UInt8((value / 256) % 256)
                let r = UInt8(value % 256)
                
                pixelArray[i].r = r
                pixelArray[i].g = g
                pixelArray[i].b = b
                pixelArray[i].a = 255
            }
        } else  {
            //NSLog("\(#function): Converting \(width)x\(height) image, with subimage from \(minX),\(minY) to \(maxX),\(maxY), to a UIImage using CGDataProvider.")
            for j in 0..<height {
                for i in 0..<width {
                    
                    let pixelIndex = i + width * j

                    if let pixelValue = getPixel(x: i, y: j) {
                        let value = Int32(pixelValue * 1_000_000)
                        let b = UInt8((value / 65536) % 256)
                        let g = UInt8((value / 256) % 256)
                        let r = UInt8(value % 256)
                        
                        pixelArray[pixelIndex].r = r
                        pixelArray[pixelIndex].g = g
                        pixelArray[pixelIndex].b = b
                        pixelArray[pixelIndex].a = 255
                    } else  {
                        pixelArray[pixelIndex].r = 0
                        pixelArray[pixelIndex].g = 0
                        pixelArray[pixelIndex].b = 0
                        pixelArray[pixelIndex].a = 0
                    }
                }
            }
        }
        //NSLog("finished copying data to pixelArray")
        
        //var data = pixelArray // Copy to mutable []
        guard let providerRef = CGDataProvider(
            data: NSData(bytes: &pixelArray, length: pixelArray.count * MemoryLayout<PixelData>.size)
            ) else { return UIImage() }
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        let cgim = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: width * (bitsPerPixel / bitsPerComponent),
            space: rgbColorSpace,
            bitmapInfo: bitmapInfo,
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
        
        let image = UIImage(cgImage: cgim!)
        
        //NSLog("\(#function) finished")
        NSLog("\(#function): took " + String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime));
        
        return image
    }

    
    func asPNG() -> Data? {
        return asUIImage().pngData()
    }
    
    func compress() {
        NSLog("\(#function): packing a \(width)x\(height) image")
        pngBuffer = asPNG()
        pixels = []
    }
    
    func uncompress() {
        guard let png = pngBuffer else { return }
        guard let uiImage = UIImage(data: png) else { return }
        guard let image = uiImage.cgImage else { return }
        
        // see: https://gist.github.com/bpercevic/3046ffe2b90a6cea8cfd
        let bmp = image.dataProvider?.data
        var data: UnsafePointer<UInt8> = CFDataGetBytePtr(bmp)
        var r, g, b: UInt8
        
        NSLog("\(#function): extracting \(image.width)x\(image.height) image")
        setSize(width: image.height, height: image.width)
        for i in 0..<pixels.count {
            r = data.pointee
            data = data.advanced(by: 1)
            g = data.pointee
            data = data.advanced(by: 1)
            b = data.pointee
            data = data.advanced(by: 1)
            _ = data.pointee
            data = data.advanced(by: 1)
            
            pixels[i] = valueFromRGB(r: r, g: g, b: b)
        }
        
        pngBuffer = nil
    }
    
}
