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
        case Sun, Spherical, Rect
    }
    
    //var position        : Float3 = Float3(0,0,0)
    
    // out
    
    var lightType       : LightType = .Spherical
    
    var surfacePos      = float3(0,0,0)
    var normal          = float3(0,0,0)
    var emission        = float3(0,0,0)
    
    var area            : Float = 1
    
    var direction       = float3(0,0,0)

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

final class GraphSunLightNode : GraphLightNode {

    var directionIn: Float3 = Float3(0,0,0)
    var emissionIn  : Float3 = Float3(0,0,0)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Sun, .None, options)
        name = "Sun"
        leaves = []
        lightType = .Sun
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat3Value(options, container: context, error: &error, name: "direction", isOptional: false) {
            directionIn = value
        }
        if let value = extractFloat3Value(options, container: context, error: &error, name: "emission", isOptional: true) {
            emissionIn = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        direction = simd_normalize(directionIn.toSIMD())
        emission = emissionIn.toSIMD()// * float(numOfLights)

        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        let code = ""
        
        context.addDataVariable(directionIn)
        context.addDataVariable(emissionIn)
             
        var data1 = float4()
        var data2 = float4()
        
        data1.x = 0
        
        let direction = normalize(directionIn.toSIMD())
        data1.y = direction.x
        data1.z = direction.y
        data1.w = direction.z
        
        //print(direction.x, direction.y, direction.z)
        let emission = emissionIn.toSIMD()

        data2.x = emission.x
        data2.y = emission.y
        data2.z = emission.z
        
        context.lightsData[0].x += 1
        context.lightsData.append(data1)
        context.lightsData.append(data2)
        
        return code
    }
    
    override func getHelp() -> String
    {
        return "Defines an SDF Object. SDF objects contain lists of SDF primitives and booleans and can also contain child objects."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3("direction"), "Direction", "The direction of the sun light.")
        ]
        return options + GraphTransformationNode.getTransformationOptions()
    }
}
