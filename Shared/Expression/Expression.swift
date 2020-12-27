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
        ExpressionNodeItem("*", {() -> ExpressionNode in return MultiplyNode() }),
    ]
        
    init()
    {
    }
    
    var values      : [AnyObject?] = []
    var uncomsumed  : [Int] = []
    
    var currentAtom : ExpressionNode? = nil
    
    var nodes       : [ExpressionNode] = []
    
    func parse(expression: String, context: VariableContainer, error: inout CompileError)
    {
        print("parse", expression)
        
        var offset      : Int = 0
        var token       : String = ""
        
        /// Extract a substring until one of the given tokens is encountered and set token to it
        func extractUpToToken(_ tokenList: [String]) -> String
        {
            var result = ""
            
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
        
        while offset < expression.count {
            let element = extractUpToToken([" ", "<"])
            
            // " " means a standalone expression
            if token == " " {
                if let f = Float(element) {
                    uncomsumed.append(values.count)
                    values.append(Float1(f))
                    
                    if uncomsumed.count == 2 {
                        // We have two values, need an atom
                        if let atom = currentAtom {
                            atom.setupAtom(self, uncomsumed, &error)
                            if error.error != nil { return }
                            uncomsumed = [values.count]
                            values.append(nil)
                            atom.execute(self)
                            nodes.append(atom)
                        }
                    }
                } else
                if let atomNode = getAtom(element) {
                    currentAtom = atomNode
                }
            } else
            if token == "<" {
                let parameters = extractUpToTokenHierarchy([">"], "<")
                if let variable = BaseVariable.createType(element, context: context, parameters: parameters) {
                }
            }
            //print(element, offset)
        }        
    }
    
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
}
