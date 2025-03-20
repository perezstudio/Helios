# Helios Browser Documentation

## Introduction

Welcome to the documentation for Helios, a macOS web browser application built with SwiftUI and SwiftData. This documentation provides a comprehensive overview of the application's architecture, components, and functionality.

## Table of Contents

1. [Project Overview](project_overview.md)
2. [Application Architecture](app_architecture.md)
3. [File Structure](file_structure.md)
4. [Data Models](data_models.md)
5. [View Models](view_models.md)
6. [Views](views.md)
7. [WebView Management](webview_management.md)

## Getting Started

Helios is a SwiftUI application that follows the MVVM (Model-View-ViewModel) architecture. It uses SwiftData for persistence and WebKit for web rendering.

### Key Features

- **Multiple Workspaces**: Organize your browsing with separate workspaces
- **Profile-based Browsing**: Maintain isolated browsing contexts
- **Tab Management**: Support for pinned, bookmarked, and regular tabs
- **Site Permissions**: Fine-grained control over website permissions
- **Search Engine Management**: Configure and use multiple search engines

### Technology Stack

- **SwiftUI**: For building the user interface
- **SwiftData**: For data persistence
- **WebKit**: For web content rendering
- **Combine**: For reactive programming

## Core Concepts

### Profiles

Profiles are isolated browsing contexts with their own:
- Workspaces
- Browsing history
- Site permissions
- Search engine preferences

Profiles ensure complete isolation of browser data between different users or contexts.

### Workspaces

Workspaces are collections of tabs with associated metadata:
- Name
- Icon
- Color theme
- Tab collection

Workspaces help organize browsing activities by context or project.

### Tabs

Tabs represent individual web pages and can be:
- Normal tabs: Standard browsing tabs
- Pinned tabs: Always-visible tabs, typically for frequently used sites
- Bookmarked tabs: Tabs that represent bookmarks

### Site Settings

Site settings provide granular control over website permissions:
- Hardware access (camera, microphone, location)
- Content settings (JavaScript, popups, notifications)
- Advanced features (AR/VR, window management)

## Additional Resources

- SwiftUI Documentation: [https://developer.apple.com/documentation/swiftui](https://developer.apple.com/documentation/swiftui)
- SwiftData Documentation: [https://developer.apple.com/documentation/swiftdata](https://developer.apple.com/documentation/swiftdata)
- WebKit Documentation: [https://developer.apple.com/documentation/webkit](https://developer.apple.com/documentation/webkit)

## Contribution Guidelines

When contributing to the Helios project:

1. Follow the existing architecture and code organization
2. Maintain isolated profile sessions using proper WebKit configuration
3. Use SwiftData for persistence
4. Update documentation when making significant changes
5. Follow SwiftUI best practices for UI components
