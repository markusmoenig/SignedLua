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
    
    var id              = UUID()
    var name            : String
    
    var role            : Role

    var code            : String = ""
    
    var graphPosition   = CGPoint(x: 100, y: 100)
    
    var subCommands     : [SignedCommand] = []
    
    // To identify the editor session
    var scriptContext   = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case code
        case subCommands
        case graphPosition
    }
    
    init(_ name: String = "Unnamed", role: Role = .Geometry, graphPosition: CGPoint = CGPoint(x: 100, y: 100), code: String = "")
    {
        self.name = name
        self.role = role
        self.code = code
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(Role.self, forKey: .role)
        subCommands = try container.decode([SignedCommand].self, forKey: .subCommands)
        code = try container.decode(String.self, forKey: .code)
        graphPosition = try container.decode(CGPoint.self, forKey: .graphPosition)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(code, forKey: .code)
        try container.encode(graphPosition, forKey: .graphPosition)
    }
    
    static func ==(lhs: SignedCommand, rhs: SignedCommand) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

