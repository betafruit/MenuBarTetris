//
//  Tetris.swift
//  MenuBarTetris
//
//  Created by BetaFruit on 3/12/24.
//

import Foundation
import SwiftUI

class Tetris: ObservableObject {
    private var grid: [[Int]] = Array(
        repeating: Array(repeating: 0, count: 10), count: 20)  // [Rows][Columns]
    @Published var renderGrid: [[Int]] = Array(
        repeating: Array(repeating: 0, count: 10), count: 20)  // [Rows][Columns]

    private var activePiece: Int = 0
    private var activePosition: Coord = Coord(x: 0, y: 0)
    private var activeRotation: Int = 0
    private var spawnBag: [Int] = Array(0...6)

    @Published var startLevel: Int = UserDefaults.standard.integer(
        forKey: "startLevel")
    @Published var level: Int = 0
    @Published var clearedLines: Int = 0
    @Published var score: Int = 0
    @Published var hardDrops: Bool = UserDefaults.standard.bool(
        forKey: "hardDrops")

    private var timer: Timer?
    private var fastTimer: Timer?
    private var fastFlicker: Bool = false
    private var flickerLines: [Int] = []

    private var isAnimating: Bool = false
    private var isPaused: Bool = true
    @Published var isInMenu: Bool = true

    init() {}  // Ensure only one instance

    func pauseUnpause(pause: Bool) {
        if !isInMenu {  // Don't unpause on resumed focus if there is no game happening
            if pause {
                timer?.invalidate()
                isPaused = true
            } else {
                timer?.invalidate()
                let speed: TimeInterval = pow(
                    0.8 - Double(level) / 2 * 0.007, Double(level) / 2)  // Found this time curve on the wiki but it felt to fast so I didvided the level by 2
                timer = Timer.scheduledTimer(
                    withTimeInterval: speed, repeats: true
                ) { _ in  // Every time the timer activates, apply gravity and render
                    if self.isAnimating { return }
                    self.applyGravity(manual: false)
                }
                isPaused = false
            }
        }
    }

    func endGame() {
        pauseUnpause(pause: true)  // Takes care of ending the game timer
        isInMenu = true
        grid = Array(repeating: Array(repeating: 0, count: 10), count: 20)
        renderGrid = grid  // Clear the render grid so it looks like it isn't there
        if score > UserDefaults.standard.integer(forKey: "highScore") {
            UserDefaults.standard.set(score, forKey: "highScore")
        }
        score = 0
        clearedLines = 0
        level = startLevel
        fastTimer?.invalidate()
        isAnimating = false
    }

    func changeStartLevel(amount: Int) {
        let new = (startLevel + amount + 20) % 20  // Add and extra 20 because of negative modulos being annoying
        startLevel = new
        UserDefaults.standard.set(new, forKey: "startLevel")
    }

    func newGame() {
        grid = Array(repeating: Array(repeating: 0, count: 10), count: 20)
        score = 0
        clearedLines = 0
        level = startLevel
        spawnBag = Array(0...6)
        fastTimer?.invalidate()
        fastTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) {
            [weak self] _ in self?.fastLoop()
        }  // Start the timer used to blink clearing lines
        isInMenu = false
        pauseUnpause(
            pause: false
        )  // Takes care of starting the game timer at the correct speed
        isAnimating = false
        newPiece()  // Calls render when finished
    }

    func movePiece(dir: Int) {
        if isAnimating || isPaused { return }
        let newX = activePosition.x + dir
        if checkPiece(
            pos: Coord(x: newX, y: activePosition.y), rot: activeRotation)
        {
            activePosition.x = newX
        }  // Check new position before moving
        render()
    }

    func rotatePiece(dir: Int) {
        if isAnimating || isPaused { return }
        let newRot = (activeRotation + dir + 4) % 4
        if checkPiece(pos: activePosition, rot: newRot) {
            activeRotation = newRot
        }  // Check new rotation before turning, if invalid test wall kicks
        else if activePiece != 3 {  // If piece is not O, test SRS wall kicks
            let dirIndex = dir == -1 ? 0 : 1  // If turning counterclockwise use first array, otherwise use second
            let kicks =
                activePiece == 0
                ? Ikicks[dirIndex][activeRotation]
                : Vkicks[dirIndex][activeRotation]  // Use the normal wall kicks unless the piece is I

            for kick in kicks {  // Test all possible wall kicks sequentially
                let newCoord = Coord(
                    x: activePosition.x + kick.x, y: activePosition.y - kick.y)
                if checkPiece(pos: newCoord, rot: newRot) {
                    activeRotation = newRot
                    activePosition = newCoord
                    break
                }
            }
        }
        render()
    }

    func applyGravity(manual: Bool) {
        if isAnimating || isPaused { return }
        let newY = activePosition.y + 1

        if manual && hardDrops {
            activePosition.y += findLowest()  // Do not place piece yet, allow it to be moved a bit
            pauseUnpause(pause: false)  // Restart the timer so peice can be moved more
            render()
        } else if checkPiece(
            pos: Coord(x: activePosition.x, y: newY), rot: activeRotation)  // Check new position before moving, if invalid then place
        {
            activePosition.y = newY
            render()
        } else  // Place piece on grid
        {
            for coord in tetrominoes[activePiece][activeRotation] {
                let x = coord.x + activePosition.x
                let y = coord.y + activePosition.y

                if y >= 0 {
                    grid[y][x] = activePiece + 1
                }  // Just in case you rotate a piece out of grid dimensions and then it tries to place (ie: rotating the line right when it appears)
            }

            // Check for completed lines
            var completedLines: [Int] = []
            for (i, row) in grid.enumerated() {
                var complete: Bool = true
                for cell in row {
                    if cell == 0 {
                        complete = false
                        break
                    }
                }
                if complete { completedLines.append(i) }
            }
            if completedLines.count > 0 {
                flickerLines = completedLines  // The fastloop function will flicker these
                isAnimating = true
                Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) {
                    _ in  // After flickering completed lines, score points and remove them
                    self.clearFlickerLines()
                }
            }
            newPiece()
        }
    }

    private func newPiece() {
        if spawnBag.count == 0 {
            spawnBag = Array(0...6)
        }  // If the bag is empty, refill it
        let index = Int.random(
            in: 0...spawnBag.count - 1
        )  // Pick a random index from the bag
        activePiece = spawnBag[index]
        spawnBag.remove(at: index)

        activePosition = Coord(
            x: 3, y: (activePiece == 0 || activePiece == 3) ? -1 : 0)  // Spawn the O and I pieces one higher
        activeRotation = 0
        if !checkPiece(
            pos: activePosition,
            rot: activeRotation
        ) {  // End the game after a short delay if there is no room for the new piece
            isAnimating = true
            Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
                self.endGame()
            }
        }
        render()
    }

    private func fastLoop() {  // Flicker clearing lines
        fastFlicker.toggle()
        render()
        for line in flickerLines {
            renderGrid[line] =
                fastFlicker
                ? Array(repeating: 0, count: 10)
                : Array(
                    repeating: 8,
                    count: 10
                )  // Either set line to 10 clear squares or 10 grey squares
        }
    }

    private func clearFlickerLines() {
        score += [40, 100, 300, 1300][flickerLines.count - 1] * (level + 1)  // Calculate new score
        clearedLines += flickerLines.count
        let requiredLines: Int = 10 * (level - startLevel + 1)
        if clearedLines >= requiredLines && level < 20 {
            clearedLines -= requiredLines
            level += 1
            pauseUnpause(
                pause: false
            )  // Start the timer at the new speed by unpausing the already unpaused game
        }
        var offset: Int = 0  // Basically the inverse of i in the for loop below but does not increment when lines are cleared
        for i in (0...19)
            .reversed()  // Move lines down start with the lowest one and work up
        {
            if flickerLines.contains(i) {
                for j in (0...19 - offset).reversed() {
                    grid[j] =
                        j > 0 ? grid[j - 1] : Array(repeating: 0, count: 10)
                }
            }  // If the line is disappearing set every line that isn't under the disappearing one to the one above itself (set it to nothing for the top line just in case)
            else {
                offset += 1
            }
        }
        flickerLines = []  // Clear flicker lines
        isAnimating = false
        render()
    }

    private func render() {
        renderGrid = grid  // Set the render grid to the game grid

        let lowest: Int = findLowest()  // Find the position the piece will be placed

        // Draw each square in the hard drop preview
        for coord in tetrominoes[activePiece][activeRotation] {
            let x = coord.x + activePosition.x
            let y = coord.y + activePosition.y + lowest

            if y >= 0 && y < 20 && x >= 0 && x < 10 {
                renderGrid[y][x] = 8  // Set the square to be grey
            }
        }

        // Draw each square in the active piece
        for coord in tetrominoes[activePiece][activeRotation] {
            let x = coord.x + activePosition.x
            let y = coord.y + activePosition.y

            if y >= 0 && y < 20 && x >= 0 && x < 10 {
                renderGrid[y][x] = activePiece + 1  // Set the square to the active piece's colour
            }
        }
    }

    private func findLowest() -> Int {
        var col: Bool = false
        var offset: Int = 0
        while col == false {  // Check every y position until one is invalid
            if !checkPiece(
                pos: Coord(
                    x: activePosition.x, y: activePosition.y + offset + 1),
                rot: activeRotation)
            {
                col = true
            } else {
                offset += 1
            }  // Only add one to the offset when the test succeeds because the final offset should place it one square above being invalid
        }

        return offset
    }

    private func checkPiece(pos: Coord, rot: Int) -> Bool {
        for coord in tetrominoes[activePiece][rot] {  // Test each square of the current piece in its new location
            let x = coord.x + pos.x
            let y = coord.y + pos.y

            if y >= 20 || x < 0 || x >= 10 || (y >= 0 && grid[y][x] != 0) {
                return false
            }  // Allow y to be less than 0 without being out of the bounds of the array (don't consider exceeding the top of the grid as invalid)
        }
        return true
    }

    let tetrominoes: [[[Coord]]] = [
        // I
        [
            [
                Coord(x: 0, y: 1), Coord(x: 1, y: 1), Coord(x: 2, y: 1),
                Coord(x: 3, y: 1),
            ],
            [
                Coord(x: 2, y: 0), Coord(x: 2, y: 1), Coord(x: 2, y: 2),
                Coord(x: 2, y: 3),
            ],
            [
                Coord(x: 0, y: 2), Coord(x: 1, y: 2), Coord(x: 2, y: 2),
                Coord(x: 3, y: 2),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: 1, y: 1), Coord(x: 1, y: 2),
                Coord(x: 1, y: 3),
            ],
        ],
        // J
        [
            [
                Coord(x: 0, y: 0), Coord(x: 0, y: 1), Coord(x: 1, y: 1),
                Coord(x: 2, y: 1),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: 1, y: 1), Coord(x: 1, y: 2),
                Coord(x: 2, y: 0),
            ],
            [
                Coord(x: 0, y: 1), Coord(x: 1, y: 1), Coord(x: 2, y: 1),
                Coord(x: 2, y: 2),
            ],
            [
                Coord(x: 0, y: 2), Coord(x: 1, y: 0), Coord(x: 1, y: 1),
                Coord(x: 1, y: 2),
            ],
        ],
        // L
        [
            [
                Coord(x: 0, y: 1), Coord(x: 1, y: 1), Coord(x: 2, y: 0),
                Coord(x: 2, y: 1),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: 1, y: 1), Coord(x: 1, y: 2),
                Coord(x: 2, y: 2),
            ],
            [
                Coord(x: 0, y: 1), Coord(x: 0, y: 2), Coord(x: 1, y: 1),
                Coord(x: 2, y: 1),
            ],
            [
                Coord(x: 0, y: 0), Coord(x: 1, y: 0), Coord(x: 1, y: 1),
                Coord(x: 1, y: 2),
            ],
        ],
        // O
        [
            [
                Coord(x: 1, y: 1), Coord(x: 1, y: 2), Coord(x: 2, y: 1),
                Coord(x: 2, y: 2),
            ],
            [
                Coord(x: 1, y: 1), Coord(x: 1, y: 2), Coord(x: 2, y: 1),
                Coord(x: 2, y: 2),
            ],
            [
                Coord(x: 1, y: 1), Coord(x: 1, y: 2), Coord(x: 2, y: 1),
                Coord(x: 2, y: 2),
            ],
            [
                Coord(x: 1, y: 1), Coord(x: 1, y: 2), Coord(x: 2, y: 1),
                Coord(x: 2, y: 2),
            ],
        ],
        // S
        [
            [
                Coord(x: 0, y: 1), Coord(x: 1, y: 0), Coord(x: 1, y: 1),
                Coord(x: 2, y: 0),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: 1, y: 1), Coord(x: 2, y: 1),
                Coord(x: 2, y: 2),
            ],
            [
                Coord(x: 0, y: 2), Coord(x: 1, y: 1), Coord(x: 1, y: 2),
                Coord(x: 2, y: 1),
            ],
            [
                Coord(x: 0, y: 0), Coord(x: 0, y: 1), Coord(x: 1, y: 1),
                Coord(x: 1, y: 2),
            ],
        ],
        // T
        [
            [
                Coord(x: 0, y: 1), Coord(x: 1, y: 0), Coord(x: 1, y: 1),
                Coord(x: 2, y: 1),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: 1, y: 1), Coord(x: 1, y: 2),
                Coord(x: 2, y: 1),
            ],
            [
                Coord(x: 0, y: 1), Coord(x: 1, y: 1), Coord(x: 1, y: 2),
                Coord(x: 2, y: 1),
            ],
            [
                Coord(x: 0, y: 1), Coord(x: 1, y: 0), Coord(x: 1, y: 1),
                Coord(x: 1, y: 2),
            ],
        ],
        // Z
        [
            [
                Coord(x: 0, y: 0), Coord(x: 1, y: 0), Coord(x: 1, y: 1),
                Coord(x: 2, y: 1),
            ],
            [
                Coord(x: 1, y: 1), Coord(x: 1, y: 2), Coord(x: 2, y: 0),
                Coord(x: 2, y: 1),
            ],
            [
                Coord(x: 0, y: 1), Coord(x: 1, y: 1), Coord(x: 1, y: 2),
                Coord(x: 2, y: 2),
            ],
            [
                Coord(x: 0, y: 1), Coord(x: 0, y: 2), Coord(x: 1, y: 0),
                Coord(x: 1, y: 1),
            ],
        ],
    ]  // [Tetrominos][Rotations][Squares]

    let Vkicks: [[[Coord]]] = [
        // Left
        [
            [
                Coord(x: 1, y: 0), Coord(x: 1, y: 1), Coord(x: 0, y: -2),
                Coord(x: 1, y: -2),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: 1, y: -1), Coord(x: 0, y: 2),
                Coord(x: 1, y: 2),
            ],
            [
                Coord(x: -1, y: 0), Coord(x: -1, y: 1), Coord(x: 0, y: -2),
                Coord(x: -1, y: -2),
            ],
            [
                Coord(x: -1, y: 0), Coord(x: -1, y: -1), Coord(x: 0, y: 2),
                Coord(x: -1, y: 2),
            ],
        ],
        // Right
        [
            [
                Coord(x: -1, y: 0), Coord(x: -1, y: 1), Coord(x: 0, y: -2),
                Coord(x: -1, y: -2),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: 1, y: -1), Coord(x: 0, y: 2),
                Coord(x: 1, y: 2),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: 1, y: 1), Coord(x: 0, y: -2),
                Coord(x: 1, y: -2),
            ],
            [
                Coord(x: -1, y: 0), Coord(x: -1, y: -1), Coord(x: 0, y: 2),
                Coord(x: -1, y: 2),
            ],
        ],
    ]  // [Directions][ExistingRotations][Squares]

    let Ikicks: [[[Coord]]] = [
        // Left
        [
            [
                Coord(x: -1, y: 0), Coord(x: 2, y: 0), Coord(x: -1, y: 2),
                Coord(x: 2, y: -1),
            ],
            [
                Coord(x: 2, y: 0), Coord(x: -1, y: 0), Coord(x: 2, y: 1),
                Coord(x: -1, y: -2),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: -2, y: 0), Coord(x: 1, y: -2),
                Coord(x: -2, y: 1),
            ],
            [
                Coord(x: -2, y: 0), Coord(x: 1, y: 0), Coord(x: -2, y: -1),
                Coord(x: 1, y: 2),
            ],
        ],
        // Right
        [
            [
                Coord(x: -2, y: 0), Coord(x: 1, y: 0), Coord(x: -2, y: -1),
                Coord(x: 1, y: 2),
            ],
            [
                Coord(x: -1, y: 0), Coord(x: 2, y: 0), Coord(x: -1, y: 2),
                Coord(x: 2, y: -1),
            ],
            [
                Coord(x: 2, y: 0), Coord(x: -1, y: 0), Coord(x: 2, y: 1),
                Coord(x: -1, y: -2),
            ],
            [
                Coord(x: 1, y: 0), Coord(x: -2, y: 0), Coord(x: 1, y: -2),
                Coord(x: -2, y: 1),
            ],
        ],
    ]  // [Directions][ExistingRotations][Squares] but only used for the I piece
}

struct Coord {
    var x: Int
    var y: Int

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}
