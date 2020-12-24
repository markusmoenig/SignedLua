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
        if let value = extractFloat3Value(options, container: context, error: &error, name: "color", isOptional: false) {
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
