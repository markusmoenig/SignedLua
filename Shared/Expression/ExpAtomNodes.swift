//
//  ExpAtomNodes.swift
//  Signed
//
//  Created by Markus Moenig on 18/12/20.
//

import Foundation

class MultiplyAtomNode : ExpressionNode {
    
    init()
    {
        super.init("*")
    }
    
    override func setupAtom(_ context: ExpressionContext,_ indices: [Int],_ error: inout CompileError)
    {
        self.indices = indices
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        let left = context.values[indices[0]]
        let right = context.values[indices[1]]

        if let left = left as? Float1 {
            if let right = right as? Float1 {
                context.values[indices[1] + 1] = Float1(left.toSIMD() * right.toSIMD())
            }
        }
        if let left = left as? Float1 {
            if let right = right as? Float3 {
                let rcLeft = left.toSIMD(); let rcRight = right.toSIMD()
                context.values[indices[1] + 1] = Float3(rcLeft * rcRight.x, rcLeft * rcRight.y, rcLeft * rcRight.z)
            }
        }
    }
}

class MinusAtomNode : ExpressionNode {
    
    init()
    {
        super.init("-")
    }
    
    override func setupAtom(_ context: ExpressionContext,_ indices: [Int],_ error: inout CompileError)
    {
        self.indices = indices
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        let left = context.values[indices[0]]
        let right = context.values[indices[1]]

        if let left = left as? Float1 {
            if let right = right as? Float1 {
                context.values[indices[1] + 1] = Float1(left.toSIMD() - right.toSIMD())
            }
        }
    }
}

