//
//  GraphBuilder.swift
//  Signed
//
//  Created by Markus Moenig on 13/12/20.
//

import Foundation
import Combine

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
    var cursorTimer         : Timer? = nil
    let core                : Core
    
    let selectionChanged    = PassthroughSubject<UUID?, Never>()

    var currentNode         : GraphNode? = nil
    
    var branches        : [GraphNodeItem] =
    [
        GraphNodeItem("PinholeCamera", { (_ options: [String:Any]) -> GraphNode in return GraphPinholeCameraNode(options) }),
        GraphNodeItem("DefaultSky", { (_ options: [String:Any]) -> GraphNode in return GraphDefaultSkyNode(options) }),
        GraphNodeItem("analyticalObject", { (_ options: [String:Any]) -> GraphNode in return GraphAnalyticalObject(options) }),
        GraphNodeItem("sdfObject", { (_ options: [String:Any]) -> GraphNode in return GraphSDFObject(options) }),
        GraphNodeItem("Material", { (_ options: [String:Any]) -> GraphNode in return GraphMaterialNode(options) }),
        GraphNodeItem("Render", { (_ options: [String:Any]) -> GraphNode in return GraphRenderNode(options) }),
    ]
    
    var leaves          : [GraphNodeItem] =
    [
        GraphNodeItem("analyticalPlane", { (_ options: [String:Any]) -> GraphNode in return GraphAnalyticalPlaneNode(options) }),

        GraphNodeItem("sdfSphere", { (_ options: [String:Any]) -> GraphNode in return GraphSDFSphereNode(options) }),
        GraphNodeItem("sdfBox", { (_ options: [String:Any]) -> GraphNode in return GraphSDFBoxNode(options) }),
        GraphNodeItem("sdfPlane", { (_ options: [String:Any]) -> GraphNode in return GraphSDFPlaneNode(options) }),
        
        GraphNodeItem("boolMerge", { (_ options: [String:Any]) -> GraphNode in return GraphBoolMergeNode(options) }),
        
        GraphNodeItem("texColor", { (_ options: [String:Any]) -> GraphNode in return GraphTexColorNode(options) }),
        GraphNodeItem("texChecker", { (_ options: [String:Any]) -> GraphNode in return GraphTexCheckerNode(options) }),
        GraphNodeItem("texNoise2D", { (_ options: [String:Any]) -> GraphNode in return GraphTexNoise2DNode(options) }),
    ]
    
    init(_ core: Core)
    {
        self.core = core        
    }
    
    @discardableResult func compile(_ asset: Asset, silent: Bool = false) -> CompileError
    {
        var error = CompileError()
        error.asset = asset
        
        func createError(_ errorText: String = "Syntax Error") {
            error.error = errorText
        }
        
        if asset.graph == nil {
            asset.graph = GraphContext(core)
        } else {
            asset.graph!.clear()
        }
        
        let graph = asset.graph!
        
        // Insert top hierarchy nodes for the UI
        
        let hCameraNodes = GraphNode(.Camera, .None)
        hCameraNodes.name = "Cameras"
        hCameraNodes.leaves = []
        graph.hierarchicalNodes.append(hCameraNodes)
        
        let hMaterialNodes = GraphNode(.Utility, .Material)
        hMaterialNodes.name = "Materials"
        hMaterialNodes.leaves = []
        graph.hierarchicalNodes.append(hMaterialNodes)
        
        let hObjectNodes = GraphNode(.Utility, .SDF)
        hObjectNodes.name = "Objects"
        hObjectNodes.leaves = []
        graph.hierarchicalNodes.append(hObjectNodes)
        
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
            var assignmentType : VariableAssignmentNode.AssignmentType = .Copy
            
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
                                        
                                        hCameraNodes.leaves.append(newBranch)
                                    } else
                                    if newBranch.role == .Sky {
                                        asset.graph!.skyNode = newBranch
                                        
                                        newBranch.lineNr = error.line!
                                        graph.lines[error.line!] = newBranch
                                        processed = true
                                    }
                                    
                                    if processed == false {

                                        if level == 0 {
                                            asset.graph!.nodes.append(newBranch)
                                            currentBranch = []
                                            
                                            if newBranch.context == .Analytical {
                                                asset.graph!.analyticalNodes.append(newBranch)
                                                
                                                // Separate hierarchical Node
                                                
                                                let hObject = GraphAnalyticalObject()
                                                hObject.name = newBranch.givenName
                                                hObject.lineNr = error.line!
                                                hObject.leaves = nil
                                                hObject.id = newBranch.id
                                                hObjectNodes.leaves!.append(hObject)
                                            } else
                                            if newBranch.context == .SDF {
                                                asset.graph!.sdfNodes.append(newBranch)
                                                
                                                // Separate hierarchical Node
                                                
                                                let hObject = GraphSDFObject()
                                                hObject.name = newBranch.givenName
                                                hObject.lineNr = error.line!
                                                hObject.leaves = nil
                                                hObject.id = newBranch.id
                                                hObjectNodes.leaves!.append(hObject)
                                            } else
                                            if newBranch.context == .Material {
                                                asset.graph!.materialNodes.append(newBranch)
                                                
                                                // Separate hierarchical Node
                                                
                                                let hMaterial = GraphMaterialNode()
                                                hMaterial.name = newBranch.givenName
                                                hMaterial.lineNr = error.line!
                                                hMaterial.leaves = nil
                                                hMaterial.id = newBranch.id
                                                hMaterialNodes.leaves!.append(hMaterial)
                                            } else
                                            if newBranch.context == .Render {
                                                asset.graph!.renderNodes.append(newBranch)
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
                                
                                let variableNode = VariableAssignmentNode()
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
        
        if silent == false {
            
            if asset.graph?.cameraNode == nil {
                error.error = "Project must contain a Camera!"
                error.line = 0
            }
            
            if core.state == .Idle {
                if error.error != nil {
                    error.line = error.line! + 1
                    core.scriptEditor?.setError(error)
                } else {
                    core.scriptEditor?.clearAnnotations()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.core.modelChanged.send()
            }
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
    
    func startTimer(_ asset: Asset)
    {
        DispatchQueue.main.async(execute: {
            let timer = Timer.scheduledTimer(timeInterval: 0.2,
                                             target: self,
                                             selector: #selector(self.cursorCallback),
                                             userInfo: nil,
                                             repeats: true)
            self.cursorTimer = timer
        })
    }
    
    func stopTimer()
    {
        if cursorTimer != nil {
            cursorTimer?.invalidate()
            cursorTimer = nil
        }
    }
    
    var lastContextHelpName :String? = "d"
    @objc func cursorCallback(_ timer: Timer) {
        if core.state == .Idle && core.scriptEditor != nil {
            core.scriptEditor!.getSessionCursor({ (line) in
            
                if let asset = self.core.assetFolder.current, asset.type == .Source {
                    if let context = asset.graph {
                        if let node = context.lines[line] {
                            if node.name != self.lastContextHelpName {
                                self.currentNode = node
                                self.selectionChanged.send(node.id)
                                self.core.contextText = self.generateNodeHelpText(node)
                                self.core.contextTextChanged.send(self.core.contextText)
                                self.lastContextHelpName = node.name
                            }
                        } else {
                            if self.lastContextHelpName != nil {
                                self.currentNode = nil
                                self.selectionChanged.send(nil)
                                self.core.contextText = ""
                                self.core.contextTextChanged.send(self.core.contextText)
                                self.lastContextHelpName = nil
                            }
                        }
                    }
                }
            })
        }
    }
    
    /// Generates a markdown help text for the given node
    func generateNodeHelpText(_ node:GraphNode) -> String
    {
        var help = "## " + node.name + "\n"
        help += node.getHelp()
        let options = node.getOptions()
        if options.count > 0 {
            help += "\nOptional Parameters\n"
        }
        for o in options {
            help += "* **\(o.name)** (\(o.variable.getTypeName())) - " + o.help + "\n"
        }
        return help
    }
    
    /// Go to the line of the node
    func gotoNode(_ node: GraphNode)
    {
        if currentNode != node {
            core.scriptEditor?.gotoLine(node.lineNr+1)
            currentNode = node
        }
    }
}
