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
    var destIndex : Int! = nil

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
    
    func toMetal(_ context: ExpressionContext) -> String
    {
        return ""
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
                        if options[i].rules == .SameTypeAsPrevious && type != lastType && lastType != nil {
                            error.error = "Wrong type \(type) for parameter \(i+1) of \(functionName). Needs to be \(lastType!)."
                            return false
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
        
        if argumentsIn.count != options.count {
            error.error = "Wrong number of parameters for \(functionName): \(argumentsIn.count). Should be \(options.count)."
            return false
        }
        
        return true
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
        var id           = UUID()
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
        ExpressionNodeItem("abs", {() -> ExpressionNode in return AbsFuncNode() }),
        ExpressionNodeItem("sin", {() -> ExpressionNode in return SinFuncNode() }),
        ExpressionNodeItem("cos", {() -> ExpressionNode in return CosFuncNode() }),
        ExpressionNodeItem("min", {() -> ExpressionNode in return MinFuncNode() }),
        ExpressionNodeItem("max", {() -> ExpressionNode in return MaxFuncNode() }),
        ExpressionNodeItem("mod", {() -> ExpressionNode in return ModFuncNode() }),
        ExpressionNodeItem("dot", {() -> ExpressionNode in return DotFuncNode() }),
        ExpressionNodeItem("pow", {() -> ExpressionNode in return PowFuncNode() }),
        ExpressionNodeItem("clamp", {() -> ExpressionNode in return ClampFuncNode() }),
        ExpressionNodeItem("mix", {() -> ExpressionNode in return MixFuncNode() }),
        ExpressionNodeItem("step", {() -> ExpressionNode in return StepFuncNode() }),
        ExpressionNodeItem("length", {() -> ExpressionNode in return LengthFuncNode() }),
        ExpressionNodeItem("normalize", {() -> ExpressionNode in return NormalizeFuncNode() }),
        ExpressionNodeItem("reflect", {() -> ExpressionNode in return ReflectFuncNode() }),
        ExpressionNodeItem("noise2D", {() -> ExpressionNode in return Noise2DFuncNode() }),
        
        ExpressionNodeItem("ParamFloat", {() -> ExpressionNode in return ParamFloatFuncNode() }),
        ExpressionNodeItem("Float3", {() -> ExpressionNode in return Float3FuncNode() })
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
    
    var funcParams  : [ExpressionNode] = []
    
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
                } else
                // Test for String
                if element.starts(with: "\"") {
                    resultType = .Constant
                    values.append(Text1(element.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)))
                } else {
                    if element.isEmpty == false {
                        error.error = "Unknown expression \'\(element)\'"
                    }
                }
            } else
            if token == "<" {
                let parameters = extractUpToTokenHierarchy([">"], "<")
                
                if let variable = BaseVariable.createTypeFromParameters(element, container: container, parameters: parameters, error: &error) {
                    
                    if variable.isConstant() == false {
                        resultType = .Variable
                    }
                    
                    uncomsumed.append(values.count)
                    values.append(variable)
                    
                    testForConsumption()
                } else
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
                }
            }
            
            if error.error != nil {
                return
            }
            
            //print(expression, resultType)
            //print(element, offset)
        }
    }
    
    /// Converts the expression to metal code
    func toMetal(embedded: Bool = false) -> String
    {
        var code = ""
        
        if nodes.isEmpty == false {
            for node in nodes {
                node.execute(self)
                code += node.toMetal(self)
                
                print("xx", node.name, node.toMetal(self))
                
                if node.destIndex != nil {
                    // Function node
                    values[node.destIndex]?.chained = true
                } else {
                    // Atom
                    
                    let index = node.indices[1] + 1
                    if index < values.count {
                        values[index]?.chained = true
                    }
                }
            }
        } else {
            if values.count >= 1 {
                if let result = values[values.count - 1] {
                    if result.components > 1 && result.name.isEmpty {
                        code += "\(result.getSIMDName())(\(result.toString()))"
                    } else {
                        code += "\(result.toString())"
                    }
                }
            }
        }
        
        if embedded == false {
            code += ";\n"
        }
        
        return code
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
                    ref.name = variable.name
                    ref.reference = variable
                    ref.qualifiers = indices
                    return ref
                } else
                if indices.count == 2 {
                    let ref = Float2()
                    ref.name = variable.name
                    ref.reference = variable
                    ref.qualifiers = indices
                    return ref
                } else
                if indices.count == 3 {
                    let ref = Float3()
                    ref.name = variable.name
                    ref.reference = variable
                    ref.qualifiers = indices
                    return ref
                } else
                if indices.count == 4 {
                    let ref = Float4()
                    ref.name = variable.name
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
