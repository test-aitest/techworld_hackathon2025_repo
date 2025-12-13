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
    
    // アニメーション用の状態変数
    @State private var isFloating = false
    
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
                    canvasView.drawing = PKDrawing()
                    isFloating = false
                }) {
                    Image(systemName: "arrow.forward")
                        .font(.title2)
                }
                Spacer().frame(width: 60)
                
                Button(action: {
                    canvasView.drawing = PKDrawing()
                    isFloating = false
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
                        
//                        Button(action: {
//                            // アクション
//                        }) {
//                            Image(systemName: "arrow.2.circlepath.circle")
//                                .font(.title2)
//                                .foregroundColor(.blue)
//                        }
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
            // WebSocketに接続
            webSocketManager.connect()
            
            if !canvasView.drawing.bounds.isEmpty {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }
        }
        .onDisappear {
            // WebSocketを切断
            webSocketManager.disconnect()
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
