//
//  WebViewWrapper.swift
//  Helios
//
//  Created by Kevin Perez on 11/14/24.
//
import SwiftUI
import SwiftData
@preconcurrency import WebKit

struct WebViewWrapper: NSViewRepresentable {
	let tab: Tab
	@Bindable var workspace: Workspace

	func makeNSView(context: Context) -> WKWebView {
		let webView = WKWebView()
		webView.navigationDelegate = context.coordinator
		return webView
	}

	func updateNSView(_ nsView: WKWebView, context: Context) {
		if nsView.url != tab.url {
			nsView.load(URLRequest(url: tab.url))
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject, WKNavigationDelegate {
		var parent: WebViewWrapper

		init(_ parent: WebViewWrapper) {
			self.parent = parent
		}

		func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
			if navigationAction.navigationType == .linkActivated {
				if let url = navigationAction.request.url {
					parent.workspace.openLinkInNewTab(url)
					decisionHandler(.cancel)
					return
				}
			}
			decisionHandler(.allow)
		}
	}
}
