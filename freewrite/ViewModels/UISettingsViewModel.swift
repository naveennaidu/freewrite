// Swift 5.0
//
//  UISettingsViewModel.swift
//  freewrite
//
//  Created for freewrite refactoring
//

import SwiftUI
import AppKit

class UISettingsViewModel: ObservableObject {
    @Published var isFullscreen = false
    @Published var selectedFont: String
    @Published var currentRandomFont: String = ""
    @Published var fontSize: CGFloat
    @Published var colorScheme: ColorScheme
    
    // Bottom navigation bar states
    @Published var bottomNavOpacity: Double = 1.0
    @Published var isHoveringBottomNav = false
    
    // Font hover states
    @Published var isHoveringSize = false
    @Published var hoveredFont: String? = nil
    
    // Button hover states
    @Published var isHoveringFullscreen = false
    @Published var isHoveringChat = false
    @Published var isHoveringNewEntry = false
    @Published var isHoveringThemeToggle = false
    @Published var isHoveringSync = false
    @Published var isHoveringRandom = false
    
    // Sidebar states
    @Published var showingSidebar = false
    @Published var isHoveringHistory = false
    @Published var isHoveringHistoryText = false
    @Published var isHoveringHistoryPath = false
    @Published var isHoveringHistoryArrow = false
    
    // Available fonts and sizes
    let availableFonts = NSFontManager.shared.availableFontFamilies
    let standardFonts = ["Lato-Regular", "Arial", ".AppleSystemUIFont", "Times New Roman"]
    let fontSizes: [CGFloat] = [16, 18, 20, 22, 24, 26]
    
    init() {
        // Load saved color scheme preference
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        self.colorScheme = savedScheme == "dark" ? .dark : .light
        
        // Load saved font settings or use defaults
        self.selectedFont = UserDefaults.standard.string(forKey: "selectedFont") ?? "Lato-Regular"
        self.fontSize = CGFloat(UserDefaults.standard.double(forKey: "fontSize"))
        if self.fontSize == 0 {
            self.fontSize = 18 // Default if not saved previously
        }
        
        // Set up notifications for fullscreen changes
        setupFullscreenNotifications()
    }
    
    func setupFullscreenNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isFullscreen = true
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isFullscreen = false
        }
    }
    
    func toggleTheme() {
        colorScheme = colorScheme == .light ? .dark : .light
        // Save the preference
        UserDefaults.standard.set(colorScheme == .dark ? "dark" : "light", forKey: "colorScheme")
    }
    
    func toggleFullscreen() {
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
    }
    
    func selectRandomFont() {
        if let randomFont = availableFonts.randomElement() {
            selectedFont = randomFont
            currentRandomFont = randomFont
            // Save the preference
            UserDefaults.standard.set(selectedFont, forKey: "selectedFont")
        }
    }
    
    func cycleFontSize() {
        if let currentIndex = fontSizes.firstIndex(of: fontSize) {
            let nextIndex = (currentIndex + 1) % fontSizes.count
            fontSize = fontSizes[nextIndex]
            // Save the preference
            UserDefaults.standard.set(fontSize, forKey: "fontSize")
        }
    }
    
    // MARK: - Computed Properties
    
    var fontSizeButtonTitle: String {
        return "\(Int(fontSize))px"
    }
    
    var randomButtonTitle: String {
        return currentRandomFont.isEmpty ? "Random" : "Random [\(currentRandomFont)]"
    }
    
    var lineHeight: CGFloat {
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let defaultLineHeight = getLineHeight(font: font)
        return (fontSize * 1.5) - defaultLineHeight
    }
    
    var placeholderOffset: CGFloat {
        // Instead of using calculated line height, use a simple offset
        return fontSize / 2
    }
    
    // Theme-related computed properties
    var popoverBackgroundColor: Color {
        return colorScheme == .light ? Color(NSColor.controlBackgroundColor) : Color(NSColor.darkGray)
    }
    
    var popoverTextColor: Color {
        return colorScheme == .light ? Color.primary : Color.white
    }
    
    var textColor: Color {
        return colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
    }
    
    var textHoverColor: Color {
        return colorScheme == .light ? Color.black : Color.white
    }
}

// Helper function to calculate line height
private func getLineHeight(font: NSFont) -> CGFloat {
    return font.ascender - font.descender + font.leading
}
