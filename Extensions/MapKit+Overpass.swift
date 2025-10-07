import Foundation
import MapKit
import CoreLocation

// MARK: - MKMapView Extensions

extension MKMapView {
    
    /// Creates an Overpass bounding box from the visible map area
    /// - Returns: Bounding box representing the visible map area
    public func overpassBoundingBox() -> OverpassBoundingBox? {
        return try? OverpassBoundingBox(mapRect: visibleMapRect)
    }
    
    /// Creates an Overpass bounding box from the current map region
    /// - Returns: Bounding box representing the current map region
    public func overpassBoundingBoxFromRegion() -> OverpassBoundingBox? {
        return try? OverpassBoundingBox(region: region)
    }
    
    /// Creates an Overpass bounding box centered on user location with a specific radius
    /// - Parameter radiusInMeters: Radius in meters
    /// - Returns: Bounding box centered on user location
    public func overpassBoundingBox(radiusInMeters: Double) -> OverpassBoundingBox? {
        guard let userLocation = userLocation.location else { return nil }
        return try? OverpassBoundingBox(center: userLocation.coordinate, radiusInMeters: radiusInMeters)
    }
    
    /// Creates an Overpass bounding box from the center coordinate with a specific radius
    /// - Parameters:
    ///   - center: Center coordinate
    ///   - radiusInMeters: Radius in meters
    /// - Returns: Bounding box centered on the specified coordinate
    public func overpassBoundingBox(center: CLLocationCoordinate2D, radiusInMeters: Double) -> OverpassBoundingBox? {
        return try? OverpassBoundingBox(center: center, radiusInMeters: radiusInMeters)
    }
    
    /// Checks if a coordinate is within the visible map area
    /// - Parameter coordinate: Coordinate to check
    /// - Returns: True if coordinate is visible
    public func isCoordinateVisible(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard let boundingBox = overpassBoundingBox() else { return false }
        return boundingBox.contains(coordinate)
    }
    
    /// Checks if the user location is within the center region of the map
    /// - Parameter toleranceInPoints: Tolerance in screen points (default: 100)
    /// - Returns: True if user is in center region
    public func isUserInCenterRegion(toleranceInPoints: CGFloat = 100.0) -> Bool {
        guard let userLocation = userLocation.location else { return false }
        
        let userPoint = convert(userLocation.coordinate, toPointTo: self)
        let centerPoint = convert(centerCoordinate, toPointTo: self)
        
        let xDifference = abs(centerPoint.x - userPoint.x)
        let yDifference = abs(centerPoint.y - userPoint.y)
        
        return xDifference <= toleranceInPoints && yDifference <= toleranceInPoints
    }
}

// MARK: - MKCoordinateRegion Extensions

extension MKCoordinateRegion {
    
    /// Creates an Overpass bounding box from this region
    /// - Returns: Bounding box representing the region
    public func overpassBoundingBox() -> OverpassBoundingBox? {
        return try? OverpassBoundingBox(region: self)
    }
    
    /// Expands the region by a specified amount
    /// - Parameter expansionFactor: Factor to expand by (1.0 = no change, 2.0 = double size)
    /// - Returns: New expanded region
    public func expanded(by expansionFactor: Double) -> MKCoordinateRegion {
        let newLatDelta = span.latitudeDelta * expansionFactor
        let newLonDelta = span.longitudeDelta * expansionFactor
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: newLatDelta, longitudeDelta: newLonDelta)
        )
    }
    
    /// Creates a region that encompasses multiple coordinates
    /// - Parameter coordinates: Array of coordinates to encompass
    /// - Returns: Region containing all coordinates
    public static func encompassing(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!
        
        let centerLat = (minLat + maxLat) / 2.0
        let centerLon = (minLon + maxLon) / 2.0
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        let latDelta = (maxLat - minLat) * 1.1 // Add 10% padding
        let lonDelta = (maxLon - minLon) * 1.1
        
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - CLLocationCoordinate2D Extensions

extension CLLocationCoordinate2D {
    
    /// Creates an Overpass bounding box centered on this coordinate with a specific radius
    /// - Parameter radiusInMeters: Radius in meters
    /// - Returns: Bounding box centered on this coordinate
    public func overpassBoundingBox(radiusInMeters: Double) -> OverpassBoundingBox? {
        return try? OverpassBoundingBox(center: self, radiusInMeters: radiusInMeters)
    }
    
    /// Calculates the distance to another coordinate
    /// - Parameter coordinate: Target coordinate
    /// - Returns: Distance in meters
    public func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
    
    /// Creates a bounding box that encompasses this coordinate and another coordinate
    /// - Parameter coordinate: Other coordinate to encompass
    /// - Returns: Bounding box containing both coordinates
    public func boundingBox(with coordinate: CLLocationCoordinate2D) -> OverpassBoundingBox? {
        let minLat = min(latitude, coordinate.latitude)
        let maxLat = max(latitude, coordinate.latitude)
        let minLon = min(longitude, coordinate.longitude)
        let maxLon = max(longitude, coordinate.longitude)
        
        return try? OverpassBoundingBox(
            lowestLatitude: minLat,
            lowestLongitude: minLon,
            highestLatitude: maxLat,
            highestLongitude: maxLon
        )
    }
}

// MARK: - MKMapRect Extensions

extension MKMapRect {
    
    /// Creates an Overpass bounding box from this map rect
    /// - Returns: Bounding box representing the map rect
    public func overpassBoundingBox() -> OverpassBoundingBox? {
        return try? OverpassBoundingBox(mapRect: self)
    }
    
    /// Expands the map rect by a specified amount
    /// - Parameter expansionFactor: Factor to expand by (1.0 = no change, 2.0 = double size)
    /// - Returns: New expanded map rect
    public func expanded(by expansionFactor: Double) -> MKMapRect {
        let centerX = midX
        let centerY = midY
        let newWidth = width * expansionFactor
        let newHeight = height * expansionFactor
        
        let newOriginX = centerX - (newWidth / 2.0)
        let newOriginY = centerY - (newHeight / 2.0)
        
        return MKMapRect(origin: MKMapPoint(x: newOriginX, y: newOriginY), size: MKMapSize(width: newWidth, height: newHeight))
    }
}

// MARK: - CLLocation Extensions

extension CLLocation {
    
    /// Creates an Overpass bounding box centered on this location with a specific radius
    /// - Parameter radiusInMeters: Radius in meters
    /// - Returns: Bounding box centered on this location
    public func overpassBoundingBox(radiusInMeters: Double) -> OverpassBoundingBox? {
        return try? OverpassBoundingBox(center: coordinate, radiusInMeters: radiusInMeters)
    }
    
    /// Creates a bounding box that encompasses this location and another location
    /// - Parameter location: Other location to encompass
    /// - Returns: Bounding box containing both locations
    public func boundingBox(with location: CLLocation) -> OverpassBoundingBox? {
        return coordinate.boundingBox(with: location.coordinate)
    }
}
