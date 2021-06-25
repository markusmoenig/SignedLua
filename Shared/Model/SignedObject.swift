//
//  SignedObject.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation

class SignedObject : Hashable {
    
    var id              = UUID()
    var name            = "Halloechen"
    
    var graphPosition   = CGPoint(x: 100, y: 100)
    
    static func ==(lhs: SignedObject, rhs: SignedObject) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
