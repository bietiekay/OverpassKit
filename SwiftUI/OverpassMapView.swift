import SwiftUI
import MapKit
import CoreLocation

/// SwiftUI MapView wrapper that integrates with OverpassKit
@available(iOS 17.0, macOS 14.0, *)
public struct OverpassMapView<Content: View>: View {
    
    // MARK: - Properties
    
    @StateObject private var mapState = MapState()
    @Environment(\.overpassClient) private var overpassClient
    
    private let content: (MapCameraPosition, MapProxy) -> Content
    private let onMapCameraChange: ((MapCameraPosition) -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize with content builder
    /// - Parameters:
    ///   - content: Content builder for the map
    ///   - onMapCameraChange: Callback when map camera changes
    ///   - onMapInteraction: Callback when map interaction occurs
    public init(
        @ViewBuilder content: @escaping (MapCameraPosition, MapProxy) -> Content,
        onMapCameraChange: ((MapCameraPosition) -> Void)? = nil
    ) {
        self.content = content
        self.onMapCameraChange = onMapCameraChange
    }
    
    // MARK: - Body
    
    public var body: some View {
        Map(position: $mapState.cameraPosition, interactionModes: mapState.interactionModes) {
            // Add user location
            if mapState.showsUserLocation {
                UserAnnotation()
            }
            
            // Add custom annotations
            ForEach(mapState.annotations) { annotation in
                Annotation(
                    annotation.title ?? NSLocalizedString("location_default", comment: "Default location name"),
                    coordinate: annotation.coordinate,
                    anchor: .bottom
                ) {
                    annotation.annotationView
                }
            }
            
            // Add overlays
            ForEach(mapState.overlays) { overlay in
                MapPolyline(coordinates: overlay.coordinates)
                    .stroke(overlay.color, lineWidth: overlay.lineWidth)
            }
        }
        .mapStyle(mapState.mapStyle)
        .onChange(of: mapState.cameraPosition) { _, newPosition in
            onMapCameraChange?(newPosition)
            Task { await mapState.updateBoundingBox(from: newPosition) }
        }
        .onAppear {
            setupMap()
        }
        .onChange(of: mapState.showsUserLocation) { _, newValue in
            if newValue {
                requestLocationPermission()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMap() {
        // Set initial region if not set
        if mapState.cameraPosition.region == nil {
            let defaultRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapState.cameraPosition = .region(defaultRegion)
        }
    }
    
    private func requestLocationPermission() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
    }
}

// MARK: - Map State

@available(iOS 17.0, macOS 14.0, *)
@MainActor
public class MapState: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var cameraPosition: MapCameraPosition = .automatic
    @Published public var interactionModes: MapInteractionModes = .all
    @Published public var showsUserLocation = true
    @Published public var mapStyle: MapStyle = .standard
    @Published public var annotations: [MapAnnotation] = []
    @Published public var overlays: [MapOverlay] = []
    @Published public var currentBoundingBox: OverpassBoundingBox?
    
    // MARK: - Private Properties
    
    private var locationManager = CLLocationManager()
    
    // MARK: - Methods
    
    /// Updates the bounding box based on current map position
    /// - Parameter position: Current map camera position
    public func updateBoundingBox(from position: MapCameraPosition) async {
        if let region = position.region {
            do {
                let boundingBox = try OverpassBoundingBox(region: region)
                currentBoundingBox = boundingBox
            } catch {
                print(NSLocalizedString("error_bounding_box", comment: "Error creating bounding box"))
            }
        }
    }
    
    /// Centers the map on user location
    public func centerOnUserLocation() {
        if let userLocation = locationManager.location {
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            cameraPosition = .region(region)
        }
    }
    
    /// Adds an annotation to the map
    /// - Parameter annotation: Annotation to add
    public func addAnnotation(_ annotation: MapAnnotation) {
        annotations.append(annotation)
    }
    
    /// Removes an annotation from the map
    /// - Parameter annotation: Annotation to remove
    public func removeAnnotation(_ annotation: MapAnnotation) {
        annotations.removeAll { $0.id == annotation.id }
    }
    
    /// Clears all annotations
    public func clearAnnotations() {
        annotations.removeAll()
    }
    
    /// Adds an overlay to the map
    /// - Parameter overlay: Overlay to add
    public func addOverlay(_ overlay: MapOverlay) {
        overlays.append(overlay)
    }
    
    /// Removes an overlay from the map
    /// - Parameter overlay: Overlay to remove
    public func removeOverlay(_ overlay: MapOverlay) {
        overlays.removeAll { $0.id == overlay.id }
    }
    
    /// Clears all overlays
    public func clearOverlays() {
        overlays.removeAll()
    }
    
    /// Sets the map style
    /// - Parameter style: Map style to use
    public func setMapStyle(_ style: MapStyle) {
        mapStyle = style
    }
    
    /// Enables or disables user location
    /// - Parameter enabled: Whether to show user location
    public func setShowsUserLocation(_ enabled: Bool) {
        showsUserLocation = enabled
    }
}

// MARK: - Map Annotation

@available(iOS 17.0, macOS 14.0, *)
public struct MapAnnotation: Identifiable, Equatable {
    public let id = UUID()
    public let coordinate: CLLocationCoordinate2D
    public let title: String?
    public let subtitle: String?
    public let annotationView: AnyView
    
    public init(
        coordinate: CLLocationCoordinate2D,
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder annotationView: @escaping () -> some View
    ) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.annotationView = AnyView(annotationView())
    }
    
    public static func == (lhs: MapAnnotation, rhs: MapAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Map Overlay

@available(iOS 17.0, macOS 14.0, *)
public struct MapOverlay: Identifiable, Equatable {
    public let id = UUID()
    public let coordinates: [CLLocationCoordinate2D]
    public let color: Color
    public let lineWidth: Double
    
    public init(
        coordinates: [CLLocationCoordinate2D],
        color: Color = .blue,
        lineWidth: Double = 3.0
    ) {
        self.coordinates = coordinates
        self.color = color
        self.lineWidth = lineWidth
    }
    
    public static func == (lhs: MapOverlay, rhs: MapOverlay) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Convenience Initializers

@available(iOS 17.0, macOS 14.0, *)
extension OverpassMapView {
    
    /// Initialize with a simple region
    /// - Parameter region: Initial map region
    public init(region: MKCoordinateRegion) where Content == EmptyView {
        self.init { _, _ in EmptyView() }
        self.mapState.cameraPosition = .region(region)
    }
    
    /// Initialize with user location tracking
    /// - Parameter showsUserLocation: Whether to show user location
    public init(showsUserLocation: Bool = true) where Content == EmptyView {
        self.init { _, _ in EmptyView() }
        self.mapState.showsUserLocation = showsUserLocation
    }
}

// MARK: - Map Style Extensions

@available(iOS 17.0, macOS 14.0, *)
extension MapStyle {
    
    /// Standard map style
    public static var standard: MapStyle {
        .standard(elevation: .realistic)
    }
    
    /// Hybrid map style
    public static var hybrid: MapStyle {
        .hybrid(elevation: .realistic)
    }
    
    /// Satellite map style
    public static var satellite: MapStyle {
        .imagery(elevation: .realistic)
    }
    
    /// OSM-style map (custom implementation)
    public static var osm: MapStyle {
        .standard(elevation: .realistic)
    }
}

// MARK: - Preview

@available(iOS 17.0, macOS 14.0, *)
#Preview {
    OverpassMapView { position, proxy in
        EmptyView()
    }
    .overpassClient(OverpassClient())
}
