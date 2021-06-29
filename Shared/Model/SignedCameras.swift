//
//  SignedCamera.swift
//  Signed
//
//  Created by Markus Moenig on 29/6/21.
//

import Foundation

/// This object is the base for everything, if its an geometry object or a material
class SignedPinholeCamera : Codable, Hashable {
    
    var id              = UUID()
    var name            : String
            
    var position        = float3(0, 1, 3)
    
    var orbit           = float2(0, 0)
    var zoom            : Float = 2

    var lastDelta       = float2(0, 0)
    var lastZoomDelta   = Float(0)

    // To identify the editor session
    var scriptContext   = ""
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case position
    }
    
    init(_ name: String = "Pinhole")
    {
        self.name = name
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        position = try container.decode(float3.self, forKey: .position)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(position, forKey: .position)
    }
    
    static func ==(lhs: SignedPinholeCamera, rhs: SignedPinholeCamera) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func addOrbitDelta(_ delta: float2)
    {
        orbit += delta - lastDelta
        lastDelta = delta
    }
    
    func addZoomDelta(_ delta: Float)
    {
        zoom += delta - lastZoomDelta
        lastZoomDelta = delta
    }
    
    func getPosition() -> float3 {        
        
        func rot(_ a: Float) -> float2x2 {
            return float2x2(float2(cos(a), sin(a)), float2(-sin(a),cos(a)))
        }

        var pos = float3()
        
        let ry = orbit.x.truncatingRemainder(dividingBy: 360).degreesToRadians
        let rx = orbit.y.truncatingRemainder(dividingBy: 360).degreesToRadians
        
        pos.y = zoom * cos(rx) - zoom * sin(rx)
        pos.z = zoom * sin(rx) + zoom * cos(rx)
        
        pos.x = zoom * cos(ry) - zoom * sin(ry)
        pos.z = pos.z * sin(ry) + pos.z * cos(ry)
        
        return pos
    }
}

