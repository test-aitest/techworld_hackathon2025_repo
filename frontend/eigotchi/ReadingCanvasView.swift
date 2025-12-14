//
//  ReadingCanvasView.swift
//  eigotchi
//
//  Reading mode canvas view - displays floating animation without mouth detection
//

import SwiftUI
import PencilKit

struct ReadingCanvasView: View {
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()

    // アニメーション用の状態変数
    @State private var isFloating = false
    @State private var showFloatingAnimation = false
    @State private var capturedScreenshot: UIImage?  // キャンバスのスクリーンショット
    @State private var hasDrawing = false  // 描画があるかどうか

    // Gemini API設定
    private let geminiAPIKey = "AIzaSyCFEjaPsldMJPhkuvKvtAKD9hGV8dyoL7g"

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

                Button(action: {
                    if showFloatingAnimation {
                        // アニメーション停止
                        stopFloatingAnimation()
                    } else {
                        // 浮かぶアニメーション開始
                        startFloatingAnimation()
                    }
                }) {
                    if showFloatingAnimation {
                        Image(systemName: "stop.circle")
                            .font(.title2)
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "arrow.forward")
                            .font(.title2)
                    }
                }
                .disabled(!hasDrawing)
                Spacer().frame(width: 60)

                Button(action: {
                    canvasView.drawing = PKDrawing()
                    isFloating = false
                    hasDrawing = false
                    stopFloatingAnimation()
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

                    // キャンバスエリア
                    ZStack {
                        // 動かない背景（白）
                        Color.white

                        if showFloatingAnimation, let screenshot = capturedScreenshot {
                            // 浮かぶアニメーション表示中
                            Image(uiImage: screenshot)
                                .resizable()
                                .scaledToFit()
                                .offset(y: isFloating ? -10 : 0)
                                .transition(.opacity)
                        } else {
                            // 描画レイヤー（背景透明）
                            ReadingDrawingCanvas(
                                canvasView: $canvasView,
                                toolPicker: $toolPicker,
                                onDrawingChanged: {
                                    hasDrawing = !canvasView.drawing.bounds.isEmpty
                                }
                            )
                            .id("drawing")
                            .transition(.opacity)
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
                            Text("描いたイラストの説明")
                                .font(.title3)
                                .fontWeight(.bold)

                            ScrollView {
                                Text("ここに描いたイラストの説明や、キャラクターからのメッセージが表示されます。\n\n自由に絵を描いて楽しんでください！")
                                    .font(.body)
                                    .foregroundColor(.primary)
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
        .navigationTitle("お絵描き - Reading")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 浮かぶアニメーションを開始
    private func startFloatingAnimation() {
        // キャンバスのスクリーンショットを取得
        guard let screenshot = captureCanvasScreenshot() else {
            print("❌ スクリーンショットの取得に失敗しました")
            return
        }

        capturedScreenshot = screenshot

        withAnimation {
            showFloatingAnimation = true
        }

        // 浮かぶアニメーション開始
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            isFloating = true
        }

        // 画像認識を実行（非同期）
        Task {
            await recognizeDrawing(screenshot: screenshot)
        }
    }

    /// 描かれた絵を認識してコンソールに出力
    @MainActor
    private func recognizeDrawing(screenshot: UIImage) async {
        let service = GeminiService(apiKey: geminiAPIKey)

        do {
            print("🔍 画像認識を開始...")
            let description = try await service.recognizeDrawing(in: screenshot)
            print("✅ 認識結果: \(description)")
        } catch {
            print("❌ 画像認識エラー: \(error)")
            print("🔧 エラー詳細: \(error.localizedDescription)")
        }
    }

    /// 浮かぶアニメーションを停止
    private func stopFloatingAnimation() {
        withAnimation {
            showFloatingAnimation = false
            isFloating = false
            capturedScreenshot = nil
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
}

struct ReadingDrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    var onDrawingChanged: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput

        // キャンバス自体の背景を透明にする
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        canvasView.delegate = context.coordinator

        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 更新処理なし
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: ReadingDrawingCanvas

        init(_ parent: ReadingDrawingCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            print("Drawing data changed")
            parent.onDrawingChanged()
        }
    }
}

#Preview {
    NavigationStack {
        ReadingCanvasView()
    }
}
