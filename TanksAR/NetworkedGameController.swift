//
//  NetworkedGameController.swift
//  TanksAR
//
//  Created by Fraggle on 9/8/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import Foundation
import MultipeerConnectivity

// At start of game:
//      establish peers (done!)
//      leader assigns players to peerIDs
//      leader (host) announces self while notifying peers of their player numbers
//      leader's client creates the board/player locations and broadcasts it
// During a turn
//      Current player can broadcast aim/weapon/targeting info
// Completing a turn
//      Final aim/weapon/seed info is broadcast
//      Each peer computes result and animates individually
// After turn
//      leader's client broadcasts verification/current player info

struct TurnInfo : Codable {
    var round: Int
    var playerID: Int
    var tank: Tank
    var weaponID: Int
    var weaponSizeID: Int
    var usingComputer: Bool
    var isFire: Bool
}

struct GameNetworkMessage : Codable {
    var fromLeader: Bool?
    var playerID: Int?
    var playerReady: Bool?
    var totalPlayers: Int?
    var gameModel: GameModel?
    var turnInfo: TurnInfo?
    var enableUI: Bool?
    var finishedTurn: Bool?
    var checkSum: String?
}

class NetworkedGameController : NetworkClient {
    // external controllers to talk to
    var viewController: UIViewController!
    var networkController: NetworkController!

    // local state
    var name: String = "Unamed"
    var isLeader = false
    var leaderPeerID: MCPeerID!
    var playerPeerIDs: [MCPeerID] = []
    var myPlayerID: Int = -1
    var totalPlayers: Int = 10
    var playersReady: [Bool] = []
    
    // wrappers for network controller state
    var connectionState: MCSessionState = .notConnected
    var connectionStateString: String {
        switch connectionState {
        case .connected:
            return "Connected"
        case .notConnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        }
    }
    var numConnected: Int {
        return networkController.mcSession.connectedPeers.count+1
    }
    
    init(gameViewController: UIViewController) {
        NSLog("\(#function)")

        networkController = NetworkController()
        self.viewController = gameViewController
        networkController.delegate = self
    }
    
    // MARK -- Basic communication and game setup
    
    func sendMessage(_ message: GameNetworkMessage, to: MCPeerID) {
        NSLog("\(#function)")

        let encoder = PropertyListEncoder()
        let encodedValue = try? encoder.encode(message)
        NSLog("\(#function) encodedValue: \(String(describing: encodedValue))")
        if let data = encodedValue {
            networkController.sendData(data, to: to)
        }
    }

    func broadcastMessage(_ message: GameNetworkMessage, includeSelf: Bool = false) {
        NSLog("\(#function)")

        let encoder = PropertyListEncoder()
        let encodedValue = try? encoder.encode(message)
        NSLog("\(#function) encodedValue: \(String(describing: encodedValue))")
        if let data = encodedValue {
            networkController.broadcastData(data, includeSelf: includeSelf)
        }
    }
    
    func disconnect() {
        networkController.disconnect()
    }
    
    func newConnection(peerID: MCPeerID) {
        if let viewController = viewController as? NetworkSetupViewController {
            viewController.playerJoined(displayName: peerID.displayName)
        }

        if isLeader {
            NSLog("\(#function) as leader")
            var message = GameNetworkMessage()
            message.fromLeader = true
            message.totalPlayers = totalPlayers
            sendMessage(message, to: peerID)
        }
        updateViewController()
    }

    func stateChanged(for peer: MCPeerID, to state: MCSessionState) {
        connectionState = state
        NSLog("\(#line) \(#function): state change for \(peer), now has \(networkController.mcSession.connectedPeers.count) peers")
        updateViewController()
    }

    func setGameName(to: String) {
        networkController.setDisplayName(to: to)
        if isLeader {
            leaderPeerID = networkController.mcSession.myPeerID
        }
    }
    
    func advertiseGame(name: String) {
        NSLog("\(#function)")
        
        leaderPeerID = networkController.mcSession.myPeerID
        isLeader = true
        networkController.setDisplayName(to: name)
        networkController.advertise()
    }
    
    func stopAdvertising() {
        NSLog("\(#function)")
        
        isLeader = false
        networkController.stopAdvertising()
    }

    func browseHosts(from: UIViewController) {
        NSLog("\(#function)")

        networkController.browse(currentViewController: from)
    }
    
    func setExpectedPlayers(numPlayers: Int) {
        totalPlayers = numPlayers
        if isLeader {
            broadcastPlayerCount()
        }
    }

    func broadcastPlayerCount() {
        NSLog("\(#function) broadcasting \(totalPlayers) players")
        var message = GameNetworkMessage()
        message.fromLeader = true
        message.totalPlayers = totalPlayers
        broadcastMessage(message)
    }

    // MARK -- Game functions
    
    func startGame() {
        NSLog("\(#function)")
        if isLeader {
            NSLog("\(#function): as leader")
            leaderPeerID = networkController.mcSession.myPeerID

            // assign player ids
            playerPeerIDs.append(contentsOf: networkController.mcSession.connectedPeers)
            playerPeerIDs.append(networkController.mcSession.myPeerID)
            for i in 1..<playerPeerIDs.count {
                let swapIdx = arc4random() % UInt32(i)
                playerPeerIDs.swapAt(i, Int(swapIdx))
            }
            
            // announce ids and leadership
            for i in 0..<playerPeerIDs.count {
                var message = GameNetworkMessage()
                message.fromLeader = true
                message.playerID = i
                sendMessage(message, to: playerPeerIDs[i])
                NSLog("\(#function): \(playerPeerIDs[i]) == \(leaderPeerID!)")
                if playerPeerIDs[i] == leaderPeerID {
                    NSLog("\(#function) setting myPlayerID for leader")
                    myPlayerID = i
                }
            }

            unreadyAll()
        } else {
            NSLog("\(#function): as client")
        }
    }
    
    func startRound() {
        NSLog("\(#function)")
        
        guard let viewController = viewController as? GameViewController else { return }
        let gameModel = viewController.gameModel

        if isLeader {
            NSLog("\(#function): as leader")
            var message = GameNetworkMessage()
            message.gameModel = gameModel
            broadcastMessage(message)
            playerReady()
        }
    }
    
    func unreadyAll() {
        guard isLeader else { return }
        playersReady = [Bool](repeating: false, count: playerPeerIDs.count)

        var message = GameNetworkMessage()
        message.enableUI = false
        
        broadcastMessage(message, includeSelf: true)
    }

    func playerReady() {
        NSLog("\(#function)")
        
        var message = GameNetworkMessage()
        message.playerID = myPlayerID
        message.playerReady = true
        
        sendMessage(message, to: leaderPeerID)
    }
        
    func playerAiming(isFiring: Bool = false) {
        NSLog("\(#function)")
        
        guard let viewController = viewController as? GameViewController else { return }
        let gameModel = viewController.gameModel

        // get current player
        let currentPlayer = gameModel.board.currentPlayer
        guard currentPlayer == myPlayerID else { return }
        let player = gameModel.board.players[currentPlayer]
        
        // setup turn info struct
        var message = GameNetworkMessage()
        message.turnInfo = TurnInfo(round: gameModel.board.currentRound,
                                    playerID: currentPlayer,
                                    tank: player.tank,
                                    weaponID: player.weaponID,
                                    weaponSizeID: player.weaponSizeID,
                                    usingComputer: player.useTargetingComputer,
                                    isFire: isFiring)
        
        if isFiring {
            NSLog("sending firing message: \(message)")
            unreadyAll()
        }
        
        // broadcast message
        broadcastMessage(message)
    }
    
    func finishedTurn() {
        NSLog("\(#function)")
        
        var message = GameNetworkMessage()
        message.finishedTurn = true

        sendMessage(message, to: leaderPeerID)
        playerReady()
    }
    
    func handleMessage(_ data: Data, from: MCPeerID) {
        NSLog("\(#function)")
        
        let decoder = PropertyListDecoder()
        guard let message = try? decoder.decode(GameNetworkMessage.self, from: data) else { return }
        NSLog("got message: \(message)")
        
        // handle leader assignment and leader messages
        if let fromLeader = message.fromLeader {
            if fromLeader {
                leaderPeerID = from
                NSLog("\(#function): leader is \(leaderPeerID!)")
                
                if let playerID = message.playerID {
                    NSLog("\(#function), I will be player \(playerID)")
                    myPlayerID = playerID
                }

                if let players = message.totalPlayers {
                    NSLog("\(#function), setting total players to \(players).")
                    totalPlayers = players
                    updateViewController()
                }
            }
        }
        
        // All setup messages need to be processed above this line
        
        guard let viewController = viewController as? GameViewController else { return }
        
        if let gameModel = message.gameModel {
            viewController.gameModel = gameModel
            updateViewController()
            playerReady()
        }
        
        if let enableUI = message.enableUI {
            NSLog("enableUI in message set to \(enableUI)")
            DispatchQueue.main.async {
                if enableUI {
                    viewController.enableUI()
                } else {
                    viewController.disableUI()
                }
            }
            updateViewController()
        }
        
        if let ready = message.playerReady {
            playersReady[message.playerID!] = ready
            
            // check to see if all ready
            var allReady = true
            for ready in playersReady {
                allReady = allReady && ready
            }
            
            // enable current player if all are ready
            if allReady {
                let playerID = viewController.gameModel.board.currentPlayer
                let playerName = viewController.gameModel.board.players[playerID].name
                NSLog("enabling \(playerName)")
                
                var message = GameNetworkMessage()
                message.enableUI = true
                
                sendMessage(message, to: playerPeerIDs[playerID])
            }
        }
        
        if let checkSum = message.checkSum {
            if !isLeader {
                NSLog("\(#function): client got a checksum \(checkSum), need to verify it!")
            }
        }
        
        if let turnInfo = message.turnInfo {
            let gameModel = viewController.gameModel
            
            gameModel.setTankAim(azimuth: turnInfo.tank.azimuth, altitude: turnInfo.tank.altitude)
            gameModel.setTankPower(power: turnInfo.tank.velocity)
            let currentPlayer = gameModel.board.currentPlayer
            gameModel.board.players[currentPlayer].weaponID = turnInfo.weaponID
            gameModel.board.players[currentPlayer].weaponSizeID = turnInfo.weaponSizeID
            gameModel.board.players[currentPlayer].useTargetingComputer = turnInfo.usingComputer

            DispatchQueue.main.async {
                // trigger view updates
                viewController.updateHUD()
                
                if turnInfo.isFire {
                    NSLog("got firing message: \(message)")
                    viewController.launchProjectile()
                }
            }
        }
        
    }
    
    func updateViewController() {
        if let viewController = viewController as? NetworkSetupViewController {
            DispatchQueue.main.async {
                viewController.updateUI()
            }
        }
        
        if let viewController = viewController as? GameViewController {
            DispatchQueue.main.async {
                viewController.updateUI()
            }
        }

    }
}
