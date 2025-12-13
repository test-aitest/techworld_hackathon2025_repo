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
                    // キャンバスエリア（3/4）
                    DrawingCanvas(canvasView: $canvasView, toolPicker: $toolPicker)
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
                        
                        Button(action: {
                            
                        }) {
                            Image(systemName: "arrow.2.circlepath.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .frame(height: geometry.size.height / 4)
                    .background(Color(.systemGray6))
                }
            }
        }
        .navigationTitle("お絵描き")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white

        // ツールピッカーの設定
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // 必要に応じて更新処理を追加
    }
}

#Preview {
    NavigationStack {
        CanvasView()
    }
}
