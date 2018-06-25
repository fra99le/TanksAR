//
//  MenuViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import UIKit

class MenuViewController: UIViewController {

    var humans = 1
    var ais = 2
    var rounds = 2
    var useBlocks = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
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

    // make this a target for unwinding segues
    @IBAction func unwindToMainMenu(unwindSegue: UIStoryboardSegue) {
        if let source = unwindSegue.source as? GameViewController {
            source.unplaceBoard()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dest = segue.destination as? GameViewController {
            dest.numHumans = humans;
            dest.numAIs = ais;
            dest.numRounds = rounds
            dest.useBlocks = useBlocks
            NSLog("\(#function) starting \(dest.numRounds) round game.")
        } else {
            super.prepare(for: segue, sender: sender)
        }
    }
    
    @IBOutlet weak var humansNumLabel: UILabel!
    @IBOutlet weak var aisNumLabel: UILabel!
    @IBOutlet weak var roundsNumLabel: UILabel!

    @IBOutlet weak var humansStepper: UIStepper!
    @IBOutlet weak var aisStepper: UIStepper!
    @IBOutlet weak var roundsStepper: UIStepper!

    @IBOutlet weak var modeButton: UIButton!
    
    @IBAction func humansStepperTapped(_ sender: UIStepper) {
        humans = Int(sender.value)
        updateUI()
    }
    
    @IBAction func aisStepperTapped(_ sender: UIStepper) {
        ais = Int(sender.value)
        updateUI()
    }

    @IBAction func roundsStepperTapped(_ sender: UIStepper) {
        rounds = Int(sender.value)
        updateUI()
    }
    
    @IBAction func playGameTapped(_ sender: UIButton) {
        
    }

    @IBAction func modeTapped(_ sender: UIButton) {
        useBlocks = !useBlocks
        NSLog("useBlocks: \(useBlocks)")
        updateUI()
    }
    
    
    func updateUI() {
        humansStepper.value = Double(humans)
        aisStepper.value = Double(ais)
        roundsStepper.value = Double(rounds)
        humansNumLabel.text = "\(humans)"
        aisNumLabel.text = "\(ais)"
        roundsNumLabel.text = "\(rounds)"
        modeButton.setTitle(useBlocks ? "Super-Retro" : "Retro", for: .normal)
    }
    
}
