//
//  PermissionsForm.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//

import SwiftUI
import SwiftData

struct PermissionsForm: View {
    @Bindable var settings: SiteSettings
    
    var body: some View {
        Section("Hardware Access") {
            OptionalPermissionRow(title: "Location", selection: .init(
                get: { settings.location },
                set: { settings.location = $0 }
            ))
            OptionalPermissionRow(title: "Camera", selection: .init(
                get: { settings.camera },
                set: { settings.camera = $0 }
            ))
            // Add other permission rows...
        }
        
        Section("Content Settings") {
            OptionalPermissionRow(title: "JavaScript", selection: .init(
                get: { settings.javascript },
                set: { settings.javascript = $0 }
            ))
            // Add other content settings...
        }
        
        Section("Advanced Features") {
            OptionalPermissionRow(title: "Augmented Reality", selection: .init(
                get: { settings.augmentedReality },
                set: { settings.augmentedReality = $0 }
            ))
            // Add other advanced features...
        }
    }
}
