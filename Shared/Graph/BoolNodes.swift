//
//  GraphBoolNodes.swift
//  Signed
//
//  Created by Markus Moenig on 14/12/20.
//

import MetalKit
import simd

/// defBoolean
final class GraphDefBooleanNode : GraphNode
{
    var funcParameters : [ExpressionNode] = []
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Boolean, .Definition, options)
        name = "defBoolean"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let name = options["name"] as? String {
            self.givenName = name.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        } else {
            error.error = "defBoolean needs a 'Name' parameter"
        }
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        var params = ""
        var code = "float4 \(givenName)(float4 shapeA, float4 shapeB__PARAMS__) {\n"

        setEnvironmentVariables(context: context)
                
        for leave in leaves {
            code += leave.generateMetalCode(context: context)
        }
                    
        for p in context.funcParameters {
            params += ", "

            if let text = p.argumentsIn[0].values[0] as? Text1 {
                if let result = p.argumentsIn[1].execute() {
                    params += result.getSIMDName()
                    params += " "
                    params += text.name.lowercased()
                }
            }
        }
        
        funcParameters = context.funcParameters
    
        code = code.replacingOccurrences(of: "__PARAMS__", with: params)
        
        code += "  return outShape;\n"
        code += "}\n"
                
        return code
    }
    
    override func setEnvironmentVariables(context: GraphContext)
    {
        //context.parameters = [Float4("shapeA", 0, 0, 0, 0, .System), Float4("shapeB", 0, 0, 0, 0, .System)]
        context.funcParameters = []
        
        context.variables = [:]
        context.variables["shapeA"] = Float4("shapeA", 0, 0, 0, 0, .System)
        context.variables["shapeB"] = Float4("shapeB", 0, 0, 0, 0, .System)
    }
    
    override func getHelp() -> String
    {
        return "Definition of an sdfPrimitive, like a sphere or a cube."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options : [GraphOption] = []
        return options
    }
}

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
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        let code =
        """

            if (newDistance.x < distance.x) distance = newDistance;

        """
                
        return code
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
    override func generateMetalCode(context: GraphContext) -> String
    {
        context.addDataVariable(smoothing)

        let code =
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
                
        return code
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
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        let code =
        """

            if (-newDistance.x > distance.x) {
                distance = newDistance;
                distance.x = -distance.x;
            }

        """
                
        return code
    }
    
    override func getHelp() -> String
    {
        return "Subtracts the last SDF."
    }
}
