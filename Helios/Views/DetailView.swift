//
//  DetailView.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//

import SwiftUI
import SwiftData
import WebKit

struct DetailView: View {
	@Bindable var viewModel: BrowserViewModel
	let windowId: UUID
	@Binding var pageSettingsInspector: Bool
	@State private var showingPermissionRequest = false
	
	var body: some View {
		NavigationStack {
			ZStack {
				if let currentTab = viewModel.getSelectedTab(for: windowId) {
					WebViewContainer(webView: viewModel.getWebView(for: currentTab))
						.id(currentTab.id as UUID)
						.transition(.opacity)
						.toolbar {
							ToolbarItem(placement: .automatic) {
								Button {
									// Handle secure site action
									print("Test")
								} label: {
									Label("Secure Site", systemImage: "lock.fill")
										.foregroundStyle(Color.green)
								}
							}
							
							ToolbarItem(placement: .automatic) {
								Button {
									if let url = URL(string: currentTab.url) {
										#if os(macOS)
										NSPasteboard.general.clearContents()
										NSPasteboard.general.setString(url.absoluteString, forType: .string)
										#endif
									}
								} label: {
									Label("Copy URL", systemImage: "link")
								}
								.help("Copy URL to clipboard")
							}
							
							ToolbarItem(placement: .automatic) {
								Button {
									// Handle share action
								} label: {
									Label("Share", systemImage: "square.and.arrow.up")
								}
							}
							
							ToolbarItem(placement: .automatic) {
								Button {
									pageSettingsInspector.toggle()
								} label: {
									Label("Page Settings", systemImage: "slider.horizontal.2.square")
								}
								.badge(PermissionManager.shared.pendingRequests.count)
							}
						}
				} else {
					ContentUnavailableView(
						"No Tab Selected",
						systemImage: "magnifyingglass",
						description: Text("Please enter a URL or perform a search.")
					)
					.transition(.opacity)
				}
				
				VStack {
					Spacer()
					HStack {
						Spacer()
						PermissionRequestContainer()
							.padding()
					}
				}
			}
		}
	}
}
