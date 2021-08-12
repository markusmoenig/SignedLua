//
//  SignedNode.swift
//  SignedNode
//
//  Created by Markus Moenig on 12/8/21.
//

import Foundation

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
}
