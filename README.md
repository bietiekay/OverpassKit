# OverpassKit

A modern, Swift-based library for interacting with the Overpass API. OverpassKit provides a clean, type-safe interface for querying OpenStreetMap data through the Overpass API, with built-in support for MapKit integration, caching, and Combine publishers.

## Features

- 🗺️ **Full Overpass API Support**: Query nodes, ways, and relations with custom filters
- 📱 **MapKit Integration**: Seamless integration with iOS map views and location services
- 🎨 **SwiftUI Support**: Native SwiftUI components and environment integration
- ⚡ **Async/Await**: Modern Swift concurrency with full async/await support
- 🔄 **Combine Support**: Legacy reactive programming with Combine publishers
- 💾 **Smart Caching**: Automatic response caching with configurable expiration
- 🎯 **Type Safety**: Strongly typed models and error handling
- 🚀 **Performance**: Efficient query building and response parsing
- 🌍 **Multiple Endpoints**: Support for various Overpass API instances
- 🛠️ **Utility Functions**: Comprehensive utilities for coordinate calculations and data filtering

## Requirements

- iOS 13.0+ / macOS 10.15+ (SwiftUI features require iOS 16.0+ / macOS 13.0+)
- Swift 5.5+ (for async/await support)
- Xcode 13.0+

## Installation

### Swift Package Manager

Add OverpassKit to your project using Swift Package Manager:

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter the repository URL: `https://github.com/yourusername/OverpassKit.git`
3. Select the version you want to use
4. Click **Add Package**

### Manual Installation

1. Download the source code
2. Add the `OverpassKit` folder to your Xcode project
3. Make sure all files are included in your target

## Quick Start

### Basic Usage

#### Async/Await (Recommended)

```swift
import OverpassKit
import CoreLocation

// Create a client
let client = OverpassClient()

// Create a bounding box around a location
let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
let boundingBox = try! OverpassBoundingBox(center: coordinate, radiusInMeters: 1000)

// Find toilets in the area using async/await
Task {
    do {
        let response = try await client.findToilets(in: boundingBox)
        print("Found \(response.elements.count) toilets")
        for element in response.elements {
            if let name = element.name {
                print("- \(name)")
            }
        }
    } catch {
        print("Error: \(error)")
    }
}
```

#### Combine (Legacy)

```swift
import OverpassKit
import CoreLocation
import Combine

// Create a client
let client = OverpassClient()

// Create a bounding box around a location
let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
let boundingBox = try! OverpassBoundingBox(center: coordinate, radiusInMeters: 1000)

// Find toilets in the area using Combine
client.findToilets(in: boundingBox)
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("Query completed")
            case .failure(let error):
                print("Error: \(error)")
            }
        },
        receiveValue: { response in
            print("Found \(response.elements.count) toilets")
            for element in response.elements {
                if let name = element.name {
                    print("- \(name)")
                }
            }
        }
    )
    .store(in: &cancellables)
```

### SwiftUI Integration

```swift
import SwiftUI
import MapKit
import OverpassKit

struct ContentView: View {
    @StateObject private var viewModel = OverpassViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern SwiftUI Map (iOS 16+)
                if #available(iOS 16.0, *) {
                    OverpassMapView { position, proxy in
                        // Map content
                    }
                    .onMapCameraChange { position in
                        handleMapCameraChange(position)
                    }
                } else {
                    // Fallback for older iOS versions
                    Map(coordinateRegion: $region, showsUserLocation: true)
                        .onChange(of: region) { _, newRegion in
                            handleRegionChange(newRegion)
                        }
                }
                
                // Search controls
                VStack {
                    Spacer()
                    SearchControlsView(viewModel: viewModel, region: $region)
                        .padding()
                }
            }
            .navigationTitle("Toilet Finder")
        }
        .overpassClient(OverpassClient())
        .environmentObject(viewModel)
    }
    
    private func handleMapCameraChange(_ position: MapCameraPosition) {
        if case .region(let newRegion) = position {
            region = newRegion
        }
    }
    
    private func handleRegionChange(_ newRegion: MKCoordinateRegion) {
        region = newRegion
    }
}

struct SearchControlsView: View {
    @ObservedObject var viewModel: OverpassViewModel
    @Binding var region: MKCoordinateRegion
    @State private var searchRadius: Double = 1000
    
    var body: some View {
        VStack {
            Button("Find Toilets") {
                Task {
                    do {
                        let boundingBox = try OverpassBoundingBox(
                            center: region.center,
                            radiusInMeters: searchRadius
                        )
                        await viewModel.searchToilets(in: boundingBox)
                    } catch {
                        print("Error: \(error)")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            Slider(value: $searchRadius, in: 100...5000, step: 100)
            Text("Radius: \(Int(searchRadius))m")
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}
```

### MapKit Integration (UIKit)

```swift
import MapKit
import OverpassKit

class MapViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!
    private let client = OverpassClient()
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up map delegate
        mapView.delegate = self
        
        // Request location permissions
        requestLocationPermissions()
    }
    
    private func fetchNearbyPOIs() {
        guard let boundingBox = mapView.overpassBoundingBox() else { return }
        
        // Find restaurants in the visible map area using async/await
        Task {
            do {
                let response = try await client.findRestaurants(in: boundingBox)
                await MainActor.run {
                    addAnnotations(for: response.elements)
                }
            } catch {
                print("Error fetching restaurants: \(error)")
            }
        }
    }
    
    private func addAnnotations(for elements: [OverpassElement]) {
        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add new annotations
        for element in elements {
            guard let coordinate = element.coordinate else { continue }
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = element.name ?? "Unknown"
            annotation.subtitle = element.amenity ?? element.description
            
            mapView.addAnnotation(annotation)
        }
    }
}

// MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Fetch new POIs when the map region changes
        fetchNearbyPOIs()
    }
}
```

### Custom Queries

```swift
// Create a custom query for specific amenities
let customQuery = OverpassQuery(
    boundingBox: boundingBox,
    elementTypes: [
        .amenity("restaurant"),
        .amenity("cafe"),
        .shop("supermarket")
    ]
)

client.execute(customQuery)
    .sink(
        receiveCompletion: { completion in
            // Handle completion
        },
        receiveValue: { response in
            // Process response
        }
    )
    .store(in: &cancellables)

// Or use a raw query string
let rawQuery = """
[out:json][timeout:25];
(
  node["amenity"="restaurant"]["cuisine"="italian"](37.7,122.4,37.8,122.5);
  way["amenity"="restaurant"]["cuisine"="italian"](37.7,122.4,37.8,122.5);
);
out body;>;out skel qt;
"""

client.execute(rawQuery)
    .sink(
        receiveCompletion: { completion in
            // Handle completion
        },
        receiveValue: { response in
            // Process response
        }
    )
    .store(in: &cancellables)
```

## API Reference

### Core Classes

#### `OverpassClient`

The main client for interacting with the Overpass API.

```swift
@MainActor
class OverpassClient: ObservableObject {
    init(endpoint: OverpassKit.Endpoint = .overpassAPI)
    
    // Async/Await Methods (Recommended)
    func execute(_ query: OverpassQuery) async throws -> OverpassResponse
    func findToilets(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse
    func findRestaurants(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse
    func findCafes(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse
    func findHotels(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse
    func findShops(in boundingBox: OverpassBoundingBox, shopType: String?) async throws -> OverpassResponse
    func findParks(in boundingBox: OverpassBoundingBox) async throws -> OverpassResponse
    
    // Combine Methods (Legacy)
    func executePublisher(_ query: OverpassQuery) -> AnyPublisher<OverpassResponse, OverpassError>
    func findToilets(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError>
    func findRestaurants(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError>
    func findCafes(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError>
    func findHotels(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError>
    func findShops(in boundingBox: OverpassBoundingBox, shopType: String?) -> AnyPublisher<OverpassResponse, OverpassError>
    func findParks(in boundingBox: OverpassBoundingBox) -> AnyPublisher<OverpassResponse, OverpassError>
    
    // Published Properties for SwiftUI
    @Published var isLoading: Bool
    @Published var lastError: OverpassError?
    @Published var lastResponse: OverpassResponse?
}
```

#### `OverpassQuery`

Represents an Overpass QL query with support for common element types.

```swift
class OverpassQuery {
    init(boundingBox: OverpassBoundingBox, elementTypes: [ElementType], outputFormat: OverpassKit.OutputFormat = .json, timeout: OverpassKit.Timeout = OverpassKit.Timeout())
    
    static func toilets(in boundingBox: OverpassBoundingBox) -> OverpassQuery
    static func restaurants(in boundingBox: OverpassBoundingBox) -> OverpassQuery
    static func cafes(in boundingBox: OverpassBoundingBox) -> OverpassQuery
    static func hotels(in boundingBox: OverpassBoundingBox) -> OverpassQuery
    static func shops(in boundingBox: OverpassBoundingBox, shopType: String?) -> OverpassQuery
    static func parks(in boundingBox: OverpassBoundingBox) -> OverpassQuery
}
```

#### `OverpassBoundingBox`

Represents a geographic bounding box for Overpass queries.

```swift
struct OverpassBoundingBox {
    init(lowestLatitude: Double, lowestLongitude: Double, highestLatitude: Double, highestLongitude: Double) throws
    init(center: CLLocationCoordinate2D, radiusInMeters: Double) throws
    init(region: MKCoordinateRegion) throws
    init(mapRect: MKMapRect) throws
    
    func overpassString() -> String
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool
    func expanded(by expansionInDegrees: Double) throws -> OverpassBoundingBox
}
```

#### `OverpassElement`

Represents an individual element returned from Overpass API queries.

```swift
struct OverpassElement {
    let id: Int64
    let type: ElementType
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
    
    var coordinate: CLLocationCoordinate2D?
    var name: String?
    var description: String?
    var amenity: String?
    var address: OverpassAddress?
    
    func hasTag(_ key: String) -> Bool
    func getTag(_ key: String) -> String?
    func hasTag(_ key: String, value: String) -> Bool
}
```

#### `OverpassViewModel`

SwiftUI view model for Overpass operations with state management.

```swift
@MainActor
class OverpassViewModel: ObservableObject {
    init(client: OverpassClient = OverpassClient())
    
    // Published Properties
    @Published var isLoading: Bool
    @Published var lastError: OverpassError?
    @Published var lastResponse: OverpassResponse?
    @Published var searchHistory: [SearchQuery]
    @Published var favoriteLocations: [FavoriteLocation]
    
    // Search Methods
    func searchToilets(in boundingBox: OverpassBoundingBox) async -> SearchResult
    func searchRestaurants(in boundingBox: OverpassBoundingBox) async -> SearchResult
    func searchCafes(in boundingBox: OverpassBoundingBox) async -> SearchResult
    func searchHotels(in boundingBox: OverpassBoundingBox) async -> SearchResult
    func searchShops(in boundingBox: OverpassBoundingBox, shopType: String?) async -> SearchResult
    func searchParks(in boundingBox: OverpassBoundingBox) async -> SearchResult
    
    // Favorites Management
    func addToFavorites(_ location: FavoriteLocation)
    func removeFromFavorites(_ location: FavoriteLocation)
    func isFavorite(_ location: FavoriteLocation) -> Bool
}
```

#### `OverpassMapView` (iOS 16+)

SwiftUI MapView wrapper that integrates with OverpassKit.

```swift
@available(iOS 16.0, macOS 13.0, *)
struct OverpassMapView<Content: View>: View {
    init(@ViewBuilder content: (MapCameraPosition, MapProxy) -> Content)
    
    // Convenience Initializers
    init(region: MKCoordinateRegion)
    init(showsUserLocation: Bool = true)
}
```

### MapKit Extensions

OverpassKit provides convenient extensions for MapKit integration:

```swift
// Create bounding box from map view
let boundingBox = mapView.overpassBoundingBox()

// Create bounding box from map region
let boundingBox = mapView.overpassBoundingBoxFromRegion()

// Create bounding box centered on user location
let boundingBox = mapView.overpassBoundingBox(radiusInMeters: 1000)

// Check if user is in center region
let isUserInCenter = mapView.isUserInCenterRegion()

// Check if coordinate is visible
let isVisible = mapView.isCoordinateVisible(coordinate)
```

### Utility Functions

```swift
// Coordinate calculations
let distance = OverpassUtilities.distance(from: coord1, to: coord2)
let bearing = OverpassUtilities.bearing(from: coord1, to: coord2)
let newCoord = OverpassUtilities.coordinate(from: coord1, distance: 1000, bearing: 45)

// Bounding box utilities
let boundingBox = OverpassUtilities.boundingBox(for: coordinates, paddingFactor: 1.1)
let expandedBox = OverpassUtilities.expandBoundingBox(boundingBox, by: 500)

// Element filtering
let nearbyElements = OverpassUtilities.filterElements(elements, within: 1000, of: coordinate)
let sortedElements = OverpassUtilities.sortElements(elements, byDistanceFrom: coordinate)
let groupedElements = OverpassUtilities.groupElements(elements, by: "amenity")

// Tag utilities
let uniqueValues = OverpassUtilities.uniqueTagValues(for: elements, tagKey: "cuisine")
let matchingElements = OverpassUtilities.findElements(elements, withTags: ["amenity": "restaurant", "cuisine": "italian"])

// Address formatting
let formattedAddress = OverpassUtilities.formatAddress(address)
let extractedAddress = OverpassUtilities.extractAddress(from: element)
```

## Configuration

### Endpoints

OverpassKit supports multiple Overpass API endpoints:

```swift
enum OverpassKit.Endpoint: String, CaseIterable {
    case overpassAPI = "https://overpass-api.de/api/interpreter"
    case miataru = "https://overpass.miataru.com/api/interpreter"
    case kumiSystems = "https://overpass.kumi.systems/api/interpreter"
}

let client = OverpassClient(endpoint: .miataru)
```

### Timeouts

Configure query timeouts:

```swift
let timeout = OverpassKit.Timeout(serverTimeout: 30, clientTimeout: 32)
let query = OverpassQuery.toilets(in: boundingBox, timeout: timeout)
```

### Output Formats

Choose the output format for your queries:

```swift
enum OverpassKit.OutputFormat: String, CaseIterable {
    case json = "json"
    case xml = "xml"
    case csv = "csv"
}

let query = OverpassQuery.toilets(in: boundingBox, outputFormat: .xml)
```

## Error Handling

OverpassKit provides comprehensive error handling:

```swift
enum OverpassError: Error, LocalizedError {
    case invalidCoordinates
    case invalidBoundingBox
    case networkError(Error)
    case invalidResponse
    case timeout
    case queryError(String)
    case noData
}

client.findToilets(in: boundingBox)
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("Query completed successfully")
            case .failure(let error):
                switch error {
                case .networkError(let networkError):
                    print("Network error: \(networkError)")
                case .timeout:
                    print("Query timed out")
                case .invalidResponse:
                    print("Invalid response from server")
                case .noData:
                    print("No data returned")
                default:
                    print("Error: \(error.localizedDescription)")
                }
            }
        },
        receiveValue: { response in
            // Handle successful response
        }
    )
    .store(in: &cancellables)
```

## Caching

OverpassKit automatically caches responses to improve performance:

```swift
// Clear the cache
client.clearCache()

// Cache is automatically managed with 5-minute expiration
// Cache size is limited to 50 responses
```

## Best Practices

1. **Use appropriate bounding box sizes**: Smaller bounding boxes provide faster responses
2. **Implement proper error handling**: Always handle potential errors gracefully
3. **Cancel requests when appropriate**: Cancel ongoing requests when the user changes the map region
4. **Use caching effectively**: The library automatically caches responses, but you can clear the cache when needed
5. **Handle location permissions**: Ensure you have proper location permissions before making queries
6. **Consider rate limiting**: Be mindful of API usage limits on public endpoints
7. **Prefer async/await over Combine**: Use modern Swift concurrency for better performance and readability
8. **Use @MainActor for UI updates**: Ensure all UI updates happen on the main thread
9. **Leverage SwiftUI environment**: Use the `.overpassClient()` modifier to provide the client throughout your view hierarchy
10. **Handle task cancellation**: Use `Task` and check `Task.isCancelled` for proper cleanup

## Examples

### Toilet Finder App

```swift
class ToiletFinderViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!
    private let client = OverpassClient()
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupLocationManager()
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
    }
    
    private func setupLocationManager() {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func fetchToilets() {
        guard let boundingBox = mapView.overpassBoundingBox() else { return }
        
        client.findToilets(in: boundingBox)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.showError(error)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.displayToilets(response.elements)
                }
            )
            .store(in: &cancellables)
    }
    
    private func displayToilets(_ elements: [OverpassElement]) {
        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add toilet annotations
        for element in elements {
            guard let coordinate = element.coordinate else { continue }
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = element.name ?? "Toilet"
            annotation.subtitle = element.description
            
            mapView.addAnnotation(annotation)
        }
    }
    
    private func showError(_ error: OverpassError) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ToiletFinderViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        fetchToilets()
    }
}

extension ToiletFinderViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
        
        // Stop updating location after first update
        manager.stopUpdatingLocation()
    }
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [OpenStreetMap](https://www.openstreetmap.org/) for providing the data
- [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API) for the query language
- The OpenStreetMap community for maintaining and improving the data

## Support

If you have any questions or need help, please open an issue on GitHub or contact the maintainers.
