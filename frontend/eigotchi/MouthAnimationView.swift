//
//  MouthAnimationView.swift
//  eigotchi
//
//  口をぱくぱく動かすアニメーションビュー
//

import SwiftUI
import PencilKit
import ImageIO

// GIFアニメーション表示用のUIViewRepresentable
struct GIFImageView: UIViewRepresentable {
    let gifName: String
    let isAnimating: Bool  // アニメーション制御用

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard let asset = NSDataAsset(name: gifName) else { return }

        if isAnimating {
            // アニメーションGIFを表示
            if uiView.image?.images == nil {
                uiView.image = UIImage.gifImageWithData(asset.data)
            }
        } else {
            // 静止画（最初のフレーム）を表示
            if let source = CGImageSourceCreateWithData(asset.data as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                uiView.image = UIImage(cgImage: cgImage)
            }
        }
    }
}

// UIImage拡張: GIFデータから画像を生成
extension UIImage {
    static func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("GIFソースの作成に失敗")
            return nil
        }

        return UIImage.animatedImageWithSource(source)
    }

    static func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [UIImage]()
        var duration: TimeInterval = 0.0

        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(cgImage: cgImage)
                images.append(image)

                // フレームの表示時間を取得
                let frameDuration = UIImage.frameDuration(at: i, source: source)
                duration += frameDuration
            }
        }

        return UIImage.animatedImage(with: images, duration: duration)
    }

    static func frameDuration(at index: Int, source: CGImageSource) -> TimeInterval {
        var frameDuration: TimeInterval = 0.1 // デフォルト

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
            return frameDuration
        }

        if let delayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? TimeInterval {
            frameDuration = delayTime
        } else if let delayTime = gifProperties[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
            frameDuration = delayTime
        }

        return frameDuration
    }
}

/// スクリーンショットを使用する口アニメーションビュー
struct MouthAnimationViewWithImage: View {
    let screenshot: UIImage
    let mouthDetection: MouthDetection?
    let openAIAPIKey: String?
    let onSpeechComplete: (() -> Void)?
    @Binding var userIsSpeaking: Bool  // ユーザーが話しているかどうか
    @Binding var isGIFAnimating: Bool  // GIFアニメーション制御
    @State private var mouthScale: CGFloat = 1.0
    @State private var isAnimating = false
    @State private var showPromptMessage = false  // 催促メッセージ表示
    @State private var ttsService: OpenAITTSService?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 検出に使ったスクリーンショットを表示（画面いっぱいに）
                Image(uiImage: screenshot)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .zIndex(0)  // 背景レイヤー

                // 口の部分を検出できた場合、アニメーションレイヤーを追加
                if let mouth = mouthDetection {
                    // 1. 元の口を白で隠す
                    Rectangle()
                        .fill(Color.white)
                        .frame(
                            width: mouth.boundingBox.width * geometry.size.width,
                            height: mouth.boundingBox.height * geometry.size.height
                        )
                        .position(
                            x: mouth.boundingBox.midX * geometry.size.width,
                            y: mouth.boundingBox.midY * geometry.size.height
                        )
                        .zIndex(1)

                    // 2. アニメーションする口を表示
                    MouthOverlayViewForImage(
                        screenshot: screenshot,
                        mouthBounds: mouth.boundingBox,
                        scale: mouthScale,
                        canvasSize: geometry.size,
                        isGIFAnimating: isGIFAnimating
                    )
                    .zIndex(2)
                }

                // 催促メッセージ（下部から表示）- 最上位レイヤー
                if showPromptMessage {
                    VStack {
                        Spacer()

                        Image("prompt_speech_bubble")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geometry.size.width * 0.8)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 30)
                            .padding(.bottom, 60)
                    }
                    .zIndex(100)  // 最上位レイヤーに表示
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            startMouthAnimation()

//            // OpenAI TTSで「こんにちは」を再生
//            if let apiKey = openAIAPIKey {
//                ttsService = OpenAITTSService(apiKey: apiKey)
//                Task {
//                    do {
//                        try await ttsService?.speak(text: "こんにちは") {
//                            // 音声再生が終了したらGIFアニメーションを停止（ビューは表示したまま）
//                            self.isGIFAnimating = false
//
//                            // 少し待ってから催促メッセージを表示
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
//                                    self.showPromptMessage = true
//                                }
//
//                                // 5秒後にメッセージを自動的に消す
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
//                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
//                                        self.showPromptMessage = false
//                                    }
//                                }
//                            }
//                        }
//                    } catch {
//                        print("TTS エラー: \(error)")
//                    }
//                }
//            }
        }
        .onDisappear {
            isAnimating = false
            ttsService?.stop()
        }
        .onChange(of: userIsSpeaking) { _, newValue in
            // ユーザーが話し始めたらメッセージを消す
            if newValue && showPromptMessage {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showPromptMessage = false
                }
            }
        }
    }

    private func startMouthAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        // ぱくぱくアニメーション（繰り返し）
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            mouthScale = 0.7  // 口を少し縮める（閉じる）
        }
    }
}

/// GIF画像を使った口アニメーション
struct MouthOverlayViewForImage: View {
    let screenshot: UIImage
    let mouthBounds: CGRect  // 正規化座標 (0.0-1.0)
    let scale: CGFloat
    let canvasSize: CGSize
    let isGIFAnimating: Bool

    var body: some View {
        GeometryReader { geometry in
            // AssetsからGIFアニメーションを読み込み
            GIFImageView(gifName: "animated_mouth2", isAnimating: isGIFAnimating)
                .frame(
                    width: mouthBounds.width * geometry.size.width,
                    height: mouthBounds.height * geometry.size.height
                )
                .scaleEffect(y: scale, anchor: .center)
                .position(
                    x: mouthBounds.midX * geometry.size.width,
                    y: mouthBounds.midY * geometry.size.height
                )
        }
    }
}

struct MouthAnimationView: View {
    let drawing: PKDrawing
    let mouthDetection: MouthDetection?
    let openAIAPIKey: String?
    let onSpeechComplete: (() -> Void)?
    @State private var mouthScale: CGFloat = 1.0
    @State private var isAnimating = false
    @State private var isGIFAnimating = true  // GIFアニメーション制御
    @State private var ttsService: OpenAITTSService?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 元の描画全体を表示
                DrawingImageView(drawing: drawing)

                // 口の部分を検出できた場合、アニメーションレイヤーを追加
                if let mouth = mouthDetection {
                    // デバッグ情報を表示（onAppearで一度だけ）
                    // let _ = print("🎯 検出された口の位置:")
                    // let _ = print("  - 中心X: \(mouth.boundingBox.midX) (画面上: \(mouth.boundingBox.midX * geometry.size.width)px)")
                    // let _ = print("  - 中心Y: \(mouth.boundingBox.midY) (画面上: \(mouth.boundingBox.midY * geometry.size.height)px)")
                    // let _ = print("  - 幅: \(mouth.boundingBox.width) (画面上: \(mouth.boundingBox.width * geometry.size.width)px)")
                    // let _ = print("  - 高さ: \(mouth.boundingBox.height) (画面上: \(mouth.boundingBox.height * geometry.size.height)px)")
                    // let _ = print("  - キャンバスサイズ: \(geometry.size)")

                    // デバッグ: 検出領域を赤い枠で表示
                    Rectangle()
                        .stroke(Color.red, lineWidth: 3)
                        .frame(
                            width: mouth.boundingBox.width * geometry.size.width,
                            height: mouth.boundingBox.height * geometry.size.height
                        )
                        .position(
                            x: mouth.boundingBox.midX * geometry.size.width,
                            y: mouth.boundingBox.midY * geometry.size.height
                        )

                    // 1. 元の口を青色で隠す（デバッグ用：白→青に変更して見やすくする）
                    Rectangle()
                        .fill(Color.blue.opacity(0.8))
                        .frame(
                            width: mouth.boundingBox.width * geometry.size.width,
                            height: mouth.boundingBox.height * geometry.size.height
                        )
                        .position(
                            x: mouth.boundingBox.midX * geometry.size.width,
                            y: mouth.boundingBox.midY * geometry.size.height
                        )

                    // 2. アニメーションする口を表示
                    MouthOverlayView(
                        drawing: drawing,
                        mouthBounds: mouth.boundingBox,
                        scale: mouthScale,
                        canvasSize: geometry.size
                    )
                }
            }
        }
        .onAppear {
            startMouthAnimation()

            // OpenAI TTSで「こんにちは」を再生
//            if let apiKey = openAIAPIKey {
//                ttsService = OpenAITTSService(apiKey: apiKey)
//                Task {
//                    do {
//                        try await ttsService?.speak(text: "こんにちは") {
//                            // 音声再生が終了したらスケールアニメーションを停止（ビューは表示したまま）
//                            self.isAnimating = false
//                        }
//                    } catch {
//                        print("TTS エラー: \(error)")
//                    }
//                }
//            }
        }
        .onDisappear {
            isAnimating = false
            ttsService?.stop()
        }
    }

    private func startMouthAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        // ぱくぱくアニメーション（繰り返し）
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            mouthScale = 0.7  // 口を少し縮める（閉じる）
        }
    }
}

/// PKDrawingを画像として表示するビュー
struct DrawingImageView: View {
    let drawing: PKDrawing

    var body: some View {
        let image = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
    }
}

/// 口の部分にオーバーレイして、スケールアニメーションを適用
struct MouthOverlayView: View {
    let drawing: PKDrawing
    let mouthBounds: CGRect  // 正規化座標 (0.0-1.0)
    let scale: CGFloat
    let canvasSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            if let mouthImage = extractMouthImage() {
                Image(uiImage: mouthImage)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: mouthBounds.width * geometry.size.width,
                        height: mouthBounds.height * geometry.size.height
                    )
                    .scaleEffect(y: scale, anchor: .center)
                    .position(
                        x: (mouthBounds.midX) * geometry.size.width,
                        y: (mouthBounds.midY) * geometry.size.height
                    )
                    // 元の描画を隠すためのブレンドモード
                    .blendMode(.normal)
            }
        }
    }

    /// 口の領域だけを切り出した画像を生成
    private func extractMouthImage() -> UIImage? {
        let fullImage = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)

        // 正規化座標を実際のピクセル座標に変換
        let imageSize = fullImage.size
        let pixelBounds = CGRect(
            x: mouthBounds.origin.x * imageSize.width,
            y: mouthBounds.origin.y * imageSize.height,
            width: mouthBounds.width * imageSize.width,
            height: mouthBounds.height * imageSize.height
        )

        // 画像から口の部分を切り出し
        guard let cgImage = fullImage.cgImage?.cropping(to: pixelBounds) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

// 口をぱくぱくさせるための拡張機能を持つCanvasView
struct AnimatedCanvasView: View {
    @Binding var canvasView: PKCanvasView
    @State private var mouthDetection: MouthDetection?
    @State private var isDetecting = false
    @State private var showAnimation = false
    @State private var geminiAPIKey: String = ""
    @State private var openAIAPIKey: String = ""

    var body: some View {
        ZStack {
            if showAnimation, let drawing = canvasView.drawing as PKDrawing? {
                MouthAnimationView(
                    drawing: drawing,
                    mouthDetection: mouthDetection,
                    openAIAPIKey: openAIAPIKey.isEmpty ? nil : openAIAPIKey,
                    onSpeechComplete: {
                        withAnimation {
                            showAnimation = false
                        }
                    }
                )
                .transition(.opacity)
            }
        }
    }

    func detectAndAnimate(apiKey: String) async {
        guard !isDetecting else { return }
        isDetecting = true
        defer { isDetecting = false }

        // Canvas描画を画像に変換
        let drawing = canvasView.drawing
        guard !drawing.bounds.isEmpty else {
            print("Drawing is empty")
            return
        }

        let image = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)

        // Gemini APIで口を検出
        let service = GeminiService(apiKey: apiKey)
        do {
            if let detection = try await service.detectMouth(in: image) {
                await MainActor.run {
                    self.mouthDetection = detection
                    withAnimation {
                        self.showAnimation = true
                    }
                }
            } else {
                print("No mouth detected")
            }
        } catch {
            print("Error detecting mouth: \(error)")
        }
    }
}
