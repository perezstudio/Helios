//
//  IconPicker.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI

struct IconPicker: View {
    @Binding var selectedIcon: String
    @Binding var selectedGroup: IconGroup
    
    var body: some View {
        VStack {
            // Group Scroll Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(iconGroups) { group in
                        Button {
                            selectedGroup = group // Change selected group
                        } label: {
                            Text(group.name)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(group.id == selectedGroup.id ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
			.background(Color.gray.opacity(0.60))
            
            // Icons Grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 15) {
                    ForEach(selectedGroup.symbols, id: \.self) { icon in
                        Button {
                            selectedIcon = icon // Select icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .padding()
                                .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
        }
    }
}
