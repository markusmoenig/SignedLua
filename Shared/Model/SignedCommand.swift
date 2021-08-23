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
        case GeometryAndMaterial, MaterialOnly
    }
    
    enum Action: Int32, Codable {
        case None, Add, Subtract
    }
    
    enum Primitive: Int32, Codable {
        case Heightfield, Sphere, Box
    }
    
    var id              = UUID()
    var name            : String
    
    var role            : Role
    var action          : Action
    var primitive       : Primitive
    
    var dataGroups      : SignedDataGroups
    var material        : SignedMaterial

    var normal          : float3 = float3()

    var code            : String = ""
                
    // To identify the editor session
    var scriptContext   = ""
    
    /// The geometryId for this cmd
    var geometryId      : Int = 0
    
    var icon            : CGImage? = nil
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case action
        case primitive
        case dataGroups
        case material
        case normal
        case code
        case geometryId
    }
    
    init(_ name: String = "Unnamed", role: Role = .GeometryAndMaterial, action: Action = .Add, primitive: Primitive = .Box, data: [String: SignedData] = [:], material: SignedMaterial = SignedMaterial())
    {
        self.name = name
        self.role = role
        self.action = action
        self.primitive = primitive
        self.material = material

        self.dataGroups = SignedDataGroups(data)

        initDataGroups()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        role = try container.decode(Role.self, forKey: .role)
        action = try container.decode(Action.self, forKey: .action)
        primitive = try container.decode(Primitive.self, forKey: .primitive)

        dataGroups = try container.decode(SignedDataGroups.self, forKey: .dataGroups)
        material = try container.decode(SignedMaterial.self, forKey: .material)

        normal = try container.decode(float3.self, forKey: .normal)

        code = try container.decode(String.self, forKey: .code)
        geometryId = try container.decode(Int.self, forKey: .geometryId)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(action, forKey: .action)
        try container.encode(primitive, forKey: .primitive)
        try container.encode(dataGroups, forKey: .dataGroups)
        try container.encode(material, forKey: .material)
        try container.encode(normal, forKey: .normal)
        try container.encode(code, forKey: .code)
        try container.encode(geometryId, forKey: .geometryId)
    }
    
    static func ==(lhs: SignedCommand, rhs: SignedCommand) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Initializes the data groups with default values, or, when already exists, make sure all options are present
    func initDataGroups(fromConstructor: Bool = false) {
            
        addDataGroup(name: "Transform", entities: [
            SignedDataEntity("Position", float3(0,0,0), float2(-0.5, 0.5)),
            SignedDataEntity("Rotation", float3(0,0,0), float2(0, 360), .Slider),
        ])
        
        addDataGroup(name: "Modifier", entities: [
            SignedDataEntity("Noise", Float(0), float2(0, 2)),
            SignedDataEntity("Surface Distance", Float(0), float2(-0.5, 0.5)),
        ])
        
        addDataGroup(name: "Boolean", entities: [
            SignedDataEntity("Smoothing", Float(0.0), float2(0, 1))
        ])
        
        addDataGroup(name: "Repetition", entities: [
            SignedDataEntity("Distance", Float(0.1), float2(0, 5)),
            SignedDataEntity("Upper Limit", float3(0,0,0), float2(-1000, 1000)),
            SignedDataEntity("Lower Limit", float3(0,0,0), float2(-1000, 1000)),
        ])
        
        addDataGroup(name: "Library", entities: [
            SignedDataEntity("Name", "Object", .TextField, .GeometryLibrary)
        ])
    }
    
    /// Creates or adds the given entities to the new or existing group. This way we can dynamically add new options to existing projects.
    func addDataGroup(name: String, entities: [SignedDataEntity]) {
        let group = dataGroups.getGroup(name)
        if let group = group {
            // If group exists, make sure all entities are present

            for e in entities {
                if group.exists(e.key) == false {
                    group.data.append(e)
                }
            }
        } else {
            // If group does not exist add it
            dataGroups.addGroup(name, SignedData(entities))
        }
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
        
        if let data = try? JSONEncoder().encode(from.dataGroups) {
            if let copied = try? JSONDecoder().decode(SignedDataGroups.self, from: data) {
                self.dataGroups = copied
            }
        }
    }
    
    /// Copies the material part of the command
    func copyMaterial(from: SignedMaterial) {
        
        if let data = try? JSONEncoder().encode(from) {
            if let copied = try? JSONDecoder().decode(SignedMaterial.self, from: data) {
                self.material = copied
            }
        }
    }
    
    /// Returns all data groups
    func allDataGroups() -> [SignedData]
    {
        var groups = dataGroups.flat()
        groups.append(material.data)
        return groups
    }
}

