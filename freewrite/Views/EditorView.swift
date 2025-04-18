// Swift 5.0
//
//  EditorView.swift
//  freewrite
//
//  Created for freewrite refactoring
//

import AppKit
import SwiftUI

struct EditorView: View {
    @ObservedObject var entryViewModel: EntryViewModel
    @ObservedObject var uiSettings: UISettingsViewModel
    
    @FocusState private var isEditorFocused: Bool
    @State private var blinkCount = 0
    @State private var isBlinking = false
    @State private var opacity: Double = 1.0
    @State private var shouldShowGray = true
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color(uiSettings.colorScheme == .light ? .white : .black)
                .ignoresSafeArea()
            
            // Center alignment container
            HStack {
                Spacer()
                
                ZStack(alignment: .topLeading) {
                    // Text Editor with bindings for the entry content
                    TextEditor(text: Binding(
                        get: { entryViewModel.text },
                        set: { newValue in
                            // Ensure the text always starts with two newlines
                            if !newValue.hasPrefix("\n\n") {
                                entryViewModel.text = "\n\n" + newValue.trimmingCharacters(in: .newlines)
                            } else {
                                entryViewModel.text = newValue
                            }
                        }
                    ))
                    .background(Color(uiSettings.colorScheme == .light ? .white : .black))
                    .font(.custom(uiSettings.selectedFont, size: uiSettings.fontSize))
                    .foregroundColor(uiSettings.colorScheme == .light ? Color(red: 0.20, green: 0.20, blue: 0.20) : Color(red: 0.9, green: 0.9, blue: 0.9))
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .lineSpacing(uiSettings.lineHeight)
                    .frame(maxWidth: 650)
                    .id("\(uiSettings.selectedFont)-\(uiSettings.fontSize)-\(uiSettings.colorScheme)")
                    .padding(.bottom, uiSettings.bottomNavOpacity > 0 ? 68 : 0)
                    .ignoresSafeArea()
                    .colorScheme(uiSettings.colorScheme)
                    .focused($isEditorFocused)
                    .onChange(of: isEditorFocused) { newValue in
                        if newValue {
                            shouldShowGray = false
                        }
                    }
                    
                    // Placeholder text overlay
                    if entryViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entryViewModel.placeholderText.isEmpty ? "\n\nBegin writing..." : entryViewModel.placeholderText)
                            .font(.custom(uiSettings.selectedFont, size: uiSettings.fontSize))
                            .foregroundColor(uiSettings.colorScheme == .light ? .gray.opacity(0.5) : .gray.opacity(0.6))
                            .allowsHitTesting(false)
                            .frame(maxWidth: 650, alignment: .leading)
                            .offset(x: 5, y: uiSettings.placeholderOffset)
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            // Start blinking animation
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
            
            // Focus the editor when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isEditorFocused = true
            }
        }
    }
}
