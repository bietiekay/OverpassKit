import Foundation
import CoreLocation
import MapKit

/// Represents a geographic bounding box for Overpass API queries
public struct OverpassBoundingBox: Equatable, Hashable {
    
    // MARK: - Properties
    
    /// Lowest latitude (southernmost point)
    public let lowestLatitude: Double
    
    /// Lowest longitude (westernmost point)
    public let lowestLongitude: Double
    
    /// Highest latitude (northernmost point)
    public let highestLatitude: Double
    
    /// Highest longitude (easternmost point)
    public let highestLongitude: Double
    
    /// Coordinate span of the bounding box
    public var span: MKCoordinateSpan {
        let latitudeDelta = abs(highestLatitude - lowestLatitude)
        let longitudeDelta = abs(highestLongitude - lowestLongitude)
        return MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    }
    
    /// Center coordinate of the bounding box
    public var center: CLLocationCoordinate2D {
        let centerLat = (lowestLatitude + highestLatitude) / 2.0
        let centerLon = (lowestLongitude + highestLongitude) / 2.0
        return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }
    
    /// Area of the bounding box in square degrees
    public var area: Double {
        return span.latitudeDelta * span.longitudeDelta
    }
    
    // MARK: - Initialization
    
    /// Initialize with coordinate bounds
    /// - Parameters:
    ///   - lowestLatitude: Southernmost latitude (-90.0 to 90.0)
    ///   - lowestLongitude: Westernmost longitude (-180.0 to 180.0)
    ///   - highestLatitude: Northernmost latitude (-90.0 to 90.0)
    ///   - highestLongitude: Easternmost longitude (-180.0 to 180.0)
    /// - Throws: OverpassError.invalidCoordinates if coordinates are invalid
    public init(
        lowestLatitude: Double,
        lowestLongitude: Double,
        highestLatitude: Double,
        highestLongitude: Double
    ) throws {
        // Validate coordinate ranges
        guard lowestLatitude >= -90.0 && lowestLatitude <= 90.0 else {
            throw OverpassError.invalidCoordinates
        }
        guard highestLatitude >= -90.0 && highestLatitude <= 90.0 else {
            throw OverpassError.invalidCoordinates
        }
        guard lowestLongitude >= -180.0 && lowestLongitude <= 180.0 else {
            throw OverpassError.invalidCoordinates
        }
        guard highestLongitude >= -180.0 && highestLongitude <= 180.0 else {
            throw OverpassError.invalidCoordinates
        }
        
        // Validate logical bounds
        guard lowestLatitude <= highestLatitude else {
            throw OverpassError.invalidBoundingBox
        }
        guard lowestLongitude <= highestLongitude else {
            throw OverpassError.invalidBoundingBox
        }
        
        self.lowestLatitude = lowestLatitude
        self.lowestLongitude = lowestLongitude
        self.highestLatitude = highestLatitude
        self.highestLongitude = highestLongitude
    }
    
    /// Initialize from a center coordinate and radius
    /// - Parameters:
    ///   - center: Center coordinate of the bounding box
    ///   - radiusInMeters: Radius in meters
    /// - Throws: OverpassError.invalidCoordinates if coordinates are invalid
    public init(center: CLLocationCoordinate2D, radiusInMeters: Double) throws {
        let radiusInDegrees = radiusInMeters / 111000.0 // Approximate conversion
        
        try self.init(
            lowestLatitude: center.latitude - radiusInDegrees,
            lowestLongitude: center.longitude - radiusInDegrees,
            highestLatitude: center.latitude + radiusInDegrees,
            highestLongitude: center.longitude + radiusInDegrees
        )
    }
    
    /// Initialize from a MapKit region
    /// - Parameter region: MKCoordinateRegion to convert
    /// - Throws: OverpassError.invalidCoordinates if coordinates are invalid
    public init(region: MKCoordinateRegion) throws {
        let center = region.center
        let halfLatDelta = region.span.latitudeDelta / 2.0
        let halfLonDelta = region.span.longitudeDelta / 2.0
        
        try self.init(
            lowestLatitude: center.latitude - halfLatDelta,
            lowestLongitude: center.longitude - halfLonDelta,
            highestLatitude: center.latitude + halfLatDelta,
            highestLongitude: center.longitude + halfLonDelta
        )
    }
    
    /// Initialize from visible map rect
    /// - Parameter mapRect: MKMapRect to convert
    /// - Throws: OverpassError.invalidCoordinates if coordinates are invalid
    public init(mapRect: MKMapRect) throws {
        let bottomLeft = MKMapPoint(x: mapRect.minX, y: mapRect.maxY)
        let topRight = MKMapPoint(x: mapRect.maxX, y: mapRect.minY)
        
        let bottomLeftCoord = bottomLeft.coordinate
        let topRightCoord = topRight.coordinate
        
        try self.init(
            lowestLatitude: bottomLeftCoord.latitude,
            lowestLongitude: bottomLeftCoord.longitude,
            highestLatitude: topRightCoord.latitude,
            highestLongitude: topRightCoord.longitude
        )
    }
    
    // MARK: - Overpass Query String
    
    /// Converts the bounding box to Overpass QL format
    /// - Returns: String in format "(lat1,lon1,lat2,lon2)"
    public func overpassString() -> String {
        return "(\(lowestLatitude),\(lowestLongitude),\(highestLatitude),\(highestLongitude))"
    }
    
    // MARK: - Utility Methods
    
    /// Checks if a coordinate is within this bounding box
    /// - Parameter coordinate: Coordinate to check
    /// - Returns: True if coordinate is within bounds
    public func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= lowestLatitude &&
               coordinate.latitude <= highestLatitude &&
               coordinate.longitude >= lowestLongitude &&
               coordinate.longitude <= highestLongitude
    }
    
    /// Expands the bounding box by a specified amount
    /// - Parameter expansionInDegrees: Amount to expand in degrees
    /// - Returns: New expanded bounding box
    /// - Throws: OverpassError.invalidCoordinates if resulting coordinates are invalid
    public func expanded(by expansionInDegrees: Double) throws -> OverpassBoundingBox {
        return try OverpassBoundingBox(
            lowestLatitude: lowestLatitude - expansionInDegrees,
            lowestLongitude: lowestLongitude - expansionInDegrees,
            highestLatitude: highestLatitude + expansionInDegrees,
            highestLongitude: highestLongitude + expansionInDegrees
        )
    }
    
    /// Creates a bounding box that includes both this bounding box and another
    /// - Parameter other: Other bounding box to include
    /// - Returns: New bounding box encompassing both
    /// - Throws: OverpassError.invalidCoordinates if resulting coordinates are invalid
    public func expandedToInclude(_ other: OverpassBoundingBox) throws -> OverpassBoundingBox {
        return try OverpassBoundingBox(
            lowestLatitude: Swift.min(lowestLatitude, other.lowestLatitude),
            lowestLongitude: Swift.min(lowestLongitude, other.lowestLongitude),
            highestLatitude: Swift.max(highestLatitude, other.highestLatitude),
            highestLongitude: Swift.max(highestLongitude, other.highestLongitude)
        )
    }
    
    /// Creates a bounding box that encompasses multiple coordinates
    /// - Parameter coordinates: Array of coordinates to encompass
    /// - Returns: Bounding box containing all coordinates
    /// - Throws: OverpassError.invalidCoordinates if coordinates are invalid
    public static func encompassing(_ coordinates: [CLLocationCoordinate2D]) throws -> OverpassBoundingBox {
        guard !coordinates.isEmpty else {
            throw OverpassError.invalidCoordinates
        }
        
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        
        return try OverpassBoundingBox(
            lowestLatitude: lats.min()!,
            lowestLongitude: lons.min()!,
            highestLatitude: lats.max()!,
            highestLongitude: lons.max()!
        )
    }
    
    /// Default bounding box (small area around origin)
    public static let `default` = try! OverpassBoundingBox(
        lowestLatitude: -0.1,
        lowestLongitude: -0.1,
        highestLatitude: 0.1,
        highestLongitude: 0.1
    )
    
    /// Maximum bounding box (covers most of the world)
    public static let max = try! OverpassBoundingBox(
        lowestLatitude: -85.0,
        lowestLongitude: -180.0,
        highestLatitude: 85.0,
        highestLongitude: 180.0
    )
}

// MARK: - Comparable

extension OverpassBoundingBox: Comparable {
    public static func < (lhs: OverpassBoundingBox, rhs: OverpassBoundingBox) -> Bool {
        return lhs.area < rhs.area
    }
}

// MARK: - CustomStringConvertible

extension OverpassBoundingBox: CustomStringConvertible {
    public var description: String {
        return "OverpassBoundingBox(\(lowestLatitude), \(lowestLongitude), \(highestLatitude), \(highestLongitude))"
    }
}
