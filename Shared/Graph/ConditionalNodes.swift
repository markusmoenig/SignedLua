//
//  ConditionalNodes.swift
//  Signed
//
//  Created by Markus Moenig on 27/2/21.
//

import Foundation

/// MaterialNode
final class GraphIfNode : GraphNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Material, options)
        name = "if"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        print(options)
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        return .Success
    }
    
    override func generateMetalCode(context: GraphContext) -> String
    {
        setEnvironmentVariables(context: context)

        var condition = "false"
        if let cond = options["condition"] as? String {
            condition = cond
        }
        
        var code = "if (\(condition)) {"
        
        for leave in leaves {
            code += leave.generateMetalCode(context: context)
        }
        
        code += "}"
                        
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
