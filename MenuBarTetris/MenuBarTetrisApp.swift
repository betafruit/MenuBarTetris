//
//  MenuBarTetrisApp.swift
//  MenuBarTetris
//
//  Created by BetaFruit on 3/12/24.
//

import Cocoa
import SwiftUI

@main
struct MenuBarTetrisApp: App {
    @StateObject private var game = Tetris()
    
    var body: some Scene {
        MenuBarExtra("Tetris", image: "icon") {
            GameView(game: game)
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
    }
}
