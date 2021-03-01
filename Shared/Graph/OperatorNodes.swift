//
//  OperatorNodes.swift
//  Signed
//
//  Created by Markus Moenig on 1/3/21.
//

import Foundation


import MetalKit
import simd

/// defOperator
final class GraphDefOperatorNode : GraphNode
{
    var funcParameters : [ExpressionNode] = []
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Operator, .Definition, options)
        name = "defOperator"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let name = options["name"] as? String {
            self.givenName = name.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        } else {
            error.error = "defOperator needs a 'Name' parameter"
        }
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        var params = ""
        var code = "float3 \(givenName)(float3 domain__PARAMS__) {\n"
        code += "  float3 outDomain = domain;\n"

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
        
        code += "  return outDomain;\n"
        code += "}\n"
                
        return code
    }
    
    override func setEnvironmentVariables(context: GraphContext)
    {
        context.funcParameters = []
        
        context.variables = [:]
        context.variables["domain"] = Float3("domain", 0, 0, 0, .System)
        context.variables["outDomain"] = Float3("outDomain", 0, 0, 0, .System)
    }
    
    override func getHelp() -> String
    {
        return "Definition of an sdfOperator."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options : [GraphOption] = []
        return options
    }
}

/// sdfBoolean
final class GraphOperatorNode : GraphNode
{
    var defNode                   : GraphDefOperatorNode!
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Operator, .SDF, options)
        name = "sdfOperator"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        for leave in leaves {
            leave.execute(context: context)
        }
        
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

        let tempName = context.getTempVariableName()
        
        var code =
        """

            float3 \(tempName) = position;
            position = \(defNode.givenName)(position__FUNC_PARAM_CODE__);

        """
                        
        code = code.replacingOccurrences(of: "__FUNC_PARAM_CODE__", with: funcParamCode)
        
        for leave in leaves {
            code += leave.generateMetalCode(context: context)
        }
        
        code +=
        """

            position = \(tempName);

        """
        
        return code
    }
    
    override func getHelp() -> String
    {
        return "Definition of an sdfBoolean."
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
