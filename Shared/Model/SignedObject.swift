//
//  SignedObject.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation

/// This object is the base for everything, if its an geometry object or a material
class SignedObject : Codable, Hashable {
    
    enum Role : Int, Codable {
        case Camera, Object, Renderer
    }
    
    var id              = UUID()
    var name            : String
    
    var role            : Role

    var children        : [SignedObject] = []
    
    /// Representing components which belong to a specific group, like primitives
    var components      : [SignedComponent] = []

    var graphPosition   = CGPoint(x: 100, y: 100)
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case children
        case components
        case graphPosition
    }
    
    init(_ name: String = "Unnamed", role: Role = .Object, graphPosition: CGPoint = CGPoint.zero)
    {
        self.name = name
        self.role = role
        self.graphPosition = graphPosition
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(Role.self, forKey: .role)
        children = try container.decode([SignedObject].self, forKey: .children)
        components = try container.decode([SignedComponent].self, forKey: .components)
        graphPosition = try container.decode(CGPoint.self, forKey: .graphPosition)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(children, forKey: .children)
        try container.encode(components, forKey: .components)
        try container.encode(graphPosition, forKey: .graphPosition)
    }
    
    static func ==(lhs: SignedObject, rhs: SignedObject) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
