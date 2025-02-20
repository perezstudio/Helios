//
//  WebsitesSettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//


import SwiftUI
import SwiftData

struct WebsitesSettingsView: View {
	@Environment(\.modelContext) var modelContext
	@Query(sort: \Profile.name) private var profiles: [Profile]
	
	@State private var selectedPermissionFeature: PermissionFeature = .location
	@State private var selectedProfile: Profile? = nil
	
	enum PermissionFeature: String, CaseIterable, Identifiable {
		// Hardware Access
		case location = "Location"
		case camera = "Camera"
		case microphone = "Microphone"
		case motionSensors = "Motion Sensors"
		case midiDevices = "MIDI Devices"
		case usbDevices = "USB Devices"
		case serialPorts = "Serial Ports"
		case hidDevices = "HID Devices"
		
		// Content Settings
		case notifications = "Notifications"
		case javascript = "JavaScript"
		case images = "Images"
		case popups = "Pop-ups"
		case intrusiveAds = "Intrusive Ads"
		case backgroundSync = "Background Sync"
		case automaticDownloads = "Automatic Downloads"
		case fileEditing = "File Editing"
		case clipboard = "Clipboard"
		case paymentHandlers = "Payment Handlers"
		case insecureContent = "Insecure Content"
		
		var id: String { rawValue }
	}
	
	var filteredSiteSettings: [SiteSettings] {
		let allSiteSettings = profiles.flatMap { $0.siteSettings }
		
		return allSiteSettings.filter { setting in
			let profileMatch = selectedProfile == nil || setting.profile == selectedProfile
			let permissionMatch = checkPermissionMatch(for: setting)
			
			return profileMatch && permissionMatch
		}
	}
	
	private func checkPermissionMatch(for setting: SiteSettings) -> Bool {
		switch selectedPermissionFeature {
		case .location: return setting.location != nil
		case .camera: return setting.camera != nil
		case .microphone: return setting.microphone != nil
		case .motionSensors: return setting.motionSensors != nil
		case .midiDevices: return setting.midiDevices != nil
		case .usbDevices: return setting.usbDevices != nil
		case .serialPorts: return setting.serialPorts != nil
		case .hidDevices: return setting.hidDevices != nil
		case .notifications: return setting.notifications != nil
		case .javascript: return setting.javascript != nil
		case .images: return setting.images != nil
		case .popups: return setting.popups != nil
		case .intrusiveAds: return setting.intrusiveAds != nil
		case .backgroundSync: return setting.backgroundSync != nil
		case .automaticDownloads: return setting.automaticDownloads != nil
		case .fileEditing: return setting.fileEditing != nil
		case .clipboard: return setting.clipboard != nil
		case .paymentHandlers: return setting.paymentHandlers != nil
		case .insecureContent: return setting.insecureContent != nil
		}
	}
	
	private func getPermissionState(for setting: SiteSettings) -> PermissionState? {
		switch selectedPermissionFeature {
		case .location: return setting.location
		case .camera: return setting.camera
		case .microphone: return setting.microphone
		case .motionSensors: return setting.motionSensors
		case .midiDevices: return setting.midiDevices
		case .usbDevices: return setting.usbDevices
		case .serialPorts: return setting.serialPorts
		case .hidDevices: return setting.hidDevices
		case .notifications: return setting.notifications
		case .javascript: return setting.javascript
		case .images: return setting.images
		case .popups: return setting.popups
		case .intrusiveAds: return setting.intrusiveAds
		case .backgroundSync: return setting.backgroundSync
		case .automaticDownloads: return setting.automaticDownloads
		case .fileEditing: return setting.fileEditing
		case .clipboard: return setting.clipboard
		case .paymentHandlers: return setting.paymentHandlers
		case .insecureContent: return setting.insecureContent
		}
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Manage website-specific permissions across your profiles. You can set granular controls for different sites and their access levels.")
				.foregroundStyle(.secondary)
				.padding(.horizontal)
			
			HStack(alignment: .top, spacing: 20) {
				// Left side: Permission Features List
				VStack {
					List(selection: $selectedPermissionFeature) {
						Section("Hardware Access") {
							ForEach([
								PermissionFeature.location,
								.camera,
								.microphone,
								.motionSensors,
								.midiDevices,
								.usbDevices,
								.serialPorts,
								.hidDevices
							], id: \.self) { feature in
								Text(feature.rawValue)
									.tag(feature)
							}
						}
						
						Section("Content Settings") {
							ForEach([
								PermissionFeature.notifications,
								.javascript,
								.images,
								.popups,
								.intrusiveAds,
								.backgroundSync,
								.automaticDownloads,
								.fileEditing,
								.clipboard,
								.paymentHandlers,
								.insecureContent
							], id: \.self) { feature in
								Text(feature.rawValue)
									.tag(feature)
							}
						}
					}
					.listStyle(.bordered)
					
					// Filter Picker
					Picker("Profile", selection: $selectedProfile) {
						Text("All Profiles").tag(nil as Profile?)
						ForEach(profiles, id: \.id) { profile in
							Text(profile.name).tag(profile as Profile?)
						}
					}
					.pickerStyle(.menu)
					.padding(.top, 8)
				}
				
				// Right side: Site Settings Details
				if selectedPermissionFeature != nil {
					VStack(alignment: .leading) {
						Text("\(selectedPermissionFeature.rawValue) Permissions")
							.font(.title2)
							.fontWeight(.semibold)
						
						List(filteredSiteSettings, id: \.id) { setting in
							HStack {
								VStack(alignment: .leading) {
									Text(setting.hostPattern)
										.font(.headline)
									Text(setting.profile?.name ?? "No Profile")
										.font(.subheadline)
										.foregroundStyle(.secondary)
								}
								
								Spacer()
								
								Picker("", selection: Binding(
									get: { getPermissionState(for: setting) ?? .ask },
									set: { newValue in
										switch selectedPermissionFeature {
										case .location: setting.location = newValue
										case .camera: setting.camera = newValue
										case .microphone: setting.microphone = newValue
										case .motionSensors: setting.motionSensors = newValue
										case .midiDevices: setting.midiDevices = newValue
										case .usbDevices: setting.usbDevices = newValue
										case .serialPorts: setting.serialPorts = newValue
										case .hidDevices: setting.hidDevices = newValue
										case .notifications: setting.notifications = newValue
										case .javascript: setting.javascript = newValue
										case .images: setting.images = newValue
										case .popups: setting.popups = newValue
										case .intrusiveAds: setting.intrusiveAds = newValue
										case .backgroundSync: setting.backgroundSync = newValue
										case .automaticDownloads: setting.automaticDownloads = newValue
										case .fileEditing: setting.fileEditing = newValue
										case .clipboard: setting.clipboard = newValue
										case .paymentHandlers: setting.paymentHandlers = newValue
										case .insecureContent: setting.insecureContent = newValue
										case nil: break
										}
										
										try? modelContext.save()
									}
								)) {
									ForEach(PermissionState.allCases, id: \.self) { state in
										Text(state.rawValue).tag(state)
									}
								}
								.pickerStyle(.menu)
								.frame(width: 100)
							}
							.padding(.vertical, 8)
						}
						.listStyle(.plain)
					}
					.frame(maxWidth: .infinity)
				} else {
					ContentUnavailableView(
						"Select a Permission",
						systemImage: "hand.raised",
						description: Text("Choose a permission type to see site-specific settings")
					)
					.frame(maxWidth: .infinity)
				}
			}
		}
		.padding()
		.navigationTitle("Websites")
	}
}
