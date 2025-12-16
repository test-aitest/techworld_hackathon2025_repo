//
//  MicrophoneManager.swift
//  eigotchi
//
//  Created for microphone recording and streaming
//

import Foundation
import AVFoundation
import Combine

class MicrophoneManager: ObservableObject {
    @Published var isRecording = false
    @Published var hasPermission = false
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    
    var onAudioData: ((Data) -> Void)?
    
    init() {
        requestMicrophonePermission()
    }
    
    func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    if !granted {
                        self?.errorMessage = "マイクの使用許可が必要です"
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    if !granted {
                        self?.errorMessage = "マイクの使用許可が必要です"
                    }
                }
            }
        }
    }
    
    func startRecording() {
        guard hasPermission else {
            errorMessage = "マイクの使用許可がありません"
            return
        }
        
        guard !isRecording else {
            print("Already recording")
            return
        }
        
        do {
            // AVAudioSessionを設定してアクティブ化（録音と再生の両方をサポート）
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            let audioEngine = AVAudioEngine()
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            print("Recording format: \(recordingFormat)")
            
            // 24kHz, 16bit, mono に変換（OpenAI Realtime API用）
            let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                             sampleRate: 24000,
                                             channels: 1,
                                             interleaved: true)
            
            guard let format = desiredFormat else {
                errorMessage = "音声フォーマットの設定に失敗しました"
                return
            }
            
            self.audioEngine = audioEngine
            self.inputNode = inputNode
            self.audioFormat = format
            
            // バッファサイズを設定（約100ms分のデータ）
            let bufferSize = AVAudioFrameCount(recordingFormat.sampleRate * 0.1)
            
            // recordingFormatを使用してtapをインストール
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] (buffer, time) in
                guard let self = self else { return }
                
                // バッファの実際のフォーマットを取得
                let bufferFormat = buffer.format
                
                // フォーマット変換が必要な場合
                if bufferFormat.sampleRate != format.sampleRate || 
                   bufferFormat.channelCount != format.channelCount {
                    // フォーマット変換
                    guard let converter = AVAudioConverter(from: bufferFormat, to: format) else {
                        return
                    }
                    
                    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / bufferFormat.sampleRate)
                    guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
                        return
                    }
                    
                    var error: NSError?
                    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                        outStatus.pointee = .haveData
                        return buffer
                    }
                    
                    converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                    if let error = error {
                        print("Audio conversion error: \(error)")
                        return
                    }

                    // PCMデータをDataに変換（interleaved形式）
                    let audioBuffer = convertedBuffer.audioBufferList.pointee.mBuffers
                    guard let audioData = audioBuffer.mData else {
                        return
                    }

                    let dataSize = Int(audioBuffer.mDataByteSize)
                    let data = Data(bytes: audioData, count: dataSize)

                    // コールバックでデータを送信
                    DispatchQueue.main.async {
                        self.onAudioData?(data)
                    }
                } else {
                    // フォーマット変換が不要な場合、直接データを取得
                    let audioBuffer = buffer.audioBufferList.pointee.mBuffers
                    guard let audioData = audioBuffer.mData else {
                        return
                    }

                    let dataSize = Int(audioBuffer.mDataByteSize)
                    let data = Data(bytes: audioData, count: dataSize)

                    // コールバックでデータを送信
                    DispatchQueue.main.async {
                        self.onAudioData?(data)
                    }
                }
            }
            
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.errorMessage = nil
                print("Microphone recording started")
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "録音の開始に失敗しました: \(error.localizedDescription)"
                print("Failed to start recording: \(error)")
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else {
            return
        }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        audioFormat = nil
        
        // AVAudioSessionは他のコンポーネント（AudioPlayer）も使用している可能性があるため、
        // ここでは非アクティブ化しない
        
        DispatchQueue.main.async {
            self.isRecording = false
            print("Microphone recording stopped")
        }
    }
    
    deinit {
        stopRecording()
    }
}
