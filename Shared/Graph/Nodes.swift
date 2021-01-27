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
                        v.name = givenName
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
    
    override func generateMetalCode(context: GraphContext) -> [String: String]
    {
        var codeMap : [String:String] = ["code":""]
        let materialNames : [String] = ["albedo", "specular","emission","anisotropic","metallic","roughness","subsurface","specularTint","sheen","sheenTint","clearcoat","clearcoatGloss","transmission","ior","extinction"]
                        
        func assignmentCode() -> String {
            if assignmentType == .Copy { return "=" }
            if assignmentType == .Add { return "+=" }
            if assignmentType == .Subtract { return "-=" }
            if assignmentType == .Divide { return "/=" }
            if assignmentType == .Multiply { return "*=" }
            return "Invalid Assignment"
        }
        
        if let expression = expression {
            if let v = expression.execute() {
                if materialNames.contains(givenName) {
                    codeMap["code"] = "material.\(givenName) \(assignmentCode()) \(expression.toMetal())"
                    if givenName == "albedo" && codeMap[givenName] == nil {
                        codeMap["code"]! += "material.albedo = pow(material.albedo, 2.2);\n"
                    }
                } else {
                    if codeMap[givenName] == nil {
                        codeMap["code"] = "\(v.getSIMDName()) \(givenName) = \(expression.toMetal())"
                    } else {
                        codeMap["code"] = "\(givenName) \(assignmentCode()) \(expression.toMetal())"
                    }
                }
            }
        }

        return codeMap
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
