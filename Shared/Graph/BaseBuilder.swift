//
//  BaseBuilder.swift
//  Denrim
//
//  Created by Markus Moenig on 12/1/21.
//

import Foundation

struct CompileError
{
    var asset           : Asset? = nil
    var line            : Int32? = nil
    var column          : Int32? = 0
    var error           : String? = nil
    var type            : String = "error"
}

class GraphNodeItem
{
    var name         : String
    var createNode   : (_ options: [String:Any]) -> GraphNode
    
    init(_ name: String, _ createNode: @escaping (_ options: [String:Any]) -> GraphNode)
    {
        self.name = name
        self.createNode = createNode
    }
}

class GraphBuilder
{
    var branches        : [GraphNodeItem] =
    [
        GraphNodeItem("analyticalObject", { (_ options: [String:Any]) -> GraphNode in return GraphAnalyticalObject(options) }),
        GraphNodeItem("sdfObject", { (_ options: [String:Any]) -> GraphNode in return GraphSDFObject(options) }),
        GraphNodeItem("sdfObject2D", { (_ options: [String:Any]) -> GraphNode in return GraphSDFObject2D(options) }),
        GraphNodeItem("Material", { (_ options: [String:Any]) -> GraphNode in return GraphMaterialNode(options) }),
        GraphNodeItem("Render", { (_ options: [String:Any]) -> GraphNode in return GraphRenderNode(options) }),
        GraphNodeItem("renderPBR", { (_ options: [String:Any]) -> GraphNode in return GraphPBRNode(options) }),
        GraphNodeItem("renderCustom", { (_ options: [String:Any]) -> GraphNode in return GraphCustomRenderNode(options) }),
    ]
    
    var leaves          : [GraphNodeItem] =
    [
        GraphNodeItem("analyticalPlane", { (_ options: [String:Any]) -> GraphNode in return GraphAnalyticalPlaneNode(options) }),

        GraphNodeItem("sdfSphere", { (_ options: [String:Any]) -> GraphNode in return GraphSDFSphereNode(options) }),
        GraphNodeItem("sdfBox", { (_ options: [String:Any]) -> GraphNode in return GraphSDFBoxNode(options) }),
        GraphNodeItem("sdfPlane", { (_ options: [String:Any]) -> GraphNode in return GraphSDFPlaneNode(options) }),
        
        GraphNodeItem("sdfCircle2D", { (_ options: [String:Any]) -> GraphNode in return GraphSDFCircleNode2D(options) }),
        
        GraphNodeItem("boolMerge", { (_ options: [String:Any]) -> GraphNode in return GraphBoolMergeNode(options) }),
        
        GraphNodeItem("texColor", { (_ options: [String:Any]) -> GraphNode in return GraphTexColorNode(options) }),
        GraphNodeItem("texChecker", { (_ options: [String:Any]) -> GraphNode in return GraphTexCheckerNode(options) }),
        GraphNodeItem("texNoise2D", { (_ options: [String:Any]) -> GraphNode in return GraphTexNoise2DNode(options) }),
    ]
    
    init()
    {
    }
    
    @discardableResult func compile(_ asset: Asset, silent: Bool = false) -> CompileError
    {
        var error = CompileError()
        error.asset = asset
        
        func createError(_ errorText: String = "Syntax Error") {
            error.error = errorText
        }

        if asset.graph == nil {
            asset.graph = GraphContext()
        } else {
            asset.graph!.clear()
        }
        
        let graph = asset.graph!
                
        // Create default variables
        graph.createDefaultVariables()
        
        //
        
        let ns = asset.value as NSString
        var lineNumber  : Int32 = 0
        
        //var currentTree     : GraphTree? = nil
        var currentBranch   : [GraphNode] = []
        var lastLevel       : Int = -1

        ns.enumerateLines { (str, _) in
            if error.error != nil { return }
            error.line = lineNumber
            
            //
            
            var processed = false
            var leftOfComment : String

            if str.firstIndex(of: "#") != nil {
                let split = str.split(separator: "#")
                if split.count == 2 {
                    leftOfComment = String(str.split(separator: "#")[0])
                } else {
                    leftOfComment = ""
                }
            } else {
                leftOfComment = str
            }
            
            // Get the current indention level
            let level = (str.prefix(while: {$0 == " "}).count) / 4

            leftOfComment = leftOfComment.trimmingCharacters(in: .whitespaces)
            
            // If empty, bail out, nothing todo
            if leftOfComment.count == 0 {
                lineNumber += 1
                return
            }
            
            // Drop the last branch when indention decreases
            if level < lastLevel {
                let levelsToDrop = lastLevel - level
                //print("dropped at line", error.line, "\"", str, "\"", level, levelsToDrop)
                for _ in 0..<levelsToDrop {
                    currentBranch = currentBranch.dropLast()
                }
            }
            
            var variableName : String? = nil
            var assignmentType : GraphVariableAssignmentNode.AssignmentType = .Copy
            
            // --- Check for variable assignment
            if leftOfComment.contains("="){
             
                var values : [String] = []
                
                if leftOfComment.contains("*=") {
                    assignmentType = .Multiply
                    values = leftOfComment.components(separatedBy: "*=")
                } else
                if leftOfComment.contains("/=") {
                    assignmentType = .Divide
                    values = leftOfComment.components(separatedBy: "/=")
                } else
                if leftOfComment.contains("+=") {
                    assignmentType = .Add
                    values = leftOfComment.components(separatedBy: "+=")
                } else
                if leftOfComment.contains("-=") {
                    assignmentType = .Subtract
                    values = leftOfComment.components(separatedBy: "+=")
                } else {
                    values = leftOfComment.components(separatedBy: "=")
                }
                
                if values.count == 2 {
                    variableName = String(values[0]).trimmingCharacters(in: .whitespaces)
                    leftOfComment = String(values[1])
                }
            }
            
            /// Splits the option string into a possible command and its <> enclosed options
            func splitIntoCommandPlusOptions(_ string: String,_ error: inout CompileError) -> [String]
            {
                var rc : [String] = []
                
                if let first = string.firstIndex(of: "<")?.utf16Offset(in: string) {

                    let index = string.index(string.startIndex, offsetBy: first)
                    let possibleCommand = string[..<index]//string.prefix(index)
                    rc.append(String(possibleCommand))
                    
                    //let rest = string[index...]
                    
                    var offset      : Int = first
                    var hierarchy   : Int = -1
                    var option      = ""
                    
                    while offset < string.count {
                        if string[offset] == "<" {
                            if hierarchy >= 0 {
                                option.append(string[offset])
                            }
                            hierarchy += 1
                        } else
                        if string[offset] == ">" {
                            if hierarchy == 0 {
                                rc.append(option)
                                option = ""
                                hierarchy = -1
                            } else
                            if hierarchy < 0 {
                                error.error = "Syntax Error"
                            } else {
                                hierarchy -= 1
                                if hierarchy >= 0 {
                                    option.append(string[offset])
                                }
                            }
                        } else {
                            option.append(string[offset])
                        }
                        
                        offset += 1
                    }
                    if option.isEmpty == false && error.error == nil {
                        error.error = "Syntax Error: \(option)"
                    }
                }
                               
                return rc
            }

            if leftOfComment.count > 0 {
                
                var rightValueArray : [String]
                
                if variableName == nil {
                    rightValueArray = splitIntoCommandPlusOptions(leftOfComment, &error)
                } else {
                    rightValueArray = [leftOfComment]
                }
                
                if rightValueArray.count > 0 && error.error == nil {
                    
                    let possbibleCmd = String(rightValueArray[0]).trimmingCharacters(in: .whitespaces)
                    
                    if variableName == nil {
                        
                        var options : [String: String] = [:]
                        
                        // Fill in options
                        rightValueArray.removeFirst()
                        if rightValueArray.count == 1 && rightValueArray[0] == "" {
                            // Empty Arguments
                        } else {
                            while rightValueArray.count > 0 {
                                let array = rightValueArray[0].split(separator: ":")
                                rightValueArray.removeFirst()
                                if array.count == 2 {
                                    let optionName = array[0].lowercased().trimmingCharacters(in: .whitespaces)
                                    let values = array[1].trimmingCharacters(in: .whitespaces)
                                    options[optionName] = String(values)
                                } else { createError(); rightValueArray = [] }
                            }
                        }
                        
                        let nodeOptions = self.parser_processOptions(options, &error)
                        
                        // Looking for branch
                        for branch in self.branches {
                            if branch.name == possbibleCmd {

                                let newBranch = branch.createNode(nodeOptions)
                                newBranch.verifyOptions(context: asset.graph!, error: &error)
                                
                                if error.error == nil {
                                
                                    // Special Nodes which do not get appended to nodes
                                    if newBranch.role == .Camera {
                                        asset.graph!.cameraNode = newBranch
                                        
                                        newBranch.lineNr = error.line!
                                        asset.graph!.lines[error.line!] = newBranch
                                        processed = true
                                    } else
                                    if newBranch.role == .Sky {
                                        asset.graph!.skyNode = newBranch
                                        
                                        newBranch.lineNr = error.line!
                                        graph.lines[error.line!] = newBranch
                                        processed = true
                                    } else
                                    if newBranch.role == .Render {
                                        asset.graph!.renderNode = newBranch
                                        
                                        newBranch.lineNr = error.line!
                                        graph.lines[error.line!] = newBranch
                                    }
                                    
                                    if processed == false {

                                        if level == 0 {
                                            asset.graph!.nodes.append(newBranch)
                                            currentBranch = []
                                            
                                            if newBranch.context == .Analytical {
                                                asset.graph!.analyticalNodes.append(newBranch)
                                                graph.objectNodes.append(newBranch)
                                            } else
                                            if newBranch.context == .SDF {
                                                asset.graph!.sdfNodes.append(newBranch)
                                                graph.objectNodes.append(newBranch)
                                            } else
                                            if newBranch.context == .SDF2D {
                                                asset.graph!.sdf2DNodes.append(newBranch)
                                            } else
                                            if newBranch.context == .Material {
                                                asset.graph!.materialNodes.append(newBranch)
                                            }
                                        }
                                        
                                        if currentBranch.count == 0 {
                                            //currentTree?.leaves.append(newBranch)
                                            currentBranch.append(newBranch)
                                            
                                            newBranch.lineNr = error.line!
                                            asset.graph!.lines[error.line!] = newBranch
                                        } else {
                                            if let branch = currentBranch.last {
                                                branch.leaves.append(newBranch)
                                                
                                                newBranch.lineNr = error.line!
                                                asset.graph!.lines[error.line!] = newBranch
                                            }
                                            currentBranch.append(newBranch)
                                        }
                                        processed = true
                                    }
                                }
                            }
                        }
                        
                        if processed == false {
                            // Looking for leave
                            for leave in self.leaves {
                                if leave.name == possbibleCmd {
                                    
                                    if error.error == nil {
                                        if let branch = currentBranch.last {
                                            let behaviorNode = leave.createNode(nodeOptions)
                                            behaviorNode.verifyOptions(context: asset.graph!, error: &error)
                                            if error.error == nil {
                                                behaviorNode.lineNr = error.line!
                                                branch.leaves.append(behaviorNode)
                                                asset.graph!.lines[error.line!] = behaviorNode
                                                processed = true
                                            }
                                        } else { createError("Leaf node without active branch") }
                                    }
                                }
                            }
                        }
                    } else
                    if var variableName = variableName {
                        
                        // Variable assignment
                        let rightSide = leftOfComment.trimmingCharacters(in: .whitespaces)
                        //print(variableName, "rightSide", rightSide)
                        let exp = ExpressionContext()
                        exp.parse(expression: rightSide, container: asset.graph!, error: &error)
                        
                        if error.error == nil {
                            
                            if let branch = currentBranch.last {
                                
                                if let material = currentBranch.first as? GraphMaterialNode {
                                    if variableName == "displacement" {
                                        material.hasDisplacement = true
                                    }
                                }
                                
                                var assignmentComponents : Int = 0
                                
                                if variableName.contains(".") {
                                    let array = variableName.split(separator: ".")
                                    if array.count == 2 {
                                        variableName = String(array[0])
                                        assignmentComponents = array[1].count
                                    }
                                }
                                
                                let variableNode = GraphVariableAssignmentNode()
                                variableNode.givenName = variableName
                                variableNode.assignmentComponents = assignmentComponents
                                variableNode.assignmentType = assignmentType
                                variableNode.expression = exp
                                
                                variableNode.execute(context: asset.graph!)
                                
                                variableNode.lineNr = error.line!
                                branch.leaves.append(variableNode)
                                asset.graph!.lines[error.line!] = variableNode
                                processed = true
                            } else
                            if error.error == nil { createError("Leaf node without active branch") }
                        } else { createError("Invalid expression") }
                    }
                }
                if str.trimmingCharacters(in: .whitespaces).count > 0 && processed == false && error.error == nil {
                    error.error = "Unrecognized statement"
                }
            }
            
            lastLevel = level
            lineNumber += 1
        }

        return error
    }
    
    func parser_processOptions(_ options: [String:String],_ error: inout CompileError) -> [String:Any]
    {
        //print("Processing Options", options)

        var res: [String:Any] = [:]
        
        for(name, value) in options {
            res[name] = value
        }
        
        return res
    }
}
