import Foundation
import Combine
import SwiftUI

/// Main client for interacting with the Overpass API
@MainActor
public class OverpassClient: ObservableObject {
    
    // MARK: - Properties
    
    /// The endpoint to use for API requests
    public let endpoint: OverpassKit.Endpoint
    
    /// The URL session for network requests
    private let session: URLSession
    
    /// Cache for storing recent responses
    private let cache = NSCache<NSString, CachedResponse>()
    
    /// Maximum number of cached responses
    private let maxCacheSize = 50
    
    /// Current active tasks
    private var activeTasks: [URLSessionDataTask] = []
    
    /// Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Published properties for SwiftUI
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastError: OverpassError?
    @Published public private(set) var lastResponse: OverpassResponse?
    
    // MARK: - Initialization
    
    /// Initialize with a specific endpoint
    /// - Parameter endpoint: Overpass API endpoint to use
    public init(endpoint: OverpassKit.Endpoint = .overpassAPI) {
        self.endpoint = endpoint
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 60.0  // Increased from 30 to 60 seconds
        configuration.timeoutIntervalForRequest = 60.0   // Increased from 30 to 60 seconds
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        // Allow larger responses
        configuration.httpMaximumConnectionsPerHost = 4
        
        self.session = URLSession(configuration: configuration)
        
        // Setup cache cleanup
        setupCacheCleanup()
    }
    
    // MARK: - Public Methods
    
    /// Executes an Overpass query using async/await
    /// - Parameter query: The query to execute
    /// - Returns: Overpass response
    /// - Throws: OverpassError if the query fails
    public func execute(_ query: OverpassQuery) async throws -> OverpassResponse {
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        // Check cache first
        if let cachedResponse = getCachedResponse(for: query) {
            lastResponse = cachedResponse
            return cachedResponse
        }
        
        // Cancel any existing tasks for the same query
        cancelTasks(for: query)
        
        do {
            // Create and execute the request
            let request = try await createRequest(for: query)
            let response = try await executeRequest(request)
            
            // Cache the response
            cacheResponse(response, for: query)
            lastResponse = response
            
            return response
        } catch {
            let overpassError = error as? OverpassError ?? .networkError(error)
            lastError = overpassError
            throw overpassError
        }
    }
    
    /// Executes a custom query string using async/await
    /// - Parameter queryString: Raw Overpass QL query string
    /// - Returns: Overpass response
    /// - Throws: OverpassError if the query fails
    public func execute(_ queryString: String) async throws -> OverpassResponse {
        let query = OverpassQuery(queryString: queryString)
        return try await execute(query)
    }
    
    /// Executes an Overpass query using Combine
    /// - Parameter query: The query to execute
    /// - Returns: Publisher that emits the response or error
    public func executePublisher(_ query: OverpassQuery) -> AnyPublisher<OverpassResponse, OverpassError> {
        // Check cache first
        if let cachedResponse = getCachedResponse(for: query) {
            return Just(cachedResponse)
                .setFailureType(to: OverpassError.self)
                .eraseToAnyPublisher()
        }
        
        // Cancel any existing tasks for the same query
        cancelTasks(for: query)
        
        // Create and execute the request
        return createRequestPublisher(for: query)
            .flatMap { [weak self] request in
                guard let self = self else {
                    return Fail<OverpassResponse, OverpassError>(error: .networkError(NSError(domain: "OverpassClient", code: -1, userInfo: nil))).eraseToAnyPublisher()
                }
                return self.executeRequestPublisher(request).eraseToAnyPublisher()
            }
            .handleEvents(receiveOutput: { [weak self] response in
                self?.cacheResponse(response, for: query)
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Convenience Methods with Async/Await
    
    /// Finds toilets in a bounding box using async/await
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Overpass response
    /// - Throws: OverpassError if the query fails
    public func findToilets(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse {
        let query = OverpassQuery.toilets(in: boundingBox)
        return try await execute(query)
    }
    
    /// Finds restaurants in a bounding box using async/await
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Overpass response
    /// - Throws: OverpassError if the query fails
    public func findRestaurants(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse {
        let query = OverpassQuery.restaurants(in: boundingBox)
        return try await execute(query)
    }
    
    /// Finds cafes in a bounding box using async/await
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Overpass response
    /// - Throws: OverpassError if the query fails
    public func findCafes(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse {
        let query = OverpassQuery.cafes(in: boundingBox)
        return try await execute(query)
    }
    
    /// Finds hotels in a bounding box using async/await
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Overpass response
    /// - Throws: OverpassError if the query fails
    public func findHotels(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse {
        let query = OverpassQuery.hotels(in: boundingBox)
        return try await execute(query)
    }
    
    /// Finds shops in a bounding box using async/await
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box
    ///   - shopType: Specific shop type (optional)
    /// - Returns: Overpass response
    /// - Throws: OverpassError if the query fails
    public func findShops(in boundingBox: OverpassBoundingBox, shopType: String? = nil) async throws -> OverpassResponse {
        let query = OverpassQuery.shops(in: boundingBox, shopType: shopType)
        return try await execute(query)
    }
    
    /// Finds parks in a bounding box using async/await
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Overpass response
    /// - Throws: OverpassError if the query fails
    public func findParks(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse {
        let query = OverpassQuery.parks(in: boundingBox)
        return try await execute(query)
    }
    
    // MARK: - Combine Methods (Legacy Support)
    
    /// Executes an Overpass query using Combine (legacy method)
    /// - Parameter query: The query to execute
    /// - Returns: Publisher that emits the response or error
    @available(*, deprecated, message: "Use executePublisher(_:) instead")
    public func execute(_ query: OverpassQuery) -> AnyPublisher<OverpassResponse, OverpassError> {
        return executePublisher(query)
    }
    
    /// Executes a custom query string using Combine (legacy method)
    /// - Parameter queryString: Raw Overpass QL query string
    /// - Returns: Publisher that emits the response or error
    @available(*, deprecated, message: "Use executePublisher(_:) instead")
    public func execute(_ queryString: String) -> AnyPublisher<OverpassResponse, OverpassError> {
        let query = OverpassQuery(queryString: queryString)
        return executePublisher(query)
    }
    
    /// Finds toilets in a bounding box using Combine (legacy method)
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Publisher that emits the response or error
    @available(*, deprecated, message: "Use findToilets(in:) async method instead")
    public func findToilets(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError> {
        let query = OverpassQuery.toilets(in: boundingBox)
        return executePublisher(query)
    }
    
    /// Finds restaurants in a bounding box using Combine (legacy method)
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Publisher that emits the response or error
    @available(*, deprecated, message: "Use findRestaurants(in:) async method instead")
    public func findRestaurants(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError> {
        let query = OverpassQuery.restaurants(in: boundingBox)
        return executePublisher(query)
    }
    
    /// Finds cafes in a bounding box using Combine (legacy method)
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Publisher that emits the response or error
    @available(*, deprecated, message: "Use findCafes(in:) async method instead")
    public func findCafes(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError> {
        let query = OverpassQuery.cafes(in: boundingBox)
        return executePublisher(query)
    }
    
    /// Finds hotels in a bounding box using Combine (legacy method)
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Publisher that emits the response or error
    @available(*, deprecated, message: "Use findHotels(in:) async method instead")
    public func findHotels(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError> {
        let query = OverpassQuery.hotels(in: boundingBox)
        return executePublisher(query)
    }
    
    /// Finds shops in a bounding box using Combine (legacy method)
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box
    ///   - shopType: Specific shop type (optional)
    /// - Returns: Publisher that emits the response or error
    @available(*, deprecated, message: "Use findShops(in:shopType:) async method instead")
    public func findShops(in boundingBox: OverpassBoundingBox, shopType: String? = nil) -> AnyPublisher<OverpassResponse, OverpassError> {
        let query = OverpassQuery.shops(in: boundingBox, shopType: shopType)
        return executePublisher(query)
    }
    
    /// Finds parks in a bounding box using Combine (legacy method)
    /// - Parameter boundingBox: Geographic bounding box
    /// - Returns: Publisher that emits the response or error
    @available(*, deprecated, message: "Use findParks(in:) async method instead")
    public func findParks(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError> {
        let query = OverpassQuery.parks(in: boundingBox)
        return executePublisher(query)
    }
    
    /// Cancels all active requests
    public func cancelAllRequests() {
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
    }
    
    /// Clears the response cache
    public func clearCache() {
        cache.removeAllObjects()
    }
    
    /// Clears the last error
    public func clearError() {
        lastError = nil
    }
    
    // MARK: - Private Methods
    
    /// Creates a URL request for a query using async/await
    /// - Parameter query: The query to create a request for
    /// - Returns: URL request
    /// - Throws: OverpassError if request creation fails
    private func createRequest(for query: OverpassQuery) async throws -> URLRequest {
        guard var components = URLComponents(string: endpoint.rawValue) else {
            throw OverpassError.queryError("Invalid endpoint URL")
        }
        components.queryItems = [
            URLQueryItem(name: "data", value: query.formattedQuery)
        ]
        guard let url = components.url else {
            throw OverpassError.queryError("Failed to build request URL")
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ToiletFinder/1.0 (OverpassKit; iOS)", forHTTPHeaderField: "User-Agent")
        return request
    }
    
    /// Creates a URL request for a query using Combine
    /// - Parameter query: The query to create a request for
    /// - Returns: Publisher that emits the URL request
    private func createRequestPublisher(for query: OverpassQuery) -> AnyPublisher<URLRequest, OverpassError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.networkError(NSError(domain: "OverpassClient", code: -1, userInfo: nil))))
                return
            }
            
            guard var components = URLComponents(string: self.endpoint.rawValue) else {
                promise(.failure(.queryError("Invalid endpoint URL")))
                return
            }
            components.queryItems = [
                URLQueryItem(name: "data", value: query.formattedQuery)
            ]
            guard let url = components.url else {
                promise(.failure(.queryError("Failed to build request URL")))
                return
            }
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("ToiletFinder/1.0 (OverpassKit; iOS)", forHTTPHeaderField: "User-Agent")
            promise(.success(request))
        }
        .eraseToAnyPublisher()
    }
    
    /// Executes a URL request using async/await
    /// - Parameter request: The request to execute
    /// - Returns: Overpass response
    /// - Throws: OverpassError if the request fails
    private func executeRequest(_ request: URLRequest) async throws -> OverpassResponse {
        let (data, response) = try await session.data(for: request)
        
        // Validate HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                throw OverpassError.networkError(NSError(domain: "OverpassClient", code: httpResponse.statusCode, userInfo: nil))
            }
        }
        
        // Parse JSON response
        do {
            let overpassResponse = try JSONDecoder().decode(OverpassResponse.self, from: data)
            
            // Validate response - empty responses are valid if no remark (no error)
            if overpassResponse.elements.isEmpty && overpassResponse.remark != nil {
                print("[OverpassClient] Empty response with remark: \(overpassResponse.remark ?? "unknown")")
                // This is actually a valid response, just empty
            } else if overpassResponse.elements.isEmpty {
                print("[OverpassClient] Empty response - no toilets found in this area")
                // This is also valid - just means no toilets in the area
            }
            
            return overpassResponse
        } catch {
            if let body = String(data: data, encoding: .utf8) {
                print("[OverpassClient] JSON decode failed. Error: \(error). Response length: \(data.count) bytes. Response snippet: \(body.prefix(500))")
                
                // Check if response appears to be truncated
                if body.hasSuffix("...") || body.count < 100 {
                    print("[OverpassClient] Response appears to be truncated or very short")
                }
                
                // Check for common JSON issues
                if body.contains("runtime error") {
                    print("[OverpassClient] Overpass API returned a runtime error")
                }
            } else {
                print("[OverpassClient] JSON decode failed. Error: \(error). Response length: \(data.count) bytes. Unable to decode as UTF-8")
            }
            throw OverpassError.invalidResponse
        }
    }
    
    /// Executes a URL request using Combine
    /// - Parameter request: The request to execute
    /// - Returns: Publisher that emits the response or error
    private func executeRequestPublisher(_ request: URLRequest) -> AnyPublisher<OverpassResponse, OverpassError> {
        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response in
                guard let self = self else {
                    throw OverpassError.networkError(NSError(domain: "OverpassClient", code: -1, userInfo: nil))
                }
                
                // Store the task for potential cancellation
                if let task = response as? URLSessionDataTask {
                    self.activeTasks.append(task)
                }
                
                // Validate HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    guard httpResponse.statusCode == 200 else {
                        throw OverpassError.networkError(NSError(domain: "OverpassClient", code: httpResponse.statusCode, userInfo: nil))
                    }
                }
                
                // Parse JSON response
                do {
                    let overpassResponse = try JSONDecoder().decode(OverpassResponse.self, from: data)
                    
                    // Validate response
                    guard overpassResponse.isValid else {
                        throw OverpassError.invalidResponse
                    }
                    
                    return overpassResponse
                } catch {
                    if let body = String(data: data, encoding: .utf8) {
                        print("[OverpassClient] JSON decode failed (Combine). Error: \(error). Response snippet: \(body.prefix(300))")
                    } else {
                        print("[OverpassClient] JSON decode failed (Combine). Error: \(error)")
                    }
                    throw OverpassError.invalidResponse
                }
            }
            .mapError { error in
                if let overpassError = error as? OverpassError {
                    return overpassError
                } else {
                    return .networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Gets a cached response for a query
    /// - Parameter query: The query to get cached response for
    /// - Returns: Cached response if available
    private func getCachedResponse(for query: OverpassQuery) -> OverpassResponse? {
        let key = NSString(string: query.formattedQuery)
        guard let cachedResponse = cache.object(forKey: key) else { return nil }
        
        // Check if cache is still valid (not expired)
        if Date().timeIntervalSince(cachedResponse.timestamp) < 300 { // 5 minutes
            return cachedResponse.response
        } else {
            cache.removeObject(forKey: key)
            return nil
        }
    }
    
    /// Caches a response for a query
    /// - Parameters:
    ///   - response: The response to cache
    ///   - query: The query the response is for
    private func cacheResponse(_ response: OverpassResponse, for query: OverpassQuery) {
        let key = NSString(string: query.formattedQuery)
        let cachedResponse = CachedResponse(response: response, timestamp: Date())
        
        cache.setObject(cachedResponse, forKey: key)
        
        // Clean up cache if it gets too large
        if cache.totalCostLimit > maxCacheSize {
            cleanupCache()
        }
    }
    
    /// Cancels tasks for a specific query
    /// - Parameter query: The query to cancel tasks for
    private func cancelTasks(for query: OverpassQuery) {
        // This is a simplified implementation - in a real app you might want to track tasks by query
        activeTasks.removeAll { $0.state == .canceling || $0.state == .completed }
    }
    
    /// Sets up automatic cache cleanup
    private func setupCacheCleanup() {
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .sink { [weak self] _ in
                self?.cleanupCache()
            }
            .store(in: &cancellables)
    }
    
    /// Cleans up expired cache entries
    private func cleanupCache() {
        let now = Date()
        // NSCache doesn't expose keys; rebuild keys based on known queries is not feasible here.
        // Simplified policy: clear entire cache when entries may be expired.
        // Given we already have a max cache size and 5-min validity, this is acceptable.
        cache.removeAllObjects()
    }
}

// MARK: - Cached Response

/// Represents a cached API response
private class CachedResponse {
    let response: OverpassResponse
    let timestamp: Date
    
    init(response: OverpassResponse, timestamp: Date) {
        self.response = response
        self.timestamp = timestamp
    }
}

// MARK: - Combine Extensions

extension OverpassClient {
    /// Executes a query and returns a result type
    /// - Parameter query: The query to execute
    /// - Returns: Publisher that emits a result type
    public func executeResult(_ query: OverpassQuery) -> AnyPublisher<Result<OverpassResponse, OverpassError>, Never> {
        return executePublisher(query)
            .map { Result.success($0) }
            .catch { error in
                Just(Result.failure(error))
            }
            .eraseToAnyPublisher()
    }
    
    /// Executes a query with a completion handler
    /// - Parameters:
    ///   - query: The query to execute
    ///   - completion: Completion handler called with result
    public func execute(_ query: OverpassQuery, completion: @escaping (Result<OverpassResponse, OverpassError>) -> Void) {
        executePublisher(query)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { response in
                    completion(.success(response))
                }
            )
            .store(in: &cancellables)
    }
}
