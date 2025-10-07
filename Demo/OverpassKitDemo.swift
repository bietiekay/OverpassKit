import UIKit
import MapKit
import CoreLocation
import Combine
import OverpassKit

/// Demo class showing various OverpassKit usage patterns
class OverpassKitDemo {
    
    // MARK: - Properties
    
    private let client = OverpassClient()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Demo Methods
    
    /// Demonstrates basic toilet search functionality
    func demoBasicToiletSearch() {
        print("=== Basic Toilet Search Demo ===")
        
        // Create a bounding box around San Francisco
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let boundingBox = try! OverpassBoundingBox(center: coordinate, radiusInMeters: 1000)
        
        print("Searching for toilets in San Francisco...")
        
        client.findToilets(in: boundingBox)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("✅ Search completed")
                    case .failure(let error):
                        print("❌ Search failed: \(error)")
                    }
                },
                receiveValue: { response in
                    print("🎉 Found \(response.elements.count) toilets!")
                    
                    // Display first few results
                    for (index, element) in response.elements.prefix(3).enumerated() {
                        let name = element.name ?? "Unnamed"
                        let distance = OverpassUtilities.formatDistance(
                            OverpassUtilities.distance(from: coordinate, to: element.coordinate ?? coordinate)
                        )
                        print("  \(index + 1). \(name) (\(distance) away)")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Demonstrates restaurant search functionality
    func demoRestaurantSearch() {
        print("\n=== Restaurant Search Demo ===")
        
        // Create a bounding box around New York City
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let boundingBox = try! OverpassBoundingBox(center: coordinate, radiusInMeters: 2000)
        
        print("Searching for restaurants in NYC...")
        
        client.findRestaurants(in: boundingBox)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Restaurant search failed: \(error)")
                    }
                },
                receiveValue: { response in
                    print("🍕 Found \(response.elements.count) restaurants!")
                    
                    // Group by cuisine if available
                    let grouped = OverpassUtilities.groupElements(response.elements, by: "cuisine")
                    for (cuisine, elements) in grouped.prefix(5) {
                        print("  \(cuisine): \(elements.count) restaurants")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Demonstrates custom query functionality
    func demoCustomQuery() {
        print("\n=== Custom Query Demo ===")
        
        // Create a bounding box around London
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let boundingBox = try! OverpassBoundingBox(center: coordinate, radiusInMeters: 1500)
        
        // Create a custom query for cafes and parks
        let customQuery = OverpassQuery(
            boundingBox: boundingBox,
            elementTypes: [
                .amenity("cafe"),
                .leisure("park")
            ]
        )
        
        print("Searching for cafes and parks in London...")
        
        client.execute(customQuery)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Custom query failed: \(error)")
                    }
                },
                receiveValue: { response in
                    print("🏞️ Found \(response.elements.count) places!")
                    
                    let cafes = response.elements(withAmenity: "cafe")
                    let parks = response.elements(withLeisure: "park")
                    
                    print("  Cafes: \(cafes.count)")
                    print("  Parks: \(parks.count)")
                    
                    // Show some cafe names
                    let cafeNames = cafes.compactMap { $0.name }.prefix(3)
                    if !cafeNames.isEmpty {
                        print("  Sample cafes: \(cafeNames.joined(separator: ", "))")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Demonstrates utility functions
    func demoUtilityFunctions() {
        print("\n=== Utility Functions Demo ===")
        
        let coord1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
        let coord2 = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)  // New York
        
        // Distance calculation
        let distance = OverpassUtilities.distance(from: coord1, to: coord2)
        print("📏 Distance from SF to NYC: \(OverpassUtilities.formatDistance(distance))")
        
        // Bearing calculation
        let bearing = OverpassUtilities.bearing(from: coord1, to: coord2)
        print("🧭 Bearing from SF to NYC: \(String(format: "%.1f°", bearing))")
        
        // Coordinate formatting
        print("📍 SF coordinates: \(OverpassUtilities.formatCoordinate(coord1))")
        print("📍 NYC coordinates: \(OverpassUtilities.formatCoordinate(coord2))")
        
        // Create bounding box encompassing both cities
        if let encompassingBox = OverpassUtilities.boundingBox(for: [coord1, coord2]) {
            print("🗺️ Encompassing bounding box: \(encompassingBox.overpassString())")
        }
    }
    
    /// Demonstrates MapKit integration
    func demoMapKitIntegration() {
        print("\n=== MapKit Integration Demo ===")
        
        // Create a mock map view with a region
        let mapView = MKMapView()
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: false)
        
        // Get bounding box from map view
        if let boundingBox = mapView.overpassBoundingBox() {
            print("🗺️ Map view bounding box: \(boundingBox.overpassString())")
            
            // Check if a coordinate is visible
            let testCoordinate = CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
            let isVisible = mapView.isCoordinateVisible(testCoordinate)
            print("👁️ Test coordinate visible: \(isVisible)")
        }
        
        // Get bounding box from region
        if let regionBoundingBox = mapView.overpassBoundingBoxFromRegion() {
            print("🗺️ Region bounding box: \(regionBoundingBox.overpassString())")
        }
    }
    
    /// Demonstrates error handling
    func demoErrorHandling() {
        print("\n=== Error Handling Demo ===")
        
        // Try to create an invalid bounding box
        do {
            let invalidBox = try OverpassBoundingBox(
                lowestLatitude: 91.0,  // Invalid latitude
                lowestLongitude: -180.0,
                highestLatitude: 90.0,
                highestLongitude: 180.0
            )
            print("Unexpected success: \(invalidBox)")
        } catch OverpassError.invalidCoordinates {
            print("✅ Caught invalid coordinates error")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
        
        // Try to create a bounding box with invalid bounds
        do {
            let invalidBoundsBox = try OverpassBoundingBox(
                lowestLatitude: 90.0,
                lowestLongitude: -180.0,
                highestLatitude: -90.0,  // Lower than lowest
                highestLongitude: 180.0
            )
            print("Unexpected success: \(invalidBoundsBox)")
        } catch OverpassError.invalidBoundingBox {
            print("✅ Caught invalid bounding box error")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }
    
    /// Demonstrates caching functionality
    func demoCaching() {
        print("\n=== Caching Demo ===")
        
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let boundingBox = try! OverpassBoundingBox(center: coordinate, radiusInMeters: 500)
        
        print("First search (should hit API)...")
        
        // First search - should hit the API
        let startTime = Date()
        client.findToilets(in: boundingBox)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { response in
                    let duration = Date().timeIntervalSince(startTime)
                    print("  ⏱️ First search took: \(String(format: "%.2f", duration))s")
                    print("  📍 Found: \(response.elements.count) toilets")
                }
            )
            .store(in: &cancellables)
        
        // Wait a bit then search again - should hit cache
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Second search (should hit cache)...")
            
            let startTime2 = Date()
            self.client.findToilets(in: boundingBox)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { response in
                        let duration = Date().timeIntervalSince(startTime2)
                        print("  ⏱️ Second search took: \(String(format: "%.2f", duration))s")
                        print("  📍 Found: \(response.elements.count) toilets")
                        
                        // Clear cache to demonstrate
                        self.client.clearCache()
                        print("  🗑️ Cache cleared")
                    }
                )
                .store(in: &self.cancellables)
        }
    }
    
    /// Demonstrates different endpoints
    func demoEndpoints() {
        print("\n=== Endpoints Demo ===")
        
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let boundingBox = try! OverpassBoundingBox(center: coordinate, radiusInMeters: 1000)
        
        // Test different endpoints
        let endpoints: [OverpassKit.Endpoint] = [.overpassAPI, .miataru, .kumiSystems]
        
        for endpoint in endpoints {
            print("Testing endpoint: \(endpoint.rawValue)")
            
            let endpointClient = OverpassClient(endpoint: endpoint)
            endpointClient.findToilets(in: boundingBox)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("  ❌ Failed: \(error)")
                        }
                    },
                    receiveValue: { response in
                        print("  ✅ Success: \(response.elements.count) toilets found")
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    /// Runs all demos
    func runAllDemos() {
        print("🚀 Starting OverpassKit Demos...\n")
        
        demoBasicToiletSearch()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.demoRestaurantSearch()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.demoCustomQuery()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.demoUtilityFunctions()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            self.demoMapKitIntegration()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.demoErrorHandling()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
            self.demoCaching()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 14.0) {
            self.demoEndpoints()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 16.0) {
            print("\n🎉 All demos completed!")
        }
    }
}

// MARK: - Usage Example

/// Example of how to use the demo
class DemoViewController: UIViewController {
    
    private let demo = OverpassKitDemo()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Run demos after a short delay to ensure view is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.demo.runAllDemos()
        }
    }
}
