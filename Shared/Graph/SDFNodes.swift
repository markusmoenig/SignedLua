//
//  GraphSDFNodes.swift
//  Signed
//
//  Created by Markus Moenig on 14/12/20.
//

import MetalKit
import simd


/// defSDFPrimitive
final class GraphDefPrimitiveNode : GraphNode
{
    var funcParameters : [ExpressionNode] = []
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.SDF, .Definition, options)
        name = "defPrimitive"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let name = options["name"] as? String {
            self.givenName = name.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        } else {
            error.error = "defPrimitive needs a 'Name' parameter"
        }
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        var params = ""
        var code = "float \(givenName)(float3 rayPosition__PARAMS__) {\n"

        context.parameters = [Float3("rayPosition", 0, 0, 0, .System)]
        context.funcParameters = []
                
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
        
        code += "  return outDistance;\n"
        code += "}\n"
                
        return code
    }
    
    override func setEnvironmentVariables(context: GraphContext)
    {
        context.funcParameters = []
        context.variables = ["rayPosition": Float3("rayPosition", 0, 0, 0, .System)]
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

/// sdfPrimitive
final class GraphPrimitiveNode : GraphTransformationNode
{
    var defNode                   : GraphDefPrimitiveNode!
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.SDF, .SDF, options)
        name = "sdfPrimitive"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        checkIn(context: context)
        checkOut(context: context)
        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        if context.compiledNodeNames.contains(defNode.givenName) == false {
            let vars = context.variables
            let code = defNode.generateMetalCode(context: context)
            context.variables = vars
            context.compiledGlobalCode.append(code)
            context.compiledNodeNames.append(defNode.givenName)
        }
        
        print("kkk",givenName, context.variables)
        
        var funcParamCode = ""
        var radiusValue : Float? = nil
        
        for p in defNode.funcParameters {
            
            funcParamCode += ", "

            if let text = p.argumentsIn[0].values[0] as? Text1 {
                let name = text.name.lowercased()
                
                let varType = p.argumentsIn[1].lastResult?.getType()

                if let value = options[name] as? String {
                    
                    var error = CompileError()
                    let exp = ExpressionContext()
                    exp.parse(expression: value, container: context, defaultVariableType: varType, error: &error)
                    if error.error == nil {
                     
                        if let result = exp.execute() {
                            funcParamCode += exp.toMetal(embedded: true)
                            
                            if name == "radius" {
                                radiusValue = result.toSIMD1()
                            }
                        }
                    }
                } else {
                    // If option is not present, used default value
                    if let result = p.argumentsIn[1].execute() {
                        funcParamCode += String(result.toSIMD1())
                        
                        if name == "radius" {
                            radiusValue = result.toSIMD1()
                        }
                    }
                }
            }
        }

        var code =
        """

            {
                \(generateMetalTransformCode(context: context))
                
                newDistance = float4(\(defNode.givenName)(transformedPosition__FUNC_PARAM_CODE__), 0, -1, \(context.getMaterialIndex()));
            }

        """
                
        code = code.replacingOccurrences(of: "__FUNC_PARAM_CODE__", with: funcParamCode)
        
        if let radius = radiusValue {
            context.checkForPossibleLight(atPositionIndex: position.dataIndex!, material: materialNode, radius: radius)
        }
        
        return code
    }
    
    override func getHelp() -> String
    {
        return "Definition of an sdfPrimitive, like a sphere or a cube."
    }
    
    override func getOptions() -> [GraphOption]
    {
        var options : [GraphOption] = []
        for p in defNode.funcParameters {
            
            if let text = p.argumentsIn[0].values[0] as? Text1 {
                let name = text.name

                if let result = p.argumentsIn[1].execute() {
                    if result.getType() == .Float {
                        options.append(GraphOption(result, name, ""))
                    }
                }
            }
        }
        return options + GraphTransformationNode.getTransformationOptions()
    }
}

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
        checkOut(context: context)
        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        let code =
        """

            {
                \(generateMetalTransformCode(context: context))
                
                newDistance = float4(length(transformedPosition) - float(\(radius.toString())), 0, -1, \(context.getMaterialIndex()));
            }

        """
        
        context.checkForPossibleLight(atPositionIndex: position.dataIndex!, material: materialNode, radius: radius.toSIMD())
                
        return code
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
    var size        : Float3 = Float3(1)
    var rounding    : Float1 = Float1(0)

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
        if let value = extractFloat1Value(options, container: context, error: &error, name: "rounding", isOptional: true) {
            rounding = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        checkIn(context: context)
        checkOut(context: context)
        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        let code =
        """

            {
                \(generateMetalTransformCode(context: context))

                float rounding = float(\(rounding.toString()));
                float3 q = abs(transformedPosition) - float3(\(size.toString())) + rounding;
                newDistance = float4(length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - rounding, 0, -1, \(context.getMaterialIndex()));
            }

        """
                
        return code
    }
    
    /*
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
    }*/
    
    override func getHelp() -> String
    {
        return "Creates a perfect cube of a given size."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Size", "Size of the box."),
            GraphOption(Float1(0), "Rounding", "Rounding of the box.")
        ]
        return options + GraphTransformationNode.getTransformationOptions()
    }
}
