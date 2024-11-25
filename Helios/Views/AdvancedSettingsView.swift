//
//  AdvancedSettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct AdvancedSettingsView: View {
	@AppStorage("enableDebugMenu") private var enableDebugMenu = false
	@AppStorage("customUserAgent") private var customUserAgent = ""
	
	var body: some View {
		Form {
			Section("Advanced Options") {
				Toggle("Enable Debug Menu", isOn: $enableDebugMenu)
				TextField("Custom User Agent:", text: $customUserAgent)
			}
		}
	}
}
