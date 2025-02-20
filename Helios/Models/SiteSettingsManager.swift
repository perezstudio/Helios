//
//  SiteSettingsManager.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//

import SwiftUI
import SwiftData

@Model
class SiteSettingsManager {
	@Attribute(.unique) var id: UUID
	var profile: Profile?
	var siteSettings: [SiteSettings] = []
	
	init(profile: Profile? = nil) {
		self.id = UUID()
		self.profile = profile
	}
	
	// Get settings for a specific URL
	func getSettings(for url: URL) -> SiteSettings? {
		// First try exact match
		if let host = url.host,
		   let exactMatch = siteSettings.first(where: { $0.hostPattern == host }) {
			return exactMatch
		}
		
		// Then try wildcard matches
		if let host = url.host {
			return siteSettings.first(where: { settings in
				if settings.hostPattern.hasPrefix("*.") {
					let suffix = settings.hostPattern.dropFirst(2)
					return host.hasSuffix(String(suffix))
				}
				return false
			})
		}
		
		return nil
	}
	
	// Create or update settings for a host
	func updateSettings(for hostPattern: String, update: (SiteSettings) -> Void) {
		if let existing = siteSettings.first(where: { $0.hostPattern == hostPattern }) {
			update(existing)
		} else {
			let newSettings = SiteSettings(hostPattern: hostPattern, profile: profile)
			update(newSettings)
			siteSettings.append(newSettings)
		}
	}
}
