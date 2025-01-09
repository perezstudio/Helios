//
//  Tab.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//
import SwiftUI
import SwiftData

@Model
class Tab {
    var id: UUID = UUID()
    var title: String
    var url: String
	var favicon: String = ""
	var customTitle: String = ""
    var isPinned: Bool
    var isBookmark: Bool
	var bookmarkURL: String = ""
	
	// Lazily initialize the WebNavigationService
	@Transient private var _webService: WebNavigationService? = nil
	
	var webService: WebNavigationService {
		if _webService == nil {
			print("Initializing WebNavigationService for tab: \(title)")
			_webService = WebNavigationService()
		}
		return _webService!
	}
    
    init(title: String, url: String, favicon: String = "", customTitle: String = "", isPinned: Bool = false, isBookmark: Bool = false, bookmarkURL: String = "") {
        self.title = title
        self.url = url
		self.favicon = favicon
		self.customTitle = customTitle
        self.isPinned = isPinned
        self.isBookmark = isBookmark
		self.bookmarkURL = bookmarkURL
		print("Tab initialized with title: \(title), URL: \(url)")
		print("Tab initialized: \(title)")
		print("Tab initialized: \(url)")
    }
	
	deinit {
		// Clean up the WebNavigationService when the tab is destroyed
		_webService = nil
		print("Tab deinitialized: \(title)")
		print("Tab deinitialized: \(url)")
	}
}
