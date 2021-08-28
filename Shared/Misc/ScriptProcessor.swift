//
//  ScriptProcessor.swift
//  Signed
//
//  Created by Markus Moenig on 5/1/21.
//

import Foundation

class ScriptProcessor
{
    let core                : Core
    
    var currentFunction     : ExpressionContext.ExpressionNodeItem? = nil

    init(_ core: Core)
    {
        self.core = core
    }
    
    /**
     Replaces the given option in the current line / node after it has been changed in the UI.
     - Parameters option: The option to replace.
     */
    func replaceOptionInLine(_ option: GraphOption, useRaw: Bool = true) {
        
        guard let asset = core.assetFolder.getAsset("main", .Source) else {
            return
        }
        
        if currentFunction != nil {
            if let node = core.graphBuilder.currentNode {
                if var line = getLine(node.lineNr) {
                    
                    let start = String.Index(utf16Offset: option.startIndex, in: line)
                    let end = String.Index(utf16Offset: option.endIndex, in: line)
                    line.replaceSubrange(start..<end, with: "\(useRaw ? option.raw : option.variable.toString())")
            
                    //core.scriptEditor.setAssetLine(asset, line: line)
                }
            }
        } else {
        
            if let node = core.graphBuilder.currentNode {
                if var line = getLine(node.lineNr) {
                    
                    var range = line.range(of: option.name + ":")
                    if range == nil { range = line.range(of: option.name + " :") }
                    
                    if let range = range {
                        
                        let startIndex : Int = range.lowerBound.utf16Offset(in: line)
                            
                        var endIndex : Int = startIndex
                        var foundEndIndex = false
                        
                        var opener : Int = 0
                        while endIndex < line.count {
                            
                            if line[endIndex] == "<" {
                                opener += 1
                            } else
                            if line[endIndex] == ">" {
                                if opener == 0 {
                                    foundEndIndex = true
                                    break
                                } else {
                                    opener -= 1
                                }
                            }
                            endIndex += 1
                        }
                        
                        if foundEndIndex {
                            let end = String.Index(utf16Offset: endIndex, in: line)
                            line.replaceSubrange(range.lowerBound..<end, with: "\(option.name): \(useRaw ? option.raw : option.variable.toString())")
                        }
                        //core.scriptEditor.setAssetLine(asset, line: line)
                    } else {
                        line.append("<\(option.name): \(useRaw ? option.raw : option.variable.toString())>")
                        //core.scriptEditor.setAssetLine(asset, line: line)
                    }
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
                    } else {
                        line.append("<\(key): \(String(value.x))>")
                    }
                }
                
                guard let asset = core.assetFolder.getAsset("main", .Source) else {
                    return
                }
                //core.scriptEditor.setAssetLine(asset, line: line)
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
                    } else {
                        line.append("<\(key): \(value.toString())>")
                    }
                }
                
                guard let asset = core.assetFolder.getAsset("main", .Source) else {
                    return
                }
                if withUndo == true {
                    //core.scriptEditor.setAssetLine(asset, line: line)
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
        
        currentFunction = nil
        if let node = core.graphBuilder.currentNode {
            if let function = core.graphBuilder.currentFunction {
                
                // Function
                if let line = getLine(node.lineNr) {

                    var o = Int(core.graphBuilder.currentColumn)
                    // Extract Function Arguments
                        
                    while o < line.count && line[o] != "<" {
                        o += 1
                    }
                    
                    if line[o] == "<" {
                        
                        currentFunction = function
                        options = function.createNode().getOptions()
                        
                        o += 1
                        var depth = 0
                        
                        var arg = ""
                        var index = 0
                        
                        options[0].startIndex = o
                        var canBeColor = options[0].variable.getType() == .Float3
                        
                        while o < line.count && index < options.count {
                            
                            if line[o] == "<" {
                                depth += 1
                                arg.append(line[o])
                                canBeColor = false
                            } else
                            if line[o] == ">" {
                                if depth == 0 {
                                    options[index].raw = arg
                                    options[index].endIndex = o
                                    options[index].canBeColor = canBeColor
                                    break
                                } else {
                                    depth -= 1
                                    arg.append(line[o])
                                }
                            } else
                            if line[o] == "," {
                                if depth == 0 && options.count > 1 {
                                    options[index].raw = arg
                                    options[index].endIndex = o
                                    index += 1
                                    if index < options.count {
                                        options[index].startIndex = o + 1
                                    }
                                    arg = ""
                                } else {
                                    arg.append(line[o])
                                }
                            } else {
                                arg.append(line[o])
                            }
                            o += 1
                        }
                    }
                }
                
                return options
            } else {
                
                // Line Node
                
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
                            o.raw = o.variable.toString()
                            options.append(o)
                        }
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

        leftOfComment = leftOfComment.trimmingCharacters(in: .whitespaces)
                
        var error = CompileError()
        var rightValueArray = splitIntoCommandPlusOptions(leftOfComment, &error)

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
        
        //var error = CompileError()
        //let o = splitIntoCommandPlusOptions(leftOfComment, &error)
                
        let nodeOptions = node.getOptions()

        //if let asset = core.assetFolder.getAsset("main", .Source) {
            for (key, value) in options {
                for nO in nodeOptions {
                    if nO.name.lowercased() == key {
                        nO.raw = value
                        graphOptions.append(nO)
                        /*
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
                        }*/
                    }
                }
            }
        //}
                        
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
        //core.scriptEditor.setValue(asset, value: asset.value)
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
}
