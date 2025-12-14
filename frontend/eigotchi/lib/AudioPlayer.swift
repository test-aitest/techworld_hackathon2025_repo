//
//  AudioPlayer.swift
//  eigotchi
//
//  Created for playing PCM16 audio from OpenAI Realtime API
//

import Foundation
import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var sourceFormat: AVAudioFormat? // 24kHz PCM16 mono (input)
    private var mixFormat: AVAudioFormat?    // Engine/MainMixer format (output)
    private var converter: AVAudioConverter?
    
    // PCM16 24kHz モノラルフォーマット
    private let sampleRate: Double = 24000
    private let channels: AVAudioChannelCount = 1
    
    override init() {
        super.init()
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        do {
            // AVAudioSessionを設定（録音と再生を同時に行う）
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)

            // 入力（OpenAI Realtime からの PCM16 24kHz モノラル）フォーマット
            guard let srcFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: channels,
                interleaved: false
            ) else {
                print("❌ Failed to create source audio format")
                return
            }
            self.sourceFormat = srcFormat

            // AudioEngineとPlayerNodeをセットアップ
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()

            engine.attach(player)

            // ミキサーの入出力フォーマット（デバイスに合わせた Float32 / 44.1k or 48k など）
            let mixerInputFormat = engine.mainMixerNode.inputFormat(forBus: 0)
            self.mixFormat = mixerInputFormat

            // ミキサーのフォーマットで接続（24kHz を強制しない）
            engine.connect(player, to: engine.mainMixerNode, format: mixerInputFormat)

            self.audioEngine = engine
            self.playerNode = player

            // エンジンを起動
            try engine.start()

            print("✅ AudioPlayer initialized. source: \(srcFormat), mix: \(mixerInputFormat)")

        } catch {
            print("❌ Failed to setup audio engine: \(error)")
        }
    }
    
    /// PCM16音声データを再生
    func play(pcmData: Data) {
        guard let srcFormat = sourceFormat,
              let playerNode = playerNode,
              let audioEngine = audioEngine,
              audioEngine.isRunning,
              let mixFormat = mixFormat else {
            print("❌ AudioPlayer is not ready")
            return
        }

        // 入力PCM16データから AVAudioPCMBuffer (source) を作成
        let frameLength = pcmData.count / 2 // 16bit = 2 bytes per sample (mono)

        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: AVAudioFrameCount(frameLength)) else {
            print("❌ Failed to create source audio buffer")
            return
        }

        srcBuffer.frameLength = AVAudioFrameCount(frameLength)

        // データをバッファにコピー（non-interleaved）
        pcmData.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            guard let baseAddress = rawBufferPointer.baseAddress else { return }
            let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)

            if let channelData = srcBuffer.int16ChannelData {
                let dst = channelData[0]
                dst.update(from: int16Pointer, count: Int(frameLength))
            }
        }

        // 変換器（24k PCM16 mono -> mixer Float32 44.1k/48k etc.）を用意
        guard let converter = AVAudioConverter(from: srcFormat, to: mixFormat) else {
            print("❌ Failed to create audio converter")
            return
        }
        self.converter = converter

        // 出力バッファ容量を概算（サンプルレート比で上限を見積もる）
        let ratio = mixFormat.sampleRate / srcFormat.sampleRate
        let outFrameCapacity = AVAudioFrameCount(ceil(Double(srcBuffer.frameLength) * ratio))

        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: mixFormat, frameCapacity: outFrameCapacity) else {
            print("❌ Failed to create output audio buffer")
            return
        }

        var conversionError: NSError?
        var providedSource = false
        
        let status = converter.convert(to: outBuffer, error: &conversionError) { inNumPackets, outStatus -> AVAudioBuffer? in
            if providedSource {
                outStatus.pointee = .endOfStream
                return nil
            } else {
                providedSource = true
                outStatus.pointee = .haveData
                return srcBuffer
            }
        }

        // ステータスをチェック
        if status == .error {
            print("❌ Audio conversion failed: \(conversionError?.localizedDescription ?? "unknown error")")
            return
        }
        
        if status == .inputRanDry {
            print("⚠️ Audio conversion: input ran dry")
            // 続行可能なので警告のみ
        }

        // 実際に変換されたフレーム数を frameLength に設定（convert が埋めているため）
        // outBuffer.frameLength は convert により設定済みのはずだが、念のため clamp
        if outBuffer.frameLength == 0 {
            print("⚠️ Audio conversion resulted in 0 frames")
            return
        }
        outBuffer.frameLength = min(outBuffer.frameLength, outBuffer.frameCapacity)

        // バッファを再生
        playerNode.scheduleBuffer(outBuffer) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
            }
        }

        // プレイヤーが停止している場合は再生開始
        if !playerNode.isPlaying {
            playerNode.play()
        }

        DispatchQueue.main.async {
            self.isPlaying = true
        }

        print("🔊 Playing audio: in=\(pcmData.count) bytes (\(frameLength) samples @ \(srcFormat.sampleRate)Hz) -> out=\(outBuffer.frameLength) frames @ \(mixFormat.sampleRate)Hz")
    }
    
    /// 再生を停止
    func stop() {
        playerNode?.stop()
        
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        
        print("⏹️ Audio playback stopped")
    }
    
    /// クリーンアップ
    func cleanup() {
        stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        sourceFormat = nil
        mixFormat = nil
        converter = nil
        
        // AVAudioSessionは他のコンポーネント（マイク）も使用している可能性があるため、
        // ここでは非アクティブ化しない
        print("🧹 AudioPlayer cleaned up")
    }
    
    deinit {
        cleanup()
    }
}
