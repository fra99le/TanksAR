//
//  GameConfig.swift
//  TanksAR
//
//  Created by Fraggle on 5/28/19.
//  Copyright © 2019 Doing Science To Stuff. All rights reserved.
//

import Foundation

enum drawerMode : String, Codable {
    case blocks, plainTrigs, coloredTrigs, texturedTrigs
}

struct GameConfig : Codable {
    var numHumans: Int = 1
    var numAIs: Int = 1
    var numRounds: Int = 3
    var mode: drawerMode = .texturedTrigs
    var credit: Int64 = 5000
    var playerNames: [String] = []
    var networked: Bool = false
}
