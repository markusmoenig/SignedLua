//
//  GraphBoolNodes.swift
//  Signed
//
//  Created by Markus Moenig on 14/12/20.
//

import MetalKit
import simd

/// BoolMergeNode
final class BoolMergeNode : GraphNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, . SDF, options)
        name = "boolMerge"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.rayDist[context.rayIndex] = min(context.rayDist[0], context.rayDist[1])
        context.toggleRayIndex()

        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Merges the two previous SDFs."
    }
}
