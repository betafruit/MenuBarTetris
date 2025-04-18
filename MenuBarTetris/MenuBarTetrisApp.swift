//
//  MenuBarTetrisApp.swift
//  MenuBarTetris
//
//  Created by BetaFruit on 3/12/24.
//

import Cocoa
import SwiftUI
import MenuBarExtraAccess

@main
struct MenuBarTetrisApp: App {
    @StateObject private var game = Tetris()
    @State var isMenuPresented: Bool = false
    
    var body: some Scene {
        MenuBarExtra("Tetris", image: "icon") {
            GameView(game: game, isMenuPresented: $isMenuPresented)
                .fixedSize(horizontal: true, vertical: false)
                // Pause on lost focus and resume on regained focus
                .onDisappear { game.pauseUnpause(pause: true) }
                .onAppear {
                    game.pauseUnpause(pause: false)
                    game.hardDrops = UserDefaults.standard.bool(
                        forKey: "hardDrops")
                    game.startLevel = UserDefaults.standard.integer(
                        forKey: "startLevel")
                }
        }
        .menuBarExtraStyle(.window)
        .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
            // Nothing (for now) (dun dun dun)
        }
    }
}
