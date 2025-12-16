//
//  CanvasView.swift
//  eigotchi
//
//  Created by 武内公伸 on 2025/12/13.
//

import SwiftUI
import PencilKit

struct CanvasView: View {
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @StateObject private var webSocketManager = WebSocketManager()
    @StateObject private var microphoneManager = MicrophoneManager()
    @StateObject private var audioPlayer = AudioPlayer()
    
    // 口のアニメーション関連
    @State private var mouthDetection: MouthDetection?
    @State private var showMouthAnimation = false
    @State private var isDetecting = false
    @State private var capturedScreenshot: UIImage?  // 検出に使ったスクリーンショット
    @State private var hasDrawing = false  // キャンバスに描画があるか

    // 音声会話の状態
    @State private var aiTranscript: String = ""
    @State private var connectionStatus: String = "未接続"

    // 口のアニメーション制御用
    @State private var userIsSpeaking = false
    @State private var isGIFAnimating = false  // 初期状態は口を閉じる

    private let geminiAPIKey = APIKeys.gemini

    // デバッグ用: スクリーンショットをフォトライブラリに保存するか
    // true にすると、口の検出時に画像が自動保存されます
    // project.pbxprojに権限が追加されたため、有効化できます
    private let shouldSaveScreenshotForDebug = true
    
    var body: some View {
        VStack(spacing: 0) {
            // トップツールバー
            HStack {
                Button(action: {
                    canvasView.undoManager?.undo()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(canvasView.undoManager?.canUndo == false)
                
                Button(action: {
                    canvasView.undoManager?.redo()
                }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(canvasView.undoManager?.canRedo == false)
                
                Spacer()
                
                // マイクボタン
                Button(action: {
                    if microphoneManager.isRecording {
                        microphoneManager.stopRecording()
                        userIsSpeaking = false
                        cleanupVoiceChat()
                    } else {
                        microphoneManager.startRecording()
                        userIsSpeaking = true
                    }
                }) {
                    Image(systemName: microphoneManager.isRecording ? "mic.fill" : "mic.slash")
                        .font(.title2)
                        .foregroundColor(microphoneManager.isRecording ? .red : .gray)
                }
                
                Button(action: {
                    if showMouthAnimation {
                        // アニメーション停止
                        stopMouthAnimation()
                    } else {
                        // 口を検出してアニメーション開始
                        detectAndAnimateMouth()
                    }
                }) {
                    if isDetecting {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    } else if showMouthAnimation {
                        Image(systemName: "stop.circle")
                            .font(.title2)
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "arrow.forward")
                            .font(.title2)
                            .foregroundColor(hasDrawing ? .blue : .gray)
                    }
                }
                .disabled(isDetecting || !hasDrawing)
                Spacer().frame(width: 60)
                
                Button(action: {
                    canvasView.drawing = PKDrawing()
                    hasDrawing = false
                    // アニメーション状態もリセット
                    stopMouthAnimation()
                    cleanupVoiceChat()
                }) {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // 画面分割: 2/3 キャンバス、1/3 テキストエリア
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    
                    // ★ 変更点1: ZStackを使って「固定背景」と「動くキャンバス」を重ねる
                    ZStack {
                        // 1. 動かない背景（白）
                        Color.white

                        if showMouthAnimation, let screenshot = capturedScreenshot {
                            // 口のアニメーション表示中（検出に使ったスクリーンショットを表示）
                            MouthAnimationViewWithImage(
                                screenshot: screenshot,
                                mouthDetection: mouthDetection,
                                openAIAPIKey: APIKeys.openAI,
                                onSpeechComplete: {
                                    // 音声再生完了時の処理
                                    print("音声再生完了")
                                },
                                userIsSpeaking: $userIsSpeaking,
                                isGIFAnimating: $isGIFAnimating
                            )
                            // ふわふわアニメーションを追加
                            .offset(y: userIsSpeaking ? -10 : 0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: userIsSpeaking)
                            .id("animation") // ビューを識別
                            .transition(.opacity) // フェード効果
                        } else {
                            // 2. 描画レイヤー（背景透明・ここだけ動く）
                            DrawingCanvas(
                                canvasView: $canvasView,
                                toolPicker: $toolPicker,
                                onDrawStart: {
                                    // 描画開始時の処理（必要に応じて）
                                },
                                onDrawEnd: {
                                    // 描画終了時の処理（必要に応じて）
                                },
                                onDrawingChanged: { hasContent in
                                    hasDrawing = hasContent
                                }
                            )
                            // ふわふわアニメーションは「DrawingCanvas（描画層）」にのみ適用
                            // ユーザーが話している時に浮かぶ
                            .offset(y: userIsSpeaking ? -10 : 0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: userIsSpeaking)
                            .id("drawing") // ビューを識別
                            .transition(.opacity) // フェード効果
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height * 3 / 4)
                    .clipped()
                    
                    // テキストエリア（1/4）
                    HStack(spacing: 12) {
                        // バナナキャラクター
                        Image("banana")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("AI会話")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                // 接続状態インジケーター
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(webSocketManager.isConnected ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)
                                    Text(connectionStatus)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // AI発話中インジケーター
                                if audioPlayer.isPlaying || webSocketManager.isAISpeaking {
                                    HStack(spacing: 4) {
                                        Image(systemName: "waveform")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        Text("発話中")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            ScrollView {
                                if aiTranscript.isEmpty {
                                    Text("マイクボタンをタップして会話を開始してください 🎤")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(aiTranscript)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .frame(height: geometry.size.height / 4)
                    .background(Color(.systemGray6))
                }
            }
        }
        .navigationTitle("お絵描き")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            cleanupVoiceChat()
        }
        .onChange(of: webSocketManager.isAISpeaking) { _, newValue in
            // AIが話している時は口を動かし、話していない時は閉じる
            isGIFAnimating = newValue
        }
        .onChange(of: audioPlayer.isPlaying) { _, newValue in
            // 音声再生中も口を動かす
            if newValue {
                isGIFAnimating = true
            } else if !webSocketManager.isAISpeaking {
                // 音声再生が終わり、AIも話していない場合は口を閉じる
                isGIFAnimating = false
            }
        }
    }
    
    // MARK: - Voice Chat Setup
    
    private func setupVoiceChat() {
        // WebSocketコールバックの設定
        webSocketManager.onAudioDataReceived = { audioData in
            // 受信した音声データを再生
            audioPlayer.play(pcmData: audioData)
        }
        
        webSocketManager.onTranscriptReceived = { text, isDone in
            // 文字起こしテキストを表示
            if isDone {
                aiTranscript = text
            } else {
                aiTranscript = text + "..."
            }
        }
        
        webSocketManager.onStatusReceived = { status in
            connectionStatus = status

            // 最初の挨拶が完了したらマイク録音を開始
            if status == "Initial greeting completed" {
                if microphoneManager.hasPermission {
                    microphoneManager.startRecording()
                    userIsSpeaking = true
                }
            }
        }
        
        // WebSocketに接続
        webSocketManager.connect()
        connectionStatus = "接続中..."
        
        // マイクの音声データをWebSocketに送信
        microphoneManager.onAudioData = { audioData in
            webSocketManager.sendData(audioData)
        }
        
        // WebSocket接続後、AIに話しかけてもらう
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if webSocketManager.isConnected {
                connectionStatus = "接続完了"

                // AIに話しかけてもらうトリガーメッセージを送信
                let triggerMessage = """
                {
                    "type": "ai_initiate",
                    "message": "AIから話しかけてください"
                }
                """
                webSocketManager.sendMessage(triggerMessage)

                // マイク録音はAIの挨拶が完了してから開始する（onStatusReceivedで処理）
                if !microphoneManager.hasPermission {
                    connectionStatus = "マイク権限がありません"
                }
            } else {
                connectionStatus = "接続失敗"
            }
        }
    }
    
    private func cleanupVoiceChat() {
        // マイク録音を停止
        microphoneManager.stopRecording()
        userIsSpeaking = false

        // 音声再生を停止
        audioPlayer.stop()

        // WebSocketを切断
        webSocketManager.disconnect()

        // UI状態をリセット
        aiTranscript = ""
        connectionStatus = "未接続"
        isGIFAnimating = false  // 口を閉じる
    }

    /// 口を検出してアニメーションを開始
    private func detectAndAnimateMouth() {
        // 既存の録音を停止
        if microphoneManager.isRecording {
            microphoneManager.stopRecording()
            userIsSpeaking = false
        }

        Task {
            await performMouthDetection()
        }
    }

    /// 口のアニメーションを停止
    private func stopMouthAnimation() {
        withAnimation {
            showMouthAnimation = false
            mouthDetection = nil
            capturedScreenshot = nil
            isGIFAnimating = false  // 口を閉じる
        }
    }

    @MainActor
    private func performMouthDetection() async {
        guard !isDetecting else { return }

        isDetecting = true
        defer { isDetecting = false }

        // Canvas描画を確認
        let drawing = canvasView.drawing
        guard !drawing.bounds.isEmpty else {
            return
        }

        // 実際に画面に表示されているキャンバスのスクリーンショットを取得
        guard let screenshot = captureCanvasScreenshot() else {
            return
        }

        // オプション: スクリーンショットを保存（デバッグ用）
        if shouldSaveScreenshotForDebug {
            saveImageToPhotos(screenshot)
        }

        // 直接赤色ピクセルを検出
        guard let redAreaBounds = RedColorDetector.detectRedArea(in: screenshot) else {
            return
        }

        // Gemini APIで顔の種類のみを判定
        let service = GeminiService(apiKey: geminiAPIKey)
        do {
            if let detection = try await service.detectMouth(in: screenshot) {
                // Gemini APIの検出結果の赤色領域を、直接検出した赤色領域で置き換え
                let correctedDetection = MouthDetection(
                    boundingBox: redAreaBounds,
                    confidence: detection.confidence,
                    faceType: detection.faceType,
                    redAreaBounds: redAreaBounds
                )

                self.capturedScreenshot = screenshot
                self.mouthDetection = correctedDetection
                withAnimation {
                    self.showMouthAnimation = true
                }

                setupVoiceChat()
            }
        } catch {
            // エラーハンドリング
        }
    }

    /// キャンバスのスクリーンショットを取得
    private func captureCanvasScreenshot() -> UIImage? {
        let bounds = canvasView.bounds
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let screenshot = renderer.image { context in
            canvasView.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        return screenshot
    }

    /// デバッグ用: 画像をフォトライブラリに保存
    private func saveImageToPhotos(_ image: UIImage) {
        if UIImageWriteToSavedPhotosAlbum.self != nil {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
}

struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker

    var onDrawStart: () -> Void
    var onDrawEnd: () -> Void
    var onDrawingChanged: ((Bool) -> Void)?  // 描画の有無が変更されたときのコールバック
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        
        // ★ 変更点2: キャンバス自体の背景を透明にする
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        
        canvasView.delegate = context.coordinator
        canvasView.drawingGestureRecognizer.addTarget(context.coordinator, action: #selector(Coordinator.handleDrawingGesture(_:)))
        
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 更新処理なし
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvas
        
        init(_ parent: DrawingCanvas) {
            self.parent = parent
        }
        
        @objc func handleDrawingGesture(_ gesture: UIGestureRecognizer) {
            switch gesture.state {
            case .began:
                parent.onDrawStart()
            case .ended, .cancelled, .failed:
                parent.onDrawEnd()
            default:
                break
            }
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let hasContent = !canvasView.drawing.bounds.isEmpty
            parent.onDrawingChanged?(hasContent)
        }
    }
}

#Preview {
    NavigationStack {
        CanvasView()
    }
}
