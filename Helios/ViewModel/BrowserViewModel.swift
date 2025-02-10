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

@Observable
class BrowserViewModel {
	var modelContext: ModelContext?
	var urlInput: String = ""
	var currentURL: URL? = nil
	var pinnedTabs: [Tab] = []
	var bookmarkTabs: [Tab] = []
	var normalTabs: [Tab] = []
	var workspaces: [Workspace] = []
	var urlBarFocused: Bool = false
	private var currentProfile: Profile? = nil
	private var webViewObservers: [UUID: NSObjectProtocol] = [:]
	
	private var tabSelectionsByWindow: [UUID: UUID] = [:]
	private var workspaceSelectionsByWindow: [UUID: UUID] = [:]
	private var webViewsByProfile: [UUID: [UUID: WKWebView]] = [:]
	private var navigationDelegatesByProfile: [UUID: [UUID: WebViewNavigationDelegate]] = [:]
	
	var currentWorkspace: Workspace? = nil {
		didSet {
			if let workspace = currentWorkspace,
			   workspace.profile?.id != currentProfile?.id {
				Task {
					await switchToProfile(workspace.profile)
				}
			}
		}
	}
	
	func togglePin(_ tab: Tab) {
		guard let context = modelContext,
			  let profile = currentWorkspace?.profile else { return }
		
		Task { @MainActor in
			if tab.type == .pinned {
				profile.pinnedTabs.removeAll { $0.id == tab.id }
				
				let newTab = Tab(title: tab.title, url: tab.url, type: .normal, workspace: currentWorkspace)
				newTab.faviconData = tab.faviconData
				context.insert(newTab)
				currentWorkspace?.tabs.append(newTab)
				
				pinnedTabs.removeAll { $0.id == tab.id }
				normalTabs.append(newTab)
				context.delete(tab)
				
			} else {
				let wasNormal = tab.type == .normal
				let wasBookmark = tab.type == .bookmark
				
				let pinnedTab = Tab(title: tab.title, url: tab.url, type: .pinned)
				pinnedTab.faviconData = tab.faviconData
				context.insert(pinnedTab)
				profile.pinnedTabs.append(pinnedTab)
				
				if wasNormal {
					normalTabs.removeAll { $0.id == tab.id }
				} else if wasBookmark {
					bookmarkTabs.removeAll { $0.id == tab.id }
				}
				
				if let workspace = tab.workspace {
					workspace.tabs.removeAll { $0.id == tab.id }
				}
				
				pinnedTabs.append(pinnedTab)
				context.delete(tab)
				ensureWebView(for: pinnedTab)
			}
			
			saveChanges()
		}
	}
	
	private func cleanupWebViewsForProfile(_ profile: Profile) async {
		let profileId = profile.id
		
		await MainActor.run {
			// Nullify all navigation delegates
			navigationDelegatesByProfile[profileId]?.forEach { tabId, delegate in
				if let observer = webViewObservers[tabId] {
					NotificationCenter.default.removeObserver(observer)
					webViewObservers.removeValue(forKey: tabId)
				}
			}
			
			// Stop all WebViews and clear their content
			webViewsByProfile[profileId]?.forEach { _, webView in
				webView.stopLoading()
				webView.loadHTMLString("", baseURL: nil)
				webView.navigationDelegate = nil
			}
			
			// Clear collections
			webViewsByProfile.removeValue(forKey: profileId)
			navigationDelegatesByProfile.removeValue(forKey: profileId)
		}
	}
	
	deinit {
		// Clean up all observers
		webViewObservers.forEach { _, observer in
			NotificationCenter.default.removeObserver(observer)
		}
	}
	
	private func recreateWebViewsForProfile(_ profile: Profile) async {
		let profileId = profile.id
		
		// Initialize collections if needed
		await MainActor.run {
			if webViewsByProfile[profileId] == nil {
				webViewsByProfile[profileId] = [:]
			}
			if navigationDelegatesByProfile[profileId] == nil {
				navigationDelegatesByProfile[profileId] = [:]
			}
		}
		
		// Get all tabs for this profile
		let allTabs = profile.pinnedTabs + (profile.workspaces.flatMap { $0.tabs })
		
		// Create WebViews sequentially to avoid overwhelming the system
		for tab in allTabs {
			await MainActor.run {
				ensureWebView(for: tab)
			}
			// Small delay between WebView creations
			try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
		}
	}
	
	var currentTab: Tab? = nil {
		didSet {
			if let currentTab = currentTab {
				if urlInput != currentTab.url {
					Task { @MainActor in
						self.urlInput = currentTab.url
					}
				}
				ensureWebView(for: currentTab)
			} else {
				Task { @MainActor in
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

	func handleUrlInput() async {
		guard let currentTab = currentTab else { return }
		
		let input = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !input.isEmpty && input != "about:blank" else { return }
		
		if looksLikeUrl(input) {
			let formattedUrl = formatUrlString(input)
			guard let url = URL(string: formattedUrl) else { return }
			
			currentURL = url
			currentTab.url = url.absoluteString
			getWebView(for: currentTab).load(URLRequest(url: url))
		} else {
			handleSearch(input, for: currentTab)
		}
		
		saveChanges()
	}
	
	private func handleSearch(_ input: String, for tab: Tab) {
		if let searchEngine = currentWorkspace?.profile?.defaultSearchEngine ?? SearchEngine.defaultEngines.first {
			let searchUrl = searchEngine.searchUrl.replacingOccurrences(
				of: "%s",
				with: input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
			)
			
			if let url = URL(string: searchUrl) {
				currentURL = url
				tab.url = url.absoluteString
				getWebView(for: tab).load(URLRequest(url: url))
			}
		}
	}

	func refresh() {
		if let tab = currentTab {
			getWebView(for: tab).reload()
		}
	}

	func goBack() {
		if let tab = currentTab {
			getWebView(for: tab).goBack()
		}
	}

	func goForward() {
		if let tab = currentTab {
			getWebView(for: tab).goForward()
		}
	}

	
	@MainActor
	func addNewTab(windowId: UUID? = nil, title: String = "New Tab", url: String = "about:blank", type: TabType = .normal) async {
		// Resolve the window ID
		let windowUUID = windowId ?? WindowManager.shared.activeWindow ?? UUID()
		
		guard let context = modelContext,
			  let currentWorkspace = await getCurrentWorkspace(for: windowUUID) else { return }
		
		if type == .pinned {
			// Handle pinned tabs at profile level
			addNewPinnedTab(title: title, url: url)
			return
		}
		
		// Create the new tab
		let newTab = Tab(title: title, url: url, type: type, workspace: currentWorkspace)
		context.insert(newTab)
		currentWorkspace.tabs.append(newTab)
		
		// Add to appropriate tabs array
		if type == .normal {
			normalTabs.append(newTab)
		} else if type == .bookmark {
			bookmarkTabs.append(newTab)
		}
		
		// Ensure WebView is created before selecting the tab
		ensureWebView(for: newTab)
		
		// Select the new tab and focus URL bar
		selectTab(newTab, for: windowUUID)
		urlBarFocused = true
		
		saveChanges()
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
	
	private func updatePinnedTabsForProfile(_ profile: Profile?) {
		Task { @MainActor in
			if let profile = profile {
				self.pinnedTabs = profile.pinnedTabs
			} else {
				self.pinnedTabs = []
			}
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

	@MainActor
	func addWorkspace(name: String, icon: String, colorTheme: ColorTheme, profile: Profile?) async {
		guard let context = modelContext else { return }
		
		// Create workspace
		let workspace = Workspace(name: name, icon: icon, colorTheme: colorTheme)
		workspace.profile = profile
		
		// Update context
		context.insert(workspace)
		
		// Update state
		workspaces.append(workspace)
		
		if let windowId = WindowManager.shared.activeWindow {
			await setCurrentWorkspace(workspace, for: windowId)
		}
		
		try? context.save()
	}
	
	func updateWorkspace(_ workspace: Workspace, name: String, icon: String, colorTheme: ColorTheme, profile: Profile?) {
		let oldProfile = workspace.profile
		
		workspace.name = name
		workspace.icon = icon
		workspace.colorTheme = colorTheme
		workspace.profile = profile
		
		// If profile changed, handle the transition
		if oldProfile?.id != profile?.id {
			Task {
				await switchToProfile(profile)
			}
		}
		
		saveChanges()
		
		// Update workspaces array if needed
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
		
		// If WebView already exists with correct configuration, return
		if let existingWebView = webViewsByProfile[profileId]?[tab.id] {
			return
		}
		
		// Get a fresh configuration from SessionManager
		let configuration = SessionManager.shared.getConfiguration(for: profile)
		let webView = WKWebView(frame: .zero, configuration: configuration)
		
		// Initialize collections if needed
		if webViewsByProfile[profileId] == nil {
			webViewsByProfile[profileId] = [:]
		}
		if navigationDelegatesByProfile[profileId] == nil {
			navigationDelegatesByProfile[profileId] = [:]
		}
		
		// Set up WebView
		setupWebView(webView, for: tab, profile: profile)
		webViewsByProfile[profileId]?[tab.id] = webView
		
		// Load content
		if let url = URL(string: tab.url), url.scheme != nil {
			webView.load(URLRequest(url: url))
		}
	}

	func getWebView(for tab: Tab) -> WKWebView {
		let profile = tab.workspace?.profile
		let profileId = profile?.id ?? UUID()
		
		// Ensure we have storage for this profile
		if webViewsByProfile[profileId] == nil {
			webViewsByProfile[profileId] = [:]
		}
		
		// Try to find existing WebView by webViewId
		if let webViewId = tab.webViewId,
		   let existingWebView = webViewsByProfile[profileId]?[webViewId] {
			return existingWebView
		}
		
		// If no WebView exists or webViewId is nil, create a new one
		return createWebView(for: tab)
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
		
		// Create navigation delegate
		let navigationDelegate = WebViewNavigationDelegate(
			tab: tab,
			onTitleUpdate: { [weak self] title in
				guard let self = self else { return }
				Task { @MainActor in
					if let title = title {
						tab.title = title
						self.saveChanges()
					}
				}
			},
			onUrlUpdate: { [weak self] url in
				guard let self = self else { return }
				Task { @MainActor in
					self.urlInput = url
				}
			}
		)
		
		webView.navigationDelegate = navigationDelegate
		
		if let webViewId = tab.webViewId {
			navigationDelegatesByProfile[profileId]?[webViewId] = navigationDelegate
		}
		
		// Configure user agent based on profile
		configureUserAgent(webView, for: profile)
		
		// Set up user agent refresh observer
		let observer = NotificationCenter.default.addObserver(
			forName: NSNotification.Name("RefreshWebViews"),
			object: nil,
			queue: .main
		) { [weak self, weak webView] notification in
			guard let self = self,
				  let webView = webView,
				  let userInfo = notification.userInfo,
				  let notifiedProfileId = userInfo["profileId"] as? UUID,
				  notifiedProfileId == profile?.id else {
				return
			}
			
			Task { @MainActor in
				self.configureUserAgent(webView, for: profile)
				webView.reload()
			}
		}
		
		webViewObservers[tab.id] = observer
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
		currentTab = tab
		
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
	
	func setUrlInput(_ input: String) {
		DispatchQueue.main.async {
			self.urlInput = input
		}
	}
	
	func getCurrentWorkspace(for windowId: UUID) async -> Workspace? {
		if let workspaceId = workspaceSelectionsByWindow[windowId] {
			return workspaces.first(where: { $0.id == workspaceId })
		}
		return workspaces.first
	}
	
	func switchToProfile(_ newProfile: Profile?) async {
		guard newProfile?.id != currentProfile?.id else { return }
		
		let oldProfile = currentProfile
		
		await MainActor.run {
			// Update current profile
			currentProfile = newProfile
			
			if let newProfile = newProfile {
				updatePinnedTabsForProfile(newProfile)
				
				// Only recreate WebViews if they don't exist
				for tab in normalTabs + bookmarkTabs + pinnedTabs {
					if tab.webViewId == nil ||
					   webViewsByProfile[newProfile.id]?[tab.webViewId!] == nil {
						_ = createWebView(for: tab)
					}
				}
			}
			
			// Clean up old profile if needed
			if let oldProfile = oldProfile {
				Task {
					await cleanupUnusedWebViews(for: oldProfile)
				}
			}
		}
	}
	
	private func cleanupUnusedWebViews(for profile: Profile) async {
			let profileId = profile.id
			
			// Get all active tab webViewIds for this profile
			let activeWebViewIds = Set((profile.workspaces.flatMap { $0.tabs } + profile.pinnedTabs)
				.compactMap { $0.webViewId })
			
			// Remove any WebViews that aren't associated with active tabs
			webViewsByProfile[profileId]?.forEach { webViewId, webView in
				if !activeWebViewIds.contains(webViewId) {
					webView.stopLoading()
					webView.loadHTMLString("", baseURL: nil)
					webViewsByProfile[profileId]?.removeValue(forKey: webViewId)
					navigationDelegatesByProfile[profileId]?.removeValue(forKey: webViewId)
				}
			}
		}
	
	private func cleanupProfileWebViews(_ profile: Profile) async {
		let profileId = profile.id
		
		await MainActor.run {
			// First nullify all navigation delegates to prevent callbacks
			navigationDelegatesByProfile[profileId]?.forEach { tabId, delegate in
				if let observer = webViewObservers[tabId] {
					NotificationCenter.default.removeObserver(observer)
					webViewObservers.removeValue(forKey: tabId)
				}
			}
			
			// Stop all WebViews and clear their content
			webViewsByProfile[profileId]?.forEach { _, webView in
				webView.stopLoading()
				webView.loadHTMLString("", baseURL: nil)
				webView.navigationDelegate = nil
			}
			
			// Clear collections
			webViewsByProfile.removeValue(forKey: profileId)
			navigationDelegatesByProfile.removeValue(forKey: profileId)
		}
	}
	
	@MainActor
	func setCurrentWorkspace(_ workspace: Workspace?, for windowId: UUID) async {
		// Store old workspace for comparison
		let oldWorkspace = workspaceSelectionsByWindow[windowId].flatMap { id in
			workspaces.first(where: { $0.id == id })
		}
		
		// Update workspace selection
		workspaceSelectionsByWindow[windowId] = workspace?.id
		
		if let workspace = workspace {
			// Only update tab arrays if workspace changed
			if workspace.id != oldWorkspace?.id {
				// Preserve WebView states by checking existing tabs
				let newBookmarkTabs = workspace.tabs.filter { $0.type == .bookmark }
				let newNormalTabs = workspace.tabs.filter { $0.type == .normal }
				
				// Update arrays while preserving any existing WebView states
				bookmarkTabs = newBookmarkTabs
				normalTabs = newNormalTabs
				
				// Update current tab selection if needed
				if getSelectedTab(for: windowId) == nil && !normalTabs.isEmpty {
					selectTab(normalTabs.first, for: windowId)
				}
			}
			
			// Switch profile if needed, but only if it's actually different
			if workspace.profile?.id != currentProfile?.id {
				await switchToProfile(workspace.profile)
			}
		} else {
			// Clear tabs only if we're actually removing the workspace
			if oldWorkspace != nil {
				bookmarkTabs = []
				normalTabs = []
				selectTab(nil, for: windowId)
			}
		}
		
		// Update currentWorkspace last to ensure all state is ready
		currentWorkspace = workspace
		
		// Ensure all tabs have their WebViews
		Task {
			for tab in normalTabs + bookmarkTabs {
				ensureWebView(for: tab)
			}
		}
	}
	
	private func cleanupWebView(for tab: Tab) {
		let profileId = tab.workspace?.profile?.id ?? UUID()
		
		// Remove observer if it exists
		if let observer = webViewObservers[tab.id] {
			NotificationCenter.default.removeObserver(observer)
			webViewObservers.removeValue(forKey: tab.id)
		}
		
		// Clean up the WebView
		if let webViewId = tab.webViewId,
		   let webView = webViewsByProfile[profileId]?[webViewId] {
			webView.stopLoading()
			webView.loadHTMLString("", baseURL: nil)
			webViewsByProfile[profileId]?.removeValue(forKey: webViewId)
			navigationDelegatesByProfile[profileId]?.removeValue(forKey: webViewId)
		}
		
		// Clear the webViewId from the tab
		tab.webViewId = nil
		try? modelContext?.save()
	}
	
	private func looksLikeUrl(_ input: String) -> Bool {
		// Ignore special URLs
		if input.starts(with: "about:") {
			return false
		}
		
		// Basic pattern for domain names
		let pattern = "^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$"
		let domainPredicate = NSPredicate(format: "SELF MATCHES %@", pattern)
		
		// Remove any protocols and www before checking
		let strippedInput = input
			.replacingOccurrences(of: "https://", with: "")
			.replacingOccurrences(of: "http://", with: "")
			.replacingOccurrences(of: "www.", with: "")
		
		return domainPredicate.evaluate(with: strippedInput)
	}

	private func formatUrlString(_ input: String) -> String {
		var urlString = input.trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Check if the URL already has a protocol
		if !urlString.contains("://") {
			urlString = "https://" + urlString
		}
		
		return urlString
	}
	
	private func configureUserAgent(_ webView: WKWebView, for profile: Profile?) {
		if let profile = profile {
			webView.customUserAgent = profile.userAgent
		} else {
			webView.customUserAgent = UserAgent.safari.rawValue
		}
	}
	
	private func createWebView(for tab: Tab) -> WKWebView {
		let profile = tab.workspace?.profile
		let profileId = profile?.id ?? UUID()
		
		// Generate new WebView ID if needed
		if tab.webViewId == nil {
			tab.webViewId = UUID()
		}
		
		// Get configuration from SessionManager
		let configuration = SessionManager.shared.getConfiguration(for: profile)
		let webView = WKWebView(frame: .zero, configuration: configuration)
		
		// Set up WebView with profile
		setupWebView(webView, for: tab, profile: profile)
		
		// Store WebView with its ID
		if let webViewId = tab.webViewId {
			webViewsByProfile[profileId]?[webViewId] = webView
		}
		
		// Load content if needed
		if let url = URL(string: tab.url), url.scheme != nil {
			webView.load(URLRequest(url: url))
		}
		
		return webView
	}
	
	func recreateWebViews(for profile: Profile) {
		let profileId = profile.id
		
		// Clean up existing WebViews
		webViewsByProfile[profileId]?.forEach { _, webView in
			webView.stopLoading()
			webView.loadHTMLString("", baseURL: nil)
		}
		
		// Clear existing collections
		webViewsByProfile[profileId] = [:]
		navigationDelegatesByProfile[profileId] = [:]
		
		// Recreate WebViews for all tabs
		let allTabs = profile.pinnedTabs + (profile.workspaces.flatMap { $0.tabs })
		for tab in allTabs {
			ensureWebView(for: tab)
		}
	}
	
	func switchProfile(_ newProfile: Profile?) {
		if newProfile?.id != currentProfile?.id {
			// Clean up old profile's WebViews
			if let oldProfile = currentProfile {
				webViewsByProfile[oldProfile.id]?.removeAll()
				navigationDelegatesByProfile[oldProfile.id]?.removeAll()
			}
			
			currentProfile = newProfile
			
			// Set up new profile's WebViews
			if let newProfile = newProfile {
				recreateWebViews(for: newProfile)
			}
		}
	}
}

