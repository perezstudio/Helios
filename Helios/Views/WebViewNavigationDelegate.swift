//
//  WebViewNavigationDelegate.swift
//  Helios
//
//  Created by Kevin Perez on 1/12/25.
//

import SwiftUI
import SwiftData
import WebKit

class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private weak var tab: Tab?
    private let onTitleUpdate: (String?) -> Void
    
    init(tab: Tab, onTitleUpdate: @escaping (String?) -> Void) {
        self.tab = tab
        self.onTitleUpdate = onTitleUpdate
        super.init()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onTitleUpdate(webView.title)
    }
}
