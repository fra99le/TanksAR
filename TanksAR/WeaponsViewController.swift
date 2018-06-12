//
//  WeaponsViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/11/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import UIKit

class WeaponsViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        azimuthTextField.delegate = self
        altitudeTextField.delegate = self
        velocityTextField.delegate = self
        weaponPicker.delegate = self

        if let model = gameModel {
            let player = model.board.players[model.board.currentPlayer]
            azimuthTextField.text = "\(player.tank.azimuth * (180/Float.pi))º"
            altitudeTextField.text = "\(player.tank.altitude * (180/Float.pi))º"
            velocityTextField.text = "\(player.tank.velocity) m/s"
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
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
    
    var sizeMode = false
    @IBOutlet weak var weaponTypeLabel: UILabel!
    @IBOutlet weak var weaponSizeLabel: UILabel!
    
    @IBOutlet weak var weaponSizeButton: UIButton!
    @IBOutlet weak var weaponChangeButton: UIButton!
    
    @IBOutlet weak var doneButton: UIButton!
    
    @IBAction func changeWeaponTapped(_ sender: UIButton) {
        sizeMode = false
        weaponPicker.isHidden = false
        doneButton.isHidden = true
    }
    
    @IBAction func changeSizeTapped(_ sender: UIButton) {
        sizeMode = true
        weaponPicker.isHidden = false
        doneButton.isHidden = true
    }
    
    @IBOutlet weak var weaponPicker: UIPickerView!
    
    // MARK: - UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        // number of scrolly wheels
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        guard let model = gameModel else { return 0 }
        let board = model.board
        let weapons = model.weaponsList

        // number of values in scrolly wheel \(component)
        if sizeMode {
            return weapons[board.players[board.currentPlayer].weaponID].sizes.count
        } else {
            return weapons.count
        }
    }

    // MARK: - UIPickerViewDelegate
    func pickerView(_ picker: UIPickerView, titleForRow: Int, forComponent: Int) -> String? {
        guard let model = gameModel else { return "Unknown" }
        let board = model.board
        let weapons = model.weaponsList

        if sizeMode {
            let player = board.players[board.currentPlayer]
            return weapons[player.weaponID].sizes[player.weaponSizeID].name
        } else  {
            return weapons[titleForRow].name
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        NSLog("\(#function) called")
        guard let model = gameModel else { return }
        let board = model.board
        var players = board.players

        // set appropriate value
        if sizeMode {
            players[board.currentPlayer].weaponSizeID = row
        } else {
            players[board.currentPlayer].weaponID = row
            players[board.currentPlayer].weaponSizeID = max(players[board.currentPlayer].weaponSizeID,
                                                            model.weaponsList[row].sizes.count-1)
        }
        
        weaponPicker.isHidden = true
        
        updateUI()
    }
    
    func updateUI() {
        guard let model = gameModel else { return }
        let board = model.board
        var players = board.players

        // update labels
        let player = players[board.currentPlayer]
        let weapon = model.weaponsList[player.weaponID]
        weaponTypeLabel.text = weapon.name
        weaponSizeLabel.text = weapon.sizes[player.weaponSizeID].name
        if weaponSizeLabel.text == "" {
            weaponSizeLabel.text = "N/A"
            weaponSizeButton.isEnabled = false
        } else {
            weaponSizeButton.isEnabled = true
        }

        // restore normal visibilites
        doneButton.isHidden = false
        weaponPicker.isHidden = true
    }
}
