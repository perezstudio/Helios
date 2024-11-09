//
//  WebkitViewContainer.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData
import WebKit

class WebContainerView: NSView {
	var currentTabID: UUID?
	weak var webView: WKWebView? {
		willSet {
			guard webView !== newValue else { return }
			webView?.removeFromSuperview()
		}
		didSet {
			guard webView?.superview !== self else { return }
			if let webView = webView {
				addSubview(webView)
				webView.frame = bounds
				webView.autoresizingMask = [.width, .height]
			}
		}
	}
	
	func setWebView(_ webView: WKWebView?, for tabID: UUID) {
		guard currentTabID != tabID else { return }
		currentTabID = tabID
		self.webView = webView
	}
	
	override func layout() {
		super.layout()
		webView?.frame = bounds
	}
}

// MARK: - WebView Container
struct WebViewContainer: NSViewRepresentable {
	let tab: Tab
	let modelContext: ModelContext
	
	private func createWebView(coordinator: WebViewCoordinator) -> WKWebView {
		print("Creating WebView for tab: \(tab.id)")
		let config = WKWebViewConfiguration()
		config.preferences.javaScriptCanOpenWindowsAutomatically = true
		config.preferences.isElementFullscreenEnabled = true
		
		let webView = WKWebView(frame: .zero, configuration: config)
		webView.allowsMagnification = true
		webView.allowsBackForwardNavigationGestures = true
		webView.navigationDelegate = coordinator
		webView.uiDelegate = coordinator
		
		let request = URLRequest(url: tab.url)
		webView.load(request)
		coordinator.observeNavigationState(webView)
		
		return webView
	}
	
	func makeNSView(context: Context) -> WebContainerView {
		print("Creating container for tab: \(tab.id)")
		let containerView = WebContainerView()
		
		// Get or create WebView
		let webView = WebViewStore.shared.getOrCreateWebView(
			for: tab.id,
			createWebView: { createWebView(coordinator: context.coordinator) }
		)
		
		// Set the WebView
		containerView.setWebView(webView, for: tab.id)
		return containerView
	}
	
	func updateNSView(_ containerView: WebContainerView, context: Context) {
		print("Updating container for tab: \(tab.id)")
		
		// Get existing WebView or create new one
		let webView = WebViewStore.shared.getOrCreateWebView(
			for: tab.id,
			createWebView: { createWebView(coordinator: context.coordinator) }
		)
		
		// Update container's WebView if tab changed
		containerView.setWebView(webView, for: tab.id)
		
		// Only reload if URL changed and tab is not loading
		if webView.url != tab.url && !WebViewStore.shared.isTabLoading(tab.id) {
			print("Loading URL: \(tab.url) in tab: \(tab.id)")
			WebViewStore.shared.load(url: tab.url, for: tab.id)
			context.coordinator.lastLoadedDate = Date()
		}
	}
	
	static func dismantleNSView(_ containerView: WebContainerView, coordinator: Coordinator) {
		let tabID = coordinator.parent.tab.id
		print("Dismantling container for tab: \(tabID)")
		
		if !coordinator.parent.tab.isPinned {
			WebViewStore.shared.remove(for: tabID)
			containerView.webView = nil
			containerView.currentTabID = nil
		}
	}
	
	func makeCoordinator() -> WebViewCoordinator {
		WebViewCoordinator(self)
	}
}

// MARK: - URL Extension for Validation
extension URL {
	var isValid: Bool {
		guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
			return false
		}
		if let match = detector.firstMatch(in: self.absoluteString, options: [], range: NSRange(location: 0, length: self.absoluteString.utf16.count)) {
			return match.range.length == self.absoluteString.utf16.count
		}
		return false
	}
}

// MARK: - WebView Store

import WebKit

class WebViewStore {
	static let shared = WebViewStore()
	private var webViews: [UUID: WKWebView] = [:]
	private var activeTabID: UUID?
	private var loadingTabIDs: Set<UUID> = []
	private var lastURLs: [UUID: URL] = [:]
	
	private init() {}
	
	func getOrCreateWebView(for tabID: UUID, createWebView: () -> WKWebView) -> WKWebView {
		print("Getting or creating WebView for tab: \(tabID)")
		
		// Return existing WebView if available
		if let existingWebView = webViews[tabID] {
			return existingWebView
		}
		
		// Create new WebView
		let webView = createWebView()
		store(webView, for: tabID)
		return webView
	}
	
	func store(_ webView: WKWebView, for tabID: UUID) {
		print("Storing WebView for tab: \(tabID)")
		
		// Clean up existing WebView if different
		if let existingWebView = webViews[tabID], existingWebView !== webView {
			cleanupWebView(existingWebView)
			webViews.removeValue(forKey: tabID)
			lastURLs.removeValue(forKey: tabID)
		}
		
		webViews[tabID] = webView
		lastURLs[tabID] = webView.url
		activeTabID = tabID
	}
	
	func remove(for tabID: UUID) {
		print("Removing WebView for tab: \(tabID)")
		if let webView = webViews[tabID] {
			cleanupWebView(webView)
			webViews.removeValue(forKey: tabID)
			lastURLs.removeValue(forKey: tabID)
			loadingTabIDs.remove(tabID)
			
			if activeTabID == tabID {
				activeTabID = nil
			}
		}
	}
	
	private func cleanupWebView(_ webView: WKWebView) {
		webView.stopLoading()
		webView.navigationDelegate = nil
		webView.uiDelegate = nil
		webView.removeFromSuperview()
	}
	
	func load(url: URL, for tabID: UUID) {
		guard let webView = webViews[tabID],
			  !isTabLoading(tabID),
			  lastURLs[tabID] != url else {
			return
		}
		
		print("Loading URL: \(url) in tab: \(tabID)")
		markTabLoading(tabID)
		lastURLs[tabID] = url
		let request = URLRequest(url: url)
		webView.load(request)
	}
	
	func isTabLoading(_ tabID: UUID) -> Bool {
		return loadingTabIDs.contains(tabID)
	}
	
	func markTabLoading(_ tabID: UUID) {
		loadingTabIDs.insert(tabID)
	}
	
	func markTabFinishedLoading(_ tabID: UUID) {
		loadingTabIDs.remove(tabID)
	}
	
	// Navigation methods
	func goBack(for tabID: UUID) {
		guard let webView = webViews[tabID], webView.canGoBack else { return }
		webView.goBack()
	}
	
	func goForward(for tabID: UUID) {
		guard let webView = webViews[tabID], webView.canGoForward else { return }
		webView.goForward()
	}
	
	func stopLoading(for tabID: UUID) {
		if let webView = webViews[tabID] {
			webView.stopLoading()
			markTabFinishedLoading(tabID)
		}
	}
	
	func reload(for tabID: UUID) {
		guard let webView = webViews[tabID], !isTabLoading(tabID) else { return }
		markTabLoading(tabID)
		webView.reload()
	}
	
	func cleanup() {
		print("Cleaning up all WebViews")
		for (tabID, webView) in webViews {
			cleanupWebView(webView)
			print("Cleaned up WebView for tab: \(tabID)")
		}
		webViews.removeAll()
		lastURLs.removeAll()
		loadingTabIDs.removeAll()
		activeTabID = nil
	}
}

// MARK: - Additional Notification Names
extension Notification.Name {
	static let webViewCanGoBackChanged = Notification.Name("webViewCanGoBackChanged")
	static let webViewCanGoForwardChanged = Notification.Name("webViewCanGoForwardChanged")
}


class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
	var parent: WebViewContainer
	var lastLoadedDate: Date?
	private var canGoBackObservation: NSKeyValueObservation?
	private var canGoForwardObservation: NSKeyValueObservation?
	
	init(_ parent: WebViewContainer) {
		self.parent = parent
		super.init()
	}
	
	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		print("Started loading for tab: \(parent.tab.id)")
		NotificationCenter.default.post(
			name: .webViewStartedLoading,
			object: parent.tab
		)
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		print("Finished loading for tab: \(parent.tab.id)")
		NotificationCenter.default.post(
			name: .webViewFinishedLoading,
			object: parent.tab
		)
		
		// Update URL if it changed
		if let url = webView.url {
			parent.tab.url = url
			try? parent.modelContext.save()
		}
		
		// Update tab title
		webView.evaluateJavaScript("document.title") { [weak self] (result, error) in
			if let title = result as? String {
				DispatchQueue.main.async {
					self?.parent.tab.title = title
					try? self?.parent.modelContext.save()
				}
			}
		}
		
		// Get favicon
		webView.evaluateJavaScript("""
			var link = document.querySelector("link[rel~='icon']");
			if (!link) {
				link = document.querySelector("link[rel~='shortcut icon']");
			}
			link ? link.href : null;
		""") { [weak self] (result, error) in
			if let iconURLString = result as? String,
			   let iconURL = URL(string: iconURLString) {
				self?.downloadFavicon(from: iconURL)
			}
		}
	}
	
	private func downloadFavicon(from url: URL) {
		URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
			if let data = data {
				DispatchQueue.main.async {
					self?.parent.tab.favicon = data
					try? self?.parent.modelContext.save()
				}
			}
		}.resume()
	}
	
	func observeNavigationState(_ webView: WKWebView) {
		canGoBackObservation = webView.observe(\.canGoBack) { [weak self] webView, _ in
			guard let self = self else { return }
			NotificationCenter.default.post(
				name: .webViewCanGoBackChanged,
				object: (self.parent.tab.id, webView.canGoBack)
			)
		}
		
		canGoForwardObservation = webView.observe(\.canGoForward) { [weak self] webView, _ in
			guard let self = self else { return }
			NotificationCenter.default.post(
				name: .webViewCanGoForwardChanged,
				object: (self.parent.tab.id, webView.canGoForward)
			)
		}
	}
	
	deinit {
		canGoBackObservation?.invalidate()
		canGoForwardObservation?.invalidate()
	}
}
