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
    
    enum Role: String, Codable {
        case Geometry, Brush
    }
    
    enum Action: String, Codable {
        case Add, Subtract
    }
    
    enum Primitive: String, Codable {
        case Sphere, Box
    }
    
    var id              = UUID()
    var name            : String
    
    var role            : Role
    var action          : Action
    var primitive       : Primitive

    var code            : String = ""
        
    var subCommands     : [SignedCommand] = []
    
    // To identify the editor session
    var scriptContext   = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case action
        case primitive
        case code
        case subCommands
    }
    
    init(_ name: String = "Unnamed", role: Role = .Geometry, action: Action = .Add, primitive: Primitive = .Box)
    {
        self.name = name
        self.role = role
        self.action = action
        self.primitive = primitive
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        role = try container.decode(Role.self, forKey: .role)
        action = try container.decode(Action.self, forKey: .action)
        primitive = try container.decode(Primitive.self, forKey: .primitive)

        subCommands = try container.decode([SignedCommand].self, forKey: .subCommands)
        code = try container.decode(String.self, forKey: .code)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(code, forKey: .code)
    }
    
    static func ==(lhs: SignedCommand, rhs: SignedCommand) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

