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

class NormalizeFuncNode : ExpressionNode {
    
    var argument  : ExpressionContext? = nil
    var destIndex : Int = 0

    init()
    {
        super.init("normalize")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let arg = splitIntoOne(self.name, container, parameters, &error) {
            argument = arg
            let a1 = arg.execute()
            if a1 != nil {
                return a1
            } else { error.error = "Unsupported argument for \(name)<>" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let f4 = argument!.execute() as? Float4 {
            let rc = simd_normalize(f4.toSIMD()); let v = Float4(); v.fromSIMD(rc)
            context.values[destIndex] = v

        } else
        if let f3 = argument!.execute() as? Float3 {
            let rc = simd_normalize(f3.toSIMD()); let v = Float3(); v.fromSIMD(rc)
            context.values[destIndex] = v
        } else
        if let f2 = argument!.execute() as? Float2 {
            let rc = simd_normalize(f2.toSIMD()); let v = Float2(); v.fromSIMD(rc)
            context.values[destIndex] = v
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

class Noise2DFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext)? = nil
    var arg       : ExpressionContext? = nil
    var destIndex : Int = 0
    
    init()
    {
        super.init("noise2D")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let arg = splitIntoOne(self.name, container, parameters, &error) {
            let a1 = arg.execute();
            if a1 != nil && a1!.getType() == .Float2 {
                self.arg = arg
                return a1
            } else { error.error = "\(name)<> expects one Float2 parameter" }
        }
        return nil
    }
    
    // https://www.shadertoy.com/view/4dS3Wd
    @inlinable func hash(_ p: float2) -> Float
    {
        var p3 = simd_fract(float3(p.x, p.y, p.x) * 0.13)
        p3 += simd_dot(p3, float3(p3.y, p3.z, p3.x) + 3.333)
        return simd_fract((p3.x + p3.y) * p3.z)
    }
    
    @inlinable func noise(_ x: float2) -> Float
    {
        let i = floor(x)
        let f = simd_fract(x)

        let a : Float = hash(i)
        let b : Float = hash(i + float2(1.0, 0.0))
        let c : Float = hash(i + float2(0.0, 1.0))
        let d : Float = hash(i + float2(1.0, 1.0))

        let u : float2 = f * f * (3.0 - 2.0 * f)
        return simd_mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let arg = arg {
            if let f2 = arg.execute() as? Float2 {
                let rc = noise(f2.toSIMD())
                let v = Float1(); v.fromSIMD(rc)
                context.values[destIndex] = v
            }
        }
    }
}
