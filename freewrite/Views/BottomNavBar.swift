// Swift 5.0
//
//  BottomNavBar.swift
//  freewrite
//
//  Created for freewrite refactoring
//

import SwiftUI
import AppKit

struct BottomNavBar: View {
    @ObservedObject var entryViewModel: EntryViewModel
    @ObservedObject var uiSettings: UISettingsViewModel
    @ObservedObject var timerViewModel: TimerViewModel
    @StateObject var cloudManager = CloudStorageManager.shared
    
    @State private var showingChatMenu = false
    @State private var showingSyncSettings = false
    @State private var syncStatusMessage: String? = nil
    
    var body: some View {
        HStack {
            // Left section - Font controls
            HStack(spacing: 8) {
                Button(uiSettings.fontSizeButtonTitle) {
                    uiSettings.cycleFontSize()
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.isHoveringSize ? uiSettings.textHoverColor : uiSettings.textColor)
                .onHover { hovering in
                    uiSettings.isHoveringSize = hovering
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button("Lato") {
                    uiSettings.selectedFont = "Lato-Regular"
                    uiSettings.currentRandomFont = ""
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.hoveredFont == "Lato" ? uiSettings.textHoverColor : uiSettings.textColor)
                .onHover { hovering in
                    uiSettings.hoveredFont = hovering ? "Lato" : nil
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button("Arial") {
                    uiSettings.selectedFont = "Arial"
                    uiSettings.currentRandomFont = ""
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.hoveredFont == "Arial" ? uiSettings.textHoverColor : uiSettings.textColor)
                .onHover { hovering in
                    uiSettings.hoveredFont = hovering ? "Arial" : nil
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button("System") {
                    uiSettings.selectedFont = ".AppleSystemUIFont"
                    uiSettings.currentRandomFont = ""
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.hoveredFont == "System" ? uiSettings.textHoverColor : uiSettings.textColor)
                .onHover { hovering in
                    uiSettings.hoveredFont = hovering ? "System" : nil
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button("Serif") {
                    uiSettings.selectedFont = "Times New Roman"
                    uiSettings.currentRandomFont = ""
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.hoveredFont == "Serif" ? uiSettings.textHoverColor : uiSettings.textColor)
                .onHover { hovering in
                    uiSettings.hoveredFont = hovering ? "Serif" : nil
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button(uiSettings.randomButtonTitle) {
                    uiSettings.selectRandomFont()
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.isHoveringBottomNav ? uiSettings.textHoverColor : uiSettings.textColor)
                .onHover { hovering in
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
            }
            .padding(8)
            .cornerRadius(6)
            
            Spacer()
            
            // Right section - Controls
            HStack(spacing: 8) {
                Button(timerViewModel.timerButtonTitle) {
                    timerViewModel.toggleTimer()
                }
                .buttonStyle(.plain)
                .foregroundColor(timerViewModel.timerColor(colorScheme: uiSettings.colorScheme))
                .onHover { hovering in
                    timerViewModel.isHoveringTimer = hovering
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button("Chat") {
                    showingChatMenu = true
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.isHoveringChat ? uiSettings.textHoverColor : uiSettings.textColor)
                .onHover { hovering in
                    uiSettings.isHoveringChat = hovering
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                .popover(isPresented: $showingChatMenu, attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0)), arrowEdge: .top) {
                    ChatMenuView(entryViewModel: entryViewModel, showingMenu: $showingChatMenu, uiSettings: uiSettings)
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button(uiSettings.isFullscreen ? "Minimize" : "Fullscreen") {
                    uiSettings.toggleFullscreen()
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.isHoveringFullscreen ? uiSettings.textHoverColor : uiSettings.textColor)
                .onHover { hovering in
                    uiSettings.isHoveringFullscreen = hovering
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button(action: {
                    entryViewModel.createNewEntry()
                }) {
                    Text("New Entry")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.isHoveringNewEntry ? uiSettings.textHoverColor : uiSettings.textColor)
                .onHover { hovering in
                    uiSettings.isHoveringNewEntry = hovering
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                // iCloud Sync button
                Button(action: {
                    showingSyncSettings = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: cloudManager.isSyncing ? "arrow.triangle.2.circlepath" : "icloud")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                        
                        if cloudManager.isSyncing {
                            Text("Syncing...")
                                .font(.system(size: 13))
                        }
                    }
                    .foregroundColor(uiSettings.isHoveringSync ? uiSettings.textHoverColor : uiSettings.textColor)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .onHover { hovering in
                    uiSettings.isHoveringSync = hovering
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                .popover(isPresented: $showingSyncSettings, attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0)), arrowEdge: .top) {
                    SyncSettingsView(cloudManager: cloudManager, uiSettings: uiSettings, loadExistingEntries: entryViewModel.loadExistingEntries)
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button(action: {
                    uiSettings.toggleTheme()
                }) {   
                    Image(systemName: uiSettings.colorScheme == .light ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(uiSettings.isHoveringThemeToggle ? uiSettings.textHoverColor : uiSettings.textColor)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    uiSettings.isHoveringThemeToggle = hovering
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                
                Text("•")
                    .foregroundColor(.gray)
                
                Button(action: {
                    uiSettings.showingSidebar.toggle()
                }) {
                    Image(systemName: "sidebar.right")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(uiSettings.isHoveringHistory ? uiSettings.textHoverColor : uiSettings.textColor)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    uiSettings.isHoveringHistory = hovering
                    uiSettings.isHoveringBottomNav = hovering
                    hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
            }
            .padding(8)
            .cornerRadius(6)
        }
        .padding()
        .background(Color(uiSettings.colorScheme == .light ? .white : .black))
        .opacity(uiSettings.bottomNavOpacity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                uiSettings.bottomNavOpacity = hovering || uiSettings.isHoveringBottomNav ? 1.0 : 0.3
            }
        }
    }
}

struct ChatMenuView: View {
    @ObservedObject var entryViewModel: EntryViewModel
    @Binding var showingMenu: Bool
    @ObservedObject var uiSettings: UISettingsViewModel
    
    var body: some View {
        if entryViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("hi. my name is farza.") {
            Text("Yo. Sorry, you can't chat with the guide lol. Please write your own entry.")
                .font(.system(size: 14))
                .foregroundColor(uiSettings.popoverTextColor)
                .frame(width: 250)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(uiSettings.popoverBackgroundColor)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
        } else if entryViewModel.text.count < 350 {
            Text("Please free write for at minimum 5 minutes first. Then click this. Trust.")
                .font(.system(size: 14))
                .foregroundColor(uiSettings.popoverTextColor)
                .frame(width: 250)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(uiSettings.popoverBackgroundColor)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
        } else {
            VStack(spacing: 0) {
                Button(action: {
                    showingMenu = false
                    entryViewModel.openChatGPT()
                }) {
                    Text("ChatGPT")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.popoverTextColor)
                
                Divider()
                
                Button(action: {
                    showingMenu = false
                    entryViewModel.openClaude()
                }) {
                    Text("Claude")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundColor(uiSettings.popoverTextColor)
            }
            .frame(width: 120)
            .background(uiSettings.popoverBackgroundColor)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
        }
    }
}

struct SyncSettingsView: View {
    @ObservedObject var cloudManager: CloudStorageManager
    @ObservedObject var uiSettings: UISettingsViewModel
    @State private var syncStatusMessage: String? = nil
    var loadExistingEntries: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("iCloud Sync Settings")
                .font(.headline)
                .padding(.bottom, 5)
            
            if cloudManager.isCloudAvailable {
                Toggle("Enable iCloud Sync", isOn: $cloudManager.useICloudSync)
                    .onChange(of: cloudManager.useICloudSync) { newValue in
                        if newValue {
                            // Migrate local files to iCloud
                            syncStatusMessage = "Migrating to iCloud..."
                            cloudManager.migrateLocalToCloud { success, message in
                                DispatchQueue.main.async {
                                    syncStatusMessage = success ? "Migration to iCloud complete" : message
                                    // Reload entries after migration
                                    loadExistingEntries()
                                }
                            }
                        } else {
                            // Migrate iCloud files to local
                            syncStatusMessage = "Migrating to local storage..."
                            cloudManager.migrateCloudToLocal { success, message in
                                DispatchQueue.main.async {
                                    syncStatusMessage = success ? "Migration to local complete" : message
                                    // Reload entries after migration
                                    loadExistingEntries()
                                }
                            }
                        }
                    }
                
                if let statusMessage = syncStatusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(cloudManager.syncError != nil ? .red : .gray)
                        .padding(.top, 5)
                }
                
                Text("Storage location: \(cloudManager.storageType == .iCloud ? "iCloud" : "Local")")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            } else {
                Text("iCloud not available on this device")
                    .foregroundColor(.gray)
                
                Text("Make sure you're signed in to iCloud in System Settings")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(width: 250)
        .background(uiSettings.popoverBackgroundColor)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }
}
