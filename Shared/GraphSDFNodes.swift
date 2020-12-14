//
//  GraphSDFNodes.swift
//  Signed
//
//  Created by Markus Moenig on 14/12/20.
//

import MetalKit
import simd

/// SDFSphereNode
final class SDFSphereNode : SDFNode
{
    var radius        : Float1 = Float1(1)

    override init(_ options: [String:Any] = [:])
    {
        super.init(options)
        name = "sdfSphere"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat1Value(options, context: context, error: &error, name: "radius", isOptional: true) {
            radius = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position += position.toSIMD()
        
        context.rayDist[context.rayIndex] = simd_length(context.rayPos - context.position) - radius.x
        context.toggleRayIndex()
        
        context.position -= position.toSIMD()
        return .Success
    }
}

/// SDFBoxNode
final class SDFBoxNode : SDFNode
{
    var size    : Float3 = Float3(1)

    override init(_ options: [String:Any] = [:])
    {
        super.init(options)
        name = "sdfBox"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat3Value(options, context: context, error: &error, name: "size", isOptional: true) {
            size = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position += position.toSIMD()

        let q : float3 = abs(context.rayPos - context.position) - size.toSIMD()
        context.rayDist[context.rayIndex] = simd_length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
        context.toggleRayIndex()

        context.position -= position.toSIMD()

        return .Success
    }
}

