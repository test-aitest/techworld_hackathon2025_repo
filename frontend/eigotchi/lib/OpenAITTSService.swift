//
//  OpenAITTSService.swift
//  eigotchi
//
//  OpenAI Text-to-Speech Service
//

import Foundation
import AVFoundation

class OpenAITTSService: NSObject, AVAudioPlayerDelegate {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/audio/speech"
    private var audioPlayer: AVAudioPlayer?
    private var onCompletion: (() -> Void)?

    override init() {
        self.apiKey = ""
        super.init()
    }

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    /// テキストを音声に変換して再生する
    func speak(text: String, voice: String = "alloy", model: String = "tts-1", onCompletion: (() -> Void)? = nil) async throws {
        self.onCompletion = onCompletion
        // リクエストボディ
        let requestBody: [String: Any] = [
            "model": model,
            "input": text,
            "voice": voice
        ]

        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "Invalid URL", code: -1)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // API リクエスト
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid response", code: -1)
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "API Error: \(httpResponse.statusCode) - \(errorMessage)", code: httpResponse.statusCode)
        }

        // 音声データを再生
        try await playAudio(data: data)
    }

    /// 音声データを再生する
    private func playAudio(data: Data) async throws {
        // メインスレッドで音声プレイヤーを初期化して再生
        try await MainActor.run {
            do {
                // オーディオセッションを設定
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)

                // オーディオプレイヤーを作成して再生
                self.audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()

                print("🔊 音声再生開始: \(data.count) bytes")
            } catch {
                print("❌ 音声再生エラー: \(error)")
                throw error
            }
        }
    }

    /// 音声の再生を停止する
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - AVAudioPlayerDelegate

    /// 音声再生が終了したときに呼ばれる
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🔊 音声再生終了: success=\(flag)")

        // メインスレッドでコールバックを実行
        DispatchQueue.main.async {
            self.onCompletion?()
            self.onCompletion = nil
        }
    }

    /// 音声再生がエラーで終了したときに呼ばれる
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ 音声再生エラー: \(error?.localizedDescription ?? "Unknown error")")

        // エラー時もコールバックを実行
        DispatchQueue.main.async {
            self.onCompletion?()
            self.onCompletion = nil
        }
    }
}
