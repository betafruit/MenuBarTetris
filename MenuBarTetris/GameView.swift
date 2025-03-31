//
//  GameView.swift
//  MenuBarTetris
//
//  Created by BetaFruit on 3/12/24.
//

import SwiftUI

struct GameView: View {
    @ObservedObject var game: Tetris
    @State private var keyRepeatTimer: Timer?
    @State private var lastKeyPressed: UInt16?
    @State private var lastEvent: NSEvent?

    var body: some View {
        VStack {
            HStack {
                if game.isInMenu {
                    HStack {
                        Button(action: { game.changeStartLevel(amount: -1) }) {
                            Text("-")
                        }.padding(.trailing, -10)
                        Spacer()
                        Text("Lvl \(game.startLevel + 1)").font(.headline)
                        Spacer()
                        Button(action: { game.changeStartLevel(amount: 1) }) {
                            Text("+")
                        }.padding(.leading, -10)
                    }
                    .frame(width: 95)

                    Spacer()

                    if game.hardDrops {
                        Button(action: {
                            game.hardDrops = false
                            UserDefaults.standard.set(
                                false, forKey: "hardDrops")
                        }) { Text("S/⏷ = Hard Drop") }.font(.system(size: 12))
                    } else {
                        Button(action: {
                            game.hardDrops = true
                            UserDefaults.standard.set(true, forKey: "hardDrops")
                        }) { Text("S/⏷ = Soft Drop") }.font(.system(size: 12))
                    }
                } else {
                    Text("Lvl \(game.level + 1)").font(.headline)

                    Spacer()

                    Text(
                        "Hi: \(UserDefaults.standard.integer(forKey: "highScore"))"
                    ).font(.headline)

                    Text("Score: \(game.score)").font(.headline)
                }
            }
            .frame(maxHeight: 10)
            .padding(.top)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Grid(horizontalSpacing: 1, verticalSpacing: 1) {  // Render the grid
                ForEach(0..<20, id: \.self) { row in
                    GridRow {
                        ForEach(0..<10, id: \.self) { column in
                            Rectangle()
                                .fill(colourCell(game.renderGrid[row][column]))
                                .frame(width: 20, height: 20)
                        }
                    }
                }
            }
            .border(Color.secondary, width: 1)
            .padding(.horizontal)

            HStack {
                if game.isInMenu {
                    Button(action: { game.newGame() }) { Text("Start Game") }
                } else {
                    Button(action: { game.endGame() }) { Text("Abandon Game") }
                }

                Spacer()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                }
            }
            .padding(.top, 8)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if !event.isARepeat {
                    self.startKeyRepeat(event: event)
                }
                return nil
            }

            NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
                self.stopKeyRepeat()
                return nil
            }
        }
    }

    func startKeyRepeat(event: NSEvent) {
        stopKeyRepeat()
        keyAction(with: event)
        lastEvent = event

        if let mapping = keyMappings[Int(event.keyCode)],
            mapping.repeatable && !(mapping.action == .drop && game.hardDrops)  // Do not repeat hard drops
        {
            keyRepeatTimer = Timer.scheduledTimer(
                withTimeInterval: 0.2, repeats: false
            ) { _ in  // Initial delay
                self.keyRepeatTimer = Timer.scheduledTimer(
                    withTimeInterval: 0.07, repeats: true
                ) { _ in  // Repeat
                    if let event = self.lastEvent {
                        self.keyAction(with: event)
                    }
                }
            }
        }
    }

    func stopKeyRepeat() {
        keyRepeatTimer?.invalidate()
        keyRepeatTimer = nil
        lastEvent = nil
    }

    func keyAction(with event: NSEvent) {
        guard let mapping = keyMappings[Int(event.keyCode)] else { return }

        switch mapping.action {
        case .moveLeft:
            game.movePiece(dir: -1)
        case .moveRight:
            game.movePiece(dir: 1)
        case .rotateLeft:
            game.rotatePiece(dir: -1)
        case .rotateRight:
            game.rotatePiece(dir: -1)
        case .drop:
            game.applyGravity(manual: true)
        case .hide:
            NSApp.hide(nil)
        }
    }

    func colourCell(_ value: Int) -> Color {
        switch value {
        case 0:
            return Color.clear
        case 1:
            return Color.cyan
        case 2:
            return Color.blue
        case 3:
            return Color.orange
        case 4:
            return Color.yellow
        case 5:
            return Color.green
        case 6:
            return Color.purple
        case 7:
            return Color.red
        case 8:
            return Color.white.opacity(0.5)
        default:
            return Color.clear
        }
    }
}

enum KeyAction {
    case moveLeft
    case moveRight
    case rotateLeft
    case rotateRight
    case drop
    case hide
}

struct KeyActionMapping {
    let action: KeyAction
    let repeatable: Bool
}

let keyMappings: [Int: KeyActionMapping] = [
    126: KeyActionMapping(action: .rotateLeft, repeatable: false),  // Up
    13: KeyActionMapping(action: .rotateLeft, repeatable: false),  // W

    123: KeyActionMapping(action: .moveLeft, repeatable: true),  // Left
    0: KeyActionMapping(action: .moveLeft, repeatable: true),  // A

    125: KeyActionMapping(action: .drop, repeatable: true),  // Down
    1: KeyActionMapping(action: .drop, repeatable: true),  // S

    124: KeyActionMapping(action: .moveRight, repeatable: true),  // Right
    2: KeyActionMapping(action: .moveRight, repeatable: true),  // D

    44: KeyActionMapping(action: .hide, repeatable: false),  // Forward Slash
    56: KeyActionMapping(action: .hide, repeatable: false),  // Shift
    58: KeyActionMapping(action: .hide, repeatable: false),  // Option
    60: KeyActionMapping(action: .hide, repeatable: false),  // Right Shift
    12: KeyActionMapping(action: .hide, repeatable: false),  // Q
]

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView(game: Tetris())
            .fixedSize()
    }
}
