//
//  GraphTexNodes.swift
//  Signed
//
//  Created by Markus Moenig on 24/12/20.
//

import MetalKit
import simd

/// TexColor
final class TexColorNode : GraphNode
{
    var color        : Float3 = Float3(0.5, 0.5, 0.5)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Material, options)
        name = "texColor"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat3Value(options, container: context, error: &error, name: "color", isOptional: true) {
            color = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.outColor.x = color.x
        context.outColor.y = color.y
        context.outColor.z = color.z
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates a texture of a static color."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0.5, 0.5, 0.5), "Color", "The static color of the texture.")
        ]
        return options
    }
}

/// TexChecker
final class TexCheckerNode : GraphNode
{
    var colorA        : Float3 = Float3(0.0, 0.0, 0.0)
    var colorB        : Float3 = Float3(1, 1, 1)
    var size          = Float1(1)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Material, options)
        name = "texChecker"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat3Value(options, container: context, error: &error, name: "colorA", isOptional: true) {
            colorA = value
        }
        if let value = extractFloat3Value(options, container: context, error: &error, name: "colorA", isOptional: true) {
            colorA = value
        }
        if let value = extractFloat1Value(options, container: context, error: &error, name: "size", isOptional: true) {
            size = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        let size : Float = self.size.toSIMD()
        let p = floor(float2(context.hitPosition.x, context.hitPosition.z) / size)
        let c = abs(fmod(p.x + p.y, 2.0))
        
        let rc = simd_mix(colorA.toSIMD(), colorB.toSIMD(), float3(c, c, c))
        context.outColor.x = rc.x
        context.outColor.y = rc.y
        context.outColor.z = rc.z
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates a texture of a static color."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0.5, 0.5, 0.5), "Color", "The static color of the texture.")
        ]
        return options
    }
}

/// TexNoise2DNode
final class TexNoise2DNode : GraphNode
{
    var position         : Float2 = Float2(0.0, 0.0)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Material, options)
        name = "texNoise2D"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat2Value(options, container: context, error: &error, name: "position", isOptional: true) {
            position = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        let n = noise(position.toSIMD())
        
        print(position.toSIMD(), n)
        context.outColor.x = n
        context.outColor.y = n
        context.outColor.z = n
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
        return "Creates a texture of a static color."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0.5, 0.5, 0.5), "Color", "The static color of the texture.")
        ]
        return options
    }
}
