//
//  ContentView.swift
//  Helios
//
//  Created by Kevin Perez on 12/17/24.
//

import SwiftUI
import SwiftData
import WebKit

struct ContentView: View {
	@Environment(\.modelContext) var modelContext
	@Bindable var viewModel: BrowserViewModel
	@State private var windowId = WindowIdentifier()
	@State private var pageSettingsInspector: Bool = false
	@State private var columnVisibility = NavigationSplitViewVisibility.all
	
	var body: some View {
		NavigationSplitView(columnVisibility: $columnVisibility) {
			SidebarView(windowId: windowId.id, viewModel: viewModel, columnVisibility: $columnVisibility)
		} detail: {
			DetailView(viewModel: viewModel, windowId: windowId.id, pageSettingsInspector: $pageSettingsInspector)
				.toolbar {
					ToolbarItem(placement: .navigation) {
						HStack {
							if let currentTab = viewModel.currentTab {
								FaviconView(tab: currentTab, size: 16)
							}
						}
					}
				}
				.navigationTitle(viewModel.currentTab?.title ?? "Helios Browser")
				.navigationSubtitle(viewModel.currentWorkspace?.name ?? "No Workspace Selected")
		}
		.onAppear {
			viewModel.setModelContext(modelContext)
			WindowManager.shared.registerWindow(windowId.id)
		}
		.onDisappear {
			WindowManager.shared.unregisterWindow(windowId.id)
		}
		.focusedSceneValue(\.windowId, windowId.id)
		.inspector(isPresented: $pageSettingsInspector) {
			if let currentTab = viewModel.getSelectedTab(for: windowId.id),
			   let url = URL(string: currentTab.url) {
				PageSettingsView(
					url: url,
					profile: viewModel.currentWorkspace?.profile,
					settings: viewModel.getPageSettings(for: currentTab) ?? SiteSettings(hostPattern: url.host ?? "")
				)
			} else {
				Text("No tab selected")
			}
		}
		
	}
}

class WindowIdentifier: ObservableObject {
	let id = UUID()
}

//#Preview {
//    ContentView()
//}
