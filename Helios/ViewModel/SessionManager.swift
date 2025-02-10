import WebKit
import SwiftUI

@Observable
class SessionManager {
	static let shared = SessionManager()
	
	private var processPoolsByProfile: [UUID: WKProcessPool] = [:]
	private var dataStoresByProfile: [UUID: WKWebsiteDataStore] = [:]
	private var configurationsByProfile: [UUID: WKWebViewConfiguration] = [:]
	private let queue = DispatchQueue(label: "com.helios.sessionmanager")
	
	private init() {}
	
	func getConfiguration(for profile: Profile?) -> WKWebViewConfiguration {
		queue.sync {
			if let profile = profile {
				return getProfileConfiguration(for: profile)
			} else {
				return createIsolatedConfiguration()
			}
		}
	}
	
	func getDataStore(for profile: Profile?) -> WKWebsiteDataStore {
		queue.sync {
			guard let profile = profile else {
				return WKWebsiteDataStore.default() // Use default if profile is nil
			}
			
			if let existingDataStore = dataStoresByProfile[profile.id] {
				return existingDataStore
			}

			let newDataStore = WebKitDirectoryHelper.setupCustomDataStore(for: profile)
			dataStoresByProfile[profile.id] = newDataStore
			return newDataStore
		}
	}
	
	private func getProfileConfiguration(for profile: Profile) -> WKWebViewConfiguration {
		// Always create a new configuration for the profile
		let config = WKWebViewConfiguration()
		
		// Get or create process pool for profile (this helps maintain cookies and session data)
		let processPool = processPoolsByProfile[profile.id] ?? {
			let pool = WKProcessPool()
			processPoolsByProfile[profile.id] = pool
			return pool
		}()
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
		config.processPool = WKProcessPool()
		config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
		
		let prefs = WKPreferences()
		prefs.javaScriptCanOpenWindowsAutomatically = true
		config.preferences = prefs
		
		return config
	}
	
	private func getOrCreateDataStore(for profile: Profile) -> WKWebsiteDataStore {
		if let existingStore = dataStoresByProfile[profile.id] {
			return existingStore
		}
		
		let dataStore = WebKitDirectoryHelper.setupCustomDataStore(for: profile)
		dataStoresByProfile[profile.id] = dataStore
		return dataStore
	}
	
	func cleanupProfile(_ profile: Profile) async {
		await MainActor.run {
			// Clean up website data
			if let dataStore = dataStoresByProfile[profile.id] {
				dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
					dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
									   for: records) {
						print("Cleaned up website data for profile: \(profile.id)")
					}
				}
			}
			
			// Remove configurations
			configurationsByProfile.removeValue(forKey: profile.id)
			processPoolsByProfile.removeValue(forKey: profile.id)
			dataStoresByProfile.removeValue(forKey: profile.id)
			
			// Clean up profile directory
			WebKitDirectoryHelper.clearProfileData(for: profile)
		}
	}
}
