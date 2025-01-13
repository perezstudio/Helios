//
//  BrowserViewModel.swift
//  Helios
//
//  Created by Kevin Perez on 1/12/25.
//

import Foundation
import SwiftUI
import WebKit
import SwiftData
import Combine

class BrowserViewModel: ObservableObject {
	var modelContext: ModelContext?
	@Published var urlInput: String = "" // URL bar input
	@Published var currentURL: URL? = nil
	@Published var pinnedTabs: [Tab] = []
	@Published var bookmarkTabs: [Tab] = []
	@Published var normalTabs: [Tab] = []
	@Published var workspaces: [Workspace] = []
	@Published var currentWorkspace: Workspace? = nil {
		didSet {
			if let workspace = currentWorkspace {
				// Load all tabs from the workspace and filter them by type
				let allTabs = workspace.tabs
				normalTabs = allTabs.filter { $0.type == .normal }
				bookmarkTabs = allTabs.filter { $0.type == .bookmark }
				pinnedTabs = allTabs.filter { $0.type == .pinned }
				
				// Set current tab to first normal tab if it exists
				if currentTab == nil && !normalTabs.isEmpty {
					currentTab = normalTabs.first
				}
			} else {
				normalTabs = []
				bookmarkTabs = []
				pinnedTabs = []
				currentTab = nil
			}
		}
	}
	@Published var currentTab: Tab? = nil {
		didSet {
			if let currentTab = currentTab {
				// Avoid updating URL if it hasn't changed
				if urlInput != currentTab.url {
					DispatchQueue.main.async {
						self.urlInput = currentTab.url
					}
				}
				ensureWebView(for: currentTab)
			} else {
				DispatchQueue.main.async {
					self.urlInput = ""
				}
			}
		}
	}
	func setModelContext(_ context: ModelContext) {
		self.modelContext = context
		loadSavedData()  // Load data once we have the context
	}
	private var navigationDelegates: [UUID: WebViewNavigationDelegate] = [:]

	// Dictionary to manage WebView instances
	private var webViews: [UUID: WKWebView] = [:]

	// MARK: - Public Methods

	func handleUrlInput() {
		guard let currentTab = currentTab else { return }
		
		var urlString = urlInput
		if !urlString.contains("://") {
			urlString = "https://" + urlString
		}
		
		guard let url = URL(string: urlString) else { return }
		
		currentURL = url
		currentTab.url = url.absoluteString
		
		getWebView(for: currentTab).load(URLRequest(url: url))
		
		saveChanges()
	}

	func refresh() {
		currentTab.map { getWebView(for: $0).reload() }
	}

	func goBack() {
		currentTab.map { getWebView(for: $0).goBack() }
	}

	func goForward() {
		currentTab.map { getWebView(for: $0).goForward() }
	}

	
	func addNewTab(title: String = "New Tab", url: String = "about:blank", type: TabType = .normal) {
		 guard let context = modelContext else { return }
		 currentTab = nil

		 DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			 let newTab = Tab(title: title, url: url, type: type, workspace: self.currentWorkspace)
			 context.insert(newTab)
			 self.normalTabs.append(newTab)
			 self.currentTab = newTab
			 self.saveChanges()
		 }
	 }

	func deleteTab(_ tab: Tab) {
		if let index = normalTabs.firstIndex(where: { $0.id == tab.id }) {
			// Remove the WebView first
			if let webView = webViews[tab.id] {
				webView.stopLoading()
				webView.loadHTMLString("", baseURL: nil)
				webViews.removeValue(forKey: tab.id)
				navigationDelegates.removeValue(forKey: tab.id) // Clean up navigation delegate
			}
			
			// Update current tab before removing the tab
			if currentTab?.id == tab.id {
				currentTab = normalTabs.isEmpty ? nil : normalTabs[max(0, index - 1)]
			}
			
			// Remove the tab from the array
			normalTabs.remove(at: index)
			
			// Save changes after deletion
			saveChanges()
		}
	}

	func addWorkspace(name: String, icon: String, colorTheme: ColorTheme, profile: Profile?) {
		guard let context = modelContext else { return }
		let workspace = Workspace(name: name, icon: icon, colorTheme: colorTheme)
		workspace.profile = profile
		context.insert(workspace)
		workspaces.append(workspace)
		currentWorkspace = workspace
		saveChanges()
	}
	
	func updateWorkspace(_ workspace: Workspace, name: String, icon: String, colorTheme: ColorTheme, profile: Profile?) {
		workspace.name = name
		workspace.icon = icon
		workspace.colorTheme = colorTheme
		workspace.profile = profile
		saveChanges()
		
		// Force view update
		if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
			workspaces[index] = workspace
		}
	}

	func deleteWorkspace(_ workspace: Workspace) {
		guard let context = modelContext else { return }
		
		// If this is the current workspace, clear it
		if currentWorkspace?.id == workspace.id {
			currentWorkspace = workspaces.first(where: { $0.id != workspace.id })
		}
		
		// Remove from context and array
		context.delete(workspace)
		workspaces.removeAll(where: { $0.id == workspace.id })
		saveChanges()
	}

	func toggleSidebar() {
		// Handle sidebar toggle logic
	}

	// MARK: - WebView Management

	private func ensureWebView(for tab: Tab) {
		if webViews[tab.id] == nil {
			print("Initializing WebView for tab: \(tab.id)")
			let configuration = WKWebViewConfiguration()
			let webView = WKWebView(frame: .zero, configuration: configuration)
			webViews[tab.id] = webView
			
			// Setup the navigation delegate
			setupWebView(webView, for: tab)
			
			// Load the URL only if we haven't loaded it before
			if let url = URL(string: tab.url), url.scheme != nil {
				print("Loading URL: \(url.absoluteString) for tab \(tab.id)")
				webView.load(URLRequest(url: url))
			} else {
				print("Loading blank page for tab: \(tab.id)")
				webView.load(URLRequest(url: URL(string: "about:blank")!))
			}
		}
	}

	func getWebView(for tab: Tab) -> WKWebView {
		ensureWebView(for: tab)
		guard let webView = webViews[tab.id] else {
			fatalError("Unexpectedly found nil WebView for tab \(tab.id). This should never happen.")
		}
		print("Returning WebView for tab: \(tab.id)")
		return webView
	}

	// MARK: - Persistence

	func saveChanges() {
		guard let context = modelContext else { return }
		do {
			try context.save()
		} catch {
			print("Failed to save changes: \(error)")
		}
	}
	
	func loadSavedData() {
		guard let context = modelContext else { return }
		do {
			// Fetch workspaces with their tabs included
			let descriptor = FetchDescriptor<Workspace>()
			let savedWorkspaces = try context.fetch(descriptor)
			self.workspaces = savedWorkspaces
			
			// If there's no current workspace but we have saved workspaces,
			// set the first one as current
			if currentWorkspace == nil && !savedWorkspaces.isEmpty {
				currentWorkspace = savedWorkspaces[0]
				
				// The didSet observer will handle loading the tabs
			}
		} catch {
			print("Failed to load saved data: \(error)")
		}
	}
	
	private func setupWebView(_ webView: WKWebView, for tab: Tab) {
		let navigationDelegate = WebViewNavigationDelegate(tab: tab) { [weak self] title in
			self?.updateTabTitle(tab, title: title)
		}
		webView.navigationDelegate = navigationDelegate
		// Store the delegate to prevent it from being deallocated
		navigationDelegates[tab.id] = navigationDelegate
	}

	private func updateTabTitle(_ tab: Tab, title: String?) {
		Task { @MainActor in
			if let title = title {
				tab.title = title
				saveChanges()
			}
		}
	}
}
