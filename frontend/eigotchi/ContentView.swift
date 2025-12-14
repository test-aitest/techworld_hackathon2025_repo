//
//  ContentView.swift
//  eigotchi
//
//  Created by 武内公伸 on 2025/12/13.
//

import SwiftUI

struct ContentView: View {
    @State private var isAnimating = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                NavigationLink(destination: SelectView()) {
                    Image("top")
                        .resizable()
                        .scaledToFit()
                        .aspectRatio(4/3, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
                .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("画面をタップ")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                        .offset(y: isAnimating ? -10 : 0)
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    ContentView()
}
