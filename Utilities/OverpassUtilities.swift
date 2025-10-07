import Foundation
import CoreLocation
import MapKit

/// Utility functions and extensions for working with Overpass data
public struct OverpassUtilities {
    
    // MARK: - Coordinate Utilities
    
    /// Converts degrees to radians
    /// - Parameter degrees: Angle in degrees
    /// - Returns: Angle in radians
    public static func degreesToRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }
    
    /// Converts radians to degrees
    /// - Parameter radians: Angle in radians
    /// - Returns: Angle in degrees
    public static func radiansToDegrees(_ radians: Double) -> Double {
        return radians * 180.0 / .pi
    }
    
    /// Calculates the distance between two coordinates using the Haversine formula
    /// - Parameters:
    ///   - coordinate1: First coordinate
    ///   - coordinate2: Second coordinate
    /// - Returns: Distance in meters
    public static func distance(from coordinate1: CLLocationCoordinate2D, to coordinate2: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: coordinate1.latitude, longitude: coordinate1.longitude)
        let location2 = CLLocation(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
        return location1.distance(from: location2)
    }
    
    /// Calculates the bearing between two coordinates
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Ending coordinate
    /// - Returns: Bearing in degrees (0-360)
    public static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = degreesToRadians(from.latitude)
        let lat2 = degreesToRadians(to.latitude)
        let deltaLon = degreesToRadians(to.longitude - from.longitude)
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x)
        return (radiansToDegrees(bearing) + 360).truncatingRemainder(dividingBy: 360)
    }
    
    /// Calculates a coordinate at a given distance and bearing from a starting point
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - distance: Distance in meters
    ///   - bearing: Bearing in degrees
    /// - Returns: New coordinate
    public static func coordinate(from: CLLocationCoordinate2D, distance: CLLocationDistance, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0 // Earth's radius in meters
        let angularDistance = distance / earthRadius
        let bearingRad = degreesToRadians(bearing)
        
        let lat1 = degreesToRadians(from.latitude)
        let lon1 = degreesToRadians(from.longitude)
        
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearingRad))
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(
            latitude: radiansToDegrees(lat2),
            longitude: radiansToDegrees(lon2)
        )
    }
    
    // MARK: - Bounding Box Utilities
    
    /// Creates a bounding box that encompasses multiple coordinates with padding
    /// - Parameters:
    ///   - coordinates: Array of coordinates to encompass
    ///   - paddingFactor: Padding factor (1.0 = no padding, 1.1 = 10% padding)
    /// - Returns: Bounding box encompassing all coordinates
    public static func boundingBox(for coordinates: [CLLocationCoordinate2D], paddingFactor: Double = 1.1) -> OverpassBoundingBox? {
        guard !coordinates.isEmpty else { return nil }
        
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!
        
        let latCenter = (minLat + maxLat) / 2.0
        let lonCenter = (minLon + maxLon) / 2.0
        let latDelta = (maxLat - minLat) * paddingFactor / 2.0
        let lonDelta = (maxLon - minLon) * paddingFactor / 2.0
        
        return try? OverpassBoundingBox(
            lowestLatitude: latCenter - latDelta,
            lowestLongitude: lonCenter - lonDelta,
            highestLatitude: latCenter + latDelta,
            highestLongitude: lonCenter + lonDelta
        )
    }
    
    /// Creates a bounding box centered on a coordinate with a specific radius
    /// - Parameters:
    ///   - center: Center coordinate
    ///   - radiusInMeters: Radius in meters
    /// - Returns: Bounding box centered on the coordinate
    public static func boundingBox(center: CLLocationCoordinate2D, radiusInMeters: Double) -> OverpassBoundingBox? {
        return try? OverpassBoundingBox(center: center, radiusInMeters: radiusInMeters)
    }
    
    /// Expands a bounding box by a specified amount
    /// - Parameters:
    ///   - boundingBox: Original bounding box
    ///   - expansionInMeters: Expansion amount in meters
    /// - Returns: Expanded bounding box
    public static func expandBoundingBox(_ boundingBox: OverpassBoundingBox, by expansionInMeters: Double) -> OverpassBoundingBox? {
        let expansionInDegrees = expansionInMeters / 111000.0 // Approximate conversion
        
        return try? boundingBox.expanded(by: expansionInDegrees)
    }
    
    // MARK: - Element Filtering Utilities
    
    /// Filters elements by distance from a coordinate
    /// - Parameters:
    ///   - elements: Array of elements to filter
    ///   - coordinate: Reference coordinate
    ///   - maxDistance: Maximum distance in meters
    /// - Returns: Filtered array of elements
    public static func filterElements(_ elements: [OverpassElement], within maxDistance: Double, of coordinate: CLLocationCoordinate2D) -> [OverpassElement] {
        return elements.filter { element in
            guard let elementCoord = element.coordinate else { return false }
            return distance(from: coordinate, to: elementCoord) <= maxDistance
        }
    }
    
    /// Sorts elements by distance from a coordinate
    /// - Parameters:
    ///   - elements: Array of elements to sort
    ///   - coordinate: Reference coordinate
    /// - Returns: Sorted array of elements (closest first)
    public static func sortElements(_ elements: [OverpassElement], byDistanceFrom coordinate: CLLocationCoordinate2D) -> [OverpassElement] {
        return elements.sorted { element1, element2 in
            guard let coord1 = element1.coordinate, let coord2 = element2.coordinate else {
                return false
            }
            
            let distance1 = distance(from: coordinate, to: coord1)
            let distance2 = distance(from: coordinate, to: coord2)
            return distance1 < distance2
        }
    }
    
    /// Groups elements by a specific tag value
    /// - Parameters:
    ///   - elements: Array of elements to group
    ///   - tagKey: Tag key to group by
    /// - Returns: Dictionary with tag values as keys and arrays of elements as values
    public static func groupElements(_ elements: [OverpassElement], by tagKey: String) -> [String: [OverpassElement]] {
        var grouped: [String: [OverpassElement]] = [:]
        
        for element in elements {
            if let tagValue = element.getTag(tagKey) {
                if grouped[tagValue] == nil {
                    grouped[tagValue] = []
                }
                grouped[tagValue]?.append(element)
            }
        }
        
        return grouped
    }
    
    // MARK: - Tag Utilities
    
    /// Extracts all unique tag values for a specific key from elements
    /// - Parameters:
    ///   - elements: Array of elements
    ///   - tagKey: Tag key to extract values for
    /// - Returns: Array of unique tag values
    public static func uniqueTagValues(for elements: [OverpassElement], tagKey: String) -> [String] {
        let values = elements.compactMap { $0.getTag(tagKey) }
        return Array(Set(values)).sorted()
    }
    
    /// Finds elements with specific tag combinations
    /// - Parameters:
    ///   - elements: Array of elements to search
    ///   - tags: Dictionary of tag key-value pairs
    /// - Returns: Array of elements matching all specified tags
    public static func findElements(_ elements: [OverpassElement], withTags tags: [String: String]) -> [OverpassElement] {
        return elements.filter { element in
            for (key, value) in tags {
                guard element.hasTag(key, value: value) else { return false }
            }
            return true
        }
    }
    
    /// Finds elements with any of the specified tag values
    /// - Parameters:
    ///   - elements: Array of elements to search
    ///   - tagKey: Tag key to search for
    ///   - tagValues: Array of possible tag values
    /// - Returns: Array of elements matching any of the specified tag values
    public static func findElements(_ elements: [OverpassElement], withTag tagKey: String, anyOf tagValues: [String]) -> [OverpassElement] {
        return elements.filter { element in
            guard let elementValue = element.getTag(tagKey) else { return false }
            return tagValues.contains(elementValue)
        }
    }
    
    // MARK: - Address Utilities
    
    /// Formats an address from address components
    /// - Parameter address: Address object to format
    /// - Returns: Formatted address string
    public static func formatAddress(_ address: OverpassAddress) -> String {
        var parts: [String] = []
        
        if let houseNumber = address.houseNumber { parts.append(houseNumber) }
        if let street = address.street { parts.append(street) }
        if let city = address.city { parts.append(city) }
        if let state = address.state { parts.append(state) }
        if let postcode = address.postcode { parts.append(postcode) }
        if let country = address.country { parts.append(country) }
        
        return parts.isEmpty ? NSLocalizedString("unknown_address", comment: "Unknown address placeholder") : parts.joined(separator: ", ")
    }
    
    /// Extracts address information from element tags
    /// - Parameter element: Element to extract address from
    /// - Returns: Address object if available
    public static func extractAddress(from element: OverpassElement) -> OverpassAddress? {
        guard let tags = element.tags else { return nil }
        
        var addressDict: [String: String] = [:]
        for (key, value) in tags {
            if key.hasPrefix("addr:") {
                let addressKey = String(key.dropFirst(5)) // Remove "addr:" prefix
                addressDict[addressKey] = value
            }
        }
        
        return addressDict.isEmpty ? nil : OverpassAddress(dictionary: addressDict)
    }
    
    // MARK: - Validation Utilities
    
    /// Validates if a coordinate is within valid ranges
    /// - Parameter coordinate: Coordinate to validate
    /// - Returns: True if coordinate is valid
    public static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0 &&
               coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0
    }
    
    /// Validates if a bounding box is valid
    /// - Parameter boundingBox: Bounding box to validate
    /// - Returns: True if bounding box is valid
    public static func isValidBoundingBox(_ boundingBox: OverpassBoundingBox) -> Bool {
        return boundingBox.lowestLatitude <= boundingBox.highestLatitude &&
               boundingBox.lowestLongitude <= boundingBox.highestLongitude &&
               isValidCoordinate(CLLocationCoordinate2D(latitude: boundingBox.lowestLatitude, longitude: boundingBox.lowestLongitude)) &&
               isValidCoordinate(CLLocationCoordinate2D(latitude: boundingBox.highestLatitude, longitude: boundingBox.highestLongitude))
    }
    
    // MARK: - Conversion Utilities
    
    /// Converts a distance from meters to a human-readable string
    /// - Parameter distanceInMeters: Distance in meters
    /// - Returns: Human-readable distance string
    public static func formatDistance(_ distanceInMeters: Double) -> String {
        if distanceInMeters < 1000 {
            return NSLocalizedString("distance_meters", comment: "Distance in meters format")
        } else if distanceInMeters < 10000 {
            return String(format: NSLocalizedString("distance_kilometers_decimal", comment: "Distance in kilometers with decimal format"), distanceInMeters / 1000)
        } else {
            return String(format: NSLocalizedString("distance_kilometers_whole", comment: "Distance in kilometers without decimal format"), distanceInMeters / 1000)
        }
    }
    
    /// Converts a coordinate to a string representation
    /// - Parameter coordinate: Coordinate to format
    /// - Returns: Formatted coordinate string
    public static func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let latString = String(format: "%.6f", coordinate.latitude)
        let lonString = String(format: "%.6f", coordinate.longitude)
        return String(format: NSLocalizedString("coordinate_format", comment: "Coordinate format string"), latString, lonString)
    }
}
