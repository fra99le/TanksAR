//
//  MenuViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import UIKit

class MenuViewController: UIViewController {

    var humans = 2
    var ais = 0
    
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
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dest = segue.destination as? GameViewController {
            dest.numHumans = humans;
            dest.numAIs = ais;
        } else {
            super.prepare(for: segue, sender: sender)
        }
    }
    
    @IBOutlet weak var humansNumLabel: UILabel!
    @IBOutlet weak var aisNumLabel: UILabel!
    
    @IBOutlet weak var humansStepper: UIStepper!
    @IBOutlet weak var aisStepper: UIStepper!
    
    @IBAction func humansStepperTapped(_ sender: UIStepper) {
        humans = Int(sender.value)
        updateUI()
    }
    
    @IBAction func aisStepperTapped(_ sender: UIStepper) {
        ais = Int(sender.value)
        updateUI()
    }
    
    func updateUI() {
        humansStepper.value = Double(humans)
        aisStepper.value = Double(ais)
        humansNumLabel.text = "\(humans)"
        aisNumLabel.text = "\(ais)"
    }
}
