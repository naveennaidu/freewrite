// Swift 5.0
//
//  TimerViewModel.swift
//  freewrite
//
//  Created for freewrite refactoring
//

import SwiftUI
import Combine

class TimerViewModel: ObservableObject {
    @Published var timeRemaining: Int = 900  // 15 minutes
    @Published var timerIsRunning = false
    @Published var isHoveringTimer = false
    @Published var isHoveringClock = false
    @Published var lastClickTime: Date? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init() {
        setupTimerSubscription()
    }
    
    private func setupTimerSubscription() {
        timer
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if self.timerIsRunning && self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else if self.timeRemaining == 0 {
                    self.timerIsRunning = false
                }
            }
            .store(in: &cancellables)
    }
    
    func toggleTimer() {
        let now = Date()
        if let lastClick = lastClickTime,
           now.timeIntervalSince(lastClick) < 0.3 {
            // Double-click detected, reset timer
            timeRemaining = 900 // 15 minutes
            timerIsRunning = false
        } else {
            // Single click, toggle timer
            timerIsRunning.toggle()
        }
        lastClickTime = now
    }
    
    func resetTimer() {
        timeRemaining = 900 // 15 minutes
        timerIsRunning = false
    }
    
    // MARK: - Computed Properties
    
    var timerButtonTitle: String {
        if !timerIsRunning && timeRemaining == 900 {
            return "15:00"
        }
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func timerColor(colorScheme: ColorScheme) -> Color {
        if timerIsRunning {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : .gray.opacity(0.8)
        } else {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : (colorScheme == .light ? .gray : .gray.opacity(0.8))
        }
    }
}
