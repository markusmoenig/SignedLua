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
