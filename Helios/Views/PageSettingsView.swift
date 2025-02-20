//
//  PageSettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//

import SwiftUI
import SwiftData

struct PageSettingsView: View {
	@Environment(\.modelContext) private var modelContext
	let url: URL
	let profile: Profile?
	@Bindable var settings: SiteSettings
	
	@State private var showAddPatternSheet = false
	@State private var customPattern = ""
	@State private var currentSiteSettings: SiteSettings?
	
	var body: some View {
		Form {
			Section {
				if let host = url.host {
					Text(host)
						.fontWeight(.bold)
						.font(.headline)
					
					if currentSiteSettings == nil {
						Button("Add site-specific settings") {
							showAddPatternSheet = true
						}
					}
				}
			}
			
			Section("Usage") {
				Text(ByteCountFormatter.string(fromByteCount: Int64(settings.usageSize), countStyle: .file))
			}
			
			Section("Hardware Access") {
				Picker("Location", selection: .init(
					get: { settings.location },
					set: { settings.location = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.location.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("Camera", selection: .init(
					get: { settings.camera },
					set: { settings.camera = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.camera.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("Microphone", selection: .init(
					get: { settings.microphone },
					set: { settings.microphone = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.microphone.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("Motion Sensors", selection: .init(
					get: { settings.motionSensors },
					set: { settings.motionSensors = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.motionSensors.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
			}
			
			Section("Content Settings") {
				Picker("Notifications", selection: .init(
					get: { settings.notifications },
					set: { settings.notifications = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.notifications.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("JavaScript", selection: .init(
					get: { settings.javascript },
					set: { settings.javascript = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.javascript.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("Images", selection: .init(
					get: { settings.images },
					set: { settings.images = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.images.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("Pop-ups", selection: .init(
					get: { settings.popups },
					set: { settings.popups = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.popups.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("Sound", selection: .init(
					get: { settings.sound },
					set: { settings.sound = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.sound.rawValue))").tag(Optional<SoundState>.none)
					ForEach(SoundState.allCases, id: \.self) { state in
						Text(state.rawValue).tag(Optional(state))
					}
				}
			}
			
			Section("Security") {
				Picker("Insecure Content", selection: .init(
					get: { settings.insecureContent },
					set: { settings.insecureContent = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.insecureContent.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("Intrusive Ads", selection: .init(
					get: { settings.intrusiveAds },
					set: { settings.intrusiveAds = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.intrusiveAds.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
			}
			
			Section("Advanced Features") {
				Picker("Automatic Downloads", selection: .init(
					get: { settings.automaticDownloads },
					set: { settings.automaticDownloads = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.automaticDownloads.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("Background Sync", selection: .init(
					get: { settings.backgroundSync },
					set: { settings.backgroundSync = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.backgroundSync.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
				
				Picker("File System", selection: .init(
					get: { settings.fileEditing },
					set: { settings.fileEditing = $0 }
				)) {
					Text("Use Default (\(DefaultSettings.fileEditing.description))").tag(Optional<PermissionState>.none)
					ForEach(PermissionState.allCases, id: \.self) { state in
						Text(state.description).tag(Optional(state))
					}
				}
			}
		}
		.formStyle(.grouped)
		.onChange(of: settings) { _, _ in
			try? modelContext.save()
		}
		.sheet(isPresented: $showAddPatternSheet) {
			AddSitePatternSheet(url: url, pattern: $customPattern) { pattern in
				createSiteSettings(for: pattern)
			}
		}
	}
	
	private func createSiteSettings(for pattern: String) {
		guard let profile = profile else { return }
		
		// Create a new site settings for the specific pattern
		let newSettings = SiteSettings(hostPattern: pattern, profile: profile)
		modelContext.insert(newSettings)
		
		currentSiteSettings = newSettings
	}
}
