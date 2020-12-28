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
    
    var indices             : [Int] = []
    
    init(_ name: String)
    {
        self.name = name
    }
    
    /// An atom gest passed the indices to two input values and writes the result to the next  index of the second (right) value
    func setupAtom(_ context: ExpressionContext,_ indices: [Int],_ error: inout CompileError)
    {
    }
    
    func execute(_ context: ExpressionContext)
    {
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
        
    init()
    {
    }
    
    var resultType  : ResultType = .Constant
    
    var values      : [BaseVariable?] = []
    var uncomsumed  : [Int] = []
    
    var currentAtom : ExpressionNode? = nil
    
    var nodes       : [ExpressionNode] = []
    var wrongType   : String = ""
    
    func parse(expression: String, container: VariableContainer, error: inout CompileError)
    {
        //print("parse", expression)
        
        var offset      : Int = 0
        var token       : String = ""
        
        /// Extract a substring until one of the given tokens is encountered and set token to it
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
        
        /// Extract a substring until one of the given tokens is encountered and the hierarchy level for the opener is 0
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
        
        while offset < expression.count {
            let element = extractUpToToken([" ", "<"])
            
            // " " means a standalone expression
            if token == " " || token == "EOL" {
                if let f = Float(element) {
                    uncomsumed.append(values.count)
                    values.append(Float1(f))
                    
                    testForConsumption()
                } else
                if let atomNode = getAtom(element) {
                    currentAtom = atomNode
                } else
                if let variableRef = getVariableReference(element, container: container, error: &error) {
                    uncomsumed.append(values.count)
                    values.append(variableRef)
                    
                    testForConsumption()
                } else {
                    error.error = "Unknown expression \'\(element)\'"
                }
            } else
            if token == "<" {
                let parameters = extractUpToTokenHierarchy([">"], "<")
                if let variable = BaseVariable.createType(element, container: container, parameters: parameters, error: &error) {
                    uncomsumed.append(values.count)
                    values.append(variable)
                    
                    testForConsumption()
                }
            }
            
            if error.error != nil {
                return                
            }
            //print(element, offset)
        }
    }
    
    /// Returns a possible result
    @inlinable func execute() -> BaseVariable?
    {
        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            if let result = values[values.count - 1] {
                return result
            }
        }
        return nil
    }
    
    /// Returns a possible Float1 result
    @inlinable func executeForFloat1() -> Float1?
    {
        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let f1 = result as? Float1 {
                f1.context = self
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
    
    /// Returns a possible Float2 result
    @inlinable func executeForFloat2() -> Float2?
    {
        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let f2 = result as? Float2 {
                f2.context = self
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
        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let f3 = result as? Float3 {
                f3.context = self
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
        for node in nodes {
            node.execute(self)
        }
        
        if values.count >= 1 {
            let result = values[values.count - 1]
            if let f4 = result as? Float4{
                f4.context = self
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
