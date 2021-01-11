//
//  GraphAnalyticalNodes.swift
//  Signed
//
//  Created by Markus Moenig on 16/12/20.
//

import Foundation
import simd

/// Analytical Plane
final class GraphAnalyticalPlaneNode : GraphDistanceNode
{
    var normal    : Float3 = Float3(0, 1, 0)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Analytical, options)
        name = "analyticalPlane"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat3Value(options, container: context, error: &error, name: "normal", isOptional: true) {
            normal = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        let groundT : Float = (0.0 - context.camOrigin.y) / context.rayDir.y
        if groundT > 0.0 {
            if groundT < context.analyticalDist {
                context.analyticalDist = groundT
                context.analyticalNormal = float3(0,1,0)
                context.analyticalMaterial = context.activeMaterial
            }
        }
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

