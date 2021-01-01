//
//  DenrimSpecific.swift
//  Signed
//
//  Created by Markus Moenig on 30/12/20.
//

import Foundation
import simd

class CastRayFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext)? = nil
    var destIndex : Int = 0
    
    init()
    {
        super.init("castRay")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let args = splitIntoTwo(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute(); let a2 = arguments!.1.execute()
            if a1 != nil && a2 != nil && a1!.getType() == a2!.getType() && a1!.getType() == .Float3 {
                return a1
            } else { error.error = "castRay<> expects two Float3 parameters" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let rayOrigin = arguments!.0.execute() as? Float3 {
            if let rayDirection = arguments!.1.execute() as? Float3 {

                //let local = context.copy()
                
                //context.values[destIndex] = v
            }
        }
    }
}
