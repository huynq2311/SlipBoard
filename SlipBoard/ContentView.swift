//
//  ContentView.swift
//  SlipBoard
//
//  Created by huynq3 on 5/17/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        AppRootContainer(
            provider: FixtureSlipBoardSessionProvider(initialPreset: .fullDemo)
        )
    }
}

#Preview {
    ContentView()
        .frame(width: 1280, height: 820)
}
