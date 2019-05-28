//
//  NetworkController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 9/8/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import MultipeerConnectivity

protocol NetworkClient {
    func newConnection(peerID: MCPeerID)
    func stateChanged(for peer: MCPeerID, to state: MCSessionState)
    func handleMessage(_ data: Data, from: MCPeerID)
}

class NetworkController : NSObject, MCSessionDelegate, MCBrowserViewControllerDelegate, MCNearbyServiceAdvertiserDelegate {
    var mcSession: MCSession!
    var delegate: NetworkClient?
    var serviceType: String = "ARtilleryGame"
    var state: MCSessionState = .notConnected
    var maxPeers = 7

    var mcNearbyServiceAdvertiser: MCNearbyServiceAdvertiser?
    var advertising: Bool = false
    var mcBrowserViewController: MCBrowserViewController?
    
    override init() {
        NSLog("\(#function)")

        super.init()
        
        let displayName = UIDevice.current.name
        let peerID = MCPeerID(displayName: displayName)
        mcSession = MCSession(peer: peerID,
                              securityIdentity: nil,
                              encryptionPreference: .optional)
        mcSession.delegate = self
    }
    
    // functions for setting up connectivity
    func browse(currentViewController: UIViewController) {
        NSLog("\(#function)")
        
        // launch peer browser
        let mcNearbyServiceBrowser = MCNearbyServiceBrowser(peer: mcSession.myPeerID, serviceType: serviceType)
        mcBrowserViewController = MCBrowserViewController(browser: mcNearbyServiceBrowser, session: mcSession)
        mcBrowserViewController?.delegate = self
        currentViewController.present(mcBrowserViewController!, animated: true)
    }
    
    func setDisplayName(to: String) {
        NSLog("\(#function)")

        let peerID = MCPeerID(displayName: to)
        mcSession = MCSession(peer: peerID)
        mcSession.delegate = self
        if advertising {
            stopAdvertising()
            advertise()
        }
    }
    
    func advertise() {
        NSLog("\(#function)")
        
        // see: https://developer.apple.com/documentation/multipeerconnectivity/mcnearbyserviceadvertiser/1407102-init
        let info: [String:String] = [:]
        let peerID = MCPeerID(displayName: mcSession.myPeerID.displayName)
        mcSession = MCSession(peer: peerID)
        mcSession.delegate = self
        mcNearbyServiceAdvertiser = MCNearbyServiceAdvertiser(peer: mcSession.myPeerID, discoveryInfo: info, serviceType: serviceType)
        
        mcNearbyServiceAdvertiser?.startAdvertisingPeer()
        mcNearbyServiceAdvertiser?.delegate = self
        advertising = true
    }
    
    func stopAdvertising() {
        NSLog("\(#function)")
        
        mcNearbyServiceAdvertiser?.stopAdvertisingPeer()
        advertising = false
    }
    
    func sendData(_ data: Data, to: MCPeerID) {
        NSLog("\(#function) starting")
        
        if to == mcSession.myPeerID {
            // short circuit sending of local messages
            delegate?.handleMessage(data, from: mcSession.myPeerID)
        } else {
            // send message to remove recipient
            try? mcSession.send(data, toPeers: [to], with: .reliable)
        }
        NSLog("\(#function) finished")
    }
    
    func broadcastData(_ data: Data, includeSelf: Bool = false) {
        NSLog("\(#function) starting")
        
        try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
        if includeSelf {
            delegate?.handleMessage(data, from: mcSession.myPeerID)
        }
        NSLog("\(#function) finished")
    }
    
    func disconnect() {
        mcSession.disconnect()
    }
    
    // MARK -- MCBrowserViewControllerDelegate
    
    func browserViewController(_ browserViewController: MCBrowserViewController,
                               shouldPresentNearbyPeer peerID: MCPeerID,
                               withDiscoveryInfo info: [String : String]?) -> Bool {
        NSLog("\(#function)")

        if mcSession.connectedPeers.count >= maxPeers {
            return false
        }
        
        return true
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        NSLog("\(#function)")
        
        browserViewController.dismiss(animated: true, completion: {})
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        NSLog("\(#function)")
        
        browserViewController.dismiss(animated: true, completion: {})
    }
    
    // MARK -- MCSessionDelegate
    
    func session(_ session: MCSession,
                 didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
        NSLog("\(#function) got data from \(peerID)")
        
        delegate?.handleMessage(data, from: peerID)
    }
    
    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {
        NSLog("\(#function)")
    }
    
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {
        NSLog("\(#function)")
    }
    
    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) {
        NSLog("\(#function)")
    }
    
    func session(_ session: MCSession,
                 peer peerID: MCPeerID,
                 didChange state: MCSessionState) {
        NSLog("\(#function): \(self.state) -> \(state)")
        
        if state == .connected {
            NSLog("\(#function): dismissing browserViewController")
            if let browserViewController = mcBrowserViewController {
                browserViewController.dismiss(animated: true, completion: {})
            }
        }
        if peerID.isEqual(mcSession.myPeerID) {
            self.state = state
        }
        
        if let delegate = delegate {
            delegate.stateChanged(for: peerID, to: state)
        }
    }
    
    // MARK -- MCNearbyServiceAdvertiserDelegate
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("\(#function)")
        
        if mcSession.connectedPeers.count < maxPeers {
            invitationHandler(true,mcSession)
            delegate?.newConnection(peerID: peerID)
        } else {
            invitationHandler(false,mcSession)
        }
        NSLog("connectedPeers: \(mcSession.connectedPeers)")
    }

}
