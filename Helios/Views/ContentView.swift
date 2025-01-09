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
	// Shared state for URL management and web navigation
	@StateObject private var webService = WebNavigationService()
	@State private var selectedWorkspace: Workspace? = nil
	@State private var selectedTab: Tab? = nil
	
	var body: some View {
		NavigationSplitView {
			SidebarView(selectedWorkspace: $selectedWorkspace, webService: webService, selectedTab: $selectedTab)
		} detail: {
			BrowserView(selectedTab: $selectedTab)
		}
	}
}

//#Preview {
//	ContentView()
//}
