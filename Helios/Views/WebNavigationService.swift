//
//  WebNavigationService.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import Combine
import WebKit

class WebNavigationService: NSObject, ObservableObject, WKNavigationDelegate {
	@Published var url: String = ""
	var webView: WKWebView! // Ensure this is retained

	override init() {
		super.init()
		initializeWebView()
	}

	private func initializeWebView() {
		let configuration = WKWebViewConfiguration()
		webView = WKWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = self
		print("WebNavigationService initialized")
	}

	func loadURL(_ urlString: String) {
		guard let url = URL(string: urlString) else { return }
		webView.load(URLRequest(url: url))
	}

	// Navigate Back
	func goBack() {
		if webView.canGoBack { webView.goBack() }
	}

	// Navigate Forward
	func goForward() {
		if webView.canGoForward { webView.goForward() }
	}

	// Reload Page
	func reload() {
		webView.reload()
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// Update the published URL after a navigation finishes
		DispatchQueue.main.async { [weak self] in
			self?.url = webView.url?.absoluteString ?? ""
		}
	}
	
	func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
		print("WebView process terminated for tab with URL: \(webView.url?.absoluteString ?? "unknown")")
		// Reload the page if necessary
		if let currentURL = webView.url {
			webView.load(URLRequest(url: currentURL))
		}
	}

	deinit {
		webView.stopLoading()
		webView.navigationDelegate = nil
		print("WebNavigationService deinitialized")
	}
}
