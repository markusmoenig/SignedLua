//
//  ScriptProcessor.swift
//  Signed
//
//  Created by Markus Moenig on 5/1/21.
//

import Foundation

// https://stackoverflow.com/questions/24092884/get-nth-character-of-a-string-in-swift-programming-language
extension String {
    var length: Int {
        return count
    }
    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }
    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }
    subscript (r: Range<Int>) -> String {
            let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                                upper: min(length, max(0, r.upperBound))))
            let start = index(startIndex, offsetBy: range.lowerBound)
            let end = index(start, offsetBy: range.upperBound - range.lowerBound)
            return String(self[start ..< end])
        }
    }
}

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

//
//  Expression.swift
//  Signed (iOS)
//
//  Created by Markus Moenig on 18/12/20.
//

import Foundation

// https://stackoverflow.com/questions/24092884/get-nth-character-of-a-string-in-swift-programming-language
extension String {

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

class ExpressionNode {

    var name                : String = ""
    
    var argumentsIn         : [ExpressionContext] = []
    var indices             : [Int] = []
    var resultType          : ExpressionContext.ResultType = .Constant

    /// The destination index for the result
    var destIndex : Int = 0

    init(_ name: String)
    {
        self.name = name
    }
    
    /// An atom gets passed the indices to two input values and writes the result to the next  index of the second (right) value
    func setupAtom(_ context: ExpressionContext,_ indices: [Int],_ error: inout CompileError)
    {
    }
    
    /// A function gets passed the parameter string it has to evaluate itself
    func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        return nil
    }
    
    func execute(_ context: ExpressionContext)
    {
    }
    
    /// Get help text
    func getHelp() -> String
    {
        return ""
    }
    
    /// Get options
    func getOptions() -> [GraphOption]
    {
        return []
    }

    ///
    func verifyOptions(_ functionName : String,_ container: VariableContainer, _ parameters: String,_ error: inout CompileError) -> Bool
    {
        let options = getOptions()
        let array = splitParameters(parameters)
        
        var lastType : BaseVariable.VariableType? = nil
        
        print(functionName, options.count, array.count)
        if options.count != array.count {
            error.error = "Wrong number of parameters for \(functionName): \(array.count). Should be \(options.count)."
            return false
        }
        
        for i in 0..<options.count {
            let context = ExpressionContext()
            context.parse(expression: array[i], container: container, error: &error)
            if error.error == nil {
                
                if let rc = context.execute() {
                    
                    let type = rc.getType()
                    // Check type
                    var rightType = false
                    if type == options[i].variable.getType() {
                        rightType = true
                    } else {
                        for v in options[i].optionals {
                            if type == v.getType() {
                                rightType = true
                                break
                            }
                        }
                    }
                    
                    if rightType {
                        var passesRules = false
                        if options[i].rules == .SameTypeAsPrevious && type != lastType {
                            error.error = "Wrong type \(type) for parameter \(i+1) of \(functionName). Needs to be \(lastType!)."
                        } else {
                            passesRules = true
                        }
                        
                        if passesRules {
                            lastType = type
                            if context.isConstant() == false {
                                resultType = .Variable
                            }
                            argumentsIn.append(context)
                        }
                    } else {
                        error.error = "Wrong type \(type) for parameter \(i+1) of \(functionName)."
                        return false
                    }
                }
            } else {
                return false
            }
        }
        
        return true
    }
    
    // Utilities
    func splitIntoOne(_ functionName : String,_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> ExpressionContext?
    {
        let array = splitParameters(parameters)
        if array.count == 1 {
            let arg1Context = ExpressionContext()
            arg1Context.parse(expression: array[0], container: container, error: &error)
            
            if error.error != nil { return nil }
            
            return arg1Context
        } else {
            error.error = "Wrong number of parameters for \(functionName)"
        }
        
        return nil
    }
    
    func splitIntoTwo(_ functionName : String,_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> (ExpressionContext, ExpressionContext)?
    {
        let array = splitParameters(parameters)
        if array.count == 2 {
            let arg1Context = ExpressionContext()
            arg1Context.parse(expression: array[0], container: container, error: &error)
            
            if error.error != nil { return nil }
            
            let arg2Context = ExpressionContext()
            arg2Context.parse(expression: array[1], container: container, error: &error)
            
            if error.error != nil { return nil }
            
            return (arg1Context, arg2Context)
        } else {
            error.error = "Wrong number of parameters for \(functionName)"
        }
        
        return nil
    }
    
    func splitIntoThree(_ functionName : String,_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> (ExpressionContext, ExpressionContext, ExpressionContext)?
    {
        let array = splitParameters(parameters)
        if array.count == 3 {
            let arg1Context = ExpressionContext()
            arg1Context.parse(expression: array[0], container: container, error: &error)
            
            if error.error != nil { return nil }
            
            let arg2Context = ExpressionContext()
            arg2Context.parse(expression: array[1], container: container, error: &error)
            
            if error.error != nil { return nil }
            
            let arg3Context = ExpressionContext()
            arg3Context.parse(expression: array[2], container: container, error: &error)
            
            if error.error != nil { return nil }
            
            return (arg1Context, arg2Context, arg3Context)
        } else {
            error.error = "Wrong number of parameters for \(functionName)"
        }
        
        return nil
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
            if parameters[offset] == "," {
                if hierarchy == 0 {
                    arguments.append(arg.trimmingCharacters(in: .whitespaces))
                    arg = ""
                } else {
                    arg.append(parameters[offset])
                }
            } else
            if parameters[offset] == "<" {
                hierarchy += 1
                arg.append(parameters[offset])
            } else
            if parameters[offset] == ">" {
                hierarchy -= 1
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
}

class ExpressionContext
{
    enum ResultType {
        case Constant, Variable
    }
    
    class ExpressionNodeItem
    {
        var name         : String
        var createNode   : () -> ExpressionNode
        
        init(_ name: String,_ createNode: @escaping () -> ExpressionNode)
        {
            self.name = name
            self.createNode = createNode
        }
    }
    
    var atoms               : [ExpressionNodeItem] =
    [
        ExpressionNodeItem("*", {() -> ExpressionNode in return MultiplyAtomNode() }),
        ExpressionNodeItem("/", {() -> ExpressionNode in return DivisionAtomNode() }),
        ExpressionNodeItem("-", {() -> ExpressionNode in return MinusAtomNode() }),
        ExpressionNodeItem("+", {() -> ExpressionNode in return AddAtomNode() }),
    ]
    
    var functions           : [ExpressionNodeItem] =
    [
        ExpressionNodeItem("dot", {() -> ExpressionNode in return DotFuncNode() }),
        ExpressionNodeItem("pow", {() -> ExpressionNode in return PowFuncNode() }),
        ExpressionNodeItem("clamp", {() -> ExpressionNode in return ClampFuncNode() }),
        ExpressionNodeItem("mix", {() -> ExpressionNode in return MixFuncNode() }),
        ExpressionNodeItem("step", {() -> ExpressionNode in return StepFuncNode() }),
        ExpressionNodeItem("normalize", {() -> ExpressionNode in return NormalizeFuncNode() }),
        ExpressionNodeItem("reflect", {() -> ExpressionNode in return ReflectFuncNode() }),
        ExpressionNodeItem("noise2D", {() -> ExpressionNode in return Noise2DFuncNode() }),
        ExpressionNodeItem("castray", {() -> ExpressionNode in return CastRayFuncNode() }),
        ExpressionNodeItem("castshadowray", {() -> ExpressionNode in return CastShadowRayFuncNode() })
     ]
        
    init()
    {
    }
    
    var resultType  : ResultType = .Constant
    
    var values      : [BaseVariable?] = []
    var uncomsumed  : [Int] = []
    
    var currentAtom : ExpressionNode? = nil
    
    var nodes       : [ExpressionNode] = []
    var wrongType   : String = ""
    
    var cResult     : BaseVariable? = nil

    var cResult1    : Float1? = nil
    var cResult2    : Float2? = nil
    var cResult3    : Float3? = nil
    var cResult4    : Float4? = nil
    
    var lastResult  : BaseVariable? = nil
    
    var expression  : String = ""
    
    @inlinable func isConstant() -> Bool {
        return resultType == .Constant
    }
    
    /**
     Parses a an expression based on variables stored in the VariableContainer. If an error occurs it will be stored in the error struct.
     - Parameter expression: The expression to parse
     - Parameter defaultVariableType: The default variable type of this expression if any. This is for example used to be able to construct a Float3<> just from 0, 1, 2 if we know the parameter has to be a Float3<> variable.
     - Parameter error: Stores the error if any.
     */

    func parse(expression: String, container: VariableContainer, defaultVariableType: BaseVariable.VariableType? = nil, error: inout CompileError)
    {
        self.expression = expression
        //print("parse", expression)
        
        var offset      : Int = 0
        var token       : String = ""
        
        /**
         Extract a substring until one of the given tokens is encountered and set token to it
         - Parameters tokenList: The list of tokens to test against
         - Returns: The string up to one of the given tokens
         */
        func extractUpToToken(_ tokenList: [String]) -> String
        {
            var result = ""
            token = ""
            
            while offset < expression.count {
                for t in tokenList {
                    if expression[offset] == t {
                        token = t
                        offset += 1
                        return result
                    }
                }
                result += expression[offset]
                offset += 1
            }
            
            if token == "" && offset >= expression.count {
                token = "EOL"
            }
            
            return result
        }
        
        /**
        Extract a substring until one of the given tokens is encountered and the hierarchy level for the opener is 0
         - Parameters tokenList: The list of tokens to test against
         - Parameters tokenOpener: The opening token for a hierarchy
         - Returns: The string up to one of the given tokens.
        */
        func extractUpToTokenHierarchy(_ tokenList: [String],_ tokenOpener: String) -> String
        {
            var result = ""
            var hierarchy : Int = 0
            
            while offset < expression.count {
                for t in tokenList {
                    if expression[offset] == t {
                        if hierarchy == 0 {
                            token = t
                            offset += 1
                            return result
                        } else {
                            hierarchy -= 1
                        }
                    } else
                    if expression[offset] == tokenOpener {
                        hierarchy += 1
                    }
                }
                result += expression[offset]
                offset += 1
            }
            
            return result
        }
        
        /// Test if we can consume two values
        func testForConsumption() {
            if uncomsumed.count == 2 {
                // We have two values, need an atom
                if let atom = currentAtom {
                    atom.setupAtom(self, uncomsumed, &error)
                    if error.error != nil { return }
                    uncomsumed = [values.count]
                    values.append(nil)
                    atom.execute(self)
                    nodes.append(atom)
                } else {
                    error.error = "Syntax error"
                }
            }
        }
        
        // First, if we know the variable type, try to construct the variable from the given expression, we only need to test the vector types
        if let defaultVariableType = defaultVariableType {
            if defaultVariableType == .Float4 {
                if let v = container.getVariableValue(expression), v as? Float4 != nil {
                    values.append(v)
                    return
                }
                let v = Float4(container: container, parameters: expression, error: &error)
                if error.error == nil {
                    // Success
                    values.append(v)
                    return
                }
            } else
            if defaultVariableType == .Float3 {
                if let v = container.getVariableValue(expression), v as? Float3 != nil {
                    values.append(v)
                    return
                }
                let v = Float3(container: container, parameters: expression, error: &error)
                if error.error == nil {
                    // Success
                    values.append(v)
                    return
                }
            } else
            if defaultVariableType == .Float2 {
                if let v = container.getVariableValue(expression), v as? Float2 != nil {
                    values.append(v)
                    return
                }
                let v = Float2(container: container, parameters: expression, error: &error)
                if error.error == nil {
                    // Success
                    values.append(v)
                    return
                }
            } else
            if defaultVariableType == .Int {
                if let v = container.getVariableValue(expression), v as? Int1 != nil {
                    values.append(v)
                    return
                }
                if let i = Int(expression) {
                    values.append(Int1(i))
                    return
                }
            } else
            if defaultVariableType == .Bool {
                if let v = container.getVariableValue(expression), v as? Bool1 != nil {
                    values.append(v)
                    return
                }
                if let b = Bool(expression) {
                    values.append(Bool1(b))
                    return
                }
            }
        }
        
        while offset < expression.count {
            let element = extractUpToToken([" ", "<"])
            
            // " " means a standalone expression
            if token == " " || token == "EOL" {
                // Test for standalone Float
                if let f = Float(element) {
                    uncomsumed.append(values.count)
                    values.append(Float1(f))
                    
                    testForConsumption()
                } else
                // Test for an atom: *, +, etc
                if let atomNode = getAtom(element) {
                    currentAtom = atomNode
                } else
                // Test for variable reference
                if let variableRef = getVariableReference(element, container: container, error: &error) {
                    uncomsumed.append(values.count)
                    values.append(variableRef)
                    
                    if variableRef.isConstant() == false {
                        resultType = .Variable
                    }
                    testForConsumption()
                } else {
                    if element.isEmpty == false {
                        error.error = "Unknown expression \'\(element)\'"
                    }
                }
            } else
            if token == "<" {
                let parameters = extractUpToTokenHierarchy([">"], "<")
                
                if let functionNode = getFunction(element) {
                    functionNode.destIndex = values.count
                    if let result = functionNode.setupFunction(container, parameters, &error) {
                    
                        if functionNode.resultType == .Variable {
                            resultType = .Variable
                        }
                        
                        if error.error != nil { return }

                        uncomsumed.append(values.count)
                        values.append(result)
                        testForConsumption()
                        nodes.append(functionNode)
                    }
                } else
                if let variable = BaseVariable.createTypeFromParameters(element, container: container, parameters: parameters, error: &error) {
                    
                    if variable.isConstant() == false {
                        resultType = .Variable
                    }
                    
                    uncomsumed.append(values.count)
                    values.append(variable)
                    
                    testForConsumption()
                }
            }
            
            if error.error != nil {
                return
            }
            
            //print(expression, resultType)
            //print(element, offset)
        }
    }
    
    /// Returns a possible result
    @inlinable func execute() -> BaseVariable?
    {
        if cResult != nil { return cResult }
        
        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            if let result = values[values.count - 1] {
                if resultType == .Constant {
                    cResult = result
                }
                lastResult = result
                return result
            }
        }
        return nil
    }
    
    /// Returns a possible Float1 result
    @inlinable func executeForFloat1() -> Float1?
    {
        if cResult1 != nil { return cResult1 }

        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let f1 = result as? Float1 {
                if resultType == .Variable {
                    f1.context = self
                } else {
                    cResult1 = f1
                }
                return f1
            } else {
                wrongType = ""
                if result != nil {
                    wrongType = result!.getTypeName()
                }
            }
        }
        return nil
    }
    
    /// Returns a possible Int1 result
    @inlinable func executeForInt1() -> Int1?
    {
        //if cResult1 != nil { return cResult1 }

        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let i1 = result as? Int1 {
                //if resultType == .Variable {
                    i1.context = self
                //} else {
                    //cResult1 = f1
                //}
                return i1
            } else {
                wrongType = ""
                if result != nil {
                    wrongType = result!.getTypeName()
                }
            }
        }
        return nil
    }
    
    /// Returns a possible Bool1 result
    @inlinable func executeForBool1() -> Bool1?
    {
        //if cResult1 != nil { return cResult1 }

        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let b1 = result as? Bool1 {
                //if resultType == .Variable {
                    b1.context = self
                //} else {
                    //cResult1 = f1
                //}
                return b1
            } else {
                wrongType = ""
                if result != nil {
                    wrongType = result!.getTypeName()
                }
            }
        }
        return nil
    }
    
    /// Returns a possible Float2 result
    @inlinable func executeForFloat2() -> Float2?
    {
        if cResult2 != nil { return cResult2 }

        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let f2 = result as? Float2 {
                if resultType == .Variable {
                    f2.context = self
                } else {
                    cResult2 = f2
                }
                return f2
            } else {
                wrongType = ""
                if result != nil {
                    wrongType = result!.getTypeName()
                }
            }
        }
        return nil
    }
    
    /// Returns a possible Float3 result
    @inlinable func executeForFloat3() -> Float3?
    {
        if cResult3 != nil { return cResult3 }

        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let f3 = result as? Float3 {
                if resultType == .Variable {
                    f3.context = self
                } else {
                    cResult3 = f3
                }
                return f3
            } else {
                wrongType = ""
                if result != nil {
                    wrongType = result!.getTypeName()
                }
            }
        }
        return nil
    }
    
    /// Returns a possible Float4 result
    @inlinable func executeForFloat4() -> Float4?
    {
        if cResult4 != nil { return cResult4 }

        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let f4 = result as? Float4{
                if resultType == .Variable {
                    f4.context = self
                } else {
                    cResult4 = f4
                }
                return f4
            } else {
                wrongType = ""
                if result != nil {
                    wrongType = result!.getTypeName()
                }
            }
        }
        return nil
    }
    
    /// Attempts to find an atom node for the given expression
    func getAtom(_ expression: String) -> ExpressionNode? {
        for a in atoms {
            if a.name == expression {
                return a.createNode()
            }
        }
        return nil
    }
    
    /// Attempts to find a function node for the given expression
    func getFunction(_ expression: String) -> ExpressionNode? {
        for f in functions {
            if f.name == expression {
                return f.createNode()
            }
        }
        return nil
    }
    
    /// Returns a variable reference
    func getVariableReference(_ expression: String, container: VariableContainer, error: inout CompileError) -> BaseVariable? {
        
        var variableExpression = expression
        var qualifierExpression = ""

        if expression.contains(".") {
            let array = expression.split(separator: ".")
            if array.count == 2 {
                variableExpression = String(array[0])
                qualifierExpression = String(array[1])
            } else {
                return nil
            }
        }
        
        if let variable = container.getVariableValue(variableExpression) {
            
            if qualifierExpression == "" {
                return variable
            } else {
                // First get a list of valid indices
                
                var indices : [Int] = []
                for stringQualifier in qualifierExpression {
                    if stringQualifier.lowercased() == "x" {
                        indices.append(0)
                    } else
                    if stringQualifier.lowercased() == "y" {
                        indices.append(1)
                    } else
                    if stringQualifier.lowercased() == "z" {
                        indices.append(2)
                    } else
                    if stringQualifier.lowercased() == "w" {
                        indices.append(3)
                    } else {
                        error.error = "Invalid qualifier \'\(stringQualifier)\'"
                    }
                }
                
                if indices.count == 1 {
                    let ref = Float1()
                    ref.reference = variable
                    ref.qualifiers = indices
                    return ref
                } else
                if indices.count == 2 {
                    let ref = Float2()
                    ref.reference = variable
                    ref.qualifiers = indices
                    return ref
                } else
                if indices.count == 3 {
                    let ref = Float3()
                    ref.reference = variable
                    ref.qualifiers = indices
                    return ref
                } else
                if indices.count == 4 {
                    let ref = Float4()
                    ref.reference = variable
                    ref.qualifiers = indices
                    return ref
                } else {
                    error.error = "Invalid amount of qualifiers for \'\(expression)\'"
                }
            }
        }
        
        return nil
    }
}
