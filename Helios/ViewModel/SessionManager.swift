//
//  SessionManager.swift
//  Helios
//
//  Created by Kevin Perez on 1/23/25.
//


import WebKit
import SwiftUI

@Observable class SessionManager {
	static let shared = SessionManager()
	
	private var processPoolsByProfile: [UUID: WKProcessPool] = [:]
	private var dataStoresByProfile: [UUID: WKWebsiteDataStore] = [:]
	private var configurationsByProfile: [UUID: WKWebViewConfiguration] = [:]
	private let queue = DispatchQueue(label: "com.helios.sessionmanager")
	
	private init() {}
	
	func getConfiguration(for profile: Profile?) -> WKWebViewConfiguration {
		if let profile = profile {
			return queue.sync {
				return getProfileConfiguration(for: profile)
			}
		} else {
			return createIsolatedConfiguration()
		}
	}
	
	private func getProfileConfiguration(for profile: Profile) -> WKWebViewConfiguration {
		if let existingConfig = configurationsByProfile[profile.id] {
			return existingConfig
		}
		
		// Create new configuration
		let config = WKWebViewConfiguration()
		
		// Create dedicated process pool
		let processPool = WKProcessPool()
		processPoolsByProfile[profile.id] = processPool
		config.processPool = processPool
		
		// Get or create data store
		let dataStore = getOrCreateDataStore(for: profile)
		config.websiteDataStore = dataStore
		
		// Configure preferences
		let prefs = WKPreferences()
		prefs.javaScriptCanOpenWindowsAutomatically = true
		config.preferences = prefs
		
		// Cache configuration
		configurationsByProfile[profile.id] = config
		
		return config
	}
	
	private func createIsolatedConfiguration() -> WKWebViewConfiguration {
		let config = WKWebViewConfiguration()
		
		// Create new process pool
		let processPool = WKProcessPool()
		config.processPool = processPool
		
		// Use default data store
		config.websiteDataStore = WKWebsiteDataStore.default()
		
		// Configure preferences
		let prefs = WKPreferences()
		prefs.javaScriptCanOpenWindowsAutomatically = true
		config.preferences = prefs
		
		return config
	}
	
	private func getOrCreateDataStore(for profile: Profile) -> WKWebsiteDataStore {
		if let existingStore = dataStoresByProfile[profile.id] {
			return existingStore
		}
		
		// Create a new data store
		let dataStore = WKWebsiteDataStore.default()
		dataStoresByProfile[profile.id] = dataStore
		
		return dataStore
	}
	
	func cleanupProfile(_ profile: Profile) async {
		await MainActor.run {
			// Remove configuration and process pool
			configurationsByProfile.removeValue(forKey: profile.id)
			processPoolsByProfile.removeValue(forKey: profile.id)
			
			// Clean up data store
			if let dataStore = dataStoresByProfile[profile.id] {
				// Get website data types on main actor
				let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
				
				// Create a task group for cleanup
				Task {
					do {
						try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
							dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
								dataStore.removeData(ofTypes: dataTypes, for: records) {
									self.dataStoresByProfile.removeValue(forKey: profile.id)
									continuation.resume()
								}
							}
						}
					} catch {
						print("Error cleaning up profile data: \(error)")
					}
				}
			}
		}
	}
	
	private func getProfileDirectory(for profile: Profile) -> URL {
		FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Helios")
			.appendingPathComponent("Profiles")
			.appendingPathComponent(profile.id.uuidString)
	}
}
