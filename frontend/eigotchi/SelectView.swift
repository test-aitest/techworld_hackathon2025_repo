//
//  SelectView.swift
//  eigotchi
//
//  Select screen for Speaking or Reading mode
//

import SwiftUI

struct SelectView: View {
    var body: some View {
        ZStack {
            // 背景画像（ロゴやデコレーションを含む）
            Image("select_background")
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()

            // ボタンエリア
            HStack(spacing: 60) {
                // Speakingボタン
                NavigationLink(destination: CanvasView()) {
                    Image("select_speaking")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 350, height: 220)
                }
                .buttonStyle(PlainButtonStyle())

                // Readingボタン
                NavigationLink(destination: ReadingCanvasView()) {
                    Image("select_reading")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 350, height: 220)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .offset(y: 50)
        .navigationBarHidden(true)
    }
}

#Preview {
    NavigationStack {
        SelectView()
    }
}
