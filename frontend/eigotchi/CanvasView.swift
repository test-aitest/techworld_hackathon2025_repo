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
    
    // アニメーション用の状態変数
    @State private var isFloating = false

    // 口のアニメーション関連
    @State private var mouthDetection: MouthDetection?
    @State private var showMouthAnimation = false
    @State private var isDetecting = false
    @State private var capturedScreenshot: UIImage?  // 検出に使ったスクリーンショット

    // 音声会話の状態
    @State private var aiTranscript: String = ""
    @State private var connectionStatus: String = "未接続"

    // TODO: APIキーを安全に管理してください（環境変数、Keychainなど）
    // テスト用のAPIキー（本番環境では絶対に使用しないでください）
    private let geminiAPIKey = "AIzaSyCFEjaPsldMJPhkuvKvtAKD9hGV8dyoL7g"

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
                    } else {
                        microphoneManager.startRecording()
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
                    }
                }
                .disabled(isDetecting || canvasView.drawing.bounds.isEmpty)
                Spacer().frame(width: 60)
                
                Button(action: {
                    canvasView.drawing = PKDrawing()
                    isFloating = false
                    // アニメーション状態もリセット
                    stopMouthAnimation()
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
                                mouthDetection: mouthDetection
                            )
                            .id("animation") // ビューを識別
                            .transition(.opacity) // フェード効果
                        } else {
                            // 2. 描画レイヤー（背景透明・ここだけ動く）
                            DrawingCanvas(
                                canvasView: $canvasView,
                                toolPicker: $toolPicker,
                                onDrawStart: {
                                    withAnimation(.easeOut(duration: 0.1)) {
                                        isFloating = false
                                    }
                                },
                                onDrawEnd: {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        if !canvasView.drawing.bounds.isEmpty {
                                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                                isFloating = true
                                            }
                                        }
                                    }
                                }
                            )
                            // ふわふわアニメーションは「DrawingCanvas（描画層）」にのみ適用
                            .offset(y: isFloating ? -10 : 0)
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
        .onAppear {
            setupVoiceChat()
            
            if !canvasView.drawing.bounds.isEmpty {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }
        }
        .onDisappear {
            cleanupVoiceChat()
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
        }
        
        // WebSocketに接続
        webSocketManager.connect()
        connectionStatus = "接続中..."
        
        // マイクの音声データをWebSocketに送信
        microphoneManager.onAudioData = { audioData in
            webSocketManager.sendData(audioData)
        }
        
        // WebSocket接続後、マイク録音を開始
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if webSocketManager.isConnected {
                connectionStatus = "接続完了"
                
                if microphoneManager.hasPermission {
                    microphoneManager.startRecording()
                    print("✅ Microphone recording started")
                } else {
                    print("⚠️ Microphone permission not granted")
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
        print("🎤 Microphone stopped")
        
        // 音声再生を停止
        audioPlayer.stop()
        print("🔊 Audio player stopped")
        
        // WebSocketを切断
        webSocketManager.disconnect()
        print("🔌 WebSocket disconnected")
    }

    /// 口を検出してアニメーションを開始
    private func detectAndAnimateMouth() {
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
            print("描画が空です")
            return
        }

        // 実際に画面に表示されているキャンバスのスクリーンショットを取得
        guard let screenshot = captureCanvasScreenshot() else {
            print("❌ スクリーンショットの取得に失敗しました")
            return
        }

        // デバッグ: 画像サイズを出力
        print("📸 スクリーンショットサイズ: \(screenshot.size)")

        // オプション: スクリーンショットを保存（デバッグ用）
        if shouldSaveScreenshotForDebug {
            saveImageToPhotos(screenshot)
        }

        // Gemini APIで口を検出
        let service = GeminiService(apiKey: geminiAPIKey)
        do {
            print("🔍 口の検出を開始...")
            print("📏 画像サイズ: \(screenshot.size.width) x \(screenshot.size.height)")

            if let detection = try await service.detectMouth(in: screenshot) {
                print("✅ 口を検出しました（Y:\(detection.boundingBox.midY)）")

                self.capturedScreenshot = screenshot  // スクリーンショットを保存
                self.mouthDetection = detection
                withAnimation {
                    self.showMouthAnimation = true
                }
            } else {
                print("⚠️ 口が検出できませんでした")
            }
        } catch {
            print("❌ エラー: \(error)")
            print("🔧 エラー詳細: \(error.localizedDescription)")
            // エラーアラートを表示（オプション）
        }
    }

    /// キャンバスのスクリーンショットを取得
    private func captureCanvasScreenshot() -> UIImage? {
        let bounds = canvasView.bounds

        // UIGraphicsImageRendererを使用してスクリーンショットを取得
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let screenshot = renderer.image { context in
            canvasView.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }

        return screenshot
    }

    /// デバッグ用: 画像をフォトライブラリに保存
    /// 注意: Info.plistに以下の権限が必要です
    /// - Privacy - Photo Library Additions Usage Description
    private func saveImageToPhotos(_ image: UIImage) {
        // フォトライブラリへのアクセス権限がない場合、クラッシュを防ぐ
        // この機能を使用する場合は、Xcodeでプロジェクト設定のInfoタブから
        // "Privacy - Photo Library Additions Usage Description" を追加してください
        do {
            // セレクタを使って安全にチェック
            if UIImageWriteToSavedPhotosAlbum.self != nil {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                print("💾 スクリーンショットをフォトライブラリに保存しました")
            }
        } catch {
            print("⚠️ 画像の保存に失敗しました: \(error)")
        }
    }
}

struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    
    var onDrawStart: () -> Void
    var onDrawEnd: () -> Void
    
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
            print("Drawing data changed")
        }
    }
}

#Preview {
    NavigationStack {
        CanvasView()
    }
}
