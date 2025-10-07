import Foundation
import CoreLocation

/// Represents a complete response from the Overpass API
public struct OverpassResponse: Codable, Equatable {
    
    // MARK: - Properties
    
    /// Array of elements returned by the query
    public let elements: [OverpassElement]
    
    /// Optional remark from the server
    public let remark: String?
    
    /// Optional copyright notice
    public let copyright: String?
    
    /// Optional generator information
    public let generator: String?
    
    /// Optional version information
    public let version: String?
    
    /// Optional osm3s metadata
    public let osm3s: OverpassOSM3S?
    
    // MARK: - Initialization
    
    public init(
        elements: [OverpassElement],
        remark: String? = nil,
        copyright: String? = nil,
        generator: String? = nil,
        version: String? = nil,
        osm3s: OverpassOSM3S? = nil
    ) {
        self.elements = elements
        self.remark = remark
        self.copyright = copyright
        self.generator = generator
        self.version = version
        self.osm3s = osm3s
    }
    
    private enum CodingKeys: String, CodingKey {
        case elements
        case remark
        case copyright
        case generator
        case version
        case osm3s
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.elements = try container.decode([OverpassElement].self, forKey: .elements)
        self.remark = try container.decodeIfPresent(String.self, forKey: .remark)
        self.copyright = try container.decodeIfPresent(String.self, forKey: .copyright)
        self.generator = try container.decodeIfPresent(String.self, forKey: .generator)
        if let versionString: String = try? container.decode(String.self, forKey: .version) {
            self.version = versionString
        } else if let versionNumber: Double = try? container.decode(Double.self, forKey: .version) {
            if floor(versionNumber) == versionNumber {
                self.version = String(Int(versionNumber))
            } else {
                self.version = String(versionNumber)
            }
        } else if let versionInt: Int = try? container.decode(Int.self, forKey: .version) {
            self.version = String(versionInt)
        } else {
            self.version = nil
        }
        self.osm3s = try container.decodeIfPresent(OverpassOSM3S.self, forKey: .osm3s)
    }
    
    // MARK: - Utility Methods
    
    /// Checks if the response contains valid data
    public var isValid: Bool {
        // A response is valid if it has elements OR if it's empty but has no error remark
        // Empty responses with remarks are still valid - they just mean "no results found"
        return true
    }
    
    /// Gets all elements of a specific type
    /// - Parameter type: Element type to filter by
    /// - Returns: Array of elements of the specified type
    public func elements(of type: OverpassElement.ElementType) -> [OverpassElement] {
        return elements.filter { $0.type == type }
    }
    
    /// Gets all nodes from the response
    public var nodes: [OverpassElement] {
        return elements(of: .node)
    }
    
    /// Gets all ways from the response
    public var ways: [OverpassElement] {
        return elements(of: .way)
    }
    
    /// Gets all relations from the response
    public var relations: [OverpassElement] {
        return elements(of: .relation)
    }
    
    /// Gets elements with a specific tag
    /// - Parameters:
    ///   - key: Tag key to search for
    ///   - value: Optional tag value to match
    /// - Returns: Array of elements with the specified tag
    public func elements(withTag key: String, value: String? = nil) -> [OverpassElement] {
        return elements.filter { element in
            if let elementValue = element.getTag(key) {
                if let value = value {
                    return elementValue == value
                }
                return true
            }
            return false
        }
    }
    
    /// Gets elements with a specific amenity type
    /// - Parameter amenity: Amenity type to search for
    /// - Returns: Array of elements with the specified amenity
    public func elements(withAmenity amenity: String) -> [OverpassElement] {
        return elements(withTag: "amenity", value: amenity)
    }
    
    /// Gets elements with a specific shop type
    /// - Parameter shop: Shop type to search for
    /// - Returns: Array of elements with the specified shop type
    public func elements(withShop shop: String) -> [OverpassElement] {
        return elements(withTag: "shop", value: shop)
    }
    
    /// Gets elements with a specific leisure type
    /// - Parameter leisure: Leisure type to search for
    /// - Returns: Array of elements with the specified leisure type
    public func elements(withLeisure leisure: String) -> [OverpassElement] {
        return elements(withTag: "leisure", value: leisure)
    }
    
    /// Gets elements with a specific tourism type
    /// - Parameter tourism: Tourism type to search for
    /// - Returns: Array of elements with the specified tourism type
    public func elements(withTourism tourism: String) -> [OverpassElement] {
        return elements(withTag: "tourism", value: tourism)
    }
    
    /// Gets elements with a specific highway type
    /// - Parameter highway: Highway type to search for
    /// - Returns: Array of elements with the specified highway type
    public func elements(withHighway highway: String) -> [OverpassElement] {
        return elements(withTag: "highway", value: highway)
    }
    
    /// Gets elements with a specific building type
    /// - Parameter building: Building type to search for
    /// - Returns: Array of elements with the specified building type
    public func elements(withBuilding building: String) -> [OverpassElement] {
        return elements(withTag: "building", value: building)
    }
    
    /// Gets elements with a specific land use type
    /// - Parameter landuse: Land use type to search for
    /// - Returns: Array of elements with the specified land use type
    public func elements(withLanduse landuse: String) -> [OverpassElement] {
        return elements(withTag: "landuse", value: landuse)
    }
    
    /// Gets elements with a specific natural feature type
    /// - Parameter natural: Natural feature type to search for
    /// - Returns: Array of elements with the specified natural feature type
    public func elements(withNatural natural: String) -> [OverpassElement] {
        return elements(withTag: "natural", value: natural)
    }
    
    /// Gets elements with a specific water feature type
    /// - Parameter water: Water feature type to search for
    /// - Returns: Array of elements with the specified water feature type
    public func elements(withWater water: String) -> [OverpassElement] {
        return elements(withTag: "water", value: water)
    }
    
    /// Gets elements with names
    public var namedElements: [OverpassElement] {
        return elements.filter { $0.name != nil }
    }
    
    /// Gets elements with descriptions
    public var describedElements: [OverpassElement] {
        return elements.filter { $0.description != nil }
    }
    
    /// Gets elements with addresses
    public var addressedElements: [OverpassElement] {
        return elements.filter { $0.address != nil }
    }
    
    /// Gets elements within a bounding box
    /// - Parameter boundingBox: Bounding box to filter by
    /// - Returns: Array of elements within the bounding box
    public func elements(within boundingBox: OverpassBoundingBox) -> [OverpassElement] {
        return elements.filter { $0.isWithin(boundingBox) }
    }
    
    /// Gets elements sorted by distance from a coordinate
    /// - Parameter coordinate: Reference coordinate for sorting
    /// - Returns: Array of elements sorted by distance (closest first)
    public func elements(sortedByDistanceFrom coordinate: CLLocationCoordinate2D) -> [OverpassElement] {
        return elements.sorted { element1, element2 in
            guard let coord1 = element1.coordinate, let coord2 = element2.coordinate else {
                return false
            }
            
            let distance1 = coordinate.distance(to: coord1)
            let distance2 = coordinate.distance(to: coord2)
            return distance1 < distance2
        }
    }
    
    /// Gets elements within a certain radius of a coordinate
    /// - Parameters:
    ///   - coordinate: Center coordinate
    ///   - radiusInMeters: Radius in meters
    /// - Returns: Array of elements within the radius
    public func elements(within radiusInMeters: Double, of coordinate: CLLocationCoordinate2D) -> [OverpassElement] {
        return elements.filter { element in
            guard let elementCoord = element.coordinate else { return false }
            return coordinate.distance(to: elementCoord) <= radiusInMeters
        }
    }
}

// MARK: - Overpass OSM3S

/// Represents OSM3S metadata from Overpass responses
public struct OverpassOSM3S: Codable, Equatable {
    public let timestampOSMBase: String?
    public let copyright: String?
    
    private enum CodingKeys: String, CodingKey {
        case timestampOSMBase = "timestamp_osm_base"
        case copyright
    }
    
    public init(timestampOSMBase: String? = nil, copyright: String? = nil) {
        self.timestampOSMBase = timestampOSMBase
        self.copyright = copyright
    }
}

// Note: distance(to:) for CLLocationCoordinate2D is defined in Extensions/MapKit+Overpass.swift

// MARK: - CustomStringConvertible

extension OverpassResponse: CustomStringConvertible {
    public var description: String {
        let elementCount = elements.count
        let nodeCount = nodes.count
        let wayCount = ways.count
        let relationCount = relations.count
        
        return "OverpassResponse(\(elementCount) elements: \(nodeCount) nodes, \(wayCount) ways, \(relationCount) relations)"
    }
}
