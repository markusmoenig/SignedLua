//
//  SignedNode.swift
//  SignedNode
//
//  Created by Markus Moenig on 12/8/21.
//

import Foundation

class SignedContext {
    let model           : Model

    /// One meter is 0.1 inside the texture by default
    let meterScale      : Float = 10
    
    init(model: Model) {
        self.model = model
    }
    
    /// Adds the given cmd to the modeler pipeline
    func addToPipeline(cmd: SignedCommand) {
        model.modeler?.pipeline.append(cmd)
    }
    
    /// Converts meter to the internal texture representation
    func convertMeter(_ m: Float) -> Float {
        return m / meterScale
    }
    
    /// Converts meter to the internal texture representation
    func convertMeter(_ m: float3) -> float3 {
        return m / meterScale
    }
}

class SignedNode : Hashable, Identifiable {
    
    enum Role {
        case Building, Object, Wall, Floor, Build, Material
    }
    
    var name            : String = "Unnamed"
    var id              = UUID()
    var role            : Role = .Building
    
    var line            : Int32 = 0
    var endLine         : Int32 = 0

    var argumentsText   = ""
    var arguments       : [SignedProperty] = []
    var properties      : [String: SignedProperty] = [:]
    
    var parent          : SignedNode? = nil
    var children        : [SignedNode]? = []
    
    init(role: Role) {
        self.role = role
    }
    
    static func ==(lhs: SignedNode, rhs: SignedNode) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func verifyArguments(str: String, arguments: [SignedProperty], error: CodeError) {
        argumentsText = str
        self.arguments = arguments
        if let first = arguments.first, first.role == .Text {
            name = first.text
        }
    }
    
    func execute(context: SignedContext) {
        for c in children! {
            c.execute(context: context)
        }
    }
}

class SignedProperty {
    
    enum Role {
        case Unknown, Text, Directive, Value1D, Value2D, Value3D
    }
    
    var name            : String = "Unnamed"
    var role            : Role = .Unknown
    
    var data            = float4()
    var text            = ""
    
    init(role: Role = .Unknown) {
        self.role = role
    }
}
