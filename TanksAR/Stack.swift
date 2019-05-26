//
//  Stack.swift
//  TanksAR
//
//  Created by Bryan Franklin on 8/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation

struct Stack<T> {
    var items: [T] = []
    
    var count: Int {
        return items.count
    }
    
    var top: T? {
        return items.last
    }
    
    mutating func push(_ item: T) {
        // add item
        items.append(item)
    }
    
    mutating func pop() -> T? {
        // check for empty queue
        if items.count == 0 {
            return nil
        }
        
        return items.removeLast()
    }
}
