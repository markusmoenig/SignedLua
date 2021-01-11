//
//  CameraHelper.swift
//  Signed
//
//  Created by Markus Moenig on 5/1/21.
//

import Foundation

class CameraHelper
{
    var eye             : float3
    var center          : float3
    var fov             : Float
    
    let up              = float3(0, 1, 0)

    let cameraNode      : GraphBaseCameraNode
    
    init(_ node         : GraphBaseCameraNode)
    {
        cameraNode = node
        
        eye = node.origin.toSIMD()
        center = node.lookAt.toSIMD()
        fov = node.fov.toSIMD()
    }
    
    func calculateDirXY() -> (SIMD3<Float>, SIMD3<Float>)
    {
        let c_eye = center - eye

        let dirX = up
        let dirY = simd_normalize(simd_cross(up, c_eye))
        
        return (dirX, dirY)
    }
    
    func rotateToAPoint(p: SIMD3<Float>, o: SIMD3<Float>, v: SIMD3<Float>, alpha: Float) -> SIMD3<Float>
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

    // Zooms the camera in / out
    func zoom(dx: Float, dy: Float)
    {
        eye -= center
        eye *= dy + 1
        eye += center
        
        cameraNode.origin.fromSIMD(eye)
    }
    
    // Zooms the camera in / out
    func zoomRelative(dx: Float, dy: Float, start: SIMD3<Float>)
    {
        eye -= center
        eye = start / dy
        eye += center
        
        cameraNode.origin.fromSIMD(eye)
    }
    
    // Moves the camera
    func move(dx: Float, dy: Float, aspect: Float)
    {
        let dir = calculateDirXY()
        let e = eye - center
        let t : Float = tan(fov/2 * Float.pi / 180)
        let len = 2 * length(e) * t
        
        let add : SIMD3<Float> = dir.1 * (dx * len * aspect) + dir.0 * (dy * len)
        
        if add.x.isNaN == false && add.y.isNaN == false && add.z.isNaN == false {
            center += add
            eye += add
            
            cameraNode.origin.fromSIMD(eye)
            cameraNode.lookAt.fromSIMD(center)
        }
    }
    
    // Pans the camera
    func pan(dx: Float, dy: Float, aspect: Float)
    {
        let dir = calculateDirXY()
        let e = eye - center
        let t : Float = tan(fov/2 * Float.pi / 180)
        let len = 2 * length(e) * t
        
        let add : SIMD3<Float> = dir.1 * (dx * len * aspect) + dir.0 * (dy * len)
        
        center += add
        eye += add
        
        if add.x.isNaN == false && add.y.isNaN == false && add.z.isNaN == false {
            cameraNode.origin.fromSIMD(eye)
        }
    }
    
    // Rotates the camera
    func rotate(dx: Float, dy: Float)
    {
        let dir = calculateDirXY()

        eye = rotateToAPoint(p: eye, o: center, v: dir.0, alpha: -dx * Float.pi)
        eye = rotateToAPoint(p: eye, o: center, v: dir.1, alpha: dy * Float.pi)
        
        cameraNode.origin.fromSIMD(eye)
    }
}
