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
	@Published var urlInput: String = ""
	@Published var currentURL: URL? = nil
	@Published var pinnedTabs: [Tab] = []
	@Published var bookmarkTabs: [Tab] = []
	@Published var normalTabs: [Tab] = []
	@Published var workspaces: [Workspace] = []
	
	private var tabSelectionsByWindow: [UUID: UUID] = [:]
	private var workspaceSelectionsByWindow: [UUID: UUID] = [:]
	private var currentProfile: Profile? = nil
	
	func setUrlInput(_ input: String) {
		DispatchQueue.main.async {
			self.urlInput = input
		}
	}
	
	@Published var currentWorkspace: Workspace? = nil {
		didSet {
			// Only handle profile switching here
			if let workspace = currentWorkspace,
			   workspace.profile?.id != currentProfile?.id {
				switchToProfile(workspace.profile)
			}
		}
	}
	
	private func updatePinnedTabsForProfile(_ profile: Profile?) {
		DispatchQueue.main.async {
			if let profile = profile {
				self.pinnedTabs = profile.pinnedTabs
			} else {
				self.pinnedTabs = []
			}
		}
	}
	
	func togglePin(_ tab: Tab) {
		guard let context = modelContext,
			  let profile = currentWorkspace?.profile else { return }
		
		if tab.type == .pinned {
			// Unpinning: Remove from profile's pinned tabs
			profile.pinnedTabs.removeAll { $0.id == tab.id }
			
			// Create a new normal tab in the current workspace
			let newTab = Tab(title: tab.title, url: tab.url, type: .normal, workspace: currentWorkspace)
			context.insert(newTab)
			currentWorkspace?.tabs.append(newTab)
			
			// Update view model state
			pinnedTabs.removeAll { $0.id == tab.id }
			normalTabs.append(newTab)
			
			// Delete the original pinned tab
			context.delete(tab)
		} else {
			// Pinning: Move to profile's pinned tabs
			let wasNormal = tab.type == .normal
			let wasBookmark = tab.type == .bookmark
			
			// Create new pinned tab
			let pinnedTab = Tab(title: tab.title, url: tab.url, type: .pinned)
			context.insert(pinnedTab)
			profile.pinnedTabs.append(pinnedTab)
			
			// Remove the original tab
			if wasNormal {
				normalTabs.removeAll { $0.id == tab.id }
			} else if wasBookmark {
				bookmarkTabs.removeAll { $0.id == tab.id }
			}
			
			if let workspace = tab.workspace {
				workspace.tabs.removeAll { $0.id == tab.id }
			}
			
			// Update view model state
			pinnedTabs.append(pinnedTab)
			context.delete(tab)
		}
		
		saveChanges()
	}
	
	func switchToProfile(_ profile: Profile?) {
		if profile?.id != currentProfile?.id {
			currentProfile = profile
			updatePinnedTabsForProfile(profile)
			
			// Clean up existing WebViews
			if let oldProfile = currentProfile {
				webViewsByProfile[oldProfile.id]?.removeAll()
				navigationDelegatesByProfile[oldProfile.id]?.removeAll()
			}
			
			// Create new configuration if needed
			if let profile = profile {
				_ = getOrCreateConfiguration(for: profile)
			}
		}
	}
	
	func addNewPinnedTab(title: String = "New Tab", url: String = "about:blank") {
		guard let context = modelContext,
			  let profile = currentWorkspace?.profile else { return }
		
		// Create a single pinned tab associated with the profile
		let newTab = Tab(title: title, url: url, type: .pinned)
		context.insert(newTab)
		profile.pinnedTabs.append(newTab)
		
		// Update pinned tabs view
		updatePinnedTabsForProfile(profile)
		saveChanges()
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
		guard let context = modelContext,
			  let currentWorkspace = currentWorkspace else { return }
		
		// Clear current tab selection
		currentTab = nil
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			if type == .pinned {
				// Handle pinned tabs at profile level
				self.addNewPinnedTab(title: title, url: url)
			} else {
				// Create workspace-specific tab
				let newTab = Tab(title: title, url: url, type: type, workspace: currentWorkspace)
				context.insert(newTab)
				currentWorkspace.tabs.append(newTab)
				
				// Update appropriate tabs array
				if type == .normal {
					self.normalTabs.append(newTab)
				} else if type == .bookmark {
					self.bookmarkTabs.append(newTab)
				}
				
				self.currentTab = newTab
			}
			self.saveChanges()
		}
	}
	
	func deleteTab(_ tab: Tab) {
		// Remove selections for this tab
		let affectedWindows = tabSelectionsByWindow.filter { $0.value == tab.id }.map { $0.key }
		for windowId in affectedWindows {
			tabSelectionsByWindow[windowId] = nil
		}
		
		if tab.type == .pinned {
			// Handle pinned tab deletion across all workspaces in the profile
			if let profile = tab.workspace?.profile {
				for workspace in profile.workspaces {
					workspace.tabs.removeAll { pinnedTab in
						pinnedTab.type == .pinned && pinnedTab.url == tab.url
					}
				}
				updatePinnedTabsForProfile(profile)
			}
		} else {
			// Handle normal/bookmark tab deletion
			if let workspace = tab.workspace {
				workspace.tabs.removeAll { $0.id == tab.id }
				
				if tab.type == .normal {
					normalTabs.removeAll { $0.id == tab.id }
					
					// Update current tab selection
					for windowId in affectedWindows {
						if !normalTabs.isEmpty {
							if let index = normalTabs.firstIndex(where: { $0.id == tab.id }) {
								selectTab(normalTabs[max(0, index - 1)], for: windowId)
							}
						} else {
							selectTab(nil, for: windowId)
						}
					}
				} else {
					bookmarkTabs.removeAll { $0.id == tab.id }
				}
			}
		}
		
		// Clean up WebView
		cleanupWebView(for: tab)
		
		// Delete from context
		modelContext?.delete(tab)
		saveChanges()
	}

	func addWorkspace(name: String, icon: String, colorTheme: ColorTheme, profile: Profile?) {
		guard let context = modelContext else { return }
		
		// Create workspace outside of state update
		let workspace = Workspace(name: name, icon: icon, colorTheme: colorTheme)
		workspace.profile = profile
		
		// Update context
		context.insert(workspace)
		
		// Update state asynchronously
		DispatchQueue.main.async {
			self.workspaces.append(workspace)
			if let windowId = WindowManager.shared.activeWindow {
				self.setCurrentWorkspace(workspace, for: windowId)
			}
		}
		
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
			objectWillChange.send()
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
	
	func getSelectedTab(for windowId: UUID) -> Tab? {
		guard let tabId = tabSelectionsByWindow[windowId] else { return nil }
		return (normalTabs + bookmarkTabs + pinnedTabs).first(where: { $0.id == tabId })
	}
	
	func selectTab(_ tab: Tab?, for windowId: UUID) {
		// Update backing store
		tabSelectionsByWindow[windowId] = tab?.id
		
		// Update UI state asynchronously
		DispatchQueue.main.async {
			if let tab = tab {
				self.setUrlInput(tab.url)
				self.ensureWebView(for: tab)
			} else {
				self.setUrlInput("")
			}
		}
	}
	
	func getCurrentWorkspace(for windowId: UUID) -> Workspace? {
		if let workspaceId = workspaceSelectionsByWindow[windowId] {
			return workspaces.first(where: { $0.id == workspaceId })
		}
		return workspaces.first
	}
	
	func setCurrentWorkspace(_ workspace: Workspace?, for windowId: UUID) {
		workspaceSelectionsByWindow[windowId] = workspace?.id
		
		DispatchQueue.main.async {
			if let workspace = workspace {
				// Switch profile if needed
				if workspace.profile?.id != self.currentProfile?.id {
					self.switchToProfile(workspace.profile)
				}
				
				// Update workspace-specific tabs
				self.bookmarkTabs = workspace.tabs.filter { $0.type == .bookmark }
				self.normalTabs = workspace.tabs.filter { $0.type == .normal }
				
				// Update current tab selection
				if self.getSelectedTab(for: windowId) == nil && !self.normalTabs.isEmpty {
					self.selectTab(self.normalTabs.first, for: windowId)
				}
			} else {
				self.bookmarkTabs = []
				self.normalTabs = []
				self.selectTab(nil, for: windowId)
			}
			
			self.currentWorkspace = workspace
		}
	}
	
	private func cleanupWebView(for tab: Tab) {
		let profileId = tab.workspace?.profile?.id ?? UUID()
		if let webView = webViewsByProfile[profileId]?[tab.id] {
			webView.stopLoading()
			webView.loadHTMLString("", baseURL: nil)
			webViewsByProfile[profileId]?.removeValue(forKey: tab.id)
			navigationDelegatesByProfile[profileId]?.removeValue(forKey: tab.id)
		}
	}
	
}
