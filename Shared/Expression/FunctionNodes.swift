//
//  FunctionNodes.swift
//  Signed
//
//  Created by Markus Moenig on 30/12/20.
//

import Foundation
import simd

class DotFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext)? = nil
    var destIndex : Int = 0

    init()
    {
        super.init("dot")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let args = splitIntoTwo(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute(); let a2 = arguments!.1.execute()
            if a1 != nil && a2 != nil && a1!.getType() == a2!.getType() {
                return a1
            } else { error.error = "Unsupported parameters for dot<>" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let f41 = arguments!.0.execute() as? Float4 {
            if let f42 = arguments!.1.execute() as? Float4 {
                context.values[destIndex] = Float1(simd_dot(f41.toSIMD(), f42.toSIMD()))
            }
        } else
        if let f31 = arguments!.0.execute() as? Float3 {
            if let f32 = arguments!.1.execute() as? Float3 {
                context.values[destIndex] = Float1(simd_dot(f31.toSIMD(), f32.toSIMD()))
            }
        } else
        if let f21 = arguments!.0.execute() as? Float2 {
            if let f22 = arguments!.1.execute() as? Float2 {
                context.values[destIndex] = Float1(simd_dot(f21.toSIMD(), f22.toSIMD()))
            }
        }
    }
}

class ReflectFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext)? = nil
    var destIndex : Int = 0
    
    init()
    {
        super.init("reflect")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let args = splitIntoTwo(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute(); let a2 = arguments!.1.execute()
            if a1 != nil && a2 != nil && a1!.getType() == a2!.getType() && a1!.getType() == .Float3 {
                return a1
            } else { error.error = "reflect<> expects two Float3 parameters" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let f31 = arguments!.0.execute() as? Float3 {
            if let f32 = arguments!.1.execute() as? Float3 {
                let rc = simd_reflect(f31.toSIMD(), f32.toSIMD())
                let v = Float3(); v.fromSIMD(rc)
                context.values[destIndex] = v
            }
        }
    }
}
