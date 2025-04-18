// 
//  CloudStorageManager.swift
//  freewrite
//
//  Created as part of iCloud migration
//

import Foundation
import SwiftUI

enum StorageType {
    case local
    case iCloud
}

class CloudStorageManager: ObservableObject {
    static let shared = CloudStorageManager()
    
    @Published var isCloudAvailable = false
    @Published var isSyncing = false
    @Published var syncError: String? = nil
    @Published var storageType: StorageType = .local
    @AppStorage("useICloudSync") var useICloudSync = false
    
    private let fileManager = FileManager.default
    private let localDocumentsDirectory: URL
    private var cloudDocumentsDirectory: URL?
    
    private var fileCoordinator: NSFileCoordinator
    private var filePresenter: NSFilePresenter?
    
    init() {
        // Local directory setup
        localDocumentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Freewrite")
        
        // Create local directory if it doesn't exist
        if !fileManager.fileExists(atPath: localDocumentsDirectory.path) {
            do {
                try fileManager.createDirectory(at: localDocumentsDirectory, withIntermediateDirectories: true)
                print("Successfully created local Freewrite directory")
            } catch {
                print("Error creating local directory: \(error)")
            }
        }
        
        // Setup file coordination for syncing
        fileCoordinator = NSFileCoordinator()
        
        // Check iCloud availability
        checkiCloudAvailability()
    }
    
    // Check if iCloud is available and setup if needed
    func checkiCloudAvailability() {
        guard let ubiquityContainerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            print("iCloud is not available")
            isCloudAvailable = false
            storageType = .local
            useICloudSync = false
            return
        }
        
        isCloudAvailable = true
        print("iCloud is available, container URL: \(ubiquityContainerURL)")
        
        // Setup iCloud Documents directory
        let iCloudDocsURL = ubiquityContainerURL.appendingPathComponent("Documents").appendingPathComponent("Freewrite")
        cloudDocumentsDirectory = iCloudDocsURL
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: iCloudDocsURL.path) {
            do {
                try fileManager.createDirectory(at: iCloudDocsURL, withIntermediateDirectories: true)
                print("Successfully created iCloud Freewrite directory")
            } catch {
                print("Error creating iCloud directory: \(error)")
                syncError = "Failed to create iCloud directory: \(error.localizedDescription)"
            }
        }
        
        // Set storage type based on user preference if cloud is available
        storageType = useICloudSync ? .iCloud : .local
        
        // Setup file presenter for iCloud directory changes
        setupFilePresenter()
    }
    
    private func setupFilePresenter() {
        guard let cloudURL = cloudDocumentsDirectory else { return }
        
        // Create a file presenter to monitor changes
        let presenter = CloudDirectoryPresenter(presentedItemURL: cloudURL)
        filePresenter = presenter
        
        // Register the presenter
        NSFileCoordinator.addFilePresenter(presenter)
    }
    
    func getActiveDocumentsDirectory() -> URL {
        return storageType == .local ? localDocumentsDirectory : (cloudDocumentsDirectory ?? localDocumentsDirectory)
    }
    
    // Migrate all files from local to iCloud storage
    func migrateLocalToCloud(completion: @escaping (Bool, String?) -> Void) {
        guard isCloudAvailable, let cloudURL = cloudDocumentsDirectory else {
            completion(false, "iCloud not available")
            return
        }
        
        isSyncing = true
        
        // Get list of local files
        do {
            let localFiles = try fileManager.contentsOfDirectory(at: localDocumentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = localFiles.filter { $0.pathExtension == "md" }
            
            print("Found \(mdFiles.count) local files to migrate")
            
            // Create a dispatch group to track all file operations
            let group = DispatchGroup()
            var errors: [String] = []
            
            for fileURL in mdFiles {
                // Get the filename
                let filename = fileURL.lastPathComponent
                let destinationURL = cloudURL.appendingPathComponent(filename)
                
                // Skip if file already exists in iCloud
                if fileManager.fileExists(atPath: destinationURL.path) {
                    continue
                }
                
                group.enter()
                // Use file coordinator for safe file operations
                fileCoordinator.coordinate(writingItemAt: destinationURL, options: .forMoving, error: nil) { newURL in
                    do {
                        try fileManager.copyItem(at: fileURL, to: newURL)
                        print("Migrated: \(filename)")
                    } catch {
                        print("Failed to migrate \(filename): \(error)")
                        errors.append(filename)
                    }
                    group.leave()
                }
            }
            
            // Wait for all operations to complete
            group.notify(queue: .main) {
                self.isSyncing = false
                self.storageType = .iCloud
                self.useICloudSync = true
                
                if errors.isEmpty {
                    completion(true, nil)
                } else {
                    let errorMsg = "Failed to migrate \(errors.count) files"
                    self.syncError = errorMsg
                    completion(false, errorMsg)
                }
            }
            
        } catch {
            isSyncing = false
            let errorMsg = "Error accessing local files: \(error.localizedDescription)"
            syncError = errorMsg
            completion(false, errorMsg)
        }
    }
    
    // Migrate from iCloud to local storage
    func migrateCloudToLocal(completion: @escaping (Bool, String?) -> Void) {
        guard let cloudURL = cloudDocumentsDirectory else {
            completion(false, "iCloud directory not setup")
            return
        }
        
        isSyncing = true
        
        do {
            let cloudFiles = try fileManager.contentsOfDirectory(at: cloudURL, includingPropertiesForKeys: nil)
            let mdFiles = cloudFiles.filter { $0.pathExtension == "md" }
            
            print("Found \(mdFiles.count) cloud files to migrate to local")
            
            // Create a dispatch group to track all file operations
            let group = DispatchGroup()
            var errors: [String] = []
            
            for fileURL in mdFiles {
                // Get the filename
                let filename = fileURL.lastPathComponent
                let destinationURL = localDocumentsDirectory.appendingPathComponent(filename)
                
                // Skip if file already exists locally
                if fileManager.fileExists(atPath: destinationURL.path) {
                    continue
                }
                
                group.enter()
                fileCoordinator.coordinate(readingItemAt: fileURL, options: [], error: nil) { (url) in
                    do {
                        try fileManager.copyItem(at: url, to: destinationURL)
                        print("Migrated to local: \(filename)")
                    } catch {
                        print("Failed to migrate to local \(filename): \(error)")
                        errors.append(filename)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.isSyncing = false
                self.storageType = .local
                self.useICloudSync = false
                
                if errors.isEmpty {
                    completion(true, nil)
                } else {
                    let errorMsg = "Failed to migrate \(errors.count) files to local"
                    self.syncError = errorMsg
                    completion(false, errorMsg)
                }
            }
            
        } catch {
            isSyncing = false
            let errorMsg = "Error accessing cloud files: \(error.localizedDescription)"
            syncError = errorMsg
            completion(false, errorMsg)
        }
    }
    
    // Save a file to the active storage location
    func saveFile(filename: String, content: String, completion: @escaping (Bool, Error?) -> Void) {
        let activeDirectory = getActiveDocumentsDirectory()
        let fileURL = activeDirectory.appendingPathComponent(filename)
        
        // For iCloud storage, use file coordination
        if storageType == .iCloud {
            fileCoordinator.coordinate(writingItemAt: fileURL, options: [], error: nil) { (url) in
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    completion(true, nil)
                } catch {
                    print("Error saving file to iCloud: \(error)")
                    completion(false, error)
                }
            }
        } else {
            // For local storage, direct file operation
            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                completion(true, nil)
            } catch {
                print("Error saving file locally: \(error)")
                completion(false, error)
            }
        }
    }
    
    // Load a file from the active storage location
    func loadFile(filename: String, completion: @escaping (String?, Error?) -> Void) {
        let activeDirectory = getActiveDocumentsDirectory()
        let fileURL = activeDirectory.appendingPathComponent(filename)
        
        // Check if file exists
        if !fileManager.fileExists(atPath: fileURL.path) {
            completion(nil, NSError(domain: "CloudStorageManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"]))
            return
        }
        
        // For iCloud storage, use file coordination
        if storageType == .iCloud {
            fileCoordinator.coordinate(readingItemAt: fileURL, options: [], error: nil) { (url) in
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    completion(content, nil)
                } catch {
                    print("Error loading file from iCloud: \(error)")
                    completion(nil, error)
                }
            }
        } else {
            // For local storage, direct file operation
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                completion(content, nil)
            } catch {
                print("Error loading file locally: \(error)")
                completion(nil, error)
            }
        }
    }
    
    // Get a list of all markdown files in the active storage
    func listFiles(completion: @escaping ([URL]?, Error?) -> Void) {
        let activeDirectory = getActiveDocumentsDirectory()
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: activeDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }
            completion(mdFiles, nil)
        } catch {
            print("Error listing files: \(error)")
            completion(nil, error)
        }
    }
    
    // Delete a file from the active storage location
    func deleteFile(filename: String, completion: @escaping (Bool, Error?) -> Void) {
        let activeDirectory = getActiveDocumentsDirectory()
        let fileURL = activeDirectory.appendingPathComponent(filename)
        
        // For iCloud storage, use file coordination
        if storageType == .iCloud {
            fileCoordinator.coordinate(writingItemAt: fileURL, options: .forDeleting, error: nil) { (url) in
                do {
                    try fileManager.removeItem(at: url)
                    completion(true, nil)
                } catch {
                    print("Error deleting file from iCloud: \(error)")
                    completion(false, error)
                }
            }
        } else {
            // For local storage, direct file operation
            do {
                try fileManager.removeItem(at: fileURL)
                completion(true, nil)
            } catch {
                print("Error deleting file locally: \(error)")
                completion(false, error)
            }
        }
    }
    
    // Clean up on deinit
    deinit {
        if let presenter = filePresenter {
            NSFileCoordinator.removeFilePresenter(presenter)
        }
    }
}

// File presenter to monitor iCloud changes
class CloudDirectoryPresenter: NSObject, NSFilePresenter {
    var presentedItemURL: URL?
    var presentedItemOperationQueue = OperationQueue.main
    private var lastNotificationTime: Date? = nil
    private let notificationThrottleInterval: TimeInterval = 1.0 // Throttle to at most one notification per second
    
    init(presentedItemURL: URL) {
        self.presentedItemURL = presentedItemURL
        super.init()
    }
    
    // Called when a presented item is moved or renamed
    func presentedItemDidMove(to newURL: URL) {
        presentedItemURL = newURL
        print("iCloud directory moved to: \(newURL)")
    }
    
    // Called when a presented item's contents change
    func presentedItemDidChange() {
        // Throttle notifications to prevent excessive updates
        let now = Date()
        if let lastTime = lastNotificationTime, now.timeIntervalSince(lastTime) < notificationThrottleInterval {
            // Skip this notification if it's too soon after the last one
            return
        }
        
        lastNotificationTime = now
        print("iCloud directory contents changed")
        
        // Post notification on the main thread after a short delay to allow multiple rapid changes to coalesce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard self != nil else { return }
            NotificationCenter.default.post(name: NSNotification.Name("iCloudContentDidChange"), object: nil)
        }
    }
    
    // Called when a presented item is about to be saved
    func savePresentedItemChanges(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
}
