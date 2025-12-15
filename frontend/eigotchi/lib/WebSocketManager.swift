//
//  WebSocketManager.swift
//  eigotchi
//
//  Created for WebSocket connection management
//

import Foundation
import Combine

class WebSocketManager: ObservableObject {
    @Published var isConnected = false
    @Published var lastMessage: String = ""
    @Published var lastTranscript: String = ""
    @Published var connectionError: String?
    @Published var isAISpeaking = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let url: URL
    
    // 音声データ受信のコールバック
    var onAudioDataReceived: ((Data) -> Void)?
    var onTranscriptReceived: ((String, Bool) -> Void)?
    var onStatusReceived: ((String) -> Void)?
    
    init(urlString: String = "ws://localhost:3000/") {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid WebSocket URL: \(urlString)")
        }
        self.url = url
    }
    
    func connect() {
        guard !isConnected else {
            print("WebSocket is already connected")
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        
        // エラーハンドラを設定
        webSocketTask?.resume()
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionError = nil
            print("WebSocket connection attempt started to \(self.url.absoluteString)")
        }
        
        // 接続確認メッセージを受信
        receiveMessage()
        
        // 接続確認メッセージを送信（オプション）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.sendMessage("{\"type\":\"connect\",\"message\":\"Hello from iOS\"}")
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        isAISpeaking = false
    }
    
    func sendMessage(_ message: String) {
        guard let webSocketTask = webSocketTask else {
            connectionError = "WebSocket is not connected"
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask.send(message) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.connectionError = "Send error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func sendData(_ data: Data) {
        guard let webSocketTask = webSocketTask else {
            print("WebSocket is not connected, cannot send data")
            connectionError = "WebSocket is not connected"
            return
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask.send(message) { error in
            if let error = error {
                print("Send data error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.connectionError = "Send error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        self.lastMessage = text
                        print("📩 Received message: \(text)")
                        
                        // JSONメッセージをパースして処理
                        if let data = text.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let type = json["type"] as? String {
                            self.handleMessage(type: type, json: json)
                        }
                    }
                case .data(let data):
                    // AI音声データを受信
                    DispatchQueue.main.async {
                        self.lastMessage = "Received audio: \(data.count) bytes"
                        print("🔊 Received audio data: \(data.count) bytes")
                        
                        // 音声データのコールバックを呼び出す
                        self.onAudioDataReceived?(data)
                    }
                @unknown default:
                    break
                }
                
                // 次のメッセージを受信するために再帰的に呼び出す
                self.receiveMessage()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.connectionError = "Receive error: \(error.localizedDescription)"
                    self.isConnected = false
                    print("❌ WebSocket receive error: \(error)")
                }
            }
        }
    }
    
    private func handleMessage(type: String, json: [String: Any]) {
        switch type {
        case "status":
            if let message = json["message"] as? String {
                print("📢 Status: \(message)")
                onStatusReceived?(message)
                
                // AIの発話状態を更新
                if message.contains("Speech detected") || message.contains("Response") {
                    isAISpeaking = true
                } else if message.contains("completed") || message.contains("ended") {
                    isAISpeaking = false
                }
            }
            
        case "transcript":
            // 文字起こしテキストを受信
            if let text = json["text"] as? String,
               let isDone = json["isDone"] as? Bool {
                print("📝 Transcript: \(text) (done: \(isDone))")
                lastTranscript = text
                onTranscriptReceived?(text, isDone)
            }
            
        case "error":
            if let message = json["message"] as? String {
                print("❌ Error: \(message)")
                connectionError = message
            }
            
        default:
            print("ℹ️ Unknown message type: \(type)")
        }
    }
    
    deinit {
        disconnect()
    }
}
