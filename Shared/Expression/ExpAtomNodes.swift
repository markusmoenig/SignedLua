//
//  ExpAtomNodes.swift
//  Signed
//
//  Created by Markus Moenig on 18/12/20.
//

import Foundation

class MultiplyNode : ExpressionNode {
    
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
        if let left = context.values[indices[0]] as? Float1 {
        
            if let right = context.values[indices[1]] as? Float1 {
                context.values[indices[1] + 1] = Float1(left.toSIMD() * right.toSIMD())
            }
        }
    }
}
