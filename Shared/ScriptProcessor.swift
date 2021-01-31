//
//  ScriptProcessor.swift
//  Signed
//
//  Created by Markus Moenig on 5/1/21.
//

import Foundation

class ScriptProcessor
{
    let core            : Core
    
    init(_ core: Core)
    {
        self.core = core
    }
    
    /**
     Replaces the given option in the current line / node after it has been changed in the UI.
     - Parameters option: The option to replace.
     */
    
    func replaceOptionInLine(_ option: GraphOption) {
        
        guard let asset = core.assetFolder.getAsset("main", .Source) else {
            return
        }
        
        if let node = core.graphBuilder.currentNode {
            if var line = getLine(node.lineNr) {
                
                var range = line.range(of: option.name + ":")
                if range == nil { range = line.range(of: option.name + " :") }
                
                if let range = range {
                    
                    let startIndex : Int = range.lowerBound.utf16Offset(in: line)
                        
                    var endIndex : Int = startIndex
                    var foundEndIndex = false
                    
                    while endIndex < line.count {
                        
                        if line[endIndex] == ">" {
                            foundEndIndex = true
                            break
                        }
                        endIndex += 1
                    }
                    
                    if foundEndIndex {
                        let end = String.Index(utf16Offset: endIndex, in: line)                        
                        line.replaceSubrange(range.lowerBound..<end, with: "\(option.name): \(option.variable.toString())")
                    }
                    core.scriptEditor.setAssetLine(asset, line: line)
                } else {
                    line.append("<\(option.name): \(option.variable.toString())>")
                    core.scriptEditor.setAssetLine(asset, line: line)
                }
            }
        }
    }
    
    func replaceFloat1InLine(_ map: [String:Float1]) {
        
        if let node = core.graphBuilder.currentNode {
            if var line = getLine(node.lineNr) {
                
                for (key, value) in map {
                
                    var range = line.range(of: key + ":")
                    if range == nil { range = line.range(of: key + " :") }
                    
                    if let range = range {
                        
                        let startIndex : Int = range.lowerBound.utf16Offset(in: line)
                            
                        var endIndex : Int = startIndex
                        var foundEndIndex = false
                        
                        while endIndex < line.count {
                            
                            if line[endIndex] == ">" {
                                foundEndIndex = true
                                break
                            }
                            endIndex += 1
                        }
                        
                        if foundEndIndex {
                            let end = String.Index(utf16Offset: endIndex, in: line)
                            line.replaceSubrange(range.lowerBound..<end, with: "\(key): \(String(value.x))")
                        }
                    }
                }
                
                guard let asset = core.assetFolder.getAsset("main", .Source) else {
                    return
                }
                core.scriptEditor.setAssetLine(asset, line: line)
            }
        }
    }
    
    func replaceFloat3InLine(_ map: [String:Float3], withUndo: Bool = true) {
        
        if let node = core.graphBuilder.currentNode {
            if var line = getLine(node.lineNr) {
                
                for (key, value) in map {
                
                    var range = line.range(of: key + ":")
                    if range == nil { range = line.range(of: key + " :") }
                    
                    if let range = range {
                        
                        let startIndex : Int = range.lowerBound.utf16Offset(in: line)
                            
                        var endIndex : Int = startIndex
                        var foundEndIndex = false
                        
                        while endIndex < line.count {
                            
                            if line[endIndex] == ">" {
                                foundEndIndex = true
                                break
                            }
                            endIndex += 1
                        }
                        
                        if foundEndIndex {
                            let end = String.Index(utf16Offset: endIndex, in: line)
                            line.replaceSubrange(range.lowerBound..<end, with: "\(key): \(value.toString())")
                        }
                    }
                }
                
                guard let asset = core.assetFolder.getAsset("main", .Source) else {
                    return
                }
                if withUndo == true {
                    core.scriptEditor.setAssetLine(asset, line: line)
                } else {
                    setLine(node.lineNr, line)
                }
            }
        }
    }
    
    /// Get the graph options for the current node
    func getOptions(_ all: Bool = true) -> [GraphOption]
    {
        var options : [GraphOption] = []
        
        if let node = core.graphBuilder.currentNode {
            if let line = getLine(node.lineNr) {
                options += extractOptionsFromLine(node, line)
            }
            
            func containsOption(_ name: String) -> Bool
            {
                for o in options {
                    if o.name == name {
                        return true
                    }
                }
                return false
            }
            
            if all {
                // Add the node options which are currently not present in the script
                let opts = node.getOptions()
                for o in opts {
                    if containsOption(o.name) == false {
                        options.append(o)
                    }
                }
            }
        }
        
        return options
    }
    
    /// extract GraphOptions from the line
    func extractOptionsFromLine(_ node: GraphNode, _ str: String) -> [GraphOption]
    {
        var graphOptions : [GraphOption] = []
        var ops          : [String: String] = [:]
        var options      : [(String, String)] = []

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
                        ops[optionName] = values
                        options.append((optionName, values))
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
                        if nO.variable.getType() == .Int {
                            if let i1 = extractInt1Value(ops, container: asset.graph!, error: &error, name: key) {
                                nO.variable = i1
                                graphOptions.append(nO)
                            }
                        } else
                        if nO.variable.getType() == .Float {
                            if let f1 = extractFloat1Value(ops, container: asset.graph!, error: &error, name: key) {
                                nO.variable = f1
                                graphOptions.append(nO)
                            }
                        } else
                        if nO.variable.getType() == .Float2 {
                            if let f2 = extractFloat2Value(ops, container: asset.graph!, error: &error, name: key) {
                                nO.variable = f2
                                graphOptions.append(nO)
                            }
                        } else
                        if nO.variable.getType() == .Float3 {
                            if let f3 = extractFloat3Value(ops, container: asset.graph!, error: &error, name: key) {
                                nO.variable = f3
                                graphOptions.append(nO)
                            }
                        } else
                        if nO.variable.getType() == .Float4 {
                            if let f4 = extractFloat4Value(ops, container: asset.graph!, error: &error, name: key) {
                                nO.variable = f4
                                graphOptions.append(nO)
                            }
                        }
                    }
                }
            }
        }
                
        return graphOptions
    }
    
    /**
     Returns the given line in the source
     -Parameters line: The line number
     -Returns: The requested line or nil
     */
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
    
    func setLine(_ line: Int32,_ value: String)
    {
        guard let asset = core.assetFolder.getAsset("main", .Source) else {
            return
        }
        
        let ns = asset.value as NSString
        var lineNumber  : Int32 = 0
        var output = ""
        
        ns.enumerateLines { (str, _) in
            
            if line == lineNumber {
                output += value + "\n"
            } else {
                output += str + "\n"
            }
            
            lineNumber += 1
        }
        
        asset.value = output
        core.scriptEditor.setAssetValue(asset, value: asset.value)
    }
}
