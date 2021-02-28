//
//  ConditionalNodes.swift
//  Signed
//
//  Created by Markus Moenig on 27/2/21.
//

import Foundation

/// if
final class GraphIfNode : GraphNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Material, options)
        name = "if"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    override func generateMetalCode(context: GraphContext) -> String
    {
        setEnvironmentVariables(context: context)

        var condition = "false"
        if let cond = options["condition"] as? String {
            condition = cond
        }
        
        var code = "if (\(condition)) {\n"
        
        let v = context.variables
        
        for leave in leaves {
            code += leave.generateMetalCode(context: context)
        }
        
        context.variables = v
        
        code += "}\n"
                        
        return code
    }
    
    override func setEnvironmentVariables(context: GraphContext)
    {
    }
    
    override func getHelp() -> String
    {
        return "Defines an if statement."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options : [GraphOption] = []
        return options
    }
}

/// else
final class GraphElseNode : GraphNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Material, options)
        name = "else"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    override func generateMetalCode(context: GraphContext) -> String
    {
        setEnvironmentVariables(context: context)
        
        var code = "else {\n"
        
        let v = context.variables
        
        for leave in leaves {
            code += leave.generateMetalCode(context: context)
        }
        
        context.variables = v
        
        code += "}\n"
                        
        return code
    }
    
    override func setEnvironmentVariables(context: GraphContext)
    {
    }
    
    override func getHelp() -> String
    {
        return "Defines an if statement."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options : [GraphOption] = []
        return options
    }
}
