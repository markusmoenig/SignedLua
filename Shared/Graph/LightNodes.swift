//
//  LightNodes.swift
//  Signed
//
//  Created by Markus Moenig on 15/1/21.
//

import Foundation
import simd

/// Base Class
class GraphLightNode    : GraphNode
{
    enum LightType {
        case Directional, Spherical, Qubic
    }
    
    //var position        : Float3 = Float3(0,0,0)
    
    // out
    
    var surfacePos      = float3(0,0,0)
    var normal          = float3(0,0,0)
    var emission        = float3(0,0,0)

    var lightDir        = float3(0,0,0)

    //var rotation        : Float3 = Float3(0,0,0)
    //var scale           : Float1 = Float1(0)
    
    /*
    func verifyTranslationOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat3Value(options, container: context, error: &error, name: "position", isOptional: true) {
            position = value
        }
        /*
        if let value = extractFloat3Value(options, container: context, error: &error, name: "rotation", isOptional: true) {
            rotation = value
        }
        if let value = extractFloat1Value(options, container: context, error: &error, name: "scale", isOptional: true) {
            scale = value
        }*/
    }*/
}

final class GraphDirectionalLightNode : GraphLightNode {

    var direction : Float3 = Float3(0,0,0)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Light, .None, options)
        name = "lightDirectional"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat3Value(options, container: context, error: &error, name: "direction", isOptional: false) {
            direction = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        lightDir = simd_normalize(float3(5, 10, -10))
        
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Defines an SDF Object. SDF objects contain lists of SDF primitives and booleans and can also contain child objects."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Text1("Object"), "Name", "The name of the object.")
        ]
        return options + GraphDistanceNode.getObjectOptions()
    }
}
