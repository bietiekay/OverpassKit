import Foundation

/// Represents an Overpass QL query
public class OverpassQuery {
    
    // MARK: - Properties
    
    /// The raw Overpass QL query string
    public let queryString: String
    
    /// The formatted query string with output format and timeout
    public let formattedQuery: String
    
    /// The bounding box for the query
    public let boundingBox: OverpassBoundingBox?
    
    /// The output format for the query
    public let outputFormat: OverpassKit.OutputFormat
    
    /// The timeout configuration
    public let timeout: OverpassKit.Timeout
    
    // MARK: - Initialization
    
    /// Initialize with a custom query string
    /// - Parameters:
    ///   - queryString: Raw Overpass QL query string
    ///   - outputFormat: Output format for the query
    ///   - timeout: Timeout configuration
    public init(
        queryString: String,
        outputFormat: OverpassKit.OutputFormat = .json,
        timeout: OverpassKit.Timeout = OverpassKit.Timeout()
    ) {
        self.queryString = queryString
        self.boundingBox = nil
        self.outputFormat = outputFormat
        self.timeout = timeout
        self.formattedQuery = Self.formatQuery(queryString, outputFormat: outputFormat, timeout: timeout)
    }
    
    /// Initialize with a bounding box and element types
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box for the query
    ///   - elementTypes: Types of elements to search for
    ///   - outputFormat: Output format for the query
    ///   - timeout: Timeout configuration
    public init(
        boundingBox: OverpassBoundingBox,
        elementTypes: [ElementType],
        outputFormat: OverpassKit.OutputFormat = .json,
        timeout: OverpassKit.Timeout = OverpassKit.Timeout()
    ) {
        self.boundingBox = boundingBox
        self.outputFormat = outputFormat
        self.timeout = timeout
        
        let queryString = Self.buildQueryString(elementTypes: elementTypes, boundingBox: boundingBox)
        self.queryString = queryString
        self.formattedQuery = Self.formatQuery(queryString, outputFormat: outputFormat, timeout: timeout)
    }
    
    // MARK: - Element Types
    
    /// Types of elements that can be queried
    public enum ElementType: Equatable {
        case node(tags: [String: String]? = nil)
        case way(tags: [String: String]? = nil)
        case relation(tags: [String: String]? = nil)
        
        /// Creates a node query for a specific amenity
        /// - Parameter amenity: Amenity type to search for
        /// - Returns: Node element type
        public static func amenity(_ amenity: String) -> ElementType {
            return .node(tags: ["amenity": amenity])
        }
        
        /// Creates a node query for a specific shop type
        /// - Parameter shop: Shop type to search for
        /// - Returns: Node element type
        public static func shop(_ shop: String) -> ElementType {
            return .node(tags: ["shop": shop])
        }
        
        /// Creates a node query for a specific leisure type
        /// - Parameter leisure: Leisure type to search for
        /// - Returns: Node element type
        public static func leisure(_ leisure: String) -> ElementType {
            return .node(tags: ["leisure": leisure])
        }
        
        /// Creates a node query for a specific tourism type
        /// - Parameter tourism: Tourism type to search for
        /// - Returns: Node element type
        public static func tourism(_ tourism: String) -> ElementType {
            return .node(tags: ["tourism": tourism])
        }
        
        /// Creates a way query for a specific highway type
        /// - Parameter highway: Highway type to search for
        /// - Returns: Way element type
        public static func highway(_ highway: String) -> ElementType {
            return .way(tags: ["highway": highway])
        }
        
        /// Creates a way query for a specific building type
        /// - Parameter building: Building type to search for
        /// - Returns: Way element type
        public static func building(_ building: String) -> ElementType {
            return .way(tags: ["building": building])
        }
        
        /// Creates a way query for a specific land use type
        /// - Parameter landuse: Land use type to search for
        /// - Returns: Way element type
        public static func landuse(_ landuse: String) -> ElementType {
            return .way(tags: ["landuse": landuse])
        }
        
        /// Creates a way query for a specific natural feature type
        /// - Parameter natural: Natural feature type to search for
        /// - Returns: Way element type
        public static func natural(_ natural: String) -> ElementType {
            return .way(tags: ["natural": natural])
        }
        
        /// Creates a way query for a specific water feature type
        /// - Parameter water: Water feature type to search for
        /// - Returns: Way element type
        public static func water(_ water: String) -> ElementType {
            return .way(tags: ["water": water])
        }
        
        /// Creates a custom element type with specific tags
        /// - Parameters:
        ///   - type: Element type (node, way, or relation)
        ///   - tags: Dictionary of tag key-value pairs
        /// - Returns: Custom element type
        public static func custom(_ type: String, tags: [String: String]) -> ElementType {
            switch type.lowercased() {
            case "node":
                return .node(tags: tags)
            case "way":
                return .way(tags: tags)
            case "relation":
                return .relation(tags: tags)
            default:
                return .node(tags: tags)
            }
        }
    }
    
    // MARK: - Query Building
    
    /// Builds a query string from element types and bounding box
    /// - Parameters:
    ///   - elementTypes: Types of elements to search for
    ///   - boundingBox: Geographic bounding box
    /// - Returns: Overpass QL query string
    private static func buildQueryString(elementTypes: [ElementType], boundingBox: OverpassBoundingBox) -> String {
        var queryParts: [String] = []
        
        for elementType in elementTypes {
            let elementQuery = buildElementQuery(elementType, boundingBox: boundingBox)
            queryParts.append(elementQuery)
        }
        
        let query = queryParts.joined(separator: ";")
        return "(\(query););out body;>;out skel qt;"
    }
    
    /// Builds a query string for a specific element type
    /// - Parameters:
    ///   - elementType: Element type to query
    ///   - boundingBox: Geographic bounding box
    /// - Returns: Element-specific query string
    private static func buildElementQuery(_ elementType: ElementType, boundingBox: OverpassBoundingBox) -> String {
        let bboxString = boundingBox.overpassString()
        
        switch elementType {
        case .node(let tags):
            if let tags = tags {
                let tagFilters = tags.map { "[\"\($0.key)\"=\"\($0.value)\"]" }.joined()
                return "node\(tagFilters)\(bboxString)"
            } else {
                return "node\(bboxString)"
            }
            
        case .way(let tags):
            if let tags = tags {
                let tagFilters = tags.map { "[\"\($0.key)\"=\"\($0.value)\"]" }.joined()
                return "way\(tagFilters)\(bboxString)"
            } else {
                return "way\(bboxString)"
            }
            
        case .relation(let tags):
            if let tags = tags {
                let tagFilters = tags.map { "[\"\($0.key)\"=\"\($0.value)\"]" }.joined()
                return "relation\(tagFilters)\(bboxString)"
            } else {
                return "relation\(bboxString)"
            }
        }
    }
    
    /// Formats a query string with output format and timeout
    /// - Parameters:
    ///   - queryString: Raw query string
    ///   - outputFormat: Output format
    ///   - timeout: Timeout configuration
    /// - Returns: Formatted query string
    private static func formatQuery(
        _ queryString: String,
        outputFormat: OverpassKit.OutputFormat,
        timeout: OverpassKit.Timeout
    ) -> String {
        return "[out:\(outputFormat.rawValue)][timeout:\(timeout.serverTimeout)];\(queryString)"
    }
    
    // MARK: - Convenience Initializers
    
    /// Creates a query for toilets in a bounding box
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box
    ///   - outputFormat: Output format
    ///   - timeout: Timeout configuration
    /// - Returns: OverpassQuery for toilets
    public static func toilets(
        in boundingBox: OverpassBoundingBox,
        outputFormat: OverpassKit.OutputFormat = .json,
        timeout: OverpassKit.Timeout = OverpassKit.Timeout()
    ) -> OverpassQuery {
        return OverpassQuery(
            boundingBox: boundingBox,
            elementTypes: [.amenity("toilets")],
            outputFormat: outputFormat,
            timeout: timeout
        )
    }
    
    /// Creates a query for restaurants in a bounding box
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box
    ///   - outputFormat: Output format
    ///   - timeout: Timeout configuration
    /// - Returns: OverpassQuery for restaurants
    public static func restaurants(
        in boundingBox: OverpassBoundingBox,
        outputFormat: OverpassKit.OutputFormat = .json,
        timeout: OverpassKit.Timeout = OverpassKit.Timeout()
    ) -> OverpassQuery {
        return OverpassQuery(
            boundingBox: boundingBox,
            elementTypes: [.amenity("restaurant")],
            outputFormat: outputFormat,
            timeout: timeout
        )
    }
    
    /// Creates a query for cafes in a bounding box
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box
    ///   - outputFormat: Output format
    ///   - timeout: Timeout configuration
    /// - Returns: OverpassQuery for cafes
    public static func cafes(
        in boundingBox: OverpassBoundingBox,
        outputFormat: OverpassKit.OutputFormat = .json,
        timeout: OverpassKit.Timeout = OverpassKit.Timeout()
    ) -> OverpassQuery {
        return OverpassQuery(
            boundingBox: boundingBox,
            elementTypes: [.amenity("cafe")],
            outputFormat: outputFormat,
            timeout: timeout
        )
    }
    
    /// Creates a query for hotels in a bounding box
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box
    ///   - outputFormat: Output format
    ///   - timeout: Timeout configuration
    /// - Returns: OverpassQuery for hotels
    public static func hotels(
        in boundingBox: OverpassBoundingBox,
        outputFormat: OverpassKit.OutputFormat = .json,
        timeout: OverpassKit.Timeout = OverpassKit.Timeout()
    ) -> OverpassQuery {
        return OverpassQuery(
            boundingBox: boundingBox,
            elementTypes: [.tourism("hotel")],
            outputFormat: outputFormat,
            timeout: timeout
        )
    }
    
    /// Creates a query for shops in a bounding box
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box
    ///   - shopType: Specific shop type (optional)
    ///   - outputFormat: Output format
    ///   - timeout: Timeout configuration
    /// - Returns: OverpassQuery for shops
    public static func shops(
        in boundingBox: OverpassBoundingBox,
        shopType: String? = nil,
        outputFormat: OverpassKit.OutputFormat = .json,
        timeout: OverpassKit.Timeout = OverpassKit.Timeout()
    ) -> OverpassQuery {
        if let shopType = shopType {
            return OverpassQuery(
                boundingBox: boundingBox,
                elementTypes: [.shop(shopType)],
                outputFormat: outputFormat,
                timeout: timeout
            )
        } else {
            // Match any node with a "shop" tag, regardless of value
            let bboxString = boundingBox.overpassString()
            let element = "node[\"shop\"]\(bboxString)"
            let grouped = "(\(element););out body;>;out skel qt;"
            return OverpassQuery(
                queryString: grouped,
                outputFormat: outputFormat,
                timeout: timeout
            )
        }
    }
    
    /// Creates a query for parks in a bounding box
    /// - Parameters:
    ///   - boundingBox: Geographic bounding box
    ///   - outputFormat: Output format
    ///   - timeout: Timeout configuration
    /// - Returns: OverpassQuery for parks
    public static func parks(
        in boundingBox: OverpassBoundingBox,
        outputFormat: OverpassKit.OutputFormat = .json,
        timeout: OverpassKit.Timeout = OverpassKit.Timeout()
    ) -> OverpassQuery {
        return OverpassQuery(
            boundingBox: boundingBox,
            elementTypes: [.leisure("park")],
            outputFormat: outputFormat,
            timeout: timeout
        )
    }
}

// MARK: - CustomStringConvertible

extension OverpassQuery: CustomStringConvertible {
    public var description: String {
        return "OverpassQuery: \(formattedQuery)"
    }
}
