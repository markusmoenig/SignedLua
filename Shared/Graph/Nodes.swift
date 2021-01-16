//
//  GraphNodes.swift
//  Signed
//
//  Created by Markus Moenig on 15/12/20.
//

import MetalKit
import simd

/// GraphVariableAssignmentNode, assign or modify a variable via assignment, =, *=, -= etc
final class GraphVariableAssignmentNode : GraphNode
{
    enum AssignmentType {
        case Copy, Multiply, Divide, Add, Subtract
    }
    
    /// The right handed expression the variables gets assigned to
    var expression                  : ExpressionContext? = nil
    /// The components  of the assignment (like outColor.xyz has 3 assignment components)
    var assignmentComponents        : Int = 0
    /// The assignment type
    var assignmentType              : AssignmentType = .Copy
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Variable, .None, options)
        name = "VariableAsignment"
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        if let expression = expression {
            // Assign to existing variable
            if let existing = context.variables[givenName] {                        
                if let v = expression.execute() {
                    existing.role = expression.isConstant() ? .User : .System
                    if v.getType() == .Float && (assignmentType == .Multiply || assignmentType == .Divide) {
                        existing.assignFromFloat(from: v, using: assignmentType, upTo: assignmentComponents)
                    } else {
                        existing.assign(from: v, using: assignmentType)
                    }
                }
            } else {
                // New variable
                if let result = expression.execute() {
                    if context.variables[givenName] == nil {
                        let v = result.createType()
                        v.role = expression.isConstant() ? .User : .System
                        context.variables[givenName] = v
                    }
                    context.variables[givenName]!.assign(from: result, using: assignmentType)
                } else {
                    print("Expression result is nil for", givenName, "expression:", expression.expression)
                }
            }
        }
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates or modifies a variable."
    }
    
    override func getOptions() -> [GraphOption]
    {
        return []
    }
}
