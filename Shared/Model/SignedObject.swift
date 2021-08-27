//
//  SignedObject.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation
import CoreGraphics

/// A name with a piece of code
class SignedObject : Codable, Hashable, Identifiable {
    
    enum Role {
        case main, object, material, module
    }
    
    var id              = UUID()
    var name            : String
    
    var children        : [SignedObject]? = nil

    var code            : Data? = "-- Signed, a Lua based 3D construction language\n".data(using: .utf8)
    
    /// CodeEditor session name
    var session         : String
    
    static var sessionCounter   : Int = 0
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case code
        case children
    }
    
    init(_ name: String = "Unnamed")
    {
        self.name = name
        
        session = "__project_session\(SignedObject.sessionCounter)"
        SignedObject.sessionCounter += 1
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        children = try container.decode([SignedObject]?.self, forKey: .children)
        code = try container.decode(Data?.self, forKey: .code)
        
        session = "__project_session\(SignedObject.sessionCounter)"
        SignedObject.sessionCounter += 1
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(children, forKey: .children)
        try container.encode(code, forKey: .code)
    }
    
    static func ==(lhs: SignedObject, rhs: SignedObject) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Returns the decoded code of the object
    func getCode() -> String {
        if let data = code {
            if let value = String(data: data, encoding: .utf8) {
                return value
            }
        }
        return ""
    }
}
