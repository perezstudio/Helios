//
//  TabView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//
import SwiftUI
import SwiftData

struct TabView: View {
	
	@Binding var selectedTab: Tab?
	@Bindable var tab: Tab
    
    var body: some View {
        if(selectedTab == tab) {
			HStack {
				Text(tab.title)
				Spacer()
				Image(systemName: "xmark")
			}
			.padding(.horizontal, 8)
			.padding(.vertical, 6)
			.background (Material.bar)
			.cornerRadius(10)
		} else {
			HStack {
				Text(tab.title)
				Spacer()
				Image(systemName: "xmark")
			}
			.padding(.horizontal, 8)
			.padding(.vertical, 6)
			.cornerRadius(10)
		}
    }
}
