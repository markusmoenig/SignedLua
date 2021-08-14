//
//  SignedExpression.swift
//  SignedExpression
//
//  Created by Markus Moenig on 14/8/21.
//

import Foundation

class SignedExpression {
    
    var expression      : String
    var offset          : Int

    var token           : String = ""

    init(_ str: String, offset: Int = 0) {
        expression = str
        self.offset = offset
    }
    
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
    
    /// Returns the remaining characters in the expression
    func remaining() -> String {
        return extractUpToToken([]).trimmingCharacters(in: .whitespaces)
    }
}
