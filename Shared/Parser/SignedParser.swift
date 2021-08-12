//
//  SignedProcessor.swift
//  SignedParser
//
//  Created by Markus Moenig on 12/8/21.
//

import Foundation

struct CodeError
{
    var line            : Int32? = nil
    var column          : Int32? = 0
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
        SignedNodeRef("Building", { () -> SignedNode in return SignedNode(role: .Building) }),
        SignedNodeRef("Object", { () -> SignedNode in return SignedNode(role: .Object) }),
        SignedNodeRef("Area", { () -> SignedNode in return SignedNode(role: .Area) }),
    ]
    
    var rootNode                : SignedNode? = nil
    
    init(_ model: Model) {
        self.model = model
    }
    
    /// Parses the project and displays errors
    func parse() {
     
        var error = CodeError()
        rootNode = nil
        
        let ns = model.project.code as NSString
        var lineNumber  : Int32 = 0
        
        //var currentTree     : GraphTree? = nil
        //var currentBranch   : [GraphNode] = []
        //var lastLevel       : Int = -1
        
        var hierarchy         : [SignedNode] = []
        var unresolved        = ""
        
        /// Adds a node to the hierarchy
        func tryToAddNode(name: String) -> Bool {
            for r in nodeRefs {
                if r.name == name {
                    let node = r.createNode()
                    
                    if rootNode == nil {
                        rootNode = node
                    }
                    
                    if let last = hierarchy.last {
                        last.children.append(node)
                        node.parent = last
                    }
                    
                    hierarchy.append(node)
                    return true
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
                    leftOfComment = String(values[1])
                    
                    if let variableName = variableName {
                        if let last = hierarchy.last {
                            print("adding", variableName, "=", leftOfComment, last)

                            last.parameters[variableName] = leftOfComment
                        }
                    }
                }
            } else {                
                if leftOfComment.contains("{") {
                    
                    var nodeName = ""
                    
                    let arr = leftOfComment.components(separatedBy: "{")
                    let leftOfBracket = arr[0].trimmingCharacters(in: .whitespaces)
                    if leftOfBracket.count > 0 {
                        nodeName = leftOfBracket
                    } else {
                        nodeName = unresolved
                    }
                    
                    if tryToAddNode(name: nodeName) == false {
                        error.error = "Could not find Module '\(nodeName)'"
                    }
                } else
                if leftOfComment.contains("}") && hierarchy.count > 0 {
                    hierarchy.removeLast()
                } else {
                    unresolved = leftOfComment
                }
            }
            
            lineNumber += 1
        }
                
        if error.error != nil {
            model.codeEditor?.setErrors([error])
        } else {
            model.codeEditor?.clearAnnotations()
        }
    }
    
    /// Build 3D
    func build() {
        
        guard let modeler = model.modeler, let rootNode = rootNode else {
            return
        }
        
        let cmd = SignedCommand("Ground", role: .GeometryAndMaterial, action: .Add, primitive: .Box,
                                       data: ["Transform" : SignedData([SignedDataEntity("Position", float3(0,-0.9,0)) ]),
                                              "Geometry": SignedData([SignedDataEntity("Size", float3(0.6,0.4,0.6) * Float(Modeler_Global_Scale))])
                                             ], material: SignedMaterial(albedo: float3(0.5,0.5,0.5), metallic: 1, roughness: 0.3))
        modeler.executeCommand(cmd)
        model.renderer?.restart()
    }
}

