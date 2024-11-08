//
//  SSLIndicator.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct SSLIndicator: View {
	let url: URL
	let isSecure: Bool
	
	init(tab: Tab) {
		self.url = tab.url
		self.isSecure = tab.isSecure
	}
	
	var body: some View {
		Image(systemName: isSecure ? "lock.fill" : "lock.open.fill")
			.foregroundColor(isSecure ? .green : .orange)
			.frame(width: 16)
			.help(isSecure ? "Secure Connection (HTTPS)" : "Insecure Connection (HTTP)")
			.contentTransition(.symbolEffect(.replace))
	}
}
