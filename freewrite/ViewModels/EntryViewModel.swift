// Swift 5.0
//
//  EntryViewModel.swift
//  freewrite
//
//  Created for freewrite refactoring
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import PDFKit

class EntryViewModel: ObservableObject {
    @Published var entries: [HumanEntry] = []
    @Published var selectedEntryId: UUID? = nil
    @Published var text: String = ""
    @Published var placeholderText: String = ""
    
    @Published var pdfExporter = PDFExportViewModel()
    
    private let cloudManager = CloudStorageManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let placeholderOptions = [
        "\n\nBegin writing",
        "\n\nPick a thought and go",
        "\n\nStart typing",
        "\n\nWhat's on your mind",
        "\n\nJust start",
        "\n\nType your first thought",
        "\n\nStart with one sentence",
        "\n\nJust say it"
    ]
    
    // AI chat prompts
    private let aiChatPrompt = """
    below is my journal entry. wyt? talk through it with me like a friend. don't therpaize me and give me a whole breakdown, don't repeat my thoughts with headings. really take all of this, and tell me back stuff truly as if you're an old homie.
    
    Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.

    do not just go through every single thing i say, and say it back to me. you need to proccess everythikng is say, make connections i don't see it, and deliver it all back to me as a story that makes me feel what you think i wanna feel. thats what the best therapists do.

    ideally, you're style/tone should sound like the user themselves. it's as if the user is hearing their own tone but it should still feel different, because you have different things to say and don't just repeat back they say.

    else, start by saying, "hey, thanks for showing me this. my thoughts:"
        
    my entry:
    """
    
    private let claudePrompt = """
    Take a look at my journal entry below. I'd like you to analyze it and respond with deep insight that feels personal, not clinical.
    Imagine you're not just a friend, but a mentor who truly gets both my tech background and my psychological patterns. I want you to uncover the deeper meaning and emotional undercurrents behind my scattered thoughts.
    Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.
    Use vivid metaphors and powerful imagery to help me see what I'm really building. Organize your thoughts with meaningful headings that create a narrative journey through my ideas.
    Don't just validate my thoughts - reframe them in a way that shows me what I'm really seeking beneath the surface. Go beyond the product concepts to the emotional core of what I'm trying to solve.
    Be willing to be profound and philosophical without sounding like you're giving therapy. I want someone who can see the patterns I can't see myself and articulate them in a way that feels like an epiphany.
    Start with 'hey, thanks for showing me this. my thoughts:' and then use markdown headings to structure your response.

    Here's my journal entry:
    """
    
    init() {
        // Set up notification for iCloud changes
        NotificationCenter.default.publisher(for: NSNotification.Name("iCloudContentDidChange"))
            .sink { [weak self] _ in
                print("iCloud content changed, reloading entries")
                self?.loadExistingEntries()
            }
            .store(in: &cancellables)
        
        // Check iCloud availability and load entries
        cloudManager.checkiCloudAvailability()
        loadExistingEntries()
    }
    
    // MARK: - Entry Management
    
    func loadExistingEntries() {
        cloudManager.listFiles { [weak self] fileURLs, error in
            guard let self = self, let fileURLs = fileURLs, error == nil else {
                print("Error loading directory contents: \(error?.localizedDescription ?? "Unknown error")")
                print("Creating default entry after error")
                self?.createNewEntry()
                return
            }
            
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }
            
            print("Found \(mdFiles.count) .md files")
            
            // Process each file
            let entriesWithDates = mdFiles.compactMap { fileURL -> (entry: HumanEntry, date: Date, content: String)? in
                let filename = fileURL.lastPathComponent
                print("Processing: \(filename)")
                
                // Extract UUID and date from filename - pattern [uuid]-[yyyy-MM-dd-HH-mm-ss].md
                guard let uuidMatch = filename.range(of: "\\[(.*?)\\]", options: .regularExpression),
                      let dateMatch = filename.range(of: "\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]", options: .regularExpression),
                      let uuid = UUID(uuidString: String(filename[uuidMatch].dropFirst().dropLast())) else {
                    print("Failed to extract UUID or date from filename: \(filename)")
                    return nil
                }
                
                // Parse the date string
                let dateString = String(filename[dateMatch].dropFirst().dropLast())
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
                
                guard let fileDate = dateFormatter.date(from: dateString) else {
                    print("Failed to parse date from filename: \(filename)")
                    return nil
                }
                
                // Read file contents for preview
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let preview = content
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)
                    
                    // Format display date
                    dateFormatter.dateFormat = "MMM d"
                    let displayDate = dateFormatter.string(from: fileDate)
                    
                    return (
                        entry: HumanEntry(
                            id: uuid,
                            date: displayDate,
                            filename: filename,
                            previewText: truncated
                        ),
                        date: fileDate,
                        content: content  // Store the full content to check for welcome message
                    )
                } catch {
                    print("Error reading file: \(error)")
                    return nil
                }
            }
            
            // Sort and extract entries
            let sortedEntries = entriesWithDates
                .sorted { $0.date > $1.date }  // Sort by actual date from filename
                .map { $0.entry }
            
            DispatchQueue.main.async {
                self.entries = sortedEntries
                print("Successfully loaded and sorted \(self.entries.count) entries")
                
                // Store the current selection
                let currentEntryId = self.selectedEntryId
                
                // Check if we need to create a new entry
                if self.entries.isEmpty {
                    // First time user - create entry with welcome message
                    print("First time user, creating welcome entry")
                    self.createNewEntry()
                } else if !self.isEmptyEntryFromToday() && !self.hasOnlyWelcomeEntry(entriesWithDates: entriesWithDates) {
                    // Create a new empty entry for today if there isn't one
                    print("Creating new entry for today")
                    self.createNewEntry()
                } else {
                    // Check if we should preserve the current selection
                    if let currentId = currentEntryId, let index = self.entries.firstIndex(where: { $0.id == currentId }) {
                        // If the previously selected entry still exists, keep it selected
                        print("Preserving selected entry: \(self.entries[index].filename)")
                        self.selectedEntryId = currentId
                        self.loadEntry(entry: self.entries[index])
                    } else {
                        // Otherwise, select the first entry (most recent)
                        if let entry = self.entries.first {
                            print("Selecting most recent entry: \(entry.filename)")
                            self.selectedEntryId = entry.id
                            self.loadEntry(entry: entry)
                        }
                    }
                }
            }
        }
    }
    
    func createNewEntry() {
        let newEntry = HumanEntry.createNew()
        entries.insert(newEntry, at: 0) // Add to the beginning
        selectedEntryId = newEntry.id
        
        // If this is the first entry (entries was empty before adding this one)
        if entries.count == 1 {
            // Read welcome message from default.md
            if let defaultMessageURL = Bundle.main.url(forResource: "default", withExtension: "md"),
               let defaultMessage = try? String(contentsOf: defaultMessageURL, encoding: .utf8) {
                text = "\n\n" + defaultMessage
            }
            // Save the welcome message immediately
            saveEntry(entry: newEntry)
            // Update the preview text
            updatePreviewText(for: newEntry)
        } else {
            // Regular new entry starts with newlines
            text = "\n\n"
            // Randomize placeholder text for new entry
            placeholderText = placeholderOptions.randomElement() ?? "\n\nBegin writing"
            // Save the empty entry
            saveEntry(entry: newEntry)
        }
    }
    
    func saveEntry(entry: HumanEntry) {
        cloudManager.saveFile(filename: entry.filename, content: text) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                print("Successfully saved entry: \(entry.filename)")
                self.updatePreviewText(for: entry)  // Update preview after saving
            } else if let error = error {
                print("Error saving entry: \(error)")
            }
        }
    }
    
    func loadEntry(entry: HumanEntry) {
        cloudManager.loadFile(filename: entry.filename) { [weak self] content, error in
            guard let self = self else { return }
            
            if let content = content {
                self.text = content
                print("Successfully loaded entry: \(entry.filename)")
            } else if let error = error {
                print("Error loading entry: \(error)")
            }
        }
    }
    
    func deleteEntry(entry: HumanEntry) {
        // Delete the file from the filesystem using CloudStorageManager
        cloudManager.deleteFile(filename: entry.filename) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                print("Successfully deleted file: \(entry.filename)")
                
                // Remove the entry from the entries array
                if let index = self.entries.firstIndex(where: { $0.id == entry.id }) {
                    self.entries.remove(at: index)
                    
                    // If the deleted entry was selected, select the first entry or create a new one
                    if self.selectedEntryId == entry.id {
                        if let firstEntry = self.entries.first {
                            self.selectedEntryId = firstEntry.id
                            self.loadEntry(entry: firstEntry)
                        } else {
                            self.createNewEntry()
                        }
                    }
                }
            } else if let error = error {
                print("Error deleting file: \(error)")
            }
        }
    }
    
    func updatePreviewText(for entry: HumanEntry) {
        let documentsDirectory = cloudManager.getActiveDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let preview = content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)
            
            // Find and update the entry in the entries array
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index].previewText = truncated
            }
        } catch {
            print("Error updating preview text: \(error)")
        }
    }
    
    // MARK: - AI Chat Integration
    
    func openChatGPT() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = aiChatPrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://chat.openai.com/?m=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openClaude() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = claudePrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://claude.ai/new?q=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Export Functionality
    
    func exportEntryAsPDF(entry: HumanEntry) {
        // First make sure the current entry is saved
        if selectedEntryId == entry.id {
            saveEntry(entry: entry)
        }
        
        // Use the PDF exporter to handle the export
        if let font = NSFont(name: "Times New Roman", size: 14) {
            let lineHeight = font.ascender - font.descender + font.leading
            pdfExporter.exportEntryAsPDF(entry: entry, selectedFont: "Times New Roman", fontSize: 14, lineHeight: lineHeight)
        } else {
            pdfExporter.exportEntryAsPDF(entry: entry, selectedFont: "Times New Roman", fontSize: 14, lineHeight: 5)
        }
    }
    
    // MARK: - Helper Methods
    
//    private func createPDFFromText(text: String) -> Data? {
//        // Letter size page dimensions
//        let pageWidth: CGFloat = 612.0  // 8.5 x 72
//        let pageHeight: CGFloat = 792.0 // 11 x 72
//        let margin: CGFloat = 72.0      // 1-inch margins
//        
//        // Create PDF context
//        let pdfData = NSMutableData()
//        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)
//        
//        // Start PDF page
//        UIGraphicsBeginPDFPage()
//        
//        // Set up text attributes
//        let font = NSFont(name: "Times New Roman", size: 12) ?? .systemFont(ofSize: 12)
//        let paragraphStyle = NSMutableParagraphStyle()
//        paragraphStyle.alignment = .natural
//        paragraphStyle.lineSpacing = 5
//        
//        let attributes: [NSAttributedString.Key: Any] = [
//            .font: font,
//            .paragraphStyle: paragraphStyle,
//            .foregroundColor: NSColor.black
//        ]
//        
//        // Calculate text area
//        let textRect = CGRect(x: margin, y: margin, width: pageWidth - (margin * 2), height: pageHeight - (margin * 2))
//        
//        // Calculate line height
//        let lineHeight = getLineHeight(font: font) + paragraphStyle.lineSpacing
//        let linesPerPage = Int((pageHeight - (margin * 2)) / lineHeight)
//        
//        // Split text into lines
//        let lines = text.components(separatedBy: "\n")
//        var currentLine = 0
//        var pageCount = 1
//        
//        while currentLine < lines.count {
//            // Clear previous page if needed
//            if currentLine > 0 {
//                UIGraphicsBeginPDFPage()
//                pageCount += 1
//            }
//            
//            // Calculate how many lines we can draw on this page
//            let remainingLines = lines.count - currentLine
//            let linesToDraw = min(linesPerPage, remainingLines)
//            
//            // Draw lines for this page
//            for i in 0..<linesToDraw {
//                let lineText = lines[currentLine + i]
//                let yPosition = pageHeight - margin - CGFloat(i) * lineHeight
//                let lineRect = CGRect(x: margin, y: yPosition - font.ascender, width: pageWidth - (margin * 2), height: lineHeight)
//                
//                lineText.draw(in: lineRect, withAttributes: attributes)
//            }
//            
//            currentLine += linesToDraw
//        }
//        
//        // End PDF context
//        UIGraphicsEndPDFContext()
//        
//        return pdfData as Data
//    }
    
    private func extractTitleFromContent(_ content: String, date: String) -> String {
        // Clean up content by removing leading/trailing whitespace and newlines
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If content is empty, use "Empty Entry" as the title
        if trimmedContent.isEmpty {
            return "Empty Entry - \(date)"
        }
        
        // Try to get the first line as title
        let lines = trimmedContent.components(separatedBy: "\n")
        if let firstLine = lines.first, !firstLine.isEmpty {
            let title = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            // If first line is not empty and less than 50 chars, use it
            if !title.isEmpty && title.count <= 50 {
                return title
            }
        }
        
        // Otherwise, use "Freewrite Entry" with the date
        return "Freewrite Entry - \(date)"
    }
    
    private func hasOnlyWelcomeEntry(entriesWithDates: [(entry: HumanEntry, date: Date, content: String)]) -> Bool {
        return entries.count == 1 && entriesWithDates.first?.content.contains("Welcome to Freewrite.") == true
    }
    
    private func isEmptyEntryFromToday() -> Bool {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        
        return entries.contains { entry in
            // Convert the display date (e.g. "Mar 14") to a Date object
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            if let entryDate = dateFormatter.date(from: entry.date) {
                // Set year component to current year since our stored dates don't include year
                var components = calendar.dateComponents([.year, .month, .day], from: entryDate)
                components.year = calendar.component(.year, from: today)
                
                // Get start of day for the entry date
                if let entryDateWithYear = calendar.date(from: components) {
                    let entryDayStart = calendar.startOfDay(for: entryDateWithYear)
                    return calendar.isDate(entryDayStart, inSameDayAs: todayStart) && entry.previewText.isEmpty
                }
            }
            return false
        }
    }
}

// Helper function to calculate line height
private func getLineHeight(font: NSFont) -> CGFloat {
    return font.ascender - font.descender + font.leading
}
