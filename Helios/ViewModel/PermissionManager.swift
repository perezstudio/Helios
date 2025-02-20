//
//  PermissionManager.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//


import SwiftUI
import SwiftData

@Observable
class PermissionManager {
    static let shared = PermissionManager()
    
    var pendingRequests: [PermissionRequest] = []
    var activeRequest: PermissionRequest?
    
    private init() {}
    
    struct PermissionRequest: Identifiable, Equatable {
        let id = UUID()
        let domain: String
        let permission: PermissionFeature
        let defaultValue: PermissionState
        
        static func == (lhs: PermissionRequest, rhs: PermissionRequest) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    enum PermissionFeature: String {
        case location = "Location"
        case camera = "Camera"
        case microphone = "Microphone"
        case notifications = "Notifications"
        // Add other permission types as needed
        
        var defaultValue: PermissionState {
            switch self {
            case .location, .camera, .microphone:
                return .ask
            case .notifications:
                return .block
            }
        }
    }
    
    func requestPermission(for domain: String, permission: PermissionFeature) {
        // Check if we already have a similar request pending
        guard !pendingRequests.contains(where: { $0.domain == domain && $0.permission == permission }) else {
            return
        }
        
        let request = PermissionRequest(domain: domain, 
                                      permission: permission,
                                      defaultValue: permission.defaultValue)
        pendingRequests.append(request)
        
        if activeRequest == nil {
            activeRequest = request
        }
    }
    
    func handlePermissionResponse(_ state: PermissionState, for request: PermissionRequest, in context: ModelContext) {
        guard let siteSettings = getOrCreateSiteSettings(for: request.domain, in: context) else {
            return
        }
        
        // Only store if different from default
        if state != request.defaultValue {
            switch request.permission {
            case .location:
                siteSettings.location = state
            case .camera:
                siteSettings.camera = state
            case .microphone:
                siteSettings.microphone = state
            case .notifications:
                siteSettings.notifications = state
            }
            
            try? context.save()
        }
        
        // Remove the request
        pendingRequests.removeAll(where: { $0.id == request.id })
        if request.id == activeRequest?.id {
            activeRequest = pendingRequests.first
        }
    }
    
    private func getOrCreateSiteSettings(for domain: String, in context: ModelContext) -> SiteSettings? {
        // Try to find existing settings
        let descriptor = FetchDescriptor<SiteSettings>(
            predicate: #Predicate<SiteSettings> { settings in
                settings.hostPattern == domain
            }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // Create new settings if none exist
        let settings = SiteSettings(hostPattern: domain, useDefaults: true)
        context.insert(settings)
        return settings
    }
}
