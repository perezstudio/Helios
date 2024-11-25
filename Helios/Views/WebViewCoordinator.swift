//
//  WebViewCoordinator.swift
//  Helios
//
//  Created by Kevin Perez on 11/10/24.
//

import SwiftUI
import SwiftData
@preconcurrency import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
	var tabID: UUID
	let modelContext: ModelContext
	private let coordinatorID = UUID()
	
	private weak var currentWebView: WKWebView?
	private var isActive = true
	private var currentNavigation: WKNavigation?
	private var isVisible = false
	private var isLoading = false
	private var lastLoadedURL: URL?
	
	private var canGoBackObservation: NSKeyValueObservation?
	private var canGoForwardObservation: NSKeyValueObservation?
	private var urlObservation: NSKeyValueObservation?
	
	init(_ parent: WebViewContainer) {
		self.tabID = parent.tab.id
		self.modelContext = parent.modelContext
		self.isVisible = parent.isVisible
		super.init()
		
		// Add notification observer
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleLoadURL(_:)),
			name: .loadURL,
			object: nil
		)
	}
	
	// Add this method to handle URL loading
	@objc private func handleLoadURL(_ notification: Notification) {
		guard let loadRequest = notification.object as? LoadURLRequest,
			  loadRequest.tab.id == tabID,
			  let webView = currentWebView,
			  isMyWebView(webView) else {
			return
		}
		
		isLoading = true
		lastLoadedURL = loadRequest.url
		let request = URLRequest(url: loadRequest.url)
		webView.load(request)
	}
	
	// MARK: - Public Methods
	func setCurrentWebView(_ webView: WKWebView) {
		assert(Thread.isMainThread, "setCurrentWebView must be called on main thread")
		
		// Only clear if the new WebView is different
		if webView !== currentWebView {
			clearWebView()
		}
		
		// Store coordinator ID using associated object
		webView.associatedCoordinatorID = coordinatorID
		currentWebView = webView
		isActive = true
		
		observeNavigationState(webView)
		
		// Update visibility
		webView.isHidden = !isVisible
		
		loadInitialURL()
	}
	
	func clearWebView() {
		assert(Thread.isMainThread, "clearWebView must be called on main thread")
		
		clearObservations()
		
		if let webView = currentWebView {
			// Only clear if it matches our coordinator ID
			if webView.associatedCoordinatorID == coordinatorID {
				webView.associatedCoordinatorID = nil
			}
		}
		
		currentWebView = nil
		isActive = false
		currentNavigation = nil
	}
	
	func loadInitialURL() {
		guard let webView = currentWebView,
			  let tab = getTab(),
			  !isLoading,
			  lastLoadedURL != tab.url else { return }
		
		print("Loading URL: \(tab.url) for tab: \(tabID)")
		isLoading = true
		lastLoadedURL = tab.url
		let request = URLRequest(url: tab.url)
		webView.load(request)
	}
	
	func updateVisibility(_ visible: Bool) {
		isVisible = visible
		currentWebView?.isHidden = !visible
	}
	
	func getTab() -> Tab? {
		if Thread.isMainThread {
			return fetchTab()
		}
		var result: Tab?
		DispatchQueue.main.sync {
			result = fetchTab()
		}
		return result
	}
	
	// MARK: - Private Methods
	private func fetchTab() -> Tab? {
		assert(Thread.isMainThread)
		let targetID = self.tabID
		let descriptor = FetchDescriptor<Tab>(
			predicate: #Predicate<Tab> { $0.id == targetID }
		)
		return try? modelContext.fetch(descriptor).first
	}
	
	private func clearObservations() {
		canGoBackObservation?.invalidate()
		canGoForwardObservation?.invalidate()
		urlObservation?.invalidate()
		
		canGoBackObservation = nil
		canGoForwardObservation = nil
		urlObservation = nil
	}
	
	private func observeNavigationState(_ webView: WKWebView) {
		canGoBackObservation = webView.observe(\.canGoBack) { [weak self] webView, _ in
			guard let self = self,
				  self.isMyWebView(webView) else { return }
			
			DispatchQueue.main.async {
				guard webView.associatedCoordinatorID == self.coordinatorID else { return }
				NotificationCenter.default.post(
					name: .webViewCanGoBackChanged,
					object: (self.tabID, webView.canGoBack)
				)
			}
		}
		
		canGoForwardObservation = webView.observe(\.canGoForward) { [weak self] webView, _ in
			guard let self = self,
				  self.isMyWebView(webView) else { return }
			
			DispatchQueue.main.async {
				guard webView.associatedCoordinatorID == self.coordinatorID else { return }
				NotificationCenter.default.post(
					name: .webViewCanGoForwardChanged,
					object: (self.tabID, webView.canGoForward)
				)
			}
		}
		
		urlObservation = webView.observe(\.url) { [weak self] webView, _ in
			guard let self = self,
				  self.isMyWebView(webView),
				  let url = webView.url else { return }
			
			DispatchQueue.main.async {
				guard webView.associatedCoordinatorID == self.coordinatorID,
					  let tab = self.getTab() else { return }
				
				tab.url = url
				NotificationCenter.default.post(
					name: .webViewURLChanged,
					object: WebViewURLChange(tab: tab, url: url)
				)
				try? self.modelContext.save()
			}
		}
	}
	
	private func isMyWebView(_ webView: WKWebView) -> Bool {
		guard isActive,
			  webView === currentWebView,
			  webView.associatedCoordinatorID == coordinatorID else {
			return false
		}
		return true
	}
	
	// MARK: - WKNavigationDelegate Methods
	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		guard isMyWebView(webView) else { return }
		
		currentNavigation = navigation
		isLoading = true
		
		DispatchQueue.main.async { [weak self] in
			guard let self = self,
				  let tab = self.getTab() else { return }
			
			NotificationCenter.default.post(
				name: .webViewStartedLoading,
				object: tab
			)
		}
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		guard isMyWebView(webView),
			  navigation === currentNavigation else { return }
		
		isLoading = false
		currentNavigation = nil
		
		DispatchQueue.main.async { [weak self] in
			guard let self = self,
				  let tab = self.getTab() else { return }
			
			NotificationCenter.default.post(
				name: .webViewFinishedLoading,
				object: tab
			)
			
			if let url = webView.url {
				self.lastLoadedURL = url
				tab.url = url
				NotificationCenter.default.post(
					name: .webViewURLChanged,
					object: WebViewURLChange(tab: tab, url: url)
				)
			}
			
			self.updateTitleAndFavicon(webView: webView, tab: tab)
		}
	}
	
	private func updateTitleAndFavicon(webView: WKWebView, tab: Tab) {
		guard isMyWebView(webView) else { return }
		
		webView.evaluateJavaScript("document.title") { [weak self] (result, error) in
			guard let self = self,
				  self.isMyWebView(webView),
				  let title = result as? String else { return }
			
			DispatchQueue.main.async {
				guard webView.associatedCoordinatorID == self.coordinatorID,
					  let currentTab = self.getTab() else { return }
				currentTab.title = title
				try? self.modelContext.save()
			}
		}
		
		webView.evaluateJavaScript("""
			var link = document.querySelector("link[rel~='icon']");
			if (!link) {
				link = document.querySelector("link[rel~='shortcut icon']");
			}
			link ? link.href : null;
		""") { [weak self] (result, error) in
			guard let self = self,
				  self.isMyWebView(webView),
				  let iconURLString = result as? String,
				  let iconURL = URL(string: iconURLString) else { return }
			
			URLSession.shared.dataTask(with: iconURL) { [weak self] data, response, error in
				guard let self = self,
					  let data = data else { return }
				
				DispatchQueue.main.async {
					guard self.isMyWebView(webView),
						  let currentTab = self.getTab() else { return }
					currentTab.favicon = data
					try? self.modelContext.save()
				}
			}.resume()
		}
	}
	
	// MARK: - Navigation Policy
	func webView(_ webView: WKWebView,
				 decidePolicyFor navigationAction: WKNavigationAction,
				 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		guard isMyWebView(webView) else {
			decisionHandler(.allow)
			return
		}

		// Handle new window/tab requests
		if navigationAction.targetFrame == nil {
			handleNewTabNavigation(webView, navigationAction: navigationAction)
			decisionHandler(.cancel)
			return
		}

		// Handle command-click or middle-click
		if navigationAction.modifierFlags.contains(.command) ||
		   navigationAction.buttonNumber == 1 {  // Middle click
			handleNewTabNavigation(webView, navigationAction: navigationAction)
			decisionHandler(.cancel)
			return
		}

		// Handle normal navigation
		decisionHandler(.allow)
	}

	// MARK: - Window Creation
	func webView(_ webView: WKWebView,
				 createWebViewWith configuration: WKWebViewConfiguration,
				 for navigationAction: WKNavigationAction,
				 windowFeatures: WKWindowFeatures) -> WKWebView? {
		
		handleNewTabNavigation(webView, navigationAction: navigationAction)
		return nil
	}

	// MARK: - Private Helper Methods
	private func handleNewTabNavigation(_ webView: WKWebView, navigationAction: WKNavigationAction) {
		guard let url = navigationAction.request.url,
			  let tab = getTab(),
			  let workspace = tab.workspace else { return }

		DispatchQueue.main.async {
			let newTab = Tab.createNewTab(with: url, in: workspace)
			try? self.modelContext.save()

			// Post notification to select the new tab
			NotificationCenter.default.post(
				name: .selectNewTab,
				object: SelectTabRequest(workspace: workspace, tab: newTab)
			)
		}
	}
	
}

struct SelectTabRequest {
	let workspace: Workspace
	let tab: Tab
}


