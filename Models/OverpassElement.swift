import Foundation
import CoreLocation

/// Represents an individual element returned from Overpass API
public struct OverpassElement: Codable, Equatable, Identifiable {
    
    // MARK: - Properties
    
    /// Unique identifier for the element
    public let id: Int64
    
    /// Type of element (node, way, relation)
    public let type: ElementType
    
    /// Latitude coordinate (for nodes)
    public let lat: Double?
    
    /// Longitude coordinate (for nodes)
    public let lon: Double?
    
    /// Tags associated with the element
    public let tags: [String: String]?
    
    /// Member references (for ways and relations)
    public let members: [OverpassMember]?
    
    /// Nodes that make up this way (for ways)
    public let nodes: [Int64]?
    
    /// Geometry information for ways
    public let geometry: [OverpassGeometry]?
    
    // MARK: - Computed Properties
    
    /// Coordinate of the element (for nodes)
    public var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lon = lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Name of the element from tags
    public var name: String? {
        return tags?["name"]
    }
    
    /// Description of the element from tags
    public var description: String? {
        return tags?["description"]
    }
    
    /// Amenity type from tags
    public var amenity: String? {
        return tags?["amenity"]
    }
    
    /// Shop type from tags
    public var shop: String? {
        return tags?["shop"]
    }
    
    /// Leisure type from tags
    public var leisure: String? {
        return tags?["leisure"]
    }
    
    /// Tourism type from tags
    public var tourism: String? {
        return tags?["tourism"]
    }
    
    /// Highway type from tags
    public var highway: String? {
        return tags?["highway"]
    }
    
    /// Building type from tags
    public var building: String? {
        return tags?["building"]
    }
    
    /// Land use type from tags
    public var landuse: String? {
        return tags?["landuse"]
    }
    
    /// Natural feature type from tags
    public var natural: String? {
        return tags?["natural"]
    }
    
    /// Water feature type from tags
    public var water: String? {
        return tags?["water"]
    }
    
    /// Address information
    public var address: OverpassAddress? {
        guard let tags = tags else { return nil }
        
        var addressDict: [String: String] = [:]
        for (key, value) in tags {
            if key.hasPrefix("addr:") {
                let addressKey = String(key.dropFirst(5)) // Remove "addr:" prefix
                addressDict[addressKey] = value
            }
        }
        
        return addressDict.isEmpty ? nil : OverpassAddress(dictionary: addressDict)
    }
    
    // MARK: - Initialization
    
    public init(
        id: Int64,
        type: ElementType,
        lat: Double? = nil,
        lon: Double? = nil,
        tags: [String: String]? = nil,
        members: [OverpassMember]? = nil,
        nodes: [Int64]? = nil,
        geometry: [OverpassGeometry]? = nil
    ) {
        self.id = id
        self.type = type
        self.lat = lat
        self.lon = lon
        self.tags = tags
        self.members = members
        self.nodes = nodes
        self.geometry = geometry
    }
    
    // MARK: - Utility Methods
    
    /// Checks if the element has a specific tag
    /// - Parameter key: Tag key to check
    /// - Returns: True if tag exists
    public func hasTag(_ key: String) -> Bool {
        return tags?[key] != nil
    }
    
    /// Gets the value of a specific tag
    /// - Parameter key: Tag key
    /// - Returns: Tag value if it exists
    public func getTag(_ key: String) -> String? {
        return tags?[key]
    }
    
    /// Checks if the element matches a specific tag value
    /// - Parameters:
    ///   - key: Tag key to check
    ///   - value: Expected tag value
    /// - Returns: True if tag matches
    public func hasTag(_ key: String, value: String) -> Bool {
        return tags?[key] == value
    }
    
    /// Checks if the element is within a bounding box
    /// - Parameter boundingBox: Bounding box to check against
    /// - Returns: True if element is within bounds
    public func isWithin(_ boundingBox: OverpassBoundingBox) -> Bool {
        guard let coordinate = coordinate else { return false }
        return boundingBox.contains(coordinate)
    }
}

// MARK: - Element Types

extension OverpassElement {
    /// Types of Overpass elements
    public enum ElementType: String, Codable, CaseIterable {
        case node = "node"
        case way = "way"
        case relation = "relation"
    }
}

// MARK: - Overpass Member

/// Represents a member of a way or relation
public struct OverpassMember: Codable, Equatable {
    public let type: String
    public let ref: Int64
    public let role: String?
    
    public init(type: String, ref: Int64, role: String? = nil) {
        self.type = type
        self.ref = ref
        self.role = role
    }
}

// MARK: - Overpass Geometry

/// Represents geometry information for ways
public struct OverpassGeometry: Codable, Equatable {
    public let lat: Double
    public let lon: Double
    
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

// MARK: - Overpass Address

/// Represents address information from tags
public struct OverpassAddress: Equatable {
    public let houseNumber: String?
    public let street: String?
    public let city: String?
    public let state: String?
    public let postcode: String?
    public let country: String?
    public let fullAddress: String?
    
    public init(dictionary: [String: String]) {
        self.houseNumber = dictionary["housenumber"]
        self.street = dictionary["street"]
        self.city = dictionary["city"]
        self.state = dictionary["state"]
        self.postcode = dictionary["postcode"]
        self.country = dictionary["country"]
        
        // Build full address
        var addressParts: [String] = []
        if let houseNumber = houseNumber { addressParts.append(houseNumber) }
        if let street = street { addressParts.append(street) }
        if let city = city { addressParts.append(city) }
        if let state = state { addressParts.append(state) }
        if let postcode = postcode { addressParts.append(postcode) }
        if let country = country { addressParts.append(country) }
        
        self.fullAddress = addressParts.isEmpty ? nil : addressParts.joined(separator: ", ")
    }
}

// MARK: - CustomDebugStringConvertible

extension OverpassElement: CustomDebugStringConvertible {
    public var debugDescription: String {
        let coordString = coordinate != nil ? " at \(coordinate!)" : ""
        let nameString = name != nil ? " (\(name!))" : ""
        return "\(type.rawValue) \(id)\(coordString)\(nameString)"
    }
}
