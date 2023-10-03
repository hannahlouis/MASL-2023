//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

// custom extenstion to help find max values in each section for PT 2
extension Array {
    func splitInSubArrays(into size: Int) -> [[Element]] {
        return (0..<size).map{
            stride(from: $0, to: count, by: size).map { self[$0]}
        }
    }
}

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    var timeData:[Float]
    var fftData:[Float]
    var twentyPointData:[[Float]]
    var max1:[Float]
    var max2:[Float]
    
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        max1 = Array.init(repeating: 0.0, count: 20)
        max2 = Array.init(repeating: 0.0, count: 20)
        twentyPointData = Array.init(repeating: Array.init(repeating: 0.0, count: 20),count:2)
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        self.audioManager?.inputBlock = self.handleMicrophone
        
        // repeat this fps times per second using the timer class
        Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                            selector: #selector(self.runEveryInterval),
                            userInfo: nil,
                            repeats: true)
    }
    
    // public function for playing from a file reader file
    func startProcesingAudioFileForPlayback(){
        self.audioManager?.outputBlock = self.handleSpeakerQueryWithAudioFile
        self.fileReader?.play()
        
        // repeat this fps times per second using the timer class
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
                            selector: #selector(self.runEveryInterval),
                            userInfo: nil,
                            repeats: true)
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        sineFrequency = withFreq
        // Two examples are given that use either objective c or that use swift
        //   the swift code for loop is slightly slower thatn doing this in c,
        //   but the implementations are very similar
        //self.audioManager?.outputBlock = self.handleSpeakerQueryWithSinusoid // swift for loop
        self.audioManager?.setOutputBlockToPlaySineWave(sineFrequency) // c for loop
    }
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        self.audioManager?.play()
    }
    
    func pause(){
        self.audioManager?.pause()
    }
    
    // Here is an example function for getting the maximum frequency
    func getMaxFrequencyMagnitude() -> (Float,Float){
        // this is the slow way of getting the maximum...
        // you might look into the Accelerate framework to make things more efficient
        var max:Float = -1000.0
        var maxi:Int = 0
        var nextMax:Float = -1000.0
        var nextMaxi:Int = 0
        
        if inputBuffer != nil {
            for i in 0..<Int(fftData.count){
                if(fftData[i]>max){
                    nextMax = max
                    nextMaxi = maxi
                    
                    max = fftData[i]
                    maxi = i
                }
            }
        }
        let frequency1 = Float(maxi) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)
        return (max,frequency1)
    }
    // for sliding max windows, you might be interested in the following: vDSP_vswmax
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numOutputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    private lazy var outputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    private lazy var fileReader:AudioFileReader? = {
        
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3"){
            var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url,
                                                   samplingRate: Float(audioManager!.samplingRate),
                                                   numChannels: audioManager!.numOutputChannels)
            
            tmpFileReader!.currentTime = 0.0
            print("Audio file succesfully loaded for \(url)")
            return tmpFileReader
        }else{
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    //==========================================
    // MARK: Model Callback Methods
    // ***** CHANGED TO OUTPUT BUFFER FOR FILE PROCESSING *****
    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy data to swift array
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT and display it
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            twentyPointData = getTwentyPointData()
            
//            findPeaks1(arr: fftData)
            let x = findPeaks2()
            
            print (convert(k:x.0), "," , convert(k:x.1))
            
        }
    }
    
   
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
//        var max:Float = 0.0
//        if let arrayData = data{
//            for i in 0..<Int(numFrames){
//                if(abs(arrayData[i])>max){
//                    max = abs(arrayData[i])
//                }
//            }
//        }
//        // can this max operation be made faster??
//        print(max)
        
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    private func handleSpeakerQueryWithAudioFile(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        if let file = self.fileReader{
            
            // read from file, loaidng into data (a float pointer)
            file.retrieveFreshAudio(data,
                                    numFrames: numFrames,
                                    numChannels: numChannels)
            
            // set samples to output speaker buffer
            self.inputBuffer?.addNewFloatData(data,
                                         withNumSamples: Int64(numFrames))
        }
    }
    
    //    _     _     _     _     _     _     _     _     _     _
    //   / \   / \   / \   / \   / \   / \   / \   / \   / \   /
    //  /   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/
    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
        didSet{
            // if using swift for generating the sine wave: when changed, we need to update our increment
            //phaseIncrement = Float(2*Double.pi*sineFrequency/audioManager!.samplingRate)
            
            // if using objective c: this changes the frequency in the novocain block
            self.audioManager?.sineFrequency = sineFrequency
        }
    }
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    private func handleSpeakerQueryWithSinusoid(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        if let arrayData = data{
            var i = 0
            while i<numFrames{
                arrayData[i] = sin(phase)
                phase += phaseIncrement
                if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                i+=1
            }
        }
    }
    
    // this function splits buffer into 20 equal arrays, and adds max array value to seperate array
    func getTwentyPointData() -> [[Float]]{
        var twentyData:[[Float]] = [[2]]
        var max1Data:[Float] = []
        var max2Data:[Float] = []
        lazy var twentyDataSplit:[Float] = timeData
        for i in twentyDataSplit.splitInSubArrays(into: 20) {
            var max1:Float = 0.0
            var max2: Float = 0.0
            for j in 0...(i.count-1){
                if(i[j] > max1){
                    max2 = max1
                    max1 = i[j]
                }
            }
            max1Data.append(max1)
            max2Data.append(max2)
        }
        twentyData.append(max1Data)
        twentyData.append(max2Data)
        return twentyData // returns 20 float array of max values in sections
    }
    //use get twenty point data or not? this gives the maxes so maybe i could like use a find function to find where these are in the og ?
    
    //given an array, if there is a peak, find and return the index ->
    // peak is where the values on either side are less than
    // do i need to compare more than just the values before and after
    
    func findPeaks1(arr:[Float]) -> (Float,Float){
        var absMax = Float(-10000.0);
        var relMax = Float(-100000.0);
        
        var p = 0;
        var x = 1;
        var n = 2;
        for i in arr { // is i the index or the value?
            if p == 0{
                var next = arr[n]
                if (i>next){
                    absMax = i
                }
                
            }else {
                var next = arr[n]
                var prev = arr[p]
                if (i > prev && i > next){
                    relMax = absMax
                    absMax = i
                }
                p+=1
                n+=1
            }
        }
         print (absMax, ",", relMax)
        return (absMax,relMax)
    }
    
    func findPeaks2()-> (Int,Int){
        var max1 = Float(-1000000)
        var max2 = Float(-10000000)
        var index1 = 0
        var index2 = 0
        //var max = -10000;
        for i in 0...BUFFER_SIZE/2{
//        for i in fftData{
            
            if (i+17 <  BUFFER_SIZE/2){
                var window = fftData[i...(i+16)]
                var count = 1;
                for j in window{
                    count+=1
                    if (j == window.max() && count == 9){
                        if (j > max1 && j > max2){
                            max2 = max1
                            max1 = j
                            index2 = index1
                            index1 = i + 9
                        } else if ( j > max2 && j < max1 ){
                            max2 = j
                            index2 = i + 9
                            
                        }
                    }
                    
                    
                    
//                    if (j > max){
//                         max = window[j]
//                    }
//                    if j == 5{
//                        max2 = max1
//                        max1 = max
//                    }
                    
                }
            }
            
//            var wind = fftData[i]
           
        
            
            
            
            
//            for j in window{
//                if max < window[j]{
//                    max = window[j]
//                }
//                if max = window[5]{
//                    globalMax = window[5]
//                }
//            }
        }
        
//        print (max1 , "," , max2)
        return (index1,index2)
    }
    
    func convert (k:Int) -> (Double){
        let freq = (Double(k)*(audioManager!.samplingRate))/Double(BUFFER_SIZE)
        return freq
            
    }
    
}
