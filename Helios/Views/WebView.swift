//
//  WebView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import SwiftData
import WebKit

struct WebView: NSViewRepresentable {
	@Binding var url: URL?
	var profile: Profile // Ensure profile is passed in

	func makeNSView(context: Context) -> WKWebView {
		let configuration = WKWebViewConfiguration()
		configuration.websiteDataStore = SessionManager.shared.getDataStore(for: profile) // Use profile's data store
		let webView = WKWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = context.coordinator
		return webView
	}

	func updateNSView(_ nsView: WKWebView, context: Context) {
		if let url = url {
			let request = URLRequest(url: url)
			nsView.load(request)
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject, WKNavigationDelegate {
		var parent: WebView

		init(_ parent: WebView) {
			self.parent = parent
		}
	}
}
