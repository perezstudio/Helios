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
			// Only remove if it's being replaced with a different WebView
			if newValue !== webView {
				print("Removing old WebView")
				webView?.removeFromSuperview()
			}
		}
		didSet {
			// Only add if it's a new WebView
			if let webView = webView, webView.superview !== self {
				print("Adding new WebView to container")
				addSubview(webView)
				webView.frame = bounds
				webView.autoresizingMask = [.width, .height]
				
				// Force layout update
				layout()
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
}
