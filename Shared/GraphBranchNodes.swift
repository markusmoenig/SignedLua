//
//  GraphBranchNodes.swift
//  Signed
//
//  Created by Markus Moenig on 13/12/20.
//

import Foundation
import simd

class SDFSphereNode : GraphNode
{
    var radius      : Float1 = Float1(1)

    override init(_ options: [String:Any] = [:])
    {
        super.init(options)
        name = "sdfSphere"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat1Value(options, context: context, error: &error, name: "radius") {
            radius = value
        }
    }
    
    @discardableResult override func execute(game: Game, context: GraphContext) -> Result
    {
        context.dist = simd_length(context.pos) - radius.x

        for leave in leaves {
            leave.execute(game: game, context: context)
        }
        return .Success
    }
}
