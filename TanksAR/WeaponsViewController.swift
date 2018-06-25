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
        playerNameField.delegate = self
        azimuthTextField.delegate = self
        altitudeTextField.delegate = self
        velocityTextField.delegate = self

        if let model = gameModel {
            let player = model.board.players[model.board.currentPlayer]
            playerNameField.text = "\(player.name)"
            azimuthTextField.text = "\(player.tank.azimuth)º"
            altitudeTextField.text = "\(player.tank.altitude)º"
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
    
    @IBOutlet weak var playerNameField: UITextField!
    @IBAction func playerNameChanged(_ sender: UITextField) {
        guard let model = gameModel else { return }
        let board = model.board

        if let newName = sender.text {
            NSLog("new name: \(newName)")
            model.board.players[board.currentPlayer].name = newName
        } else {
            NSLog("new name missing!")
            model.board.players[board.currentPlayer].name = "Player \(board.currentPlayer+1)"
        }
        updateUI()
    }
    
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var creditLabel: UILabel!
    
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
    
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var reasonLabel: UILabel!
    
    @IBOutlet weak var weaponTypeLabel: UILabel!
    @IBOutlet weak var weaponSizeLabel: UILabel!
    @IBOutlet weak var weaponCostLabel: UILabel!
    @IBOutlet weak var availablePointsLabel: UILabel!
    
    @IBOutlet weak var weaponTypeStepper: UIStepper!
    @IBOutlet weak var weaponSizeStepper: UIStepper!
    
    @IBAction func weaponTypeStepperTapped(_ sender: UIStepper) {
        NSLog("\(#function) called")
        guard let model = gameModel else { return }
        let board = model.board
        var players = board.players

        // update weapon id for player
        let weaponID = Int(sender.value)
        model.board.players[board.currentPlayer].weaponID = weaponID
        model.board.players[board.currentPlayer].weaponSizeID = min(players[board.currentPlayer].weaponSizeID,
                                                                    model.weaponsList[weaponID].sizes.count-1)
        NSLog("weapon now \(weaponID)")
        NSLog("weapon size now \(model.board.players[board.currentPlayer].weaponSizeID)")

        // update size stepper options
        weaponSizeStepper.maximumValue = Double(model.weaponsList[weaponID].sizes.count-1)
        weaponSizeStepper.stepValue = Double(1)

        updateUI()
    }
    
    @IBAction func weaponSizeStepperTapped(_ sender: UIStepper) {
        NSLog("\(#function) called")
        guard let model = gameModel else { return }
        let board = model.board

        // update size ID for player
        let weaponSizeID = Int(sender.value)
        model.board.players[board.currentPlayer].weaponSizeID = weaponSizeID
        NSLog("weapon size now \(weaponSizeID)")

        updateUI()
    }
    
    func updateUI() {
        guard let model = gameModel else { return }
        let board = model.board
        var players = board.players
        let player = players[board.currentPlayer]
        let weaponID = player.weaponID
        let weapon = model.weaponsList[weaponID]
        let weaponSize = weapon.sizes[player.weaponSizeID]

        // update score label
        scoreLabel.text = "Score: \(player.score)"
        creditLabel.text = "Credit: \(player.credit)"
        
        // update name
        playerNameField.text = board.players[board.currentPlayer].name
        
        // update limits on steppers
        weaponTypeStepper.minimumValue = 0
        weaponTypeStepper.maximumValue = Double(model.weaponsList.count) - 1
        weaponTypeStepper.stepValue = Double(1)
        weaponTypeStepper.value = Double(weaponID)
        weaponSizeStepper.minimumValue = 0
        weaponSizeStepper.maximumValue = Double(model.weaponsList[weaponID].sizes.count) - 1
        weaponSizeStepper.stepValue = Double(1)
        weaponSizeStepper.value = Double(player.weaponSizeID)

        // update labels
        NSLog("weapon name: \(weapon.name), size: \(weaponSize.name), cost: \(weaponSize.cost)")
        weaponTypeLabel.text = weapon.name
        weaponSizeLabel.text = weaponSize.name
        weaponCostLabel.text = "\(weaponSize.cost) points"
        availablePointsLabel.text = "\(player.credit + player.score) points"
        weaponCostLabel.textColor = UIColor.black
        
        // disable done button and give a reason if weapon is invalid
        doneButton.isEnabled = true
        reasonLabel.isHidden = true
        if weaponID > 0 && weaponSize.cost > (player.credit + player.score) {
            reasonLabel.text = "Insufficient points for selected weapon!"
            reasonLabel.isHidden = false
            weaponCostLabel.textColor = UIColor.red
            doneButton.isEnabled = false
        }
        
        if  weaponSizeStepper.maximumValue < 2 {
            weaponSizeLabel.text = "N/A"
            weaponSizeStepper.isEnabled = false
        } else {
            weaponSizeStepper.isEnabled = true
        }
    }
}
