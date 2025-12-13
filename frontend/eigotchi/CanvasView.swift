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

            // キャンバス
            DrawingCanvas(canvasView: $canvasView, toolPicker: $toolPicker)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
