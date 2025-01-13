//
//  WebViewContainer.swift
//  Helios
//
//  Created by Kevin Perez on 1/12/25.
//


import SwiftUI
import WebKit

struct WebViewContainer: NSViewRepresentable {
	let webView: WKWebView

	func makeNSView(context: Context) -> WKWebView {
		webView.frame = .zero
		return webView
	}

	func updateNSView(_ nsView: WKWebView, context: Context) {
		// No need for updates as we're recreating the view when tab changes
	}
}
