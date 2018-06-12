//
//  WeaponsViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/11/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import UIKit

class WeaponsViewController: UIViewController, UITextFieldDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        azimuthTextField.delegate = self
        altitudeTextField.delegate = self
        velocityTextField.delegate = self
        
        if let model = gameModel {
            let player = model.board.players[model.board.currentPlayer]
            azimuthTextField.text = "\(player.tank.azimuth * (180/Float.pi))º"
            altitudeTextField.text = "\(player.tank.altitude * (180/Float.pi))º"
            velocityTextField.text = "\(player.tank.velocity) m/s"
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    var gameModel: GameModel? = nil
    
    @IBOutlet weak var azimuthTextField: UITextField!
    @IBOutlet weak var altitudeTextField: UITextField!
    @IBOutlet weak var velocityTextField: UITextField!
    
    // see: https://medium.com/@KaushElsewhere/how-to-dismiss-keyboard-in-a-view-controller-of-ios-3b1bfe973ad1
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        guard let str = textField.text else { return true }

        if str.last == "º" {
            textField.text = String(str.dropLast())
        } else if str.suffix(4) == " m/s" {
            textField.text = String(str.dropLast(4))
        }

        return true
    }
    
    @IBAction func valueChanged(_ sender: UITextField) {
        guard let str: String = sender.text else { return }
        NSLog("valueChanged to \(str)")
        guard let newValue = Double(str) else { return }

        // update model
        guard let model = gameModel else { return }
        guard model.board.currentPlayer < model.board.players.count else { return }
        let player = model.board.players[model.board.currentPlayer]
        
        if sender == azimuthTextField {
            model.setTankAim(azimuth: Float(newValue) * (Float.pi/180), altitude: player.tank.altitude)
            azimuthTextField.text = "\(Float(newValue))º"
        } else if sender == altitudeTextField {
            model.setTankAim(azimuth: player.tank.azimuth, altitude: Float(newValue) * (Float.pi/180))
            altitudeTextField.text = "\(Float(newValue))º"
        } else if sender == velocityTextField {
            model.setTankPower(power: Float(newValue))
            velocityTextField.text = "\(Float(newValue)) m/s"
        } else  {
            NSLog("\(#function): Unknown sender \(sender)")
        }
        
        // re-add degree symbol
        NSLog("new value: \(sender.text!)")
    }
    
    @IBOutlet weak var weaponSizeButton: UIButton!
    @IBOutlet weak var weaponChangeButton: UIButton!
    
    @IBAction func changeWeaponTapped(_ sender: UIButton) {
    }
    
    @IBAction func changeSizeTapped(_ sender: UIButton) {
    }
    
    @IBOutlet weak var weaponPicker: UIPickerView!
    
}
