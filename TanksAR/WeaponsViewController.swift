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
        }

        return true
    }
    
    @IBAction func azimuthChanged(_ sender: UITextField) {
        guard let str: String = sender.text else { return }
        NSLog("azimuthChanged to \(str)")
        guard let newValue = Double(str) else { return }

        // update model
        guard let model = gameModel else { return }
        let player = model.board.players[model.board.currentPlayer]
        model.setTankAim(azimuth: Float(newValue), altitude: player.tank.altitude)
        
        // re-add degree symbol
        azimuthTextField.text = "\(newValue)º"
        NSLog("new value: \(azimuthTextField.text!)")
    }
    
    @IBAction func altitudeChanged(_ sender: UITextField) {
    }
    
    @IBAction func powerChanged(_ sender: UITextField) {
    }
    
    @IBOutlet weak var weaponSizeButton: UIButton!
    @IBOutlet weak var weaponChangeButton: UIButton!
    
    @IBAction func changeWeaponTapped(_ sender: UIButton) {
    }
    
    @IBAction func changeSizeTapped(_ sender: UIButton) {
    }
    
    @IBOutlet weak var weaponPicker: UIPickerView!
    
}
