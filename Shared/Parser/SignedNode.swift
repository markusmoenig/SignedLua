//
//  SignedNode.swift
//  SignedNode
//
//  Created by Markus Moenig on 12/8/21.
//

import Foundation

class SignedContext {
    let model           : Model
    
    init(model: Model) {
        self.model = model
    }
    
    /// Adds the given cmd to the modeler pipeline
    func addToPipeline(cmd: SignedCommand) {
        model.modeler?.pipeline.append(cmd)
    }
}

class SignedNode {
    
    enum Role {
        case Building, Object, Area, Floor, Material
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
