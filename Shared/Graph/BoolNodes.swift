//
//  GraphBoolNodes.swift
//  Signed
//
//  Created by Markus Moenig on 14/12/20.
//

import MetalKit
import simd

/// BoolMergeNode
final class GraphBoolMergeNode : GraphNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Boolean, .SDF, options)
        name = "boolMerge"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        if context.rayDist[0] < context.rayDist[1] {
            context.rayDist[context.rayIndex] = context.rayDist[0]
            context.hitMaterial[context.rayIndex] = context.hitMaterial[0]
        } else {
            context.rayDist[context.rayIndex] = context.rayDist[1]
            context.hitMaterial[context.rayIndex] = context.hitMaterial[1]
        }
        //context.rayDist[context.rayIndex] = min(context.rayDist[0], context.rayDist[1])
        context.toggleRayIndex()

        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> [String: String]
    {
        var codeMap : [String:String] = [:]
        
        codeMap["map"] =
        """

            if (newDistance.x < distance.x) distance = newDistance;

        """
                
        return codeMap
    }
    
    override func getHelp() -> String
    {
        return "Merges the two previous SDFs."
    }
}

/// BoolMergeNode
final class GraphBoolSmoothMergeNode : GraphNode
{
    var smoothing = Float1(0.5)
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Boolean, .SDF, options)
        name = "boolSmoothMerge"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let smoothing = extractFloat1Value(options, container: context, error: &error, name: "smoothing", isOptional: true) {
            self.smoothing = smoothing
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        if let index = smoothing.dataIndex, index < context.data.count {
            context.data[index] = smoothing.toSIMD4()
        }

        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> [String: String]
    {
        var codeMap : [String:String] = [:]
        
        context.addDataVariable(smoothing)

        codeMap["map"] =
        """

            {
                float k = dataIn.data[\(smoothing.dataIndex!)].x;
                float h = clamp( 0.5 + 0.5 * (newDistance.x - distance.x) / k, 0.0, 1.0);
                float dist = mix(newDistance.x, distance.x, h) - k * h * (1.0 - h);
                float4 shape = distance;

                if (newDistance.x < distance.x) {
                    distance = newDistance;
                    float blend = fract(distance.z);
                    //if (blend >= 0.999) {
                        distance.z = shape.w;
                        distance.z += clamp( 1.0 - h, 0.0, 0.999);
                    //}
                } else {
                    float blend = fract(distance.z);
                    //if (blend <= 0.999) {
                        distance.z = newDistance.w;
                        distance.z += clamp( h, 0.0, 0.999);
                    //}
                }
                distance.x = dist;
            }

        """
                
        return codeMap
    }
    
    override func getHelp() -> String
    {
        return "Merges the two previous SDFs."
    }
}

/// GraphBoolSubtractNode
final class GraphBoolSubtractNode : GraphNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Boolean, .SDF, options)
        name = "boolSubtract"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        if context.rayDist[0] < context.rayDist[1] {
            context.rayDist[context.rayIndex] = context.rayDist[0]
            context.hitMaterial[context.rayIndex] = context.hitMaterial[0]
        } else {
            context.rayDist[context.rayIndex] = context.rayDist[1]
            context.hitMaterial[context.rayIndex] = context.hitMaterial[1]
        }
        //context.rayDist[context.rayIndex] = min(context.rayDist[0], context.rayDist[1])
        context.toggleRayIndex()

        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> [String: String]
    {
        var codeMap : [String:String] = [:]
        
        codeMap["map"] =
        """

            if (-newDistance.x > distance.x) {
                distance = newDistance;
                distance.x = -distance.x;
            }

        """
                
        return codeMap
    }
    
    override func getHelp() -> String
    {
        return "Subtracts the last SDF."
    }
}
