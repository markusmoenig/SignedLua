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
        GraphNodeItem("PinholeCamera", { (_ options: [String:Any]) -> GraphNode in return PinholeCameraNode(options) }),
        GraphNodeItem("DefaultSky", { (_ options: [String:Any]) -> GraphNode in return DefaultSkyNode(options) }),
        GraphNodeItem("analyticalObject", { (_ options: [String:Any]) -> GraphNode in return AnalyticalObject(options) }),
        GraphNodeItem("sdfObject", { (_ options: [String:Any]) -> GraphNode in return SDFObject(options) }),
    ]
    
    var leaves          : [GraphNodeItem] =
    [
        GraphNodeItem("analyticalPlane", { (_ options: [String:Any]) -> GraphNode in return AnalyticalPlaneNode(options) }),

        GraphNodeItem("sdfSphere", { (_ options: [String:Any]) -> GraphNode in return SDFSphereNode(options) }),
        GraphNodeItem("sdfBox", { (_ options: [String:Any]) -> GraphNode in return SDFBoxNode(options) }),
        GraphNodeItem("sdfPlane", { (_ options: [String:Any]) -> GraphNode in return SDFPlaneNode(options) }),
        GraphNodeItem("boolMerge", { (_ options: [String:Any]) -> GraphNode in return BoolMergeNode(options) }),
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
            // --- Check for variable assignment
            let values = leftOfComment.split(separator: "=")
            if values.count == 2 {
                variableName = String(values[0]).trimmingCharacters(in: .whitespaces)
                leftOfComment = String(values[1])
            }

            if leftOfComment.count > 0 {
                let arguments = leftOfComment.split(separator: " ", omittingEmptySubsequences: true)
                if arguments.count > 0 {
                    //print(level, arguments)
                    
                    //let cmd = arguments[0].trimmingCharacters(in: .whitespaces)
                    /*
                    if cmd == "tree" {
                        if arguments.count >= 2 {
                            let name = arguments[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)

                            if CharacterSet.letters.isSuperset(of: CharacterSet(charactersIn: name)) {
                                if level == 0 {
                                    currentTree = GraphTree(name)
                                    asset.graph!.trees.append(currentTree!)
                                    currentBranch = []
                                    processed = true
                                    asset.graph!.lines[error.line!] = "tree"

                                    // Rest of the parameters are incoming variables
                                    
                                    if arguments.count > 2 {
                                        var variablesString = ""
                                        
                                        for index in 2..<arguments.count {
                                            var string = arguments[index].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
                                            string = string.replacingOccurrences(of: ">", with: "<")
                                            variablesString += string
                                        }
                                        
                                        var rightValueArray = variablesString.split(separator: "<")
                                        while rightValueArray.count > 1 {
                                            let possibleVar = rightValueArray[0].lowercased()
                                            let varName = String(rightValueArray[1])
                                            if CharacterSet.letters.isSuperset(of: CharacterSet(charactersIn: varName)) {
                                                if possibleVar == "int" {
                                                    currentTree?.parameters.append(GraphVariable(varName, Int1(0)))
                                                } else
                                                if possibleVar == "bool" {
                                                    currentTree?.parameters.append(GraphVariable(varName, Bool1()))
                                                } else
                                                if possibleVar == "float" {
                                                    currentTree?.parameters.append(GraphVariable(varName, Float1(0)))
                                                } else
                                                if possibleVar == "float2" {
                                                    currentTree?.parameters.append(GraphVariable(varName, Float2(0,0)))
                                                } else
                                                if possibleVar == "float3" {
                                                    currentTree?.parameters.append(GraphVariable(varName, Float3(0,0,0)))
                                                } else
                                                if possibleVar == "float4" {
                                                    currentTree?.parameters.append(GraphVariable(varName, Float4(0,0,0,0)))
                                                }
                                            } else { error.error = "Invalid variable '\(varName)'" }
                                            
                                            rightValueArray = Array(rightValueArray.dropFirst(2))
                                        }
                                    }
                                }
                            } else { error.error = "Invalid name for tree '\(name)'" }
                        } else { error.error = "No name given for tree" }
                    } else {
                    */
                    var rightValueArray : [String.SubSequence]
                        
                    if leftOfComment.firstIndex(of: "<") != nil {
                        rightValueArray = leftOfComment.split(separator: "<")
                    } else {
                        rightValueArray = leftOfComment.split(separator: " ")
                    }
                    
                    if rightValueArray.count > 0 {
                        
                        let possbibleCmd = String(rightValueArray[0]).trimmingCharacters(in: .whitespaces)
                        
                        if variableName == nil {
                            
                            var options : [String: String] = [:]
                            
                            // Fill in options
                            rightValueArray.removeFirst()
                            if rightValueArray.count == 1 && rightValueArray[0] == ">" {
                                // Empty Arguments
                            } else {
                                while rightValueArray.count > 0 {
                                    let array = rightValueArray[0].split(separator: ":")
                                    //print("2", array)
                                    rightValueArray.removeFirst()
                                    if array.count == 2 {
                                        let optionName = array[0].lowercased().trimmingCharacters(in: .whitespaces)
                                        var values = array[1].trimmingCharacters(in: .whitespaces)
                                        //print("option", optionName, "value", values)
                                                                            
                                        if values.count > 0 && values.last! != ">" {
                                            createError("No closing '>' for option '\(optionName)'")
                                        } else {
                                            values = String(values.dropLast())
                                        }
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
                                            asset.graph!.lines[error.line!] = newBranch
                                            processed = true
                                        }
                                        
                                        if processed == false {

                                            if level == 0 {
                                                asset.graph!.nodes.append(newBranch)
                                                currentBranch = []
                                                
                                                if newBranch.context == .Analytical {
                                                    asset.graph!.sdfNodes.append(newBranch)
                                                } else
                                                if newBranch.context == .SDF {
                                                    asset.graph!.sdfNodes.append(newBranch)
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
                        if rightValueArray.count > 1 {
                            // Variable
                            asset.graph!.lines[error.line!] = nil//"Variable"
                            let possibleVariableType = rightValueArray[0].trimmingCharacters(in: .whitespaces)
                            if possibleVariableType == "Float4" {
                                rightValueArray.removeFirst()
                                let array = rightValueArray[0].split(separator: ",")
                                if array.count == 4 {
                                    
                                    let x : Float; if let v = Float(array[0].trimmingCharacters(in: .whitespaces)) { x = v } else { x = 0 }
                                    let y : Float; if let v = Float(array[1].trimmingCharacters(in: .whitespaces)) { y = v } else { y = 0 }
                                    let z : Float; if let v = Float(array[2].trimmingCharacters(in: .whitespaces)) { z = v } else { z = 0 }
                                    let w : Float; if let v = Float(array[3].dropLast().trimmingCharacters(in: .whitespaces)) { w = v } else { w = 0 }

                                    let value = Float4(variableName!, x, y, z, w)
                                    asset.graph!.addVariable(value)
                                    processed = true
                                } else { createError() }
                            } else
                            if possibleVariableType == "Float3" {
                                rightValueArray.removeFirst()
                                let array = rightValueArray[0].split(separator: ",")
                                if array.count == 3 {
                                    
                                    let x : Float; if let v = Float(array[0].trimmingCharacters(in: .whitespaces)) { x = v } else { x = 0 }
                                    let y : Float; if let v = Float(array[1].trimmingCharacters(in: .whitespaces)) { y = v } else { y = 0 }
                                    let z : Float; if let v = Float(array[2].trimmingCharacters(in: .whitespaces)) { z = v } else { z = 0 }

                                    let value = Float3(variableName!, x, y, z)
                                    asset.graph!.addVariable(value)
                                    processed = true
                                } else { createError() }
                            } else
                            if possibleVariableType == "Float2" {
                                rightValueArray.removeFirst()
                                let array = rightValueArray[0].split(separator: ",")
                                if array.count == 2 {
                                    
                                    let x : Float; if let v = Float(array[0].trimmingCharacters(in: .whitespaces)) { x = v } else { x = 0 }
                                    let y : Float; if let v = Float(array[1].dropLast().trimmingCharacters(in: .whitespaces)) { y = v } else { y = 0 }

                                    let value = Float2(variableName!, x, y)
                                    asset.graph!.addVariable(value)
                                    processed = true
                                } else { createError() }
                            } else
                            if possibleVariableType == "Float" {
                                rightValueArray.removeFirst()
                                let value : Float; if let v = Float(rightValueArray[0].dropLast().trimmingCharacters(in: .whitespaces)) { value = v } else { value = 0 }
                                asset.graph!.addVariable(Float1(variableName!, value))
                                processed = true
                            } else
                            if possibleVariableType == "Int" {
                                rightValueArray.removeFirst()
                                let value : Int; if let v = Int(rightValueArray[0].dropLast().trimmingCharacters(in: .whitespaces)) { value = v } else { value = 0 }
                                asset.graph!.addVariable(Int1(variableName!, value))
                                processed = true
                            } else
                            if possibleVariableType == "Bool" {
                                rightValueArray.removeFirst()
                                let value : Bool; if let v = Bool(rightValueArray[0].dropLast().trimmingCharacters(in: .whitespaces)) { value = v } else { value = false }
                                asset.graph!.addVariable(Bool1(variableName!, value))
                                processed = true
                            } else
                            if possibleVariableType == "Text" {
                                rightValueArray.removeFirst()
                                let v = String(rightValueArray[0].dropLast().trimmingCharacters(in: .whitespaces))
                                asset.graph!.addVariable(Text1(variableName!, v))
                                processed = true
                            } else { error.error = "Unrecognized Variable type '\(possbibleCmd)'" }
                        }
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
        core.scriptEditor?.gotoLine(node.lineNr+1)
    }
    
    /// Get the graph options for the current node
    func getOptions() -> [GraphOption]
    {
        var options : [GraphOption] = []
        
        if let node = currentNode {
            //options += node.getOptions()
            if let line = getLine(node.lineNr) {
                print(line)
                options += extractOptionsFromLine(node, line)
            }
        }
        
        return options
    }
    
    /// extract GraphOptions from the line
    func extractOptionsFromLine(_ node: GraphNode, _ str: String) -> [GraphOption]
    {
        var graphOptions : [GraphOption] = []
        var options      : [String: String] = [:]

        var leftOfComment: String

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
        //let level = (str.prefix(while: {$0 == " "}).count) / 4

        leftOfComment = leftOfComment.trimmingCharacters(in: .whitespaces)
        
        var rightValueArray : [String.SubSequence]
            
        if leftOfComment.firstIndex(of: "<") != nil {
            rightValueArray = leftOfComment.split(separator: "<")
        } else {
            rightValueArray = leftOfComment.split(separator: " ")
        }
        
        if rightValueArray.count > 0 {

        // Fill in options
        rightValueArray.removeFirst()
            if rightValueArray.count == 1 && rightValueArray[0] == ">" {
                // Empty Arguments
            } else {
                while rightValueArray.count > 0 {
                    let array = rightValueArray[0].split(separator: ":")
                    //print("2", array)
                    rightValueArray.removeFirst()
                    if array.count == 2 {
                        let optionName = array[0].lowercased().trimmingCharacters(in: .whitespaces)
                        var values = array[1].trimmingCharacters(in: .whitespaces)
                        //print("option", optionName, "value", values)
                                                            
                        if values.count > 0 && values.last! != ">" {
                        } else {
                            values = String(values.dropLast())
                        }
                        options[optionName] = String(values)
                    } else { rightValueArray = [] }
                }
            }
        }
                
        let nodeOptions = node.getOptions()
        var error = CompileError()

        if let asset = core.assetFolder.getAsset("main", .Source) {
            for (key, _) in options {
                for nO in nodeOptions {
                    if nO.name.lowercased() == key {
                        if nO.variable.getType() == .Float {

                            if let f1 = extractFloat1Value(options, container: asset.graph!, error: &error, name: key) {
                                nO.variable = f1
                                graphOptions.append(nO)
                            }
                        }
                    }
                }
            }
        }
                
        return graphOptions
    }
    
    /// Returns the given line
    func getLine(_ line: Int32) -> String? {

        var rc : String? = nil
        guard let asset = core.assetFolder.getAsset("main", .Source) else {
            return nil
        }
        
        let ns = asset.value as NSString
        var lineNumber  : Int32 = 0
        
        ns.enumerateLines { (str, _) in
            
            if line == lineNumber {
                rc = str
            }
            
            lineNumber += 1
        }
        
        return rc
    }
}
