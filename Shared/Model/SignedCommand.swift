//
//  SignedComponent.swift
//  Signed
//
//  Created by Markus Moenig on 26/6/21.
//

import Foundation
import CoreGraphics
import SwiftUI

/// This object is the base for everything, if its an geometry object or a material
class SignedCommand : Codable, Hashable {
    
    enum Role: Int32, Codable {
        case Geometry, Brush
    }
    
    enum Action: Int32, Codable {
        case None, Add, Subtract
    }
    
    enum Primitive: Int32, Codable {
        case Sphere, Box
    }
    
    var id              = UUID()
    var name            : String
    
    var role            : Role
    var action          : Action
    var primitive       : Primitive
    
    var data            : SignedData
    var material        : SignedMaterial

    var normal          : float3 = float3()

    var code            : String = ""
            
    var subCommands     : [SignedCommand] = []
    
    // To identify the editor session
    var scriptContext   = ""
    
    var icon            : CGImage? = nil
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case action
        case primitive
        case data
        case material
        case normal
        case code
        case subCommands
    }
    
    init(_ name: String = "Unnamed", role: Role = .Geometry, action: Action = .Add, primitive: Primitive = .Box, data: SignedData = SignedData([]), material: SignedMaterial = SignedMaterial())
    {
        self.name = name
        self.role = role
        self.action = action
        self.primitive = primitive
        self.data = data
        self.material = material
        
        if self.data.exists("Position") == false {
            self.data.data.insert(SignedDataEntity("Position", float3(0,0,0)), at: 0)
        }
        
        if self.data.exists("Surface Distance") == false {
            self.data.data.append(SignedDataEntity("Surface Distance", Float(0), float2(-0.5, 0.5)))
        }
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        role = try container.decode(Role.self, forKey: .role)
        action = try container.decode(Action.self, forKey: .action)
        primitive = try container.decode(Primitive.self, forKey: .primitive)

        data = try container.decode(SignedData.self, forKey: .data)
        material = try container.decode(SignedMaterial.self, forKey: .material)

        normal = try container.decode(float3.self, forKey: .normal)

        subCommands = try container.decode([SignedCommand].self, forKey: .subCommands)
        code = try container.decode(String.self, forKey: .code)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(action, forKey: .action)
        try container.encode(primitive, forKey: .primitive)
        try container.encode(data, forKey: .data)
        try container.encode(material, forKey: .material)
        try container.encode(normal, forKey: .normal)
        try container.encode(code, forKey: .code)
        try container.encode(subCommands, forKey: .subCommands)
    }
    
    static func ==(lhs: SignedCommand, rhs: SignedCommand) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Creates a copy of itself
    func copy() -> SignedCommand?
    {
        if let data = try? JSONEncoder().encode(self) {
            if let copied = try? JSONDecoder().decode(SignedCommand.self, from: data) {
                copied.id = UUID()
                return copied
            }
        }
        return nil
    }
    
    /// Copies the geometry part of the command
    func copyGeometry(from: SignedCommand) {
        primitive = from.primitive
        
        if let data = try? JSONEncoder().encode(from.data) {
            if let copied = try? JSONDecoder().decode(SignedData.self, from: data) {
                self.data = copied
            }
        }
    }
    
    /// Copies the material part of the command
    func copyMaterial(from: SignedCommand) {
        
        if let data = try? JSONEncoder().encode(from.material) {
            if let copied = try? JSONDecoder().decode(SignedMaterial.self, from: data) {
                self.material = copied
            }
        }
    }
}

