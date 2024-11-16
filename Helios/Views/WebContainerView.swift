//
//  WebContainerView.swift
//  Helios
//
//  Created by Kevin Perez on 11/10/24.
//

import SwiftUI
import SwiftData
import WebKit

class WebContainerView: NSView {
	weak var webView: WKWebView? {
		willSet {
			// Remove old WebView
			if let oldWebView = webView, oldWebView !== newValue {
				print("Removing old WebView")
				oldWebView.removeFromSuperview()
			}
		}
		didSet {
			// Add new WebView
			if let newWebView = webView, newWebView.superview !== self {
				print("Adding new WebView to container")
				addSubview(newWebView)
				newWebView.frame = bounds
				newWebView.autoresizingMask = [.width, .height]
				
				// Force layout update
				needsLayout = true
			}
		}
	}
	
	override func layout() {
		super.layout()
		print("Container layout update - bounds: \(bounds)")
		webView?.frame = bounds
	}
	
	override var frame: NSRect {
		didSet {
			print("Container frame updated to: \(frame)")
			webView?.frame = bounds
		}
	}
	
	deinit {
		print("WebContainerView deinit")
		webView?.removeFromSuperview()
	}
}
