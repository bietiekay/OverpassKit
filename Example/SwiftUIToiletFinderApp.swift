import SwiftUI
import MapKit
import CoreLocation
import OverpassKit

/// Complete SwiftUI ToiletFinder app using OverpassKit
@main
struct SwiftUIToiletFinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .overpassClient(OverpassClient())
        }
    }
}

/// Main content view
struct ContentView: View {
    @StateObject private var viewModel = OverpassViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MapView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(0)
            
            SearchView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .tag(1)
            
            FavoritesView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "heart")
                    Text("Favorites")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .environmentObject(viewModel)
    }
}

/// Main map view
struct MapView: View {
    @ObservedObject var viewModel: OverpassViewModel
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var searchRadius: Double = 1000
    @State private var selectedSearchType: SearchType = .toilets
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map
                if #available(iOS 16.0, *) {
                    OverpassMapView { position, proxy in
                        // Map content
                    }
                    .onMapCameraChange { position in
                        handleMapCameraChange(position)
                    }
                    .overpassClient(OverpassClient())
                } else {
                    // Fallback for older iOS versions
                    Map(coordinateRegion: $region, showsUserLocation: true)
                        .onChange(of: region) { _, newRegion in
                            handleRegionChange(newRegion)
                        }
                }
                
                // Search controls overlay
                VStack {
                    Spacer()
                    
                    SearchControlsView(
                        searchType: $selectedSearchType,
                        searchRadius: $searchRadius,
                        onSearch: performSearch
                    )
                    .padding()
                }
                
                // Loading indicator
                if viewModel.isLoading {
                    LoadingView()
                }
                
                // Error alert
                if let error = viewModel.lastError {
                    ErrorAlert(error: error) {
                        viewModel.clearError()
                    }
                }
            }
            .navigationTitle("Toilet Finder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("My Location") {
                        centerOnUserLocation()
                    }
                }
            }
        }
    }
    
    private func handleMapCameraChange(_ position: MapCameraPosition) {
        // Handle map camera changes for iOS 16+
        if case .region(let newRegion) = position {
            region = newRegion
        }
    }
    
    private func handleRegionChange(_ newRegion: MKCoordinateRegion) {
        // Handle region changes for older iOS versions
        region = newRegion
    }
    
    private func performSearch() {
        Task {
            do {
                let boundingBox = try OverpassBoundingBox(center: region.center, radiusInMeters: searchRadius)
                
                switch selectedSearchType {
                case .toilets:
                    await viewModel.searchToilets(in: boundingBox)
                case .restaurants:
                    await viewModel.searchRestaurants(in: boundingBox)
                case .cafes:
                    await viewModel.searchCafes(in: boundingBox)
                case .hotels:
                    await viewModel.searchHotels(in: boundingBox)
                case .shops:
                    await viewModel.searchShops(in: boundingBox)
                case .parks:
                    await viewModel.searchParks(in: boundingBox)
                case .custom:
                    break
                }
            } catch {
                print("Failed to create bounding box: \(error)")
            }
        }
    }
    
    private func centerOnUserLocation() {
        // Center map on user location
        let locationManager = CLLocationManager()
        if let userLocation = locationManager.location {
            region.center = userLocation.coordinate
        }
    }
}

/// Search controls view
struct SearchControlsView: View {
    @Binding var searchType: SearchType
    @Binding var searchRadius: Double
    let onSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Search type picker
            Picker("Search Type", selection: $searchType) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.iconName)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            // Search radius slider
            VStack(alignment: .leading) {
                Text("Search Radius: \(Int(searchRadius))m")
                    .font(.caption)
                
                Slider(value: $searchRadius, in: 100...5000, step: 100)
            }
            
            // Search button
            Button(action: onSearch) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

/// Search results view
struct SearchView: View {
    @ObservedObject var viewModel: OverpassViewModel
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            List {
                if let response = viewModel.lastResponse {
                    Section("Search Results (\(response.elements.count) found)") {
                        ForEach(response.elements) { element in
                            ElementRowView(element: element)
                        }
                    }
                }
                
                Section("Search History") {
                    ForEach(viewModel.searchHistory) { query in
                        SearchHistoryRowView(query: query)
                    }
                }
            }
            .navigationTitle("Search Results")
            .searchable(text: $searchText, prompt: "Search locations...")
            .refreshable {
                // Refresh search results
            }
        }
    }
}

/// Element row view
struct ElementRowView: View {
    let element: OverpassElement
    @EnvironmentObject var viewModel: OverpassViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(element.name ?? "Unnamed Location")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    addToFavorites()
                }) {
                    Image(systemName: "heart")
                        .foregroundColor(.red)
                }
            }
            
            if let description = element.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let coordinate = element.coordinate {
                Text("\(coordinate.latitude, specifier: "%.4f"), \(coordinate.longitude, specifier: "%.4f")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let amenity = element.amenity {
                Label(amenity, systemImage: "tag")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func addToFavorites() {
        guard let coordinate = element.coordinate else { return }
        
        let favorite = FavoriteLocation(
            name: element.name ?? "Unnamed Location",
            coordinate: coordinate,
            type: .toilets // Default to toilets, could be made dynamic
        )
        
        viewModel.addToFavorites(favorite)
    }
}

/// Search history row view
struct SearchHistoryRowView: View {
    let query: SearchQuery
    
    var body: some View {
        HStack {
            Image(systemName: query.type.iconName)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(query.type.displayName)
                    .font(.headline)
                
                Text(query.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(query.boundingBox.area, specifier: "%.2f")°²")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

/// Favorites view
struct FavoritesView: View {
    @ObservedObject var viewModel: OverpassViewModel
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.favoriteLocations) { favorite in
                    FavoriteRowView(favorite: favorite) {
                        viewModel.removeFromFavorites(favorite)
                    }
                }
            }
            .navigationTitle("Favorites")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

/// Favorite row view
struct FavoriteRowView: View {
    let favorite: FavoriteLocation
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: favorite.type.iconName)
                .foregroundColor(.red)
            
            VStack(alignment: .leading) {
                Text(favorite.name)
                    .font(.headline)
                
                Text("\(favorite.coordinate.latitude, specifier: "%.4f"), \(favorite.coordinate.longitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Added \(favorite.addedDate, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Remove", role: .destructive, action: onRemove)
        }
    }
}

/// Settings view
struct SettingsView: View {
    @AppStorage("map_type") private var mapType = 0
    @AppStorage("search_radius") private var defaultSearchRadius = 1000.0
    @AppStorage("auto_search") private var autoSearch = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Map Settings") {
                    Picker("Map Type", selection: $mapType) {
                        Text("Standard").tag(0)
                        Text("Hybrid").tag(1)
                        Text("Satellite").tag(2)
                        Text("OSM").tag(3)
                    }
                }
                
                Section("Search Settings") {
                    HStack {
                        Text("Default Search Radius")
                        Spacer()
                        Text("\(Int(defaultSearchRadius))m")
                    }
                    
                    Slider(value: $defaultSearchRadius, in: 100...5000, step: 100)
                    
                    Toggle("Auto-search on map move", isOn: $autoSearch)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Powered by")
                        Spacer()
                        Text("OverpassKit")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

/// Loading view
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Searching...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

/// Error alert
struct ErrorAlert: View {
    let error: OverpassError
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Search Error")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .multilineTextAlignment(.center)
            
            Button("OK", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .overpassClient(OverpassClient())
}
