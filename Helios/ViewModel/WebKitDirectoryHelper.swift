import Foundation
import WebKit

class WebKitDirectoryHelper {
	static func setupCustomDataStore(for profile: Profile) -> WKWebsiteDataStore {
		let profilePath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Helios")
			.appendingPathComponent("Profiles")
			.appendingPathComponent(profile.id.uuidString)

		let dataStore = WKWebsiteDataStore.default() // Ensure persistent storage
		return dataStore
	}
	
	static func clearProfileData(for profile: Profile) {
		let profilePath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Helios")
			.appendingPathComponent("Profiles")
			.appendingPathComponent(profile.id.uuidString)

		// Get the correct data store (no optional check needed)
		let dataStore = SessionManager.shared.getDataStore(for: profile)

		// Remove all data for the profile
		dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
			dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
				print("Cleared website data for profile: \(profile.id)")
			}
		}

		// Delete the profile directory
		try? FileManager.default.removeItem(at: profilePath)
	}
}
