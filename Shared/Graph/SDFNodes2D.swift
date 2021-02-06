//
//  SDFNodes2D.swift
//  Denrim
//
//  Created by Markus Moenig on 12/1/21.
//

import Foundation
import simd

/// SDFSphereNode2D
final class GraphSDFCircleNode2D : GraphTransformationNode2D
{
    var radius        : Float1 = Float1(1)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .SDF2D, options)
        name = "sdfCircle2D"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat1Value(options, container: context, error: &error, name: "radius", isOptional: true) {
            radius = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position2D += position.toSIMD()

        context.position2D -= position.toSIMD()
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates a circle of a given radius."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(1), "Radius", "The radius of the circle.")
        ]
        return options + GraphTransformationNode2D.getTransformationOptions()
    }
}
