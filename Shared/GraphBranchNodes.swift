//
//  GraphBranchNodes.swift
//  Signed
//
//  Created by Markus Moenig on 13/12/20.
//

import Foundation

/// SDF Base Node
class SDFNode         : GraphNode
{
    var position      : Float3 = Float3(0,0,0)
    var rotation      : Float3 = Float3(0,0,0)
    var scale         : Float1 = Float1(0)
    
    func verifyTranslationOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat3Value(options, context: context, error: &error, name: "position", isOptional: true) {
            position = value
        }
        if let value = extractFloat3Value(options, context: context, error: &error, name: "rotation", isOptional: true) {
            rotation = value
        }
        if let value = extractFloat1Value(options, context: context, error: &error, name: "scale", isOptional: true) {
            scale = value
        }
    }
}

/// SDFObject
final class SDFObject : SDFNode
{
    var positionStore : Float3!

    override init(_ options: [String:Any] = [:])
    {
        super.init(options)
        name = "sdfObject"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position += position.toSIMD()
        
        for leave in leaves {
            leave.execute(context: context)
        }
        context.position -= position.toSIMD()
        return .Success
    }
}
