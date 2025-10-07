import Foundation
import CoreLocation
import MapKit
import SwiftUI

/// Main framework for Overpass API interactions
public struct OverpassKit {
    /// Default Overpass API endpoints
    public enum Endpoint: String, CaseIterable {
        case overpassAPI = "https://overpass-api.de/api/interpreter"
        case miataru = "https://overpass.miataru.com/api/interpreter"
        case kumiSystems = "https://overpass.kumi.systems/api/interpreter"
        
        var url: URL {
            return URL(string: rawValue)!
        }
    }
    
    /// Supported output formats
    public enum OutputFormat: String, CaseIterable {
        case json = "json"
        case xml = "xml"
        case csv = "csv"
    }
    
    /// Query timeout configuration
    public struct Timeout {
        public let serverTimeout: Int
        public let clientTimeout: TimeInterval
        
        public init(serverTimeout: Int = 20, clientTimeout: TimeInterval = 22.0) {
            self.serverTimeout = serverTimeout
            self.clientTimeout = clientTimeout
        }
    }
    
    /// SwiftUI environment key for Overpass client
    @MainActor
    public struct ClientKey: EnvironmentKey {
        public static var defaultValue: OverpassClient { OverpassClient() }
    }
}

// MARK: - Environment Extension

@MainActor extension EnvironmentValues {
    /// Access to the Overpass client in SwiftUI environment
    public var overpassClient: OverpassClient {
        get { self[OverpassKit.ClientKey.self] }
        set { self[OverpassKit.ClientKey.self] = newValue }
    }
}

// MARK: - View Extension

@MainActor extension View {
    /// Provides an Overpass client to the view hierarchy
    /// - Parameter client: The Overpass client to provide
    /// - Returns: A view with the Overpass client in its environment
    public func overpassClient(_ client: OverpassClient) -> some View {
        environment(\.overpassClient, client)
    }
}

/// Main error types for Overpass operations
public enum OverpassError: Error, LocalizedError {
    case invalidCoordinates
    case invalidBoundingBox
    case networkError(Error)
    case invalidResponse
    case timeout
    case queryError(String)
    case noData
    
    public var errorDescription: String? {
        switch self {
        case .invalidCoordinates:
            return "Invalid coordinates provided"
        case .invalidBoundingBox:
            return "Invalid bounding box configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .timeout:
            return "Request timed out"
        case .queryError(let message):
            return "Query error: \(message)"
        case .noData:
            return "No data returned from query"
        }
    }
}
