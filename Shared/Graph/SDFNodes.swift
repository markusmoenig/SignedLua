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
        context.rayDist[context.rayIndex] = simd_length(context.rayPosition.toSIMD() - context.position) - radius.toSIMD() - context.displacement.toSIMD()
        context.hitMaterial[context.rayIndex] = context.activeMaterial
        context.toggleRayIndex()
        
        context.position -= position.toSIMD()
        return .Success
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

        let q : float3 = simd_abs(context.rayPosition.toSIMD() - context.position) - size.toSIMD() - context.displacement.toSIMD()
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

        context.rayDist[context.rayIndex] = simd_dot(context.rayPosition.toSIMD(), normal.toSIMD())
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

