// Swift 5.0
//
//  SidebarView.swift
//  freewrite
//
//  Created for freewrite refactoring
//

import SwiftUI
import AppKit

struct SidebarView: View {
    @ObservedObject var entryViewModel: EntryViewModel
    @ObservedObject var uiSettings: UISettingsViewModel
    @ObservedObject var cloudManager: CloudStorageManager
    
    @State private var hoveredEntryId: UUID? = nil
    @State private var hoveredTrashId: UUID? = nil
    @State private var hoveredExportId: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: cloudManager.getActiveDocumentsDirectory().path)
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("History")
                                .font(.system(size: 13))
                                .foregroundColor(uiSettings.isHoveringHistory ? uiSettings.textHoverColor : uiSettings.textColor)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(uiSettings.isHoveringHistory ? uiSettings.textHoverColor : uiSettings.textColor)
                        }
                        Text(cloudManager.getActiveDocumentsDirectory().path)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                uiSettings.isHoveringHistory = hovering
                
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Divider()
            
            // Entries list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(entryViewModel.entries) { entry in
                        Button(action: {
                            if entryViewModel.selectedEntryId != entry.id {
                                // Save current entry before switching
                                if let currentId = entryViewModel.selectedEntryId,
                                   let currentEntry = entryViewModel.entries.first(where: { $0.id == currentId }) {
                                    entryViewModel.saveEntry(entry: currentEntry)
                                }
                                entryViewModel.selectedEntryId = entry.id
                                entryViewModel.loadEntry(entry: entry)
                            }
                        }) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(entry.previewText)
                                            .lineLimit(1)
                                            .font(.system(size: 12))
                                            .foregroundColor(uiSettings.textHoverColor)
                                        Spacer()
                                    }
                                    Text(entry.date)
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                if hoveredEntryId == entry.id {
                                    HStack {
                                        // Export PDF button
                                        Button(action: {
                                            entryViewModel.exportEntryAsPDF(entry: entry)
                                        }) {
                                            Image(systemName: "arrow.down.circle")
                                                .font(.system(size: 11))
                                                .foregroundColor(hoveredExportId == entry.id ? 
                                                    (uiSettings.colorScheme == .light ? .black : .white) : 
                                                    (uiSettings.colorScheme == .light ? .gray : .gray.opacity(0.8)))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .help("Export entry as PDF")
                                        .onHover { hovering in
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                hoveredExportId = hovering ? entry.id : nil
                                            }
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        
                                        // Delete button
                                        Button(action: {
                                            entryViewModel.deleteEntry(entry: entry)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 12))
                                                .foregroundColor(hoveredTrashId == entry.id ? .red : .gray)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .onHover { hovering in
                                            hoveredTrashId = hovering ? entry.id : nil
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(backgroundColor(for: entry))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hoveredEntryId = hovering ? entry.id : nil
                            }
                        }
                        .onAppear {
                            NSCursor.pop()  // Reset cursor when button appears
                        }
                        .help("Click to select this entry")  // Add tooltip
                        
                        if entry.id != entryViewModel.entries.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .frame(width: 200)
        .background(Color(uiSettings.colorScheme == .light ? .white : NSColor.black))
    }
    
    private func backgroundColor(for entry: HumanEntry) -> Color {
        if entry.id == entryViewModel.selectedEntryId {
            return Color.gray.opacity(0.1)  // More subtle selection highlight
        } else if entry.id == hoveredEntryId {
            return Color.gray.opacity(0.05)  // Even more subtle hover state
        } else {
            return Color.clear
        }
    }
}
