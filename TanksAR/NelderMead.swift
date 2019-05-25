//
//  NelderMead.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/15/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
//

import Foundation

typealias NMVector = [Float]

// Note: the correctness of this has never been properly tested.

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
    case initial, reflect, expand, contract_out, contract_in, shrink, shrink2
}

// see: http://www.scholarpedia.org/article/Nelder-Mead_algorithm
class NelderMead : Codable {
    // maintain search state
    var dimensions: Int
    var iteration: Int = 0
    var simplex: [NMSample] = []
    var seed: NMVector = []
    var state: NMState = .initial

    var x_r: NMSample = NMSample(parameters: [], value: 0)
    var x_e: NMSample = NMSample(parameters: [], value: 0)
    var x_c: NMSample = NMSample(parameters: [], value: 0)
    var s_shrink: NMVector = []

    // hyper-parameters
    var alpha: Float = 1
    var beta: Float = 0.5
    var gamma: Float = 2
    var delta: Float = 0.5

    init(dimensions: Int) {
        self.dimensions = dimensions
    }

    func setSeed(_ seed: NMVector) {
        guard state == .initial else { return }
        NSLog("\(#function) with seed \(seed)")
        self.seed = seed
    }

    func sortedSimplex(_ simplex: [NMSample]) -> [NMSample] {
        let ordered = simplex.sorted(by: {lhs, rhs in // areInIncreasingOrder
            return lhs.value < rhs.value
        })
        assert(ordered.first!.value <= ordered.last!.value)
        //NSLog("simplex: \(simplex)")
        //NSLog("ordered: \(ordered)")

        return ordered
    }

    func addResult(parameters: [Float], value: Float) {
        //NSLog("\(#function) started")

        let newSample = NMSample(parameters: parameters, value: value)

        //NSLog("\(#function) with parameters \(parameters) and value \(value)")

        // check for initialization state
        if state == .initial {
            simplex.append(newSample)
            if simplex.count >= dimensions+1 {
                self.state = .reflect
            }
            return
        }
        
        // sort simplex
        var ordered = sortedSimplex(simplex)

        // deal with shrink states
        if self.state == .shrink2 {
            ordered[self.simplex.count-2] = newSample
            state = .reflect
            simplex = ordered
            return
        } else if self.state == .shrink {
            ordered[self.simplex.count-1] = newSample
            state = .shrink2
            simplex = ordered
            return
        }

        // get h, s, l
        let h = ordered.last!
        let s = ordered[ordered.count-2]
        let l = ordered.first!
        let r = newSample
        //NSLog("f(l) = \(l.value)")
        //NSLog("f(s) = \(s.value)")
        //NSLog("f(h) = \(h.value)")
        //NSLog("f(r) = \(r.value)")

        if state == .reflect {
            x_r = r
            if l.value <= x_r.value && x_r.value < s.value {
                // accept x_r and terminate iteration
                ordered.removeLast()
                ordered.append(x_r)
                simplex = ordered
                return
            }
        }

        if state == .expand {
            x_e = r
            ordered.removeLast()
            if x_e.value < x_r.value {
                // accept x_e and terminate iteration
                ordered.append(x_e)
            } else {
                // accept x_r and terminate iteration
                ordered.append(x_r)
            }
            state = .reflect
            simplex = ordered
            return
        }

        if state == .contract_out {
            x_c = r
            if x_c.value <= x_r.value  {
                // accept x_c and terminate iteration
                ordered.removeLast()
                ordered.append(x_c)
                state = .reflect
                simplex = ordered
                return
            }
        }

        if state == .contract_in {
            x_c = r
            if x_c.value < h.value  {
                // accept x_c and terminate iteration
                ordered.removeLast()
                ordered.append(x_c)
                state = .reflect
                simplex = ordered
                return
            }
        }

        // determine next state if new point not accepted
        if r.value < l.value {
            state = .expand
        } else if r.value >= s.value {
            if s.value <= r.value && r.value < h.value {
                state = .contract_out
            } else {
                state = .contract_in
            }
        } else {
            state = .shrink
        }
        //NSLog("\(#function) ending, state=\(state)")
        //NSLog("\(#function) finished")
    }

    func nextPoint() -> [Float] {
        //NSLog("\(#function) started")

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
        NSLog("ordered simplex: \(ordered)")
        
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

        // add appropriate new point(s)
        switch state {
        case .initial:
            break // initial is handled above
        case .reflect:
            NSLog("state: reflect (alpha: \(alpha)")
            let tmp = nmVectorSubtract(c, h.parameters)
            let scaled = nmVectorScale(tmp, by: alpha)
            return nmVectorAdd(c, scaled) // x_r
        case .expand:
            NSLog("state: expand (gamma: \(gamma))")
            let tmp = nmVectorSubtract(x_r.parameters, c)
            let scaled = nmVectorScale(tmp, by: gamma)
            return nmVectorAdd(c, scaled) // x_e
        case .contract_out:
            NSLog("state: contract outside")
            let tmp = nmVectorSubtract(x_r.parameters, c)
            let scaled = nmVectorScale(tmp, by: beta)
            return nmVectorAdd(c, scaled) // x_c
        case .contract_in:
            NSLog("state: contract inside")
            let tmp = nmVectorSubtract(h.parameters, c)
            let scaled = nmVectorScale(tmp, by: beta)
            return nmVectorAdd(c, scaled) // x_c
        case .shrink:
            NSLog("state: shrink")
            let tmp = nmVectorAdd(x_r.parameters, s.parameters)
            s_shrink = nmVectorScale(tmp, by: 0.5)

            let tmp2 = nmVectorAdd(x_r.parameters, h.parameters)
            return nmVectorScale(tmp2, by: 0.5)
        case .shrink2:
            NSLog("state: shrink2")
            return s_shrink
        }
        
        //NSLog("\(#function) finished")
        //NSLog("\(#function): returning \(ret)")

        return []
    }
    
    func done(maxIterations: Int = 1000, threshold: Float = 1e-5) -> Bool {
        if iteration > maxIterations {
            return true
        }

        // sort simplex
        let ordered = sortedSimplex(simplex)

        // get h & l
        let h = ordered.last!
        let l = ordered.first!

        let tmp = nmVectorSubtract(h.parameters, l.parameters)
        let dist = nmVectorLength(tmp)
        NSLog("nelder-mead dist: \(dist) on iteration \(iteration)")
        if( dist < threshold ) {
            return true
        }

        return false
    }
}
