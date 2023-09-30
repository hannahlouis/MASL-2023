//
//  DopplerAnalystViewController.swift
//  AudioLabSwift
//
//  Created by Naim Barnett on 9/26/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import UIKit

class DopplerAnalystViewController: UIViewController {
    
    @IBOutlet weak var frequencyLabel: UILabel!
    @IBOutlet weak var frequencyValueSlider: UISlider!
    @IBOutlet weak var gestureLabel: UILabel!
    
    let dopplerAudioModel = DopplerAudioModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        dopplerAudioModel.startProcessingSinewaveForPlayback(withFreq: 15000)
        frequencyLabel.text = "Frequency: 15000"
        dopplerAudioModel.startMicrophoneProcessing()
        dopplerAudioModel.play()
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.gesture),
            userInfo: nil,
            repeats: true)
               
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        dopplerAudioModel.pause()
    }
    
    @IBAction func changeFrequency(_ sender: UISlider) {
        self.dopplerAudioModel.sineFrequency = sender.value
        frequencyLabel.text = "Frequency: \(Int(sender.value))"
    }
    
    @objc
    func gesture(){
//        var readFrequency = self.dopplerAudioModel.getMaxFrequency()
//        if readFrequency > frequencyValueSlider.value {
////            print(readFrequency)
//            gestureLabel.text = "Moving Closer!"
//        }
//        if readFrequency < frequencyValueSlider.value {
////            print(readFrequency)
//            gestureLabel.text = "Moving Further!"
//        }
//        else {
////            print(readFrequency)
//            gestureLabel.text = "No Gesture"
//        }
    }

}
