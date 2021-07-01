//
//  SignedShape.swift
//  Signed
//
//  Created by Markus Moenig on 1/7/21.
//

import Foundation

class SignedShape {
    
    var id              = UUID()
    var name            : String
    
    init(_ name: String) {
        self.name = name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
