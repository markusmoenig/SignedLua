//
//  SignedObject.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation
import CoreGraphics

/// This object is the base for everything, if its an geometry object or a material
class SignedObject : Codable, Hashable, Identifiable {
    
    var id              = UUID()
    var name            : String
    
    var children        : [SignedObject]? = nil
    
    /// The commands stack
    var commands        : [SignedCommand] = []
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case children
        case commands
    }
    
    init(_ name: String = "Unnamed")
    {
        self.name = name
        
        let initialCmd = SignedCommand("Ground", role: .GeometryAndMaterial, action: .Add, primitive: .Box,
                                       data: ["Transform" : SignedData([SignedDataEntity("Position", float3(0,-0.9,0)) ]),
                                              "Geometry": SignedData([SignedDataEntity("Size", float3(0.6,0.4,0.6) * Float(Modeler_Global_Scale))])
                                             ], material: SignedMaterial(albedo: float3(0.5,0.5,0.5), metallic: 1, roughness: 0.3))
        commands.append(initialCmd)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        children = try container.decode([SignedObject]?.self, forKey: .children)
        commands = try container.decode([SignedCommand].self, forKey: .commands)        
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(children, forKey: .children)
        try container.encode(commands, forKey: .commands)
    }
    
    static func ==(lhs: SignedObject, rhs: SignedObject) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
