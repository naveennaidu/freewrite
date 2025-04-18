// Swift 5.0
//
//  ContentView.swift
//  freewrite
//
//  Created for freewrite refactoring
//

import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    // View Models
    @StateObject private var entryViewModel = EntryViewModel()
    @StateObject private var uiSettings = UISettingsViewModel()
    @StateObject private var timerViewModel = TimerViewModel()
    @StateObject private var cloudManager = CloudStorageManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content
            ZStack {
                // Background
                Color(uiSettings.colorScheme == .light ? .white : .black)
                    .ignoresSafeArea()
                
                // Editor
                EditorView(entryViewModel: entryViewModel, uiSettings: uiSettings)
                
                // Bottom Navigation
                VStack {
                    Spacer()
                    BottomNavBar(
                        entryViewModel: entryViewModel,
                        uiSettings: uiSettings,
                        timerViewModel: timerViewModel
                    )
                }
            }
            
            // Right sidebar (conditionally shown)
            if uiSettings.showingSidebar {
                Divider()
                SidebarView(
                    entryViewModel: entryViewModel,
                    uiSettings: uiSettings,
                    cloudManager: cloudManager
                )
            }
        }
        .frame(minWidth: 1100, minHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: uiSettings.showingSidebar)
        .preferredColorScheme(uiSettings.colorScheme)
        .onChange(of: entryViewModel.text) { _ in
            // Save current entry when text changes
            if let currentId = entryViewModel.selectedEntryId,
               let currentEntry = entryViewModel.entries.first(where: { $0.id == currentId }) {
                entryViewModel.saveEntry(entry: currentEntry)
            }
        }
    }
}
