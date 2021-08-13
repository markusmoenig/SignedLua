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

class SignedNode {
    
    enum Role {
        case Building, Object, Wall, Floor, Material
    }
    
    var name            : String = ""
    var role            : Role = .Building
    
    var parameters      : [String: Any] = [:]
    
    var parent          : SignedNode? = nil
    var children        : [SignedNode] = []
    
    init(role: Role) {
        self.role = role
    }
    
    func execute(context: SignedContext) {
        for c in children {
            c.execute(context: context)
        }
    }
}
