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
				// Handle profile switching
				switchToProfile(workspace.profile)
				
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
	private var webViewsByProfile: [UUID: [UUID: WKWebView]] = [:]
	private var navigationDelegatesByProfile: [UUID: [UUID: WebViewNavigationDelegate]] = [:]
	private var webViewConfigurations: [UUID: WKWebViewConfiguration] = [:]

	// Dictionary to manage WebView instances
	private var webViews: [UUID: WKWebView] = [:]
	
	private func getOrCreateConfiguration(for profile: Profile?) -> WKWebViewConfiguration {
		guard let profile = profile else {
			// Return default configuration for no profile
			return WKWebViewConfiguration()
		}
		
		if let existingConfig = webViewConfigurations[profile.id] {
			return existingConfig
		}
		
		// Create new configuration for profile
		let config = WKWebViewConfiguration()
		
		// Create profile-specific data store directory
		let profileDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Helios")
			.appendingPathComponent("Profiles")
			.appendingPathComponent(profile.id.uuidString)
		
		// Ensure directory exists
		try? FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
		
		// Create a non-persistent data store for complete isolation
		let dataStore = WKWebsiteDataStore.nonPersistent()
		
		// Configure preferences
		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = true
		config.preferences = preferences
		
		// Set up process pool for isolation
		let processPool = WKProcessPool()
		config.processPool = processPool
		
		// Use the isolated data store
		config.websiteDataStore = dataStore
		
		// Store configuration
		webViewConfigurations[profile.id] = config
		
		return config
	}
	
	private func getWebViewsForProfile(_ profile: Profile?) -> [UUID: WKWebView] {
		guard let profile = profile else {
			// Return or create the default webviews dictionary
			return webViewsByProfile[UUID()] ?? [:]
		}
		return webViewsByProfile[profile.id] ?? [:]
	}
	
	func cleanUpProfile(_ profile: Profile) {
		let profileId = profile.id
		
		// Remove WebViews and navigation delegates
		webViewsByProfile.removeValue(forKey: profileId)
		navigationDelegatesByProfile.removeValue(forKey: profileId)
		
		// Get the configuration before removing it
		if let config = webViewConfigurations[profileId] {
			// Clean up all website data
			let dataStore = config.websiteDataStore
			dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
				dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
								   for: records) {
					print("Cleaned up website data for profile: \(profileId)")
				}
			}
		}
		
		webViewConfigurations.removeValue(forKey: profileId)
		
		// Clean up profile data directory
		let profileDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Helios")
			.appendingPathComponent("Profiles")
			.appendingPathComponent(profileId.uuidString)
		
		try? FileManager.default.removeItem(at: profileDirectory)
	}
	
	private func cleanupProfileData(_ profile: Profile) {
		// Get the profile's web view configuration
		if let config = webViewConfigurations[profile.id] {
			let dataStore = config.websiteDataStore
			
			// Remove all types of website data
			dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
				dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
								   for: records) {
					print("Cleaned up website data for profile: \(profile.id)")
				}
			}
		}
		
		// Remove the configuration
		webViewConfigurations.removeValue(forKey: profile.id)
		
		// Remove WebViews for this profile
		webViewsByProfile.removeValue(forKey: profile.id)
		navigationDelegatesByProfile.removeValue(forKey: profile.id)
		
		// Clean up profile directory
		let profileDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Helios")
			.appendingPathComponent("Profiles")
			.appendingPathComponent(profile.id.uuidString)
		
		try? FileManager.default.removeItem(at: profileDirectory)
	}
	
	func switchToProfile(_ profile: Profile?) {
		// Clean up existing WebViews
		if let currentWorkspace = currentWorkspace,
		   let currentProfile = currentWorkspace.profile,
		   currentProfile.id != profile?.id {
			// Clear current WebViews but don't remove configurations
			webViewsByProfile[currentProfile.id]?.removeAll()
			navigationDelegatesByProfile[currentProfile.id]?.removeAll()
		}
		
		// Create new configuration if needed
		if let profile = profile {
			_ = getOrCreateConfiguration(for: profile)
		}
	}

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
		// Clear currentTab first if this is the current tab
		if currentTab?.id == tab.id {
			currentTab = nil
		}
		
		if let index = normalTabs.firstIndex(where: { $0.id == tab.id }) {
			let profileId = tab.workspace?.profile?.id ?? UUID()
			
			// Remove the WebView first
			if let webView = webViewsByProfile[profileId]?[tab.id] {
				webView.stopLoading()
				webView.loadHTMLString("", baseURL: nil)
				webViewsByProfile[profileId]?.removeValue(forKey: tab.id)
				navigationDelegatesByProfile[profileId]?.removeValue(forKey: tab.id)
			}
			
			// Remove the tab from the array
			normalTabs.remove(at: index)
			
			// Update current tab after removing the tab
			if normalTabs.isEmpty {
				currentTab = nil
			} else {
				currentTab = normalTabs[max(0, index - 1)]
			}
			
			saveChanges()
		}
	}

	func addWorkspace(name: String, icon: String, colorTheme: ColorTheme, profile: Profile?) {
		guard let context = modelContext else { return }
		let workspace = Workspace(name: name, icon: icon, colorTheme: colorTheme)
		workspace.profile = profile
		context.insert(workspace)
		workspaces.append(workspace)
		
		// Handle profile configuration when creating workspace
		if let profile = profile {
			_ = getOrCreateConfiguration(for: profile)
		}
		
		currentWorkspace = workspace
		saveChanges()
	}
	
	func updateWorkspace(_ workspace: Workspace, name: String, icon: String, colorTheme: ColorTheme, profile: Profile?) {
		let oldProfile = workspace.profile
		
		workspace.name = name
		workspace.icon = icon
		workspace.colorTheme = colorTheme
		workspace.profile = profile
		
		// If profile changed, handle the transition
		if oldProfile?.id != profile?.id {
			switchToProfile(profile)
		}
		
		saveChanges()
		
		// Force view update
		if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
			workspaces[index] = workspace
		}
	}

	func deleteWorkspace(_ workspace: Workspace) {
		guard let context = modelContext else { return }
		
		// First check if this is the last workspace
		let isLastWorkspace = workspaces.count <= 1
		
		// Reset state if this is the current workspace
		if currentWorkspace?.id == workspace.id {
			currentTab = nil
			
			// Clear arrays
			normalTabs = []
			bookmarkTabs = []
			pinnedTabs = []
		}
		
		// Clean up all WebViews for tabs in this workspace
		let profileId = workspace.profile?.id ?? UUID()
		for tab in workspace.tabs {
			if let webView = webViewsByProfile[profileId]?[tab.id] {
				webView.stopLoading()
				webView.loadHTMLString("", baseURL: nil)
				webViewsByProfile[profileId]?.removeValue(forKey: tab.id)
				navigationDelegatesByProfile[profileId]?.removeValue(forKey: tab.id)
			}
		}
		
		// Remove from context and array
		context.delete(workspace)
		workspaces.removeAll(where: { $0.id == workspace.id })
		
		// Handle current workspace update
		if isLastWorkspace {
			// If this was the last workspace, set to nil
			currentWorkspace = nil
		} else if currentWorkspace?.id == workspace.id {
			// If we deleted the current workspace and there are others, switch to another one
			currentWorkspace = workspaces.first
		}
		
		saveChanges()
	}

	func toggleSidebar() {
		// Handle sidebar toggle logic
	}

	// MARK: - WebView Management

	private func ensureWebView(for tab: Tab) {
		let profile = tab.workspace?.profile
		let profileId = profile?.id ?? UUID()
		
		// Initialize profile dictionaries if needed
		if webViewsByProfile[profileId] == nil {
			webViewsByProfile[profileId] = [:]
		}
		if navigationDelegatesByProfile[profileId] == nil {
			navigationDelegatesByProfile[profileId] = [:]
		}
		
		if webViewsByProfile[profileId]?[tab.id] == nil {
			print("Initializing WebView for tab: \(tab.id) in profile: \(profileId)")
			let configuration = getOrCreateConfiguration(for: profile)
			let webView = WKWebView(frame: .zero, configuration: configuration)
			webViewsByProfile[profileId]?[tab.id] = webView
			
			// Setup the navigation delegate
			setupWebView(webView, for: tab, profile: profile)
			
			// Load the URL
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
		let profileId = tab.workspace?.profile?.id ?? UUID()
		
		guard let webView = webViewsByProfile[profileId]?[tab.id] else {
			// Create a new WebView if one doesn't exist
			let config = getOrCreateConfiguration(for: tab.workspace?.profile)
			let webView = WKWebView(frame: .zero, configuration: config)
			
			if webViewsByProfile[profileId] == nil {
				webViewsByProfile[profileId] = [:]
			}
			webViewsByProfile[profileId]?[tab.id] = webView
			
			setupWebView(webView, for: tab, profile: tab.workspace?.profile)
			
			// Load the URL
			if let url = URL(string: tab.url), url.scheme != nil {
				webView.load(URLRequest(url: url))
			} else {
				webView.load(URLRequest(url: URL(string: "about:blank")!))
			}
			
			return webView
		}
		
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
	
	private func setupWebView(_ webView: WKWebView, for tab: Tab, profile: Profile?) {
		let profileId = profile?.id ?? UUID()
		let navigationDelegate = WebViewNavigationDelegate(
			tab: tab,
			onTitleUpdate: { [weak self] title in
				self?.updateTabTitle(tab, title: title)
			},
			onUrlUpdate: { [weak self] url in
				self?.updateUrl(url)
			}
		)
		webView.navigationDelegate = navigationDelegate
		navigationDelegatesByProfile[profileId]?[tab.id] = navigationDelegate
	}
	
	private func updateUrl(_ url: String) {
		DispatchQueue.main.async {
			self.urlInput = url
		}
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
