import SwiftUI
import Combine
import CoreLocation

/// SwiftUI view model for Overpass operations
@MainActor
public class OverpassViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: OverpassError?
    @Published public private(set) var lastResponse: OverpassResponse?
    @Published public private(set) var searchHistory: [SearchQuery] = []
    @Published public private(set) var favoriteLocations: [FavoriteLocation] = []
    
    // MARK: - Private Properties
    
    private let overpassClient: OverpassClient
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Initialize with an Overpass client
    /// - Parameter client: The Overpass client to use (nil to create a default one)
    public init(client: OverpassClient? = nil) {
        self.overpassClient = client ?? OverpassClient()
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    /// Searches for toilets in a bounding box
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Search result
    @discardableResult
    public func searchToilets(in boundingBox: OverpassBoundingBox) async -> SearchResult {
        return await performSearch(
            query: .toilets(in: boundingBox),
            searchType: .toilets,
            boundingBox: boundingBox
        )
    }
    
    /// Searches for restaurants in a bounding box
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Search result
    @discardableResult
    public func searchRestaurants(in boundingBox: OverpassBoundingBox) async -> SearchResult {
        return await performSearch(
            query: .restaurants(in: boundingBox),
            searchType: .restaurants,
            boundingBox: boundingBox
        )
    }
    
    /// Searches for cafes in a bounding box
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Search result
    @discardableResult
    public func searchCafes(in boundingBox: OverpassBoundingBox) async -> SearchResult {
        return await performSearch(
            query: .cafes(in: boundingBox),
            searchType: .cafes,
            boundingBox: boundingBox
        )
    }
    
    /// Searches for hotels in a bounding box
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Search result
    @discardableResult
    public func searchHotels(in boundingBox: OverpassBoundingBox) async -> SearchResult {
        return await performSearch(
            query: .hotels(in: boundingBox),
            searchType: .hotels,
            boundingBox: boundingBox
        )
    }
    
    /// Searches for shops in a bounding box
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box
    ///   - shopType: Specific shop type (optional)
    /// - Returns: Search result
    @discardableResult
    public func searchShops(in boundingBox: OverpassBoundingBox, shopType: String? = nil) async -> SearchResult {
        return await performSearch(
            query: .shops(in: boundingBox, shopType: shopType),
            searchType: .shops,
            boundingBox: boundingBox
        )
    }
    
    /// Searches for parks in a bounding box
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Search result
    @discardableResult
    public func searchParks(in boundingBox: OverpassBoundingBox) async -> SearchResult {
        return await performSearch(
            query: .parks(in: boundingBox),
            searchType: .parks,
            boundingBox: boundingBox
        )
    }
    
    /// Performs a custom search
    /// - Parameters:
    ///   - query: Custom Overpass query
    ///   - searchType: Type of search
    ///   - boundingBox: Geographic bounding box
    /// - Returns: Search result
    @discardableResult
    public func performCustomSearch(
        _ query: OverpassQuery,
        searchType: SearchType,
        boundingBox: OverpassBoundingBox
    ) async -> SearchResult {
        return await performSearch(
            query: query,
            searchType: searchType,
            boundingBox: boundingBox
        )
    }
    
    /// Cancels the current search
    public func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        isLoading = false
    }
    
    /// Clears the last error
    public func clearError() {
        lastError = nil
    }
    
    /// Clears the last response
    public func clearResponse() {
        lastResponse = nil
    }
    
    /// Adds a location to favorites
    /// - Parameter location: Location to add to favorites
    public func addToFavorites(_ location: FavoriteLocation) {
        if !favoriteLocations.contains(where: { $0.id == location.id }) {
            favoriteLocations.append(location)
            saveFavorites()
        }
    }
    
    /// Removes a location from favorites
    /// - Parameter location: Location to remove from favorites
    public func removeFromFavorites(_ location: FavoriteLocation) {
        favoriteLocations.removeAll { $0.id == location.id }
        saveFavorites()
    }
    
    /// Checks if a location is in favorites
    /// - Parameter location: Location to check
    /// - Returns: True if location is in favorites
    public func isFavorite(_ location: FavoriteLocation) -> Bool {
        favoriteLocations.contains { $0.id == location.id }
    }
    
    // MARK: - Private Methods
    
    /// Performs a search operation
    /// - Parameters:
    ///   - query: Overpass query to execute
    ///   - searchType: Type of search
    ///   - boundingBox: Geographic bounding box
    /// - Returns: Search result
    private func performSearch(
        query: OverpassQuery,
        searchType: SearchType,
        boundingBox: OverpassBoundingBox
    ) async -> SearchResult {
        // Cancel any existing search
        cancelSearch()
        
        isLoading = true
        lastError = nil
        
        let searchQuery = SearchQuery(
            type: searchType,
            boundingBox: boundingBox,
            timestamp: Date()
        )
        
        searchTask = Task {
            do {
                let response = try await overpassClient.execute(query)
                
                if !Task.isCancelled {
                    lastResponse = response
                    lastError = nil
                    
                    // Add to search history
                    searchHistory.insert(searchQuery, at: 0)
                    if searchHistory.count > 50 {
                        searchHistory = Array(searchHistory.prefix(50))
                    }
                }
            } catch {
                if !Task.isCancelled {
                    let overpassError = error as? OverpassError ?? .networkError(error)
                    lastError = overpassError
                    lastResponse = nil
                }
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
        
        await searchTask?.value
        
        return SearchResult(
            query: searchQuery,
            response: lastResponse,
            error: lastError
        )
    }
    
    /// Loads favorite locations from UserDefaults
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "OverpassKit_Favorites"),
           let favorites = try? JSONDecoder().decode([FavoriteLocation].self, from: data) {
            favoriteLocations = favorites
        }
    }
    
    /// Saves favorite locations to UserDefaults
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteLocations) {
            UserDefaults.standard.set(data, forKey: "OverpassKit_Favorites")
        }
    }
}

// MARK: - Search Types

/// Types of searches that can be performed
public enum SearchType: String, CaseIterable, Codable {
    case toilets = "toilets"
    case restaurants = "restaurants"
    case cafes = "cafes"
    case hotels = "hotels"
    case shops = "shops"
    case parks = "parks"
    case custom = "custom"
    
    /// Display name for the search type
    public var displayName: String {
        switch self {
        case .toilets:
            return NSLocalizedString("query_type_toilets", comment: "Toilets query type")
        case .restaurants:
            return NSLocalizedString("query_type_restaurants", comment: "Restaurants query type")
        case .cafes:
            return NSLocalizedString("query_type_cafes", comment: "Cafes query type")
        case .hotels:
            return NSLocalizedString("query_type_hotels", comment: "Hotels query type")
        case .shops:
            return NSLocalizedString("query_type_shops", comment: "Shops query type")
        case .parks:
            return NSLocalizedString("query_type_parks", comment: "Parks query type")
        case .custom:
            return NSLocalizedString("query_type_custom", comment: "Custom query type")
        }
    }
    
    /// Icon name for the search type
    public var iconName: String {
        switch self {
        case .toilets:
            return "toilet"
        case .restaurants:
            return "fork.knife"
        case .cafes:
            return "cup.and.saucer"
        case .hotels:
            return "bed.double"
        case .shops:
            return "bag"
        case .parks:
            return "leaf"
        case .custom:
            return "magnifyingglass"
        }
    }
}

// MARK: - Search Query

/// Represents a search query
public struct SearchQuery: Identifiable, Equatable {
    public let id = UUID()
    public let type: SearchType
    public let boundingBox: OverpassBoundingBox
    public let timestamp: Date
    
    public init(type: SearchType, boundingBox: OverpassBoundingBox, timestamp: Date) {
        self.type = type
        self.boundingBox = boundingBox
        self.timestamp = timestamp
    }
    
    public static func == (lhs: SearchQuery, rhs: SearchQuery) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Search Result

/// Represents the result of a search operation
public struct SearchResult {
    public let query: SearchQuery
    public let response: OverpassResponse?
    public let error: OverpassError?
    
    public var isSuccess: Bool {
        error == nil && response != nil
    }
    
    public var elementCount: Int {
        response?.elements.count ?? 0
    }
}

// MARK: - Favorite Location

/// Represents a favorite location
public struct FavoriteLocation: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let name: String
    public let coordinate: CLLocationCoordinate2D
    public let type: SearchType
    public let addedDate: Date
    
    public init(name: String, coordinate: CLLocationCoordinate2D, type: SearchType, addedDate: Date = Date()) {
        self.name = name
        self.coordinate = coordinate
        self.type = type
        self.addedDate = addedDate
    }
    
    public static func == (lhs: FavoriteLocation, rhs: FavoriteLocation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CLLocationCoordinate2D Codable

extension CLLocationCoordinate2D: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}
