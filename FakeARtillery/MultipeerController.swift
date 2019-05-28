//
//  MultipeerController.swift
//  FakeARtillery
//
//  Created by Bryan Franklin on 9/4/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import MultipeerConnectivity

class MultipeerController : NSObject, MCSessionDelegate, MCBrowserViewControllerDelegate, MCNearbyServiceAdvertiserDelegate {
    var currentViewController: UIViewController!

    // see: https://developer.apple.com/documentation/multipeerconnectivity/mcnearbyservicebrowser/1407094-init
    let serviceType = "ARtilleryGame"
    var peerID: MCPeerID!
    var mcSession: MCSession!
    var mcNearbyServiceAdvertiser: MCNearbyServiceAdvertiser!
    var mcBrowserViewController: MCBrowserViewController?
    var advertising = false
    var state: MCSessionState = .notConnected
    
    init(with viewController: UIViewController) {
        super.init()
        NSLog("\(#function)")

        currentViewController = viewController
        let serviceString = UIDevice.current.name
        // get peer id and create session
        peerID = MCPeerID.init(displayName: serviceString)
        mcSession = MCSession(peer: peerID)
        // see also: https://developer.apple.com/documentation/multipeerconnectivity/mcsession/1407025-init
        
        mcSession.delegate = self
    }
    
    func browse() {
        NSLog("\(#function)")

        // launch peer browser
        let mcNearbyServiceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        mcBrowserViewController = MCBrowserViewController(browser: mcNearbyServiceBrowser, session: mcSession)
        mcBrowserViewController?.delegate = self
        currentViewController.present(mcBrowserViewController!, animated: true)
    }
    
    func advertise() {
        NSLog("\(#function)")
        
        // see: https://developer.apple.com/documentation/multipeerconnectivity/mcnearbyserviceadvertiser/1407102-init
        let info: [String:String] = [:]
        mcNearbyServiceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: serviceType)
        
        mcNearbyServiceAdvertiser.startAdvertisingPeer()
        mcNearbyServiceAdvertiser.delegate = self
        advertising = true
    }
    
    func stopAdvertising() {
        NSLog("\(#function)")
        
        mcNearbyServiceAdvertiser.stopAdvertisingPeer()
        advertising = false
    }
    
    func peersCount() -> Int {
        return mcSession.connectedPeers.count
    }
    
    func notifyUI(data: Data? = nil) {
        NSLog("\(#function)")

        if let viewController = currentViewController as? NetworkSetupViewController {
            DispatchQueue.main.async {
                viewController.updateUI()
            }
        }
    }
    
    func sendData(_ data: Data) {
        NSLog("\(#function) starting")
        try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
        NSLog("\(#function) finished")
    }
    
    // MARK -- MCBrowserViewControllerDelegate
    
    func browserViewController(_ browserViewController: MCBrowserViewController,
                               shouldPresentNearbyPeer peerID: MCPeerID,
                               withDiscoveryInfo info: [String : String]?) -> Bool {
        if peersCount() >= 7 {
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
        
        notifyUI(data: data)
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
        self.state = state

        notifyUI()
    }
    
    // MARK -- MCNearbyServiceAdvertiserDelegate
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("\(#function)")
        
        if mcSession.connectedPeers.count < 7 {
        invitationHandler(true,mcSession)
            invitationHandler(true,mcSession)
        } else {
            invitationHandler(false,mcSession)
        }
        NSLog("connectedPeers: \(mcSession.connectedPeers)")
        
        notifyUI()
    }

}
