//
//  BranchNodes2D.swift
//  Signed
//
//  Created by Markus Moenig on 12/1/21.
//

import Foundation

/// Distance Base Node 2D
class GraphTransformationNode2D : GraphNode
{
    var position        : Float2 = Float2(0,0)
    var rotation        : Float2 = Float2(0,0)
    var scale           : Float1 = Float1(0)
    
    func verifyTranslationOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat2Value(options, container: context, error: &error, name: "position", isOptional: true) {
            position = value
        }
        if let value = extractFloat2Value(options, container: context, error: &error, name: "rotation", isOptional: true) {
            rotation = value
        }
        if let value = extractFloat1Value(options, container: context, error: &error, name: "scale", isOptional: true) {
            scale = value
        }
    }
    
    static func getTransformationOptions() -> [GraphOption]
    {
        return [
            GraphOption(Float3(0,0,0), "Position", "The position of the object. If this is a child object the position is relative to it's parent.")
        ]
    }
}

/// SDFObject2D
final class GraphSDFObject2D : GraphTransformationNode2D
{
    var positionStore : Float2!
    
    var materialName  : String? = nil

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .SDF2D, options)
        name = "sdfObject2D"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let name = options["name"] as? String {
            self.givenName = name.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        } else {
            self.givenName = "SDF Object"
        }
        if let materialName = options["materialname"] as? String {
            self.materialName = materialName.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position2D += position.toSIMD()
        
        if let materialName = materialName {
            context.activeMaterial = context.getMaterial(materialName)
        } else {
            context.activeMaterial = nil
        }
        
        for leave in leaves {
            leave.execute(context: context)
        }

        context.position2D -= position.toSIMD()
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Defines an 2D SDF Object. SDF objects contain lists of SDF primitives and booleans and can also contain child objects."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Text1("Object"), "Name", "The name of the object.")
        ]
        return options + GraphTransformationNode2D.getTransformationOptions()
    }
}
