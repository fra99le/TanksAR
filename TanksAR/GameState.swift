//
//  GameState.swift
//  TanksAR
//
//  Created by Bryan Franklin on 10/7/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

struct GameState : Codable {
    var model : GameModel
    var config : GameConfig
}
