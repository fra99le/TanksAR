//
//  PriorityQueue.swift
//  TanksAR
//
//  Created by Fraggle on 7/30/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation

struct Pair<K: Comparable,V> : Comparable {
    var key: K
    var value: V
    
    static func < (lhs: Pair, rhs: Pair) -> Bool {
        return lhs.key < rhs.key
    }

    static func == (lhs: Pair, rhs: Pair) -> Bool {
        return lhs.key == rhs.key
    }
}

struct PriorityQueue<T: Comparable> {
    var items: [T] = []
    
    var count: Int {
        return items.count
    }
    
    mutating func swap(_ pos1: Int, _ pos2: Int) {
        let temp = items[pos1]
        items[pos1] = items[pos2]
        items[pos2] = temp
    }
    
    mutating func enqueue(_ item: T) {
        // add item
        items.append(item)

        // move item into proper position
        var pos = items.count-1
        var parent = (pos-1) / 2
        while pos > 0 && items[pos] < items[parent] {
            swap(pos, parent)
            
            pos = parent
            parent = (pos-1) / 2
        }
    }
    
    mutating func dequeue() -> T? {
        // check for empty queue
        if items.count == 0 {
            return nil
        }

        // swap root with last position
        swap(0, items.count-1)
        let ret = items.removeLast()
        
        // move root item down the heap
        var pos = 0
        var left = pos*2 + 1
        var right = pos*2 + 2
        while right < items.count && (items[pos] > items[left] || items[pos] > items[right]) {
            // always swap with smaller child,
            // so parent becomes the smallest of the three
            var swapWith = left
            if items[right] < items[swapWith] {
                swapWith = right
            }
            swap(pos, swapWith)
            
            pos = swapWith
            left = pos*2 + 1
            right = pos*2 + 2
        }
        
        return ret
    }
}
