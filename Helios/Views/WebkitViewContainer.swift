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
	
	private func createWebView(coordinator: WebViewCoordinator) -> WKWebView {
		print("Creating WebView for tab: \(tab.id)")
		let config = WKWebViewConfiguration()
		config.preferences.javaScriptCanOpenWindowsAutomatically = true
		config.preferences.isElementFullscreenEnabled = true
		
		config.applicationNameForUserAgent = "Version/17.2.1 Safari/605.1.15"
		
		let webView = WKWebView(frame: .zero, configuration: config)
		webView.allowsMagnification = true
		webView.allowsBackForwardNavigationGestures = true
		webView.navigationDelegate = coordinator
		webView.uiDelegate = coordinator
		
		print("Loading URL: \(tab.url) for tab: \(tab.id)")
		let request = URLRequest(url: tab.url)
		webView.load(request)
		
		return webView
	}
	
	func makeNSView(context: Context) -> WebContainerView {
		print("Creating container for tab: \(tab.id)")
		let containerView = WebContainerView()
		containerView.frame = NSRect(x: 0, y: 0, width: 800, height: 600) // Set initial size
		
		let coordinator = context.coordinator
		
		// Use the tab's ID as the key for the WebView
		let webView = WebViewStore.shared.getOrCreateWebView(
			for: tab.id,
			createWebView: { createWebView(coordinator: coordinator) }
		)
		
		containerView.webView = webView
		coordinator.setCurrentWebView(webView)
		coordinator.tabID = tab.id // Set the tabID in the coordinator
		
		return containerView
	}
	
	func updateNSView(_ containerView: WebContainerView, context: Context) {
			print("Updating container for tab: \(tab.id)")
			
			let coordinator = context.coordinator
			
			// Ensure we're using the correct WebView for this tab
			let webView = WebViewStore.shared.getOrCreateWebView(
				for: tab.id,
				createWebView: { createWebView(coordinator: coordinator) }
			)
			
			// Only update the WebView if it's different from the current one
			if containerView.webView !== webView {
				containerView.webView = webView
				coordinator.setCurrentWebView(webView)
				coordinator.tabID = tab.id // Update the tabID in the coordinator
			}
			
			// Ensure proper frame setup
			webView.frame = containerView.bounds
			webView.autoresizingMask = [.width, .height]
			
			// Force layout update
			containerView.layout()
		}
	
	static func dismantleNSView(_ containerView: WebContainerView, coordinator: WebViewCoordinator) {
		let tabID = coordinator.tabID
		print("Dismantling container for tab: \(tabID)")
		
		// Get tab to check if it's pinned
		guard let tab = coordinator.getTab() else {
			// If we can't get the tab, clean up anyway
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
