//
//  EnvironmentNodes.swift
//  Signed
//
//  Created by Markus Moenig on 2/3/21.
//

import Foundation

/// defEnvironment
final class GraphDefEnvironmentNode : GraphNode
{
    var funcParameters : [ExpressionNode] = []
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Environment, .Definition, options)
        name = "defEnvironment"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let name = options["name"] as? String {
            self.givenName = name.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        } else {
            error.error = "defEnvironment needs a 'Name' parameter"
        }
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        var params = ""
        var code = "float4 \(givenName)(float3 rayOrigin, float3 rayDirection, float3 normal, DataIn dataIn__PARAMS__) {\n"
        code += "   float4 outColor = float4(0,0,0,1);\n"

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
        
        code += "  return outColor;\n"
        code += "}\n"
                
        return code
    }
    
    override func setEnvironmentVariables(context: GraphContext)
    {
        context.funcParameters = []
        context.variables = ["rayOrigin": Float3("rayOrigin", 0, 0, 0, .System)]
        context.variables["rayDirection"] = Float3("rayDirection", 0, 0, 0, .System)
        context.variables["normal"] = Float3("normal", 0, 0, 0, .System)
        context.variables["outColor"] = Float4("outColor", 0, 0, 0, 0, .System)
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

/// envBackground
final class GraphEnvironmentNode : GraphNode
{
    var defNode                   : GraphDefEnvironmentNode!
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Environment, .Definition, options)
        name = "envBackground"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
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
                
        var funcParamCode = ""
        
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
                     
                        if let _ = exp.execute() {
                            funcParamCode += exp.toMetal(embedded: true)
                        }
                    }
                } else {
                    // If option is not present, used default value
                    if let result = p.argumentsIn[1].execute() {
                        funcParamCode += String(result.toSIMD1())
                    }
                }
            }
        }
        
        var opCode = ""

        for c in context.operatorCode {
            opCode += "        transformedPosition = \(c)\n"
            opCode += "        hash = dataIn.hash;\n"
        }
        
        var code =
        """
        
            {
                \(opCode)
                newDistance = float4(\(defNode.givenName)(transformedPosition__FUNC_PARAM_CODE__), 1, -1, \(context.getMaterialIndex()));
            }

        """
                
        code = code.replacingOccurrences(of: "__FUNC_PARAM_CODE__", with: funcParamCode)
        
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
        return options
    }
}
