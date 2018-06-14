//
//  GameOverViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/13/18.
//  Copyright © 2018 Doing Science To Stuff. All rights reserved.
//

import UIKit

class GameOverViewController: UIViewController {
    
    var winner: String = ""
    var score: Int64 = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        playerLabel.text = "\(winner) wins!"
        scoreLabel.text = "Score: \(score)"
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

    @IBOutlet weak var playerLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    
    
}