//
//  GraphSDFNodes.swift
//  Signed
//
//  Created by Markus Moenig on 14/12/20.
//

import MetalKit
import simd

/// SDFSphereNode
final class GraphSDFSphereNode : GraphTransformationNode
{
    var radius        : Float1 = Float1(1)

    init(_ options: [String:Any] = [:])
    {
        super.init(.SDF, .SDF, options)
        name = "sdfSphere"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat1Value(options, container: context, error: &error, name: "radius", isOptional: true) {
            radius = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        checkIn(context: context)
        
        if let index = radius.dataIndex, index < context.data.count {
            context.data[index] = radius.toSIMD4()
        }
        
        checkOut(context: context)
        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> [String: String]
    {
        var codeMap : [String:String] = [:]
        
        context.addDataVariable(radius)
                
        codeMap["map"] =
        """

            {
                \(generateMetalTransformCode(context: context))

                newDistance = float4(length(transformedPosition) - dataIn.data[\(radius.dataIndex!)].x, 0, -1, \(context.getMaterialIndex()));
            }

        """
        
        context.checkForPossibleLight(atPositionIndex: position.dataIndex!, material: materialNode, radius: radius.toSIMD())

                
        return codeMap
    }
    
    @inlinable public override func sampleLight(context: GraphContext) -> GraphLightInfo?
    {
        let lightInfo = GraphLightInfo(.Spherical)
        
        let r = radius.toSIMD()
        
        if context.renderQuality == .Normal {
            let r2D = context.rand2()
            lightInfo.surfacePos = position.toSIMD() + UniformSampleSphere(r2D.x, r2D.y) * r
            lightInfo.normal = normalize(lightInfo.surfacePos - position.toSIMD())
        }

        if let material = materialNode {
            material.execute(context: context)
        }
        if let emission = context.variables["emission"]! as? Float3 {
            lightInfo.emission = emission.toSIMD()// * float(numOfLights)
        }
        
        lightInfo.area = 4.0 * Float.pi * r * r
        
        lightInfo.position = position.toSIMD()
        lightInfo.radius = radius.toSIMD()
        
        return lightInfo
    }
    
    //-----------------------------------------------------------------------
    func UniformSampleSphere(_ u1: Float,_ u2: Float) -> float3
    //-----------------------------------------------------------------------
    {
        let z = 1.0 - 2.0 * u1
        let r = sqrt(max(0.0, 1.0 - z * z))
        let phi = 2.0 * Float.pi * u2
        let x = r * cos(phi)
        let y = r * sin(phi)

        return float3(x, y, z)
    }
    
    override func getHelp() -> String
    {
        return "Creates a sphere of a given radius."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(1), "Radius", "The radius of the sphere.")
        ]
        return options + GraphTransformationNode.getTransformationOptions()
    }
}

/// SDFBoxNode
final class GraphSDFBoxNode : GraphTransformationNode
{
    var size    : Float3 = Float3(1)

    init(_ options: [String:Any] = [:])
    {
        super.init(.SDF, .SDF, options)
        name = "sdfBox"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat3Value(options, container: context, error: &error, name: "size", isOptional: true) {
            size = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        checkIn(context: context)
        
        if let index = size.dataIndex, index < context.data.count {
            context.data[index] = size.toSIMD4()
        }
        
        checkOut(context: context)
        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> [String: String]
    {
        var codeMap : [String:String] = [:]
        
        context.addDataVariable(size)

        codeMap["map"] =
        """

            {
                \(generateMetalTransformCode(context: context))

                float3 q = abs(transformedPosition) - dataIn.data[\(size.dataIndex!)].xyz;
                newDistance = float4(length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0), 0, -1, \(context.getMaterialIndex()));
            }

        """
                
        return codeMap
    }
    
    @inlinable public override func sampleLight(context: GraphContext) -> GraphLightInfo?
    {
        let lightInfo = GraphLightInfo(.Spherical)
                
        if context.renderQuality == .Normal {
            lightInfo.surfacePos = position.toSIMD() + size.x / 2 * context.rand() + size.y / 2 * context.rand() + size.z / 2 * context.rand()
            lightInfo.normal = normalize(lightInfo.surfacePos - position.toSIMD())
        }

        if let material = materialNode {
            material.execute(context: context)
        }
        if let emission = context.variables["emission"]! as? Float3 {
            lightInfo.emission = emission.toSIMD()// * float(numOfLights)
        }
        
        lightInfo.area = 2 * size.x * size.y + 2 * size.y * size.z + 2 * size.x * size.z //2ab + 2bc + 2ac
        
        lightInfo.position = position.toSIMD()
        lightInfo.radius = size.x / 2
        
        return lightInfo
    }
    
    override func getHelp() -> String
    {
        return "Creates a perfect cube of a given size."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Size", "The size of the cube.")
        ]
        return options + GraphTransformationNode.getTransformationOptions()
    }
}
