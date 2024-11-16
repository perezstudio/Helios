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
	
	func makeCoordinator() -> WebViewCoordinator {
		let coordinator = WebViewCoordinator(self)
		print("Created coordinator for tab: \(tab.id)")
		return coordinator
	}
	
	func makeNSView(context: Context) -> WebContainerView {
		print("Creating container for tab: \(tab.id)")
		let containerView = WebContainerView()
		containerView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
		
		// Create and configure WebView
		let webView = createWebView(coordinator: context.coordinator)
		containerView.webView = webView
		
		// Load initial URL
		let request = URLRequest(url: tab.url)
		webView.load(request)
		
		return containerView
	}
	
	func updateNSView(_ containerView: WebContainerView, context: Context) {
		print("Updating container for tab: \(tab.id)")
		
		if containerView.webView == nil {
			// Recreate WebView if missing
			let webView = createWebView(coordinator: context.coordinator)
			containerView.webView = webView
			let request = URLRequest(url: tab.url)
			webView.load(request)
		}
		
		// Update visibility
		containerView.isHidden = !isVisible
		containerView.webView?.isHidden = !isVisible
		
		// Update frame
		if let webView = containerView.webView {
			webView.frame = containerView.bounds
		}
	}
	
	static func dismantleNSView(_ containerView: WebContainerView, coordinator: WebViewCoordinator) {
		print("Dismantling container for tab: \(coordinator.tabID)")
		if let webView = containerView.webView {
			webView.stopLoading()
			webView.navigationDelegate = nil
			webView.uiDelegate = nil
			webView.removeFromSuperview()
		}
		containerView.webView = nil
	}
	
	private func createWebView(coordinator: WebViewCoordinator) -> WKWebView {
		print("Creating WebView for tab: \(tab.id)")
		
		let config = WKWebViewConfiguration()
		config.websiteDataStore = WKWebsiteDataStore.default()
		config.applicationNameForUserAgent = "Version/17.2.1 Safari/605.1.15"
		
		let webView = WKWebView(frame: .zero, configuration: config)
		webView.navigationDelegate = coordinator
		webView.uiDelegate = coordinator
		webView.allowsMagnification = true
		webView.allowsBackForwardNavigationGestures = true
		
		return webView
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
