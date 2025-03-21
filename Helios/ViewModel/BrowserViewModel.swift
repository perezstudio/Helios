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
	var pinnedTabs: [Tab] {
		guard let currentProfile = currentWorkspace?.profile else { return [] }
		return currentProfile.pinnedTabs.sorted { $0.displayOrder < $1.displayOrder }
	}
	
	// Add init method to set up notification observer
	init() {
		// Set up notification observer for script handler cleanup
		NotificationCenter.default.addObserver(
			forName: NSNotification.Name("CleanupWebViewScriptHandler"),
			object: nil,
			queue: .main
		) { [weak self] notification in
			self?.handleScriptHandlerCleanup(notification)
		}
	}
	var bookmarkTabs: [Tab] {
		guard let currentWorkspace = currentWorkspace else { return [] }
		return currentWorkspace.tabs
			.filter { $0.type == .bookmark }
			.sorted { $0.displayOrder < $1.displayOrder }
	}
	var normalTabs: [Tab] {
		guard let currentWorkspace = currentWorkspace else { return [] }
		return currentWorkspace.tabs
			.filter { $0.type == .normal }
			.sorted { $0.displayOrder < $1.displayOrder }
	}
	var workspaces: [Workspace] = []
	var urlBarFocused: Bool = false
	private var currentProfile: Profile? = nil
	private var webViewObservers: [UUID: NSObjectProtocol] = [:]
	private var loadingTabs: Set<UUID> = []
	var permissionObservers: [String: NSObjectProtocol] = [:]
	
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
	
	private func getLastPinnedTabIndex(in workspace: Workspace) -> Int {
		return workspace.tabs.lastIndex(where: { $0.type == .pinned }) ?? -1
	}
	
	private func insertTabAtPosition(_ tab: Tab, type: TabType, in workspace: Workspace) {
		// Get the current index of the tab in the workspace
		let currentIndex = workspace.tabs.firstIndex(where: { $0.id == tab.id })
		
		// First remove the tab from its current position
		workspace.tabs.removeAll { $0.id == tab.id }
		
		// Update the tab type
		tab.type = type
		
		if type == .pinned {
			// Find the last pinned tab
			if let lastPinnedIndex = workspace.tabs.lastIndex(where: { $0.type == .pinned }) {
				// Insert after the last pinned tab
				workspace.tabs.insert(tab, at: lastPinnedIndex + 1)
			} else {
				// No pinned tabs, insert at the beginning
				workspace.tabs.insert(tab, at: 0)
			}
		} else if let currentIndex = currentIndex {
			// For unpinning, try to maintain the tab's relative position
			// Find the best position based on surrounding tabs
			let unpinnedTabs = workspace.tabs.filter { $0.type != .pinned }
			if unpinnedTabs.isEmpty {
				// If there are no unpinned tabs, append to the end of all tabs
				workspace.tabs.append(tab)
			} else {
				// Find the index of the tab that was after this one
				let pinnedCount = workspace.tabs.filter { $0.type == .pinned }.count
				
				// If this was the last pinned tab, insert it at the beginning of unpinned tabs
				if currentIndex == pinnedCount - 1 {
					workspace.tabs.insert(tab, at: pinnedCount)
				} else {
					// Insert it at the end of unpinned tabs
					workspace.tabs.append(tab)
				}
			}
		} else {
			// If we don't have a current index, just append to the end
			workspace.tabs.append(tab)
		}
	}
	
	func togglePin(_ tab: Tab) {
		guard let currentWorkspace = currentWorkspace, let profile = currentWorkspace.profile else { return }
		
		let wasPin = tab.type == .pinned
		let newType = wasPin ? TabType.normal : TabType.pinned
		
		// Calculate new display order for the tab
		let newOrder = calculateNewOrderForTab(tab, newType: newType, in: currentWorkspace)
		
		// Update tab properties
		tab.type = newType
		tab.displayOrder = newOrder
		
		// Update display order of other tabs to maintain proper ordering
		updateDisplayOrderAfterTypeChange(for: tab, wasPin: wasPin, in: currentWorkspace)
		
		// Ensure WebView exists
		ensureWebView(for: tab)
		
		// Notify of pinned tab change
		NotificationCenter.default.post(name: NSNotification.Name("PinnedTabsChanged"), object: nil)
		
		saveChanges()
	}
	
	private func calculateNewOrderForTab(_ tab: Tab, newType: TabType, in workspace: Workspace) -> Int {
		let tabsOfNewType = workspace.tabs.filter { $0.type == newType }
		
		if tabsOfNewType.isEmpty {
			// If there are no tabs of this type, use 0 as the base order
			return 0
		}
		
		if newType == .pinned {
			// For pinning, add to the end of pinned tabs
			return tabsOfNewType.map { $0.displayOrder }.max()! + 1
		} else {
			// For unpinning, add to the beginning of normal tabs
			return tabsOfNewType.map { $0.displayOrder }.min()! - 1
		}
	}
	
	private func updateDisplayOrderAfterTypeChange(for changedTab: Tab, wasPin: Bool, in workspace: Workspace) {
		// Normalize all display orders to remove gaps and ensure proper sequence
		let tabsByType: [TabType: [Tab]] = [
			.pinned: workspace.tabs.filter { $0.type == .pinned && $0.id != changedTab.id },
			.bookmark: workspace.tabs.filter { $0.type == .bookmark && $0.id != changedTab.id },
			.normal: workspace.tabs.filter { $0.type == .normal && $0.id != changedTab.id }
		]
		
		// Update orders for each type
		for (type, tabs) in tabsByType {
			let sortedTabs = tabs.sorted { $0.displayOrder < $1.displayOrder }
			for (index, tab) in sortedTabs.enumerated() {
				tab.displayOrder = index
			}
		}
		
		// Ensure the changed tab has a valid order
		if changedTab.displayOrder < 0 {
			// If it's now negative, put it at the beginning
			changedTab.displayOrder = 0
			
			// Shift other tabs of the same type
			workspace.tabs
				.filter { $0.type == changedTab.type && $0.id != changedTab.id }
				.forEach { $0.displayOrder += 1 }
		}
	}
	
	func reorderPinnedTabs(in workspace: Workspace, from source: IndexSet, to destination: Int) {
		// Get the pinned tabs in their current order
		let pinnedTabs = workspace.tabs.filter { $0.type == .pinned }
		var reorderedPinned = pinnedTabs
		reorderedPinned.move(fromOffsets: source, toOffset: destination)
		
		// Get the non-pinned tabs
		let nonPinnedTabs = workspace.tabs.filter { $0.type != .pinned }
		
		// Update the workspace's tabs array with the new order
		workspace.tabs.removeAll()
		workspace.tabs.append(contentsOf: reorderedPinned)
		workspace.tabs.append(contentsOf: nonPinnedTabs)
		
		saveChanges()
	}
	
	func reorderTabs(type: TabType, in workspace: Workspace, from source: IndexSet, to destination: Int) {
		// Get tabs of the requested type, sorted by display order
		var tabs = workspace.tabs
			.filter { $0.type == type }
			.sorted { $0.displayOrder < $1.displayOrder }
		
		// Perform the move operation
		tabs.move(fromOffsets: source, toOffset: destination)
		
		// Update display orders to reflect new ordering
		for (index, tab) in tabs.enumerated() {
			tab.displayOrder = index
		}
		
		saveChanges()
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
	
	private func createWebViewWithConfiguration(for tab: Tab, configuration: WKWebViewConfiguration) {
		let profile = tab.workspace?.profile
		let profileId = profile?.id ?? UUID()
		
		// Generate new WebView ID if needed
		if tab.webViewId == nil {
			tab.webViewId = UUID()
		}
		
		// Create the WebView with the provided configuration
		let webView = WKWebView(frame: .zero, configuration: configuration)
		
		// Set up WebView with profile
		setupWebView(webView, for: tab, profile: profile)
		
		// Store WebView with its ID
		if let webViewId = tab.webViewId {
			if webViewsByProfile[profileId] == nil {
				webViewsByProfile[profileId] = [:]
			}
			webViewsByProfile[profileId]?[webViewId] = webView
		}
		
		// Load content if needed
		if let url = URL(string: tab.url), url.scheme != nil {
			webView.load(URLRequest(url: url))
		}
	}

	
	@MainActor
	func addNewTab(
		windowId: UUID? = nil,
		title: String = "New Tab",
		url: String = "about:blank",
		type: TabType = .normal,
		configuration: WKWebViewConfiguration? = nil
	) async {
		// Resolve the window ID
		let windowUUID = windowId ?? WindowManager.shared.activeWindow ?? UUID()
		
		guard let context = modelContext,
			  let currentWorkspace = await getCurrentWorkspace(for: windowUUID) else { return }
		
		// Find the maximum order value for tabs of this type to append at the end
		let maxOrder = currentWorkspace.tabs
			.filter { $0.type == type }
			.map { $0.displayOrder }
			.max() ?? -1
		
		// Create the new tab with the correct order
		let newTab = Tab(
			title: title,
			url: url,
			type: type,
			workspace: currentWorkspace,
			displayOrder: maxOrder + 1
		)
		
		context.insert(newTab)
		currentWorkspace.tabs.append(newTab)
		
		// Ensure WebView is created before selecting the tab
		if let providedConfig = configuration {
			createWebViewWithConfiguration(for: newTab, configuration: providedConfig)
		} else {
			ensureWebView(for: newTab)
		}
		
		// Select the new tab and focus URL bar
		selectTab(newTab, for: windowUUID)
		urlBarFocused = true
		
		saveChanges()
	}
	
	func addNewPinnedTab(title: String = "New Tab", url: String = "about:blank") {
		guard let context = modelContext,
			  let currentWorkspace = currentWorkspace else { return }
		
		// Create the pinned tab in the current workspace
		let newTab = Tab(title: title, url: url, type: .pinned, workspace: currentWorkspace)
		context.insert(newTab)
		currentWorkspace.tabs.append(newTab)
		
		// Ensure the WebView is created
		ensureWebView(for: newTab)
		
		saveChanges()
	}
	
	func deleteTab(_ tab: Tab) {
		// Remove selections for this tab
		let affectedWindows = tabSelectionsByWindow.filter { $0.value == tab.id }.map { $0.key }
		for windowId in affectedWindows {
			tabSelectionsByWindow[windowId] = nil
		}
		
		// Remove from workspace
		if let workspace = tab.workspace {
			workspace.tabs.removeAll { $0.id == tab.id }
			
			// Update display orders after removal
			normalizeDisplayOrders(in: workspace)
			
			// Update current tab selection
			for windowId in affectedWindows {
				if tab.type == .normal {
					if !normalTabs.isEmpty {
						selectTab(normalTabs[0], for: windowId)
					} else {
						selectTab(nil, for: windowId)
					}
				}
			}
		}
		
		cleanupPermissionObservers(for: tab)
		
		// Clean up WebView
		cleanupWebView(for: tab)
		
		// Delete from context
		modelContext?.delete(tab)
		
		// If it was a pinned tab, refresh the pinned tabs view by notifying
		if tab.type == .pinned {
			NotificationCenter.default.post(name: NSNotification.Name("PinnedTabsChanged"), object: nil)
		}
		
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
			
			// Instead of trying to clear the computed arrays directly,
			// we'll just set the current workspace to nil after deleting
		}
		
		// Clean up all WebViews for tabs in this workspace
		let profileId = workspace.profile?.id ?? UUID()
		for tab in workspace.tabs {
			if let webViewId = tab.webViewId,
			   let webView = webViewsByProfile[profileId]?[webViewId] {
				webView.stopLoading()
				webView.loadHTMLString("", baseURL: nil)
				webViewsByProfile[profileId]?.removeValue(forKey: webViewId)
				navigationDelegatesByProfile[profileId]?.removeValue(forKey: webViewId)
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
	
	func toggleBookmark(_ tab: Tab) {
		guard let currentWorkspace = currentWorkspace else { return }
		
		if tab.type == .bookmark {
			// Convert to normal tab
			tab.type = .normal
			tab.bookmarkedUrl = nil
		} else {
			// Convert to bookmark tab
			let maxBookmarkOrder = currentWorkspace.tabs
				.filter { $0.type == .bookmark }
				.map { $0.displayOrder }
				.max() ?? -1
				
			tab.type = .bookmark
			tab.bookmarkedUrl = tab.url
			tab.displayOrder = maxBookmarkOrder + 1
		}
		
		// Update display orders to ensure proper sequencing
		normalizeDisplayOrders(in: currentWorkspace)
		
		saveChanges()
	}
	
	func normalizeDisplayOrders(in workspace: Workspace) {
		// Group tabs by type
		let pinnedTabs = workspace.tabs.filter { $0.type == .pinned }.sorted { $0.displayOrder < $1.displayOrder }
		let bookmarkTabs = workspace.tabs.filter { $0.type == .bookmark }.sorted { $0.displayOrder < $1.displayOrder }
		let normalTabs = workspace.tabs.filter { $0.type == .normal }.sorted { $0.displayOrder < $1.displayOrder }
		
		// Update display orders for each group
		for (index, tab) in pinnedTabs.enumerated() {
			tab.displayOrder = index
		}
		
		for (index, tab) in bookmarkTabs.enumerated() {
			tab.displayOrder = index
		}
		
		for (index, tab) in normalTabs.enumerated() {
			tab.displayOrder = index
		}
		
		saveChanges()
	}

	// MARK: - WebView Management

	private func ensureWebView(for tab: Tab) {
		// For pinned tabs, use the profile they belong to
		// For other tabs, use their workspace's profile
		let profile = tab.type == .pinned ? tab.profile : tab.workspace?.profile
		let profileId = profile?.id ?? UUID()
		
		// If WebView already exists with correct configuration, ensure it's loaded
		if let existingWebView = webViewsByProfile[profileId]?[tab.id] {
			if existingWebView.url == nil,
			   let url = URL(string: tab.url),
			   url.scheme != nil {
				existingWebView.load(URLRequest(url: url))
			}
			return
		}
		
		// Get a fresh configuration for this profile
		let configuration = getProfileConfiguration(for: profile)
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
				
				// Initialize current profile
				currentProfile = currentWorkspace?.profile
				
				// Load pinned tabs if there's a profile
				if let profile = currentProfile {
					// Ensure WebViews are created for all pinned tabs in this profile
					let pinnedTabs = profile.pinnedTabs
					print("Loading \(pinnedTabs.count) pinned tabs for profile \(profile.name)")
					
					for tab in pinnedTabs {
						ensureWebView(for: tab)
					}
				}
			}
		} catch {
			print("Failed to load saved data: \(error)")
		}
	}
	
	private func setupWebView(_ webView: WKWebView, for tab: Tab, profile: Profile?, windowId: UUID = WindowManager.shared.activeWindow ?? UUID()) {
		let profileId = profile?.id ?? UUID()
		
		// Create navigation delegate
		let navigationDelegate = WebViewNavigationDelegate(
			tab: tab,
			windowId: windowId,
			viewModel: self,
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
		
		// Set both delegates
		webView.navigationDelegate = navigationDelegate
		webView.uiDelegate = navigationDelegate
		
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
			if let workspace = workspaces.first(where: { $0.id == workspaceId }) {
				// Ensure that the current profile is set correctly
				await MainActor.run {
					if currentProfile?.id != workspace.profile?.id {
						currentProfile = workspace.profile
					}
				}
				return workspace
			}
		}
		let firstWorkspace = workspaces.first
		if let workspace = firstWorkspace {
			await MainActor.run {
				currentProfile = workspace.profile
			}
		}
		return firstWorkspace
	}
	
	func switchToProfile(_ newProfile: Profile?) async {
		guard newProfile?.id != currentProfile?.id else { return }
		
		let oldProfile = currentProfile
		
		// First, properly dispose of the old profile's WebViews
		if let oldProfile = oldProfile {
			await cleanupProfileWebViews(oldProfile)
		}
		
		await MainActor.run {
			// Update current profile
			currentProfile = newProfile
			
			if let newProfile = newProfile {
				// Wait briefly to ensure clean state transition
				Task {
					try? await Task.sleep(nanoseconds: 50_000_000) // 50ms pause
					
					// Create fresh WebViews with proper isolation for all tabs in this profile
					// First ensure WebViews are created for all pinned tabs in the profile
					let profilePinnedTabs = newProfile.pinnedTabs
					print("Loading \(profilePinnedTabs.count) pinned tabs for profile \(newProfile.name)")
					
					// Then add normal and bookmark tabs from the current workspace
					let allTabs = normalTabs + bookmarkTabs + profilePinnedTabs
					for tab in allTabs {
						// First clear any old webViewId to force new WebView creation
						tab.webViewId = nil
						
						// Now create a fresh WebView
						ensureWebView(for: tab)
						
						// Force reload tabs with fresh context
						if let url = URL(string: tab.url),
						   url.scheme != nil {
							getWebView(for: tab).load(URLRequest(url: url))
						}
					}
				}
			}
		}
	}
	
	// Handle cleanup of script message handlers via notification
	@MainActor
	private func handleScriptHandlerCleanup(_ notification: Notification) {
		guard let userInfo = notification.userInfo,
			  let webViewId = userInfo["webViewId"] as? UUID,
			  let handlerName = userInfo["handlerName"] as? String else {
			return
		}
		
		// Safely access all profile WebViews on the main thread
		for (profileId, webViews) in webViewsByProfile {
			if let webView = webViews[webViewId] {
				// Safely remove the script message handler
				webView.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
				print("Successfully cleaned up script handler \(handlerName) for WebView \(webViewId)")
				return
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
	
	// Safely remove a script message handler from a WebView
	@MainActor
	func removeScriptMessageHandler(from webViewId: UUID, name: String) {
		// Find the WebView across all profiles
		for (_, webViews) in webViewsByProfile {
			if let webView = webViews[webViewId] {
				// Safely remove the handler
				webView.configuration.userContentController.removeScriptMessageHandler(forName: name)
				break
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
			// Only update tab selection if workspace changed
			if workspace.id != oldWorkspace?.id {
				// Update current tab selection if needed
				if getSelectedTab(for: windowId) == nil {
					// Select the first normal tab if available
					let firstNormalTab = workspace.tabs.first(where: { $0.type == .normal })
					if let firstTab = firstNormalTab {
						selectTab(firstTab, for: windowId)
					}
				}
			}
			
			// Switch profile if needed, but only if it's actually different
			if workspace.profile?.id != currentProfile?.id {
				await switchToProfile(workspace.profile)
			}
		} else {
			// Clear tab selection if we're removing the workspace
			if oldWorkspace != nil {
				selectTab(nil, for: windowId)
			}
		}
		
		// Update currentWorkspace last to ensure all state is ready
		currentWorkspace = workspace
		
		// Ensure all tabs have their WebViews
		if let workspace = workspace {
			Task {
				for tab in workspace.tabs {
					ensureWebView(for: tab)
				}
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
			// First stop any ongoing activity
			webView.stopLoading()
			
			// Navigate to a blank page to release active resources
			webView.loadHTMLString("", baseURL: nil)
			
			// Clear any custom handlers
			webView.configuration.userContentController.removeAllUserScripts()
			webView.configuration.userContentController.removeAllScriptMessageHandlers()
			
			// Drop navigation delegate
			webView.navigationDelegate = nil
			webView.uiDelegate = nil
			
			// Remove from our caches
			webViewsByProfile[profileId]?.removeValue(forKey: webViewId)
			navigationDelegatesByProfile[profileId]?.removeValue(forKey: webViewId)
		}
		
		// Clear the webViewId from the tab to ensure we'll create a fresh one next time
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
		// For pinned tabs, use the current profile
		let profile = tab.type == .pinned ? currentProfile : tab.workspace?.profile
		let profileId = profile?.id ?? UUID()
		
		// Generate new WebView ID if needed
		if tab.webViewId == nil {
			tab.webViewId = UUID()
		}
		
		// Get configuration for this profile
		let configuration = getProfileConfiguration(for: profile)
		let webView = WKWebView(frame: .zero, configuration: configuration)
		
		// Set up WebView with profile
		setupWebView(webView, for: tab, profile: profile)
		
		// Store WebView with its ID
		if let webViewId = tab.webViewId {
			if webViewsByProfile[profileId] == nil {
				webViewsByProfile[profileId] = [:]
			}
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
		let allTabs = profile.workspaces.flatMap { $0.tabs }
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
	
	func setTabLoading(_ tab: Tab, isLoading: Bool) {
		if isLoading {
			loadingTabs.insert(tab.id)
		} else {
			loadingTabs.remove(tab.id)
		}
	}

	func isTabLoading(_ tab: Tab) -> Bool {
		loadingTabs.contains(tab.id)
	}
	
	func getPageSettings(for tab: Tab) -> SiteSettings? {
		guard let url = URL(string: tab.url),
			  let profile = currentWorkspace?.profile else {
			print("Cannot get settings: missing URL or profile")
			return nil
		}
		
		// Find existing site settings that match the URL
		let host = url.host ?? ""
		print("Looking for settings for host: \(host)")
		
		if let matchingSetting = profile.siteSettings.first(where: { $0.appliesTo(url: url) }) {
			print("Found existing settings. Camera: \(matchingSetting.camera?.rawValue ?? "nil")")
			return matchingSetting
		}
		
		// If no matching settings exist, create a new one
		print("Creating new settings for \(host)")
		let newSettings = SiteSettings(hostPattern: host, profile: profile)
		modelContext?.insert(newSettings)
		
		return newSettings
	}
	
	func reindexArrays() {
		guard let currentWorkspace = currentWorkspace else { return }
		
		// Group tabs by type
		let allTabs = currentWorkspace.tabs
		let pinnedTabs = allTabs.filter { $0.type == .pinned }.sorted { $0.displayOrder < $1.displayOrder }
		let bookmarkTabs = allTabs.filter { $0.type == .bookmark }.sorted { $0.displayOrder < $1.displayOrder }
		let normalTabs = allTabs.filter { $0.type == .normal }.sorted { $0.displayOrder < $1.displayOrder }
		
		// Update display orders for each group
		for (index, tab) in pinnedTabs.enumerated() {
			tab.displayOrder = index
		}
		
		for (index, tab) in bookmarkTabs.enumerated() {
			tab.displayOrder = index
		}
		
		for (index, tab) in normalTabs.enumerated() {
			tab.displayOrder = index
		}
		
		saveChanges()
	}
	
	private func cleanupPermissionObservers(for tab: Tab) {
		if let url = URL(string: tab.url), let host = url.host {
			let keys = permissionObservers.keys.filter { $0.hasPrefix("\(host)-") }
			for key in keys {
				if let observer = permissionObservers[key] {
					NotificationCenter.default.removeObserver(observer)
					permissionObservers.removeValue(forKey: key)
				}
			}
		}
	}
	
	// In your code where you create WKWebViewConfiguration objects
	func configureWebViewForMediaSupport(_ configuration: WKWebViewConfiguration) {
		// Allow autoplay of media
		configuration.mediaTypesRequiringUserActionForPlayback = []
		
		// Enable modern media APIs
		configuration.allowsAirPlayForMediaPlayback = true
		
		// Set preferences
		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = true
		
		// For modern WebKit features
		if #available(macOS 10.15, *) {
			configuration.defaultWebpagePreferences.allowsContentJavaScript = true
		} else {
			preferences.javaScriptEnabled = true
		}
		
		configuration.preferences = preferences
		
		// Add user script to enhance media permissions
		let mediaScript = """
		navigator.permissions.query = (function(original) {
			return function(query) {
				if (query.name === 'camera' || query.name === 'microphone') {
					return Promise.resolve({ state: 'prompt', onchange: null });
				}
				return original.apply(this, arguments);
			};
		})(navigator.permissions.query);
		"""
		
		let script = WKUserScript(source: mediaScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		configuration.userContentController.addUserScript(script)
	}
}

