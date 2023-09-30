//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate


class DopplerAudioModel {
    
    func pause(){
        self.audioManager?.pause()
    }
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    private let USE_C_SINE = false
    var timeData:[Float]
    var fftData:[Float]
    
    // MARK: Public Methods
    init() {
        BUFFER_SIZE = 2048
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float){
        sineFrequency = withFreq
        // Two examples are given that use either objective c or that use swift
        //   the swift code for loop is slightly slower thatn doing this in c,
        //   but the implementations are very similar
        if let manager = self.audioManager{
            
            if USE_C_SINE {
                // c for loop
                manager.setOutputBlockToPlaySineWave(sineFrequency)
            }else{
                // swift for loop
                manager.outputBlock = self.handleSpeakerQueryWithSinusoid
            }
            
            
        }
        
//        var K:Int
//        K = Int((Float(audioManager!.samplingRate)*withFreq)/Float(BUFFER_SIZE))
        
        
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(){
        self.audioManager?.inputBlock = self.handleMicrophone
        
        // repeat this fps times per second using the timer class
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
                            selector: #selector(self.runEveryInterval),
                            userInfo: nil,
                            repeats: true)
    }
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        if let manager = self.audioManager{
            manager.play()
        }
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    
    
    //==========================================
    // MARK: Model Callback Methods
    
    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy data to swift array
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT and display it
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
        }
    }
   
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    
    //    _     _     _     _     _     _     _     _     _     _
    //   / \   / \   / \   / \   / \   / \   / \   / \   / \   /
    //  /   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/
    
    
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
        
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    
    
    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
        didSet{
            
            if let manager = self.audioManager {
                if USE_C_SINE {
                    // if using objective c: this changes the frequency in the novocaine block
                    manager.sineFrequency = sineFrequency
                    
                }else{
                    // if using swift for generating the sine wave: when changed, we need to update our increment
                    phaseIncrement = Float(2*Double.pi*Double(sineFrequency)/manager.samplingRate)
                }
            }
        }
    }
    
    // SWIFT SINE WAVE
    // everything below here is for the swift implementation
    // this can be deleted when using the objective c implementation
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    private func handleSpeakerQueryWithSinusoid(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        // EDIT: fixed in 2023
        if let arrayData = data{
            var i = 0
            let chan = Int(numChannels)
            let frame = Int(numFrames)
            if chan==1{
                while i<frame{
                    arrayData[i] = sin(phase)
                    phase += phaseIncrement
                    if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                    i+=1
                }
            }else if chan==2{
                let len = frame*chan
                while i<len{
                    arrayData[i] = sin(phase)
                    arrayData[i+1] = arrayData[i]
                    phase += phaseIncrement
                    if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                    i+=2
                }
            }
        }
    }
    
//    func calibrate(freq:Float) -> (Float, Float){
//        var freqRange = fftData[Int((freq-100.0))...Int((freq+100.0))]
//        for
//        return ((freq-avg),(freq+avg))
//    }
}
