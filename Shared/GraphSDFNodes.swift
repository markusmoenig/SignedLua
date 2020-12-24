//
//  GraphSDFNodes.swift
//  Signed
//
//  Created by Markus Moenig on 14/12/20.
//

import MetalKit
import simd

/// SDFSphereNode
final class SDFSphereNode : DistanceNode
{
    var radius        : Float1 = Float1(1)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .SDF, options)
        name = "sdfSphere"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat1Value(options, container: context, error: &error, name: "radius", isOptional: true) {
            radius = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position += position.toSIMD()
        
        //print("in sphere", radius.toSIMD())
        context.rayDist[context.rayIndex] = simd_length(context.rayPos - context.position) - radius.toSIMD()// - noise(float2(context.position.x, context.position.y) * 100.0)
        context.hitMaterial[context.rayIndex] = context.activeMaterial
        context.toggleRayIndex()
        
        context.position -= position.toSIMD()
        return .Success
    }
    
    // https://www.shadertoy.com/view/4dS3Wd
    @inlinable func hash(_ p: float2) -> Float
    {
        var p3 = simd_fract(float3(p.x, p.y, p.x) * 0.13)
        p3 += simd_dot(p3, float3(p3.y, p3.z, p3.x) + 3.333)
        return simd_fract((p3.x + p3.y) * p3.z)
    }
    
    @inlinable func noise(_ x: float2) -> Float
    {
        let i = floor(x)
        let f = simd_fract(x)

        let a : Float = hash(i)
        let b : Float = hash(i + float2(1.0, 0.0))
        let c : Float = hash(i + float2(0.0, 1.0))
        let d : Float = hash(i + float2(1.0, 1.0))

        let u : float2 = f * f * (3.0 - 2.0 * f)
        return simd_mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y
    }
    
    override func getHelp() -> String
    {
        return "Creates a sphere of a given radius."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(1), "Radius", "The radius of the sphere.")
        ]
        return options + DistanceNode.getSDFOptions()
    }
}

/// SDFBoxNode
final class SDFBoxNode : DistanceNode
{
    var size    : Float3 = Float3(1)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .SDF, options)
        name = "sdfBox"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat3Value(options, container: context, error: &error, name: "size", isOptional: true) {
            size = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position += position.toSIMD()

        let q : float3 = simd_abs(context.rayPos - context.position) - size.toSIMD()
        context.rayDist[context.rayIndex] = simd_length(max(q,0.0)) + simd_min(simd_max(q.x,simd_max(q.y,q.z)),0.0);
        context.hitMaterial[context.rayIndex] = context.activeMaterial
        context.toggleRayIndex()

        context.position -= position.toSIMD()

        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates a perfect cube of a given size."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Size", "The size of the cube.")
        ]
        return options + DistanceNode.getSDFOptions()
    }
}

/// SDFBoxNode
final class SDFPlaneNode : DistanceNode
{
    var normal    : Float3 = Float3(0, 1, 0)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .SDF, options)
        name = "sdfPlane"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat3Value(options, container: context, error: &error, name: "normal", isOptional: true) {
            normal = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position += position.toSIMD()

        context.rayDist[context.rayIndex] = simd_dot(context.rayPos, normal.toSIMD())
        context.toggleRayIndex()

        context.position -= position.toSIMD()

        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates a plane."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0,1,0), "Normal", "The normal defines the orientation of the plane.")
        ]
        return options + DistanceNode.getSDFOptions()
    }
}

