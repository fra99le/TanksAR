//
//  ScoresViewController.swift
//  TanksAR
//
//  Created by Bryan Franklin on 6/6/18.
//  Copyright © 2018-2019 Doing Science To Stuff. All rights reserved.
//
//   This Source Code Form is subject to the terms of the Mozilla Public
//   License, v. 2.0. If a copy of the MPL was not distributed with this
//   file, You can obtain one at http://mozilla.org/MPL/2.0/.

import UIKit

class ScoresViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        } else {
            // Fallback on earlier versions
        }
    }
    
    
    @IBOutlet weak var scoresStackView: UIStackView!
    @IBOutlet var highScoreLabels: [UILabel]!

    func relativeDate(_ date: Date) -> String {
        // see: https://www.albertomoral.com/blog/2018/1/20/dateformatter-to-display-relative-dates-today-yesterday-etc
        
        let relativeFormatter = DateFormatter()
        relativeFormatter.timeStyle = .none
        relativeFormatter.dateStyle = .medium
        relativeFormatter.doesRelativeDateFormatting = true
        let relativeDate = relativeFormatter.string(from: date)

        let absoluteFormatter = DateFormatter()
        absoluteFormatter.timeStyle = .none
        absoluteFormatter.dateStyle = .medium
        absoluteFormatter.doesRelativeDateFormatting = false
        let absoluteDate = absoluteFormatter.string(from: date)

        if absoluteDate != relativeDate {
            //NSLog("Dates differ: \(relativeDate) != \(absoluteDate)")
            return relativeDate
        }
        //NSLog("Dates identical: \(relativeDate) == \(absoluteDate)")

        let interval = date.timeIntervalSinceNow
        let days = -interval / 86400
        let ret = "\(Int(days)) days ago"
        
        return ret
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // needs to get the scores and set labels
        let scoresController = HighScoreController()
        let topScores = scoresController.topScores(num: scoresController.maxShown)

        for pos in 0..<10 {
            var scoreText = "\(pos+1). Unknown . . . -1"
            if pos < topScores.count {
                let score = topScores[pos]
                let timeAgo = relativeDate(score.date)
                scoreText = "\(pos+1). \(score.name) . . . \(score.score) (\(timeAgo))"
            }
            
            // add score to stack view
            // see: https://stackoverflow.com/questions/30728062/add-views-in-uistackview-programmatically
            let scoreLabel = UILabel()
            scoreLabel.widthAnchor.constraint(equalToConstant: self.view.frame.width).isActive = true
            scoreLabel.heightAnchor.constraint(equalToConstant: 20.0).isActive = true
            scoreLabel.text  = scoreText
            scoreLabel.textAlignment = .center
            
            scoresStackView.addArrangedSubview(scoreLabel)
            scoresStackView.translatesAutoresizingMaskIntoConstraints = false
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

}
