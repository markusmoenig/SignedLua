//
//  SignedCamera.swift
//  Signed
//
//  Created by Markus Moenig on 29/6/21.
//

import Foundation

/// Pinhole camera
class SignedPinholeCamera : Codable, Hashable {
    
    var id              = UUID()
    var name            : String
    
    var data            : SignedData
            
    var position        = float3(0, 0, -3)
    var lookAt          = float3(0, 0, 0)

    var fov             : Float = 80
    let up              = float3(0, 1, 0)

    var lastDelta       = float2(0, 0)
    var lastZoomDelta   = Float(0)
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case data
    }
    
    init(_ name: String = "Pinhole")
    {
        self.name = name
        data = SignedData([])
        
        data.set("Position", float3(0,-0.3,-0.8), float2(-5, 5))
        data.set("Look At", float3(0,-0.3,0), float2(-5, 5))
        data.set("Fov", Float(80), float2(0, 160))
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        data = try container.decode(SignedData.self, forKey: .data)
        
        data.set("Position", float3(0,-0.3,-0.8), float2(-5, 5))
        data.set("Look At", float3(0,-0.3,0.0), float2(-5, 5))
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(data, forKey: .data)
    }
    
    static func ==(lhs: SignedPinholeCamera, rhs: SignedPinholeCamera) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Zooms the camera
    func zoomDelta(_ delta: Float)
    {
        let d = delta - lastZoomDelta
        
        var position = getPosition()
        var lookAt = getLookAt()

        position -= lookAt
        position *= d + 1
        position += lookAt
        
        data.set("Position", position)
        
        lookAt.y = position.y
        data.set("Look At", lookAt)
        
        lastZoomDelta = delta
    }
    
    // Rotates the camera
    func rotateDelta(_ delta: float2)
    {
        let d = delta - lastDelta
        let dir = calculateDirXY()
        
        var position = getPosition()
        var lookAt = getLookAt()

        position = rotateToAPoint(p: position, o: lookAt, v: dir.0, alpha: -d.x * Float.pi)
        position = rotateToAPoint(p: position, o: lookAt, v: dir.1, alpha: d.y * Float.pi)

        data.set("Position", position)
        
        lookAt.y = position.y
        data.set("Look At", lookAt)

        lastDelta = delta
    }
    
    // Moves the camera
    func moveDelta(_ delta: float2, aspect: Float)
    {
        let d = delta - lastDelta
        
        var position = getPosition()
        var lookAt = getLookAt()
        
        let dir = calculateDirXY()
        let e = position - lookAt
        let t : Float = tan(fov / 2 * Float.pi / 180)
        let len = 2 * length(e) * t
        
        let add : SIMD3<Float> = dir.1 * (d.x * len * aspect) + dir.0 * (d.y * len)
                
        if add.x.isNaN == false && add.y.isNaN == false && add.z.isNaN == false {
            position += add
            lookAt += add
            
            data.set("Position", position)
            data.set("Look At", lookAt)
        }
        
        lastDelta = delta
    }
    
    func getPosition() -> float3 {        
        return data.getFloat3("Position")
    }
    
    func getLookAt() -> float3 {
        return data.getFloat3("Look At")
    }
    
    func getFov() -> Float {
        return data.getFloat("Fov", 80)
    }
    
    func calculateDirXY() -> (float3, float3)
    {
        let c_eye = lookAt - position

        let dirX = up
        let dirY = simd_normalize(simd_cross(up, c_eye))
        
        return (dirX, dirY)
    }
    
    func rotateToAPoint(p: float3, o: float3, v: float3, alpha: Float) -> float3
    {
        let c : Float = cos(alpha);
        let s : Float = sin(alpha);
        let C : Float = 1.0 - c;
        var m = matrix_identity_float4x4
        
        m[0, 0] = v.x * v.x * C + c
        m[0, 1] = v.y * v.x * C + v.z * s
        m[0, 2] = v.z * v.x * C - v.y * s
        m[0, 3] = 0

        m[1, 0] = v.x * v.y * C - v.z * s
        m[1, 1] = v.y * v.y * C + c
        m[1, 2] = v.z * v.y * C + v.x * s
        m[1, 3] = 0
        
        m[2, 0] = v.x * v.z * C + v.y * s
        m[2, 1] = v.y * v.z * C - v.x * s
        m[2, 2] = v.z * v.z * C + c
        m[2, 3] = 0
        
        m[3, 0] = 0
        m[3, 1] = 0
        m[3, 2] = 0
        m[3, 3] = 1
        
        let P = p - o
        var out = o
        
        out.x += P.x * m[0, 0] + P.y * m[1, 0] + P.z * m[2, 0] + m[3, 0]
        out.y += P.x * m[0, 1] + P.y * m[1, 1] + P.z * m[2, 1] + m[3, 1]
        out.z += P.x * m[0, 2] + P.y * m[1, 2] + P.z * m[2, 2] + m[3, 2]
        
        return out
    }
}

