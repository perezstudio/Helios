//
//  WebView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
	let webView: WKWebView // Dynamic web view instance

	func makeNSView(context: Context) -> WKWebView {
		return webView // Always create with the provided instance
	}

	func updateNSView(_ nsView: WKWebView, context: Context) {
		// No need to update anything dynamically here
	}
}
