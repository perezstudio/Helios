//
//  PrivacySettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct PrivacySettingsView: View {
	@AppStorage("blockTrackers") private var blockTrackers = true
	@AppStorage("preventCrossSiteTracking") private var preventCrossSiteTracking = true
	@AppStorage("hideIpAddress") private var hideIpAddress = false
	@AppStorage("clearBrowsingDataOnQuit") private var clearBrowsingDataOnQuit = false
	@AppStorage("sendDoNotTrack") private var sendDoNotTrack = true
	
	var body: some View {
		Form {
			Section("Website Tracking") {
				VStack(alignment: .leading, spacing: 4) {
					Toggle("Block Trackers", isOn: $blockTrackers)
					Text("Prevents websites from tracking your browsing activity")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				VStack(alignment: .leading, spacing: 4) {
					Toggle("Prevent Cross-Site Tracking", isOn: $preventCrossSiteTracking)
					Text("Stops websites from tracking you across different domains")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				VStack(alignment: .leading, spacing: 4) {
					Toggle("Send Do Not Track requests", isOn: $sendDoNotTrack)
					Text("Ask websites not to track your browsing activity")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			
			Section("Privacy Protection") {
				VStack(alignment: .leading, spacing: 4) {
					Toggle("Hide IP Address", isOn: $hideIpAddress)
					Text("Uses a generic User Agent to help protect your identity")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				VStack(alignment: .leading, spacing: 4) {
					Toggle("Clear browsing data on quit", isOn: $clearBrowsingDataOnQuit)
					Text("Automatically clears browsing history and website data when closing the browser")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			
			Section("Information") {
				VStack(alignment: .leading, spacing: 8) {
					Text("Privacy Protection")
						.font(.headline)
					Text("These settings help protect your privacy while browsing. Enabling these features may affect some website functionality, but provides better protection against tracking and data collection.")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
		}
		.formStyle(.grouped)
		.onChange(of: clearBrowsingDataOnQuit) { oldValue, newValue in
			if newValue {
				// Register for app termination notification to clear data
				NotificationCenter.default.post(
					name: .registerClearDataOnQuit,
					object: nil
				)
			}
		}
	}
}
