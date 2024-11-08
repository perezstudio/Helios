//
//  SFSymbolsPicker.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct SFSymbolsPicker: View {
	@Binding var selectedSymbol: String
	// Common SF Symbols that might be relevant for browser workspaces
	let symbols = [
		"globe", "star", "bookmark", "folder",
		"house", "briefcase", "bag", "cart",
		"heart", "person", "gamecontroller",
		"music.note", "video", "photo", "doc",
		"mail", "calendar", "chart.bar", "gear",
		"terminal", "network", "cloud", "lock.shield"
	]
	
	let columns = [
		GridItem(.adaptive(minimum: 44))
	]
	
	var body: some View {
		VStack(alignment: .leading) {
			Text("Choose an Icon")
				.font(.headline)
				.padding(.bottom, 8)
			
			ScrollView {
				LazyVGrid(columns: columns, spacing: 12) {
					ForEach(symbols, id: \.self) { symbol in
						Image(systemName: symbol)
							.font(.title2)
							.frame(width: 44, height: 44)
							.background(
								selectedSymbol == symbol ?
								Color.accentColor.opacity(0.2) :
								Color.clear
							)
							.cornerRadius(8)
							.onTapGesture {
								selectedSymbol = symbol
							}
					}
				}
			}
			.frame(height: 200)
		}
		.padding()
	}
}
