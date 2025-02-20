//
//  SiteSettings.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//

import SwiftUI
import SwiftData

@Model
final class SiteSettings {
	@Attribute(.unique) var id: UUID
	var hostPattern: String
	@Relationship (inverse: \Profile.siteSettings) var profile: Profile?
	var usageSize: Int64 = 0
	
	// Hardware Access
	var location: PermissionState?
	var camera: PermissionState?
	var microphone: PermissionState?
	var motionSensors: PermissionState?
	var midiDevices: PermissionState?
	var usbDevices: PermissionState?
	var serialPorts: PermissionState?
	var hidDevices: PermissionState?
	
	// Content Settings
	var notifications: PermissionState?
	var javascript: PermissionState?
	var images: PermissionState?
	var popups: PermissionState?
	var intrusiveAds: PermissionState?
	var backgroundSync: PermissionState?
	var sound: SoundState?
	var automaticDownloads: PermissionState?
	var fileEditing: PermissionState?
	var clipboard: PermissionState?
	var paymentHandlers: PermissionState?
	var insecureContent: PermissionState?
	var v8Optimizer: PermissionState?
	
	// Advanced Features
	var augmentedReality: PermissionState?
	var virtualReality: PermissionState?
	var deviceUse: PermissionState?
	var windowManagement: PermissionState?
	var fonts: PermissionState?
	var pictureinpicture: PermissionState?
	var sharedTabs: PermissionState?
	
	init(hostPattern: String, profile: Profile? = nil, useDefaults: Bool = true) {
		self.id = UUID()
		self.hostPattern = hostPattern
		self.profile = profile
		
		if useDefaults {
			// Hardware Access
			self.location = .ask
			self.camera = .ask
			self.microphone = .ask
			self.motionSensors = .allow
			self.midiDevices = .ask
			self.usbDevices = .ask
			self.serialPorts = .ask
			self.hidDevices = .ask
			
			// Content Settings
			self.notifications = .block
			self.javascript = .allow
			self.images = .allow
			self.popups = .block
			self.intrusiveAds = .block
			self.backgroundSync = .allow
			self.sound = .automatic
			self.automaticDownloads = .ask
			self.fileEditing = .ask
			self.clipboard = .ask
			self.paymentHandlers = .allow
			self.insecureContent = .block
			self.v8Optimizer = .allow
			
			// Advanced Features
			self.augmentedReality = .ask
			self.virtualReality = .ask
			self.deviceUse = .ask
			self.windowManagement = .ask
			self.fonts = .ask
			self.pictureinpicture = .ask
			self.sharedTabs = .ask
		}
	}
}

// Extension for URL pattern matching
extension SiteSettings {
	func appliesTo(url: URL) -> Bool {
		guard let host = url.host else { return false }
		
		if hostPattern.hasPrefix("*.") {
			let suffix = hostPattern.dropFirst(2)
			return host.hasSuffix(String(suffix))
		} else {
			return host == hostPattern
		}
	}
}

class DefaultSettings {
	// Hardware Access
	static let location: PermissionState = .ask
	static let camera: PermissionState = .ask
	static let microphone: PermissionState = .ask
	static let motionSensors: PermissionState = .allow
	static let midiDevices: PermissionState = .ask
	static let usbDevices: PermissionState = .ask
	static let serialPorts: PermissionState = .ask
	static let hidDevices: PermissionState = .ask
	
	// Content Settings
	static let notifications: PermissionState = .block
	static let javascript: PermissionState = .allow
	static let images: PermissionState = .allow
	static let popups: PermissionState = .block
	static let intrusiveAds: PermissionState = .block
	static let backgroundSync: PermissionState = .allow
	static let sound: SoundState = .automatic
	static let automaticDownloads: PermissionState = .ask
	static let fileEditing: PermissionState = .ask
	static let clipboard: PermissionState = .ask
	static let paymentHandlers: PermissionState = .allow
	static let insecureContent: PermissionState = .block
	static let v8Optimizer: PermissionState = .allow
	
	// Advanced Features
	static let augmentedReality: PermissionState = .ask
	static let virtualReality: PermissionState = .ask
	static let deviceUse: PermissionState = .ask
	static let windowManagement: PermissionState = .ask
	static let fonts: PermissionState = .ask
	static let pictureinpicture: PermissionState = .ask
	static let sharedTabs: PermissionState = .ask
}
