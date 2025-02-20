//
//  OptionalPermissionRow.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//

import SwiftUI
import SwiftData

struct OptionalPermissionRow: View {
    let title: String
    @Binding var selection: PermissionState?
    
    var body: some View {
        Picker(title, selection: $selection) {
            Text("Use Default").tag(Optional<PermissionState>.none)
            ForEach(PermissionState.allCases, id: \.self) { state in
                Text(state.description).tag(Optional(state))
            }
        }
    }
}
