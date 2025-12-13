//
//  ContentView.swift
//  eigotchi
//
//  Created by 武内公伸 on 2025/12/13.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            NavigationLink(destination: CanvasView()) {
                Image("top")
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(4/3, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
}
