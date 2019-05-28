//
//  ActivityViewController.swift
//  FakeARtillery
//
//  Created by Bryan Franklin on 9/4/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit

struct PeerMessage : Codable {
    var slider: Float
    var image: Data?
}

class ActivityViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        multipeerController.currentViewController = self
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    var multipeerController: MultipeerController!
    
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var middleButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var slider: UISlider!
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBAction func leftButtonTapped(_ sender: UIButton) {
        NSLog("\(#function)")
        textField.text = "left"
        sendImage(image: leftButton.image(for: .normal))
    }
    
    @IBAction func middleButtonTapped(_ sender: UIButton) {
        NSLog("\(#function)")
        textField.text = "middle"
        sendImage(image: middleButton.image(for: .normal))
    }
    
    @IBAction func rightButtonTapped(_ sender: UIButton) {
        NSLog("\(#function)")
        textField.text = "right"
        sendImage(image: rightButton.image(for: .normal))
    }
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        NSLog("\(#function)")
        NSLog("slider value changed to \(sender.value)")
        textField.text = "slider set to \(sender.value)"
        
        sendSlider()
    }

    func sendImage(image: UIImage?) {
        NSLog("\(#function)")
        guard let image = image else { return }
        
        // see: https://gist.github.com/trilliwon/5af1abe1a113148c23ecde8c08e181a6
        let imageData = UIImagePNGRepresentation(image)
        
        let message = PeerMessage(slider: slider.value, image: imageData)
        let encoder = PropertyListEncoder()
        let encodedValue = try? encoder.encode(message)
        NSLog("encodedValue: \(String(describing: encodedValue))")
        if let data = encodedValue {
            multipeerController.sendData(data)
        }
    }
    
    func sendSlider() {
        let message = PeerMessage(slider: slider.value, image: nil)
        let encoder = PropertyListEncoder()
        let encodedValue = try? encoder.encode(message)
        NSLog("encodedValue: \(String(describing: encodedValue))")
        if let data = encodedValue {
            multipeerController.sendData(data)
        }
    }
    
    func decodeMessage(_ data: Data) {
        NSLog("\(#function)")
        let decoder = PropertyListDecoder()
        if let value = try? decoder.decode(PeerMessage.self, from: data) {
            NSLog("got \(value)")
            
            DispatchQueue.main.async {
                self.slider.setValue(value.slider, animated: false)
                if let image = value.image {
                    // see: https://gist.github.com/trilliwon/5af1abe1a113148c23ecde8c08e181a6
                    if let imageUIImage: UIImage = UIImage(data: image) {
                        self.imageView.image = imageUIImage
                    }
                } else {
                    self.textField.text = "remote slider set to \(value.slider)"
                }
            }
        }
    }

    func disconnect() {
        performSegue(withIdentifier: "unwindToMainMenu", sender: self)
    }
}
