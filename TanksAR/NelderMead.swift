//
//  NelderMead.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/15/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation

typealias NMVector = [Float]

func nmVectorAdd(_ a: NMVector, _ b: NMVector) -> NMVector {
    guard a.count == b.count else { return a }
    var sum = a
    for i in 0..<b.count {
        sum[i] += b[i]
    }
    return sum
}

func nmVectorSubtract(_ a: NMVector, _ b: NMVector) -> NMVector {
    guard a.count == b.count else { return a }
    var diff = a
    for i in 0..<b.count {
        diff[i] -= b[i]
    }
    return diff
}

func nmVectorScale(_ a: NMVector, by: Float) -> NMVector {
    var scaled = a
    for i in 0..<a.count {
        scaled[i] = a[i] * by
    }
    return scaled
}

func nmVectorLength(_ a: NMVector) -> Float {
    var sum: Float = 0
    for value in a {
        sum += value*value
    }
    return sqrt(sum)
}

struct NMSample : Codable {
    var parameters: NMVector
    var value: Float
}

// see: https://littlebitesofcocoa.com/318-codable-enums
enum NMState : String, Codable {
    case initial, reflect, expand, contract_out, contract_in, shrink
}

// see: http://www.scholarpedia.org/article/Nelder-Mead_algorithm
class NelderMead : Codable {
    // maintain search state
    var dimensions: Int
    var simplex: [NMSample] = []
    var seed: NMVector = []
    var state: NMState = .initial
    var nextQueue: [[Float]] = []
    var extendScale: Float = 1.0
    let maxExtendScale: Float = 1e6
    var prevR: NMSample? = nil
    var shrinkTemp: NMSample? = nil
    
    // hyper-parameters
    var alpha: Float = 1
    var beta: Float = 0.5
    var gamma: Float = 2
    var delta: Float = 0.5

    init(dimensions: Int) {
        self.dimensions = dimensions
        state = .initial
    }
    
    func setSeed(_ seed: NMVector) {
        guard state == .initial else { return }
        NSLog("\(#function) with seed \(seed)")
        self.seed = seed
    }

    func sortedSimplex(_ simplex: [NMSample]) -> [NMSample] {
        let ordered = simplex.sorted(by: {
            // areInIncreasingOrder
            // see: https://developer.apple.com/documentation/swift/array/2296815-sorted
            if $0.value < $1.value {
                return true
            }
            return false
        })
        //NSLog("simplex: \(simplex)")
        //NSLog("ordered: \(ordered)")

        return ordered
    }
    
    func addResult(parameters: [Float], value: Float) {
        //NSLog("\(#function) started")

        let newSample = NMSample(parameters: parameters, value: value)

        //NSLog("\(#function) with parameters \(parameters) and value \(value)")

        // check for initialization state
        if simplex.count < dimensions {
            simplex.append(newSample)
            return
        }
        
        // sort simplex
        var ordered = sortedSimplex(simplex)

        // get h, s, l
        let h = ordered.last!
        let s = ordered[ordered.count-2]
        let l = ordered.first!
        let r = newSample
        //NSLog("f(l) = \(l.value)")
        //NSLog("f(s) = \(s.value)")
        //NSLog("f(h) = \(h.value)")
        //NSLog("f(r) = \(r.value)")

        // check new point and determine next step
        if simplex.count < dimensions+1 {
            //NSLog("state: initial (simplex.count = \(simplex.count))")
            simplex.append(r)
            if simplex.count >= dimensions+1 {
                state = .reflect
            }
            return
        }
        if state == .shrink {
            //NSLog("state: \(state), nextQueue: \(nextQueue)")
            if nextQueue.count >= 1 {
                // store h's replacement for later use
                //NSLog("storing r as shrinkTemp")
                shrinkTemp = r
            } else {
                // replace h&2
                //NSLog("Replacing h&s, shrinkTemp=\(shrinkTemp!)")
                ordered.removeLast()
                ordered.removeLast()
                ordered.append(r)
                ordered.append(shrinkTemp!)
                shrinkTemp = nil
                simplex = ordered
                state = .reflect
            }
            return
        }
        // need to check for acceptance of contract results
        if state == .contract_in {
            if r.value <= (prevR?.value)! {
                ordered.removeLast()
                ordered.append(r)
                simplex = ordered
                state = .reflect
            } else {
                state = .shrink
            }
            return
        }
        if state == .contract_out {
            if r.value < h.value {
                ordered.removeLast()
                ordered.append(r)
                simplex = ordered
                state = .reflect
            } else {
                state = .shrink
            }
            return
        }
        if state == .expand {
            if r.value > (prevR?.value)! {
                ordered.removeLast()
                ordered.append(prevR!)
                simplex = ordered
                state = .reflect
            }
            return
        }

        if l.value <= r.value && r.value < s.value {
            // reflect condition met
            ordered.removeLast()
            ordered.append(newSample)
            simplex = ordered
            state = .reflect
            extendScale = 1.0
        } else if r.value < l.value {
            // expand condition met
            extendScale = min(extendScale * gamma, maxExtendScale)
            state = .expand // repeat reflection, but with a larger magnitude
        } else if r.value >= s.value {
            prevR = r
            // contract condition met
            if s.value <= r.value && r.value < h.value {
                state = .contract_out
            } else if r.value >= h.value {
                state = .contract_in
            } else {
                //NSLog("\(#function) this should be impossible at line \(#line)")
            }
        } else {
            // shrink condition met
            state = .shrink
        }
        prevR = r
        //NSLog("\(#function) ending, state=\(state)")

        //NSLog("\(#function) finished")

    }

    func nextPoint() -> [Float] {
        //NSLog("\(#function) started, nextQueue: \(nextQueue)")

        if state == .initial && simplex.count < dimensions+1 {
            NSLog("state: initial")
            //NSLog("simplex: \(simplex)")
            
            // add new initial point
            var vector = NMVector(repeating: 0.0, count: dimensions)
            if simplex.count > 0 {
                let pos = simplex.count-1
                //NSLog("\tsetting position \(pos) of vector")
                if seed[pos] != 0 {
                    vector = seed
                    vector[pos] = seed[pos] + 0.1 * nmVectorLength(seed)
                } else {
                    vector[pos] = 1
                }
                //NSLog("seed: \(seed), vector: \(vector)")
            } else if seed.count == vector.count {
                //NSLog("using seed: \(seed)")
                vector = seed
            } else {
                seed = vector
            }
            //NSLog("\treturning initial vector \(vector)")
            return vector
        }
        guard simplex.count == dimensions+1 else { return seed }

        // sort simplex
        let ordered = sortedSimplex(simplex)
        
        // get h, s, l
        let h = ordered.last!
        let s = ordered[ordered.count-2]
        let l = ordered.first!

        // compute centroid
        var sumVect = l.parameters
        for i in 1..<ordered.count-1 {
            sumVect = nmVectorAdd(sumVect, ordered[i].parameters)
        }
        let c = nmVectorScale(sumVect, by: 1/(Float(ordered.count-1)))
        let hToC = nmVectorSubtract(c, h.parameters)

        // add apropriate new point(s)
        switch state {
        case .initial:
            break // initial is handled above
        case .reflect:
            NSLog("state: reflect")
            // produces one new point
            let scaled = nmVectorScale(hToC, by: alpha)
            let xr = nmVectorAdd(c, scaled)
            nextQueue.append(xr)
        case .expand:
            NSLog("state: expand (gamma: \(gamma), extendScale: \(extendScale)")
            // produces one new point
            let scaled = nmVectorScale(hToC, by: gamma * extendScale)
            extendScale *= 2
            extendScale = min(extendScale, maxExtendScale)
            let xe = nmVectorAdd(c, scaled)
            nextQueue.append(xe)
        case .contract_out:
            NSLog("state: contract outside")
            // produces one new point
            let scaled = nmVectorScale(hToC, by: 1 + beta)
            let xc = nmVectorAdd(c, scaled)
            nextQueue.append(xc)
        case .contract_in:
            NSLog("state: contract inside")
            // produces one new point
            let scaled = nmVectorScale(hToC, by: 1 - beta)
            let xc = nmVectorAdd(c, scaled)
            nextQueue.append(xc)
        case .shrink:
            NSLog("state: shrink (nextQueue: \(nextQueue))")
            if nextQueue.count == 0 {
                // produces two new points
                let hDir = nmVectorSubtract(h.parameters, l.parameters)
                let sDir = nmVectorSubtract(s.parameters, l.parameters)
                let hScaled = nmVectorScale(hDir, by: delta)
                let sScaled = nmVectorScale(sDir, by: delta)
                let newH = nmVectorAdd(l.parameters, hScaled)
                let newS = nmVectorAdd(l.parameters, sScaled)
                nextQueue.append(newH)
                nextQueue.append(newS)
                //NSLog("added two to nextQueue: \(nextQueue)")
            }
        }
        
        //NSLog("\(#function) finished, nextQueue: \(nextQueue)")
        let ret = nextQueue.remove(at: 0)
        NSLog("\(#function): returning \(ret)")

        return ret
    }
    
    func done() -> Bool {
        return nextQueue.count > 0
    }
}
