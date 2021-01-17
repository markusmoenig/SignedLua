//
//  GraphSDFNodes.swift
//  Signed
//
//  Created by Markus Moenig on 14/12/20.
//

import MetalKit
import simd

/// SDFSphereNode
final class GraphSDFSphereNode : GraphDistanceNode
{
    var radius        : Float1 = Float1(1)

    init(_ options: [String:Any] = [:])
    {
        super.init(.SDF, .SDF, options)
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
        context.rayDist[context.rayIndex] = length(context.rayPosition.toSIMD() - context.position) - radius.toSIMD() - context.displacement.toSIMD()
        context.hitMaterial[context.rayIndex] = context.activeMaterial
        context.toggleRayIndex()
        
        context.position -= position.toSIMD()
        return .Success
    }
    
    @inlinable public override func sampleLight(context: GraphContext) -> GraphLightInfo?
    {
        let light = GraphLightInfo(.Spherical)
        
        let r2D = context.rand2()

        let r = radius.toSIMD()
        light.surfacePos = position.toSIMD() + UniformSampleSphere(r2D.x, r2D.y) * r
        light.normal = normalize(light.surfacePos - position.toSIMD())
        
        if let material = materialNode {
            material.execute(context: context)
        }
        if let emission = context.variables["emission"]! as? Float3 {
            light.emission = emission.toSIMD()// * float(numOfLights)
        }
        
        light.area = 4.0 * Float.pi * r * r
        
        return light
    }
    
    //-----------------------------------------------------------------------
    func UniformSampleSphere(_ u1: Float,_ u2: Float) -> float3
    //-----------------------------------------------------------------------
    {
        let z = 1.0 - 2.0 * u1
        let r = sqrt(max(0.0, 1.0 - z * z))
        let phi = 2.0 * Float.pi * u2
        let x = r * cos(phi)
        let y = r * sin(phi)

        return float3(x, y, z)
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
        return options + GraphDistanceNode.getSDFOptions()
    }
}

/// SDFBoxNode
final class GraphSDFBoxNode : GraphDistanceNode
{
    var size    : Float3 = Float3(1)

    init(_ options: [String:Any] = [:])
    {
        super.init(.SDF, .SDF, options)
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

        let q : float3 = abs(context.rayPosition.toSIMD() - context.position) - size.toSIMD() - context.displacement.toSIMD()
        context.rayDist[context.rayIndex] = length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
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
        return options + GraphDistanceNode.getSDFOptions()
    }
}

/// SDFPlaneNode
final class GraphSDFPlaneNode : GraphDistanceNode
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

        context.rayDist[context.rayIndex] = dot(context.rayPosition.toSIMD(), normal.toSIMD())
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
        return options + GraphDistanceNode.getSDFOptions()
    }
}

