//
//  SignedParser.swift
//  SignedParser
//
//  Created by Markus Moenig on 12/8/21.
//

import Foundation

struct CodeError
{
    var line            : Int32 = 0
    var column          : Int32 = 0
    var error           : String? = nil
    var type            : String = "error"
}

class SignedNodeRef
{
    var name         : String
    var createNode   : () -> SignedNode
    
    init(_ name: String, _ createNode: @escaping () -> SignedNode)
    {
        self.name = name
        self.createNode = createNode
    }
}

class SignedParser {
    
    let model                   : Model
    
    var nodeRefs                : [SignedNodeRef] =
    [
        SignedNodeRef("Building", { () -> SignedNode in return SignedBuildingNode() }),
        SignedNodeRef("Object", { () -> SignedNode in return SignedObjectNode() }),
        SignedNodeRef("Wall", { () -> SignedNode in return SignedWallNode() }),
        SignedNodeRef("Material", { () -> SignedNode in return SignedMaterialNode() }),
        
        SignedNodeRef("build", { () -> SignedNode in return SignedBuildNode() }),
    ]
    
    var topLevelNodes           : [SignedNode] = []
    
    init(_ model: Model) {
        self.model = model
    }
    
    /// Parses the project and displays errors
    func parse() {
     
        var error = CodeError()
        topLevelNodes = []
        
        let ns = model.project.code as NSString
        var lineNumber  : Int32 = 0
        
        //var currentTree     : GraphTree? = nil
        //var currentBranch   : [GraphNode] = []
        //var lastLevel       : Int = -1
        
        var hierarchy         : [SignedNode] = []
        
        var unresolved        = ""
        var unresolvedLine    : Int32 = 0
        
        /// Adds a node to the hierarchy
        func tryToAddNode(name: String, argumentsString: String) -> Bool {
            for r in nodeRefs {
                if r.name == name {
                    let node = r.createNode()
                    
                    if error.error == nil {
                        node.verifyArguments(parser: self, str: argumentsString, error: &error)
                        
                        if error.error == nil {
                            
                            if let last = hierarchy.last {
                                last.children!.append(node)
                                node.parent = last
                            } else {
                                topLevelNodes.append(node)
                            }
                            
                            hierarchy.append(node)
                            return true
                        }
                    }
                }
            }
            return false
        }
        
        ns.enumerateLines { (str, _) in
            
            if error.error != nil { return }
            error.line = lineNumber
            
            // Get the string left of a potential comment marker
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
            
            leftOfComment = leftOfComment.trimmingCharacters(in: .whitespaces)

            // If empty, bail out, nothing todo
            if leftOfComment.count == 0 {
                lineNumber += 1
                return
            }
            
            // Checking for assignment
            
            var variableName : String? = nil

            if leftOfComment.contains(" = ") {
                let values : [String] = leftOfComment.components(separatedBy: "=")
                
                if values.count == 2 {
                    variableName = String(values[0]).trimmingCharacters(in: .whitespaces)
                    leftOfComment = String(values[1]).trimmingCharacters(in: .whitespaces)
                    
                    if let variableName = variableName {
                        if let last = hierarchy.last {
                            if let property = self.extractProperty(str: leftOfComment, error: &error) {
                                last.properties[variableName] = property
                            }
                        }
                    }
                }
            } else {                
                if leftOfComment.contains("{") {
                    
                    var cmdLine = ""
                    
                    var startLine : Int32 = 0
                    
                    let arr = leftOfComment.components(separatedBy: "{")
                    let leftOfBracket = arr[0].trimmingCharacters(in: .whitespaces)
                    if leftOfBracket.count > 0 {
                        cmdLine = leftOfBracket
                        startLine = error.line + 1
                    } else {
                        cmdLine = unresolved
                        startLine = unresolvedLine + 1
                    }
                    
                    let expr = SignedExpression(cmdLine)
                    let nodeName = expr.extractUpToToken([" ", "("])
                    let args = (expr.token + expr.remaining()).trimmingCharacters(in: .whitespaces)
                    
                    print("node name", nodeName, "args", args)
                    
                    if tryToAddNode(name: nodeName, argumentsString: args) == false {
                        if error.error == nil {
                            error.error = "Could not find Module '\(nodeName)'"
                        }
                    } else {
                        hierarchy.last!.line = startLine
                    }
                } else
                if leftOfComment.contains("}") && hierarchy.count > 0 {
                    hierarchy.last!.endLine = error.line + 1
                    hierarchy.removeLast()
                } else {
                    unresolved = leftOfComment
                    unresolvedLine = error.line
                }
            }
            
            lineNumber += 1
        }
                
        if error.error != nil {
            model.codeEditor?.setErrors([error])
        } else {
            model.codeEditor?.clearAnnotations()
        }
        
        model.modelChanged.send()
    }
    
    /**
     Splits a "," separated list of parameters while keeping track of the <> hierarchy.
     - Parameter parameters: The list of parameters
     - Returns: The separated list
     */
    func splitParameters(_ parameters: String) -> [String] {
        var arguments : [String] = []
        
        var hierarchy : Int = 0
        var offset    : Int = 0
        
        var arg       = ""
        
        while offset < parameters.count {
            if parameters[offset] == " " {
                if hierarchy == 0 {
                    if arg.count > 0 {
                        arguments.append(arg.trimmingCharacters(in: .whitespaces))
                    }
                    arg = ""
                } else {
                    arg.append(parameters[offset])
                }
            } else
            if parameters[offset] == "\"" {
                if hierarchy == 0 {
                    hierarchy = 1
                } else {
                    hierarchy = 0
                }
                arg.append(parameters[offset])
            } else {
                arg.append(parameters[offset])
            }
            offset += 1
        }
        
        if arg.isEmpty == false {
            arguments.append(arg.trimmingCharacters(in: .whitespaces))
        }
                
        return arguments
    }
    
    /// Extracts the node arguments
    func extractArguments(argumentsString: String, error: inout CodeError) -> [SignedProperty] {
        var rc : [SignedProperty] = []
        
        let args = splitParameters(argumentsString)
        
        for a in args {
            if let property = extractProperty(str: a, error: &error) {
                rc.append(property)
            }
        }
        
        return rc
    }
    
    /// Extract property
    func extractProperty(str: String, error: inout CodeError) -> SignedProperty? {
        print("extractProperty", str)
        
        var property : SignedProperty? = nil
        
        if str.starts(with: "\"") {
            property = SignedProperty(role: .Text)
            property!.text = str.replacingOccurrences(of: "\"", with: "")
        } else
        if let number = Float(str) {
            property = SignedProperty(role: .Value1D)
            property!.data.x = number
        } else
        if str.contains(",") {
            let arr = str.components(separatedBy: ",")
            if arr.count == 2 {
                if let v1 = Float(arr[0].trimmingCharacters(in: .whitespaces)), let v2 = Float(arr[1].trimmingCharacters(in: .whitespaces)) {
                    property = SignedProperty(role: .Value2D)
                    property!.data.x = v1
                    property!.data.y = v2
                } else {
                    error.error = "Syntax Error"
                }
            } else
            if arr.count == 3 {
                if let v1 = Float(arr[0].trimmingCharacters(in: .whitespaces)), let v2 = Float(arr[1].trimmingCharacters(in: .whitespaces)), let v3 = Float(arr[2].trimmingCharacters(in: .whitespaces)) {
                    property = SignedProperty(role: .Value3D)
                    property!.data.x = v1
                    property!.data.y = v2
                    property!.data.z = v3
                } else {
                   error.error = "Syntax Error"
               }
            }
        }
        
        return property
    }
    
    func gotoNode(node: SignedNode) {
        model.codeEditor?.gotoLine(node.line)
    }
    
    /// Build 3D
    func build() {
        
        guard let modeler = model.modeler else {
            return
        }
        
        modeler.clear()
        model.renderer?.restart()
        
        /*
        let cmd = SignedCommand("Ground", role: .GeometryAndMaterial, action: .Add, primitive: .Box,
                                       data: ["Transform" : SignedData([SignedDataEntity("Position", float3(0,-0.9,0)) ]),
                                              "Geometry": SignedData([SignedDataEntity("Size", float3(0.6,0.4,0.6) * Float(Modeler_Global_Scale))])
                                             ], material: SignedMaterial(albedo: float3(0.5,0.5,0.5), metallic: 1, roughness: 0.3))
        */
        
        let context = SignedContext(model: model)
        
        for node in topLevelNodes {
            node.execute(context: context)
        }
    }
}

