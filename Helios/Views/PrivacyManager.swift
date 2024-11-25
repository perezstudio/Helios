//
//  PrivacyManager.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import Foundation
import WebKit

class PrivacyManager {
    static let shared = PrivacyManager()
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .registerClearDataOnQuit,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerForTermination()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearBrowsingDataIfNeeded()
        }
    }
    
    private func registerForTermination() {
        // This method is called when the user enables clear data on quit
        print("Registered for termination cleanup")
    }
    
    private func clearBrowsingDataIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "clearBrowsingDataOnQuit") else { return }
        
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        // Clear all website data
        dataStore.removeData(
            ofTypes: dataTypes,
            modifiedSince: .distantPast
        ) {
            print("Cleared all browsing data")
        }
    }
    
    func clearBrowsingData() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        dataStore.removeData(
            ofTypes: dataTypes,
            modifiedSince: .distantPast
        ) {
            print("Cleared all browsing data")
        }
    }
}
