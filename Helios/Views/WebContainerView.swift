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
			if newValue !== webView {
				webView?.removeFromSuperview()
			}
		}
		didSet {
			if let webView = webView, webView.superview !== self {
				webView.translatesAutoresizingMaskIntoConstraints = false
				addSubview(webView)
				
				NSLayoutConstraint.activate([
					webView.topAnchor.constraint(equalTo: topAnchor),
					webView.leadingAnchor.constraint(equalTo: leadingAnchor),
					webView.trailingAnchor.constraint(equalTo: trailingAnchor),
					webView.bottomAnchor.constraint(equalTo: bottomAnchor)
				])
				
				layout()
			}
		}
	}
	
	override func layout() {
		super.layout()
		if frame.size.width > 0 && frame.size.height > 0 {
			webView?.frame = bounds
		}
	}
}
