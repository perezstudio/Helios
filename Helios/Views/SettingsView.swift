//
//  SettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//


import SwiftUI
import SwiftData

struct SettingsView: View {
	private enum SettingsSection: String, CaseIterable {
		case general = "General"
		case privacy = "Privacy"
		case search = "Search"
		case websites = "Websites"
		case profiles = "Profiles"
		case advanced = "Advanced"
		
		var icon: String {
			switch self {
			case .general: return "gear"
			case .privacy: return "lock.shield"
			case .search: return "magnifyingglass"
			case .websites: return "globe"
			case .profiles: return "person.circle"
			case .advanced: return "slider.horizontal.3"
			}
		}
	}
	
	@State private var selectedSection: SettingsSection = .general
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		HSplitView {
			// Sidebar
			VStack(alignment: .leading, spacing: 0) {
				ForEach(SettingsSection.allCases, id: \.self) { section in
					Button(action: { selectedSection = section }) {
						HStack {
							Image(systemName: section.icon)
								.frame(width: 24)
							Text(section.rawValue)
							Spacer()
						}
						.contentShape(Rectangle())
						.padding(.horizontal, 8)
						.padding(.vertical, 4)
						.background(selectedSection == section ? Color.accentColor.opacity(0.2) : Color.clear)
					}
					.buttonStyle(.plain)
				}
				Spacer()
			}
			.frame(width: 200)
			.padding(.vertical)
			
			// Content
			ScrollView {
				VStack {
					switch selectedSection {
					case .general:
						GeneralSettingsView()
					case .privacy:
						PrivacySettingsView()
					case .search:
						SearchSettingsView()
					case .websites:
						WebsiteSettingsView()
					case .profiles:
						ProfileSettingsTab()
					case .advanced:
						AdvancedSettingsView()
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding()
			}
		}
		.frame(width: 600, height: 400)
	}
}

