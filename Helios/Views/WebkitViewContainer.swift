//
//  WebkitViewContainer.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData
import WebKit

struct WebViewContainer: NSViewRepresentable {
	let tab: Tab
	let modelContext: ModelContext
	@Binding var isVisible: Bool
	
	// Add UserDefaults observation for privacy settings
	@AppStorage("blockTrackers") private var blockTrackers = true
	@AppStorage("preventCrossSiteTracking") private var preventCrossSiteTracking = true
	@AppStorage("hideIpAddress") private var hideIpAddress = false
	@AppStorage("customUserAgent") private var customUserAgent = ""
	
	private func createWebView(coordinator: WebViewCoordinator) -> WKWebView {
		print("Creating WebView for tab: \(tab.id)")
		
		// Create WKWebViewConfiguration with privacy settings
		let config = WKWebViewConfiguration()
		
		// Set up Website Privacy preferences
		if blockTrackers {
			config.websiteDataStore = .nonPersistent()
		}
		
		// Configure content blockers if needed
		if preventCrossSiteTracking {
			config.defaultWebpagePreferences.allowsContentJavaScript = false
		}
		
		// Configure custom User Agent
		// Use Safari's default user agent string
		config.applicationNameForUserAgent = "Version/17.2.1 Safari/605.1.15"
		
		// Basic configuration
		config.preferences.javaScriptCanOpenWindowsAutomatically = true
		config.preferences.isElementFullscreenEnabled = true
		
		let webView = WKWebView(frame: .zero, configuration: config)
		webView.allowsMagnification = true
		webView.allowsBackForwardNavigationGestures = true
		webView.navigationDelegate = coordinator
		webView.uiDelegate = coordinator
		
		// Additional privacy configurations
		if hideIpAddress {
			webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2.1 Safari/605.1.15"
		}
		
		// Move the URL loading to the coordinator
		coordinator.loadInitialURL()
		
		return webView
	}
	
	func makeNSView(context: Context) -> WebContainerView {
		print("Creating container for tab: \(tab.id)")
		let containerView = WebContainerView()
		containerView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
		
		let coordinator = context.coordinator
		
		let webView = WebViewStore.shared.getOrCreateWebView(
			for: tab.id,
			createWebView: { createWebView(coordinator: coordinator) }
		)
		
		containerView.webView = webView
		coordinator.setCurrentWebView(webView)
		coordinator.tabID = tab.id
		
		return containerView
	}
	
	func updateNSView(_ containerView: WebContainerView, context: Context) {
		print("Updating container for tab: \(tab.id)")
		
		let coordinator = context.coordinator
		
		let webView = WebViewStore.shared.getOrCreateWebView(
			for: tab.id,
			createWebView: { createWebView(coordinator: coordinator) }
		)
		
		if containerView.webView !== webView {
			containerView.webView = webView
			coordinator.setCurrentWebView(webView)
			coordinator.tabID = tab.id
		}
		
		// Update privacy settings if they've changed
		if let webView = containerView.webView {
			if hideIpAddress {
				webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2.1 Safari/605.1.15"
			} else {
				webView.customUserAgent = nil
			}
		}
		
		containerView.isHidden = !isVisible
		webView.frame = containerView.bounds
		webView.autoresizingMask = [.width, .height]
		
		containerView.layout()
	}
	
	static func dismantleNSView(_ containerView: WebContainerView, coordinator: WebViewCoordinator) {
		let tabID = coordinator.tabID
		print("Dismantling container for tab: \(tabID)")
		
		guard let tab = coordinator.getTab() else {
			WebViewStore.shared.remove(for: tabID)
			containerView.webView = nil
			coordinator.clearWebView()
			return
		}
		
		if !tab.isPinned {
			WebViewStore.shared.remove(for: tabID)
			containerView.webView = nil
			coordinator.clearWebView()
		}
	}
	
	func makeCoordinator() -> WebViewCoordinator {
		let coordinator = WebViewCoordinator(self)
		print("Created new coordinator for tab: \(tab.id)")
		return coordinator
	}
}

// MARK: - Coordinator ID Store
private var coordinatorIDKey: UInt8 = 0

extension WKWebView {
	var associatedCoordinatorID: UUID? {
		get {
			return objc_getAssociatedObject(self, &coordinatorIDKey) as? UUID
		}
		set {
			objc_setAssociatedObject(self, &coordinatorIDKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		}
	}
}
