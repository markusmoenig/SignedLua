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
    
    var cResult   : BaseVariable? = nil

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
                if arguments!.0.isConstant() == false || arguments!.1.isConstant() == false {
                    resultType = .Variable
                }
                return Float1(0)
            } else { error.error = "Unsupported parameters for dot<>" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let leftResult = arguments!.0.execute() else {
            return
        }
        
        guard let rightResult = arguments!.1.execute() else {
            return
        }

        if leftResult.getType() == .Float3 {
            context.values[destIndex] = Float1(simd_dot(leftResult.toSIMD3(), rightResult.toSIMD3()))
        } else
        if leftResult.getType() == .Float4 {
            context.values[destIndex] = Float1(simd_dot(leftResult.toSIMD4(), rightResult.toSIMD4()))
        } else
        if leftResult.getType() == .Float2 {
            context.values[destIndex] = Float1(simd_dot(leftResult.toSIMD2(), rightResult.toSIMD2()))
        }
    }
}

class MixFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext, ExpressionContext)? = nil
    var destIndex : Int = 0

    init()
    {
        super.init("mix")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let args = splitIntoThree(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute(); let a2 = arguments!.1.execute(); let a3 = arguments!.2.execute()
            if a1 != nil && a2 != nil && a3 != nil && a1!.getType() == a2!.getType() && a3!.getType() == .Float {
                if arguments!.0.isConstant() == false || arguments!.1.isConstant() == false || arguments!.2.isConstant() == false {
                    resultType = .Variable
                }
                return a1
            } else { error.error = "Unsupported parameters for clamp<>" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let mixValue = arguments!.2.executeForFloat1()?.x {

            guard let in1 = arguments!.0.execute() else {
                return
            }
            
            guard let in2 = arguments!.1.execute() else {
                return
            }
            
            let v = in1.createType()
            
            for i in 0..<v.components {
                v[i] = simd_mix(in1[i], in2[i], mixValue)
            }
            context.values[destIndex] = v
        }
    }
}

class ClampFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext, ExpressionContext)? = nil
    var destIndex : Int = 0

    init()
    {
        super.init("clamp")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let args = splitIntoThree(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute(); let a2 = arguments!.1.execute(); let a3 = arguments!.2.execute()
            if a1 != nil && a2 != nil && a3 != nil && a2!.getType() == .Float && a3!.getType() == .Float {
                if arguments!.0.isConstant() == false || arguments!.1.isConstant() == false || arguments!.2.isConstant() == false {
                    resultType = .Variable
                }
                return a1
            } else { error.error = "Unsupported parameters for clamp<>" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let r12 = arguments!.1.executeForFloat1()?.x {
            if let r13 = arguments!.2.executeForFloat1()?.x {

                guard let input = arguments!.0.execute() else {
                    return
                }
                
                let v = input.createType()
                
                for i in 0..<v.components {
                    v[i] = simd_clamp(input[i], r12, r13)
                }
                context.values[destIndex] = v
            }
        }
    }
}

class PowFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext)? = nil
    var destIndex : Int = 0

    init()
    {
        super.init("pow")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let args = splitIntoTwo(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute(); let a2 = arguments!.1.execute()
            if a1 != nil && a2 != nil && a2!.getType() == .Float {
                if a1!.isConstant() == false || a2!.isConstant() == false {
                    resultType = .Variable
                }
                return a1
            } else { error.error = "Unsupported parameters for dot<>" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let p = arguments!.1.executeForFloat1() {
            guard let input = arguments!.0.execute() else {
                return
            }
            
            let v = input.createType()
            
            for i in 0..<v.components {
                v[i] = pow(input[i], p.x)
            }
            context.values[destIndex] = v
        }
    }
}

class StepFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext)? = nil
    var destIndex : Int = 0

    init()
    {
        super.init("step")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let args = splitIntoTwo(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute(); let a2 = arguments!.1.execute()
            if a1 != nil && a2 != nil && a2!.getType() == .Float {
                if a1!.isConstant() == false || a2!.isConstant() == false {
                    resultType = .Variable
                }
                return a1
            } else { error.error = "Unsupported parameters for step<>" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let p = arguments!.1.executeForFloat1() {
            guard let input = arguments!.0.execute() else {
                return
            }
            
            let v = input.createType()
            
            for i in 0..<v.components {
                v[i] = simd_step(input[i], p.x)
            }
            context.values[destIndex] = v
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
                if a1!.isConstant() == false {
                    resultType = .Variable
                }
                return a1
            } else { error.error = "Unsupported argument for \(name)<>" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let result = argument?.execute() else {
            return
        }
        
        if result.getType() == .Float3 {
            context.values[destIndex] = Float3(simd_normalize(result.toSIMD3()))
        } else
        if result.getType() == .Float4 {
            context.values[destIndex] = Float4(simd_normalize(result.toSIMD4()))
        } else
        if result.getType() == .Float2 {
            context.values[destIndex] = Float2(simd_normalize(result.toSIMD2()))
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
                if a1!.isConstant() == false || a2!.isConstant() == false {
                    resultType = .Variable
                }
                return a1
            } else { error.error = "reflect<> expects two Float3 parameters" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let leftResult = arguments!.0.execute() else {
            return
        }
        
        guard let rightResult = arguments!.1.execute() else {
            return
        }
        
        context.values[destIndex] = Float3(simd_reflect(leftResult.toSIMD3(), rightResult.toSIMD3()))
    }
}

class Noise2DFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext)? = nil
    var destIndex : Int = 0
    var smoothing : Int = 1
    
    init()
    {
        super.init("noise2D")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.destIndex = destIndex
        if let args = splitIntoTwo(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute()
            let a2 = arguments!.1.execute()
            if a1 != nil && a2 != nil && a1!.getType() == .Float2 && a2!.getType() == .Float {
                resultType = .Variable
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
        
    func fbm(_ p: float2) -> Float {
        var x = p
        var v : Float = 0.0
        var a : Float = 0.5
        let shift = float2(100, 100)
        // Rotate to reduce axial bias
        let rot = simd_float2x2(float2(cos(0.5), sin(0.5)), float2(-sin(0.5), cos(0.50)))
        for _ in 0..<smoothing {
            v += a * noise(x)
            x = rot * x * 2.0 + shift
            a *= 0.5
        }
        return v
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let arguments = arguments {
            if let f2 = arguments.0.execute() as? Float2 {
                if let f1 = arguments.1.execute() as? Float1 {
                    smoothing = Int(f1.x)
                    let rc = fbm(f2.toSIMD())
                    let v = Float1(); v.fromSIMD(rc)
                    context.values[destIndex] = v
                }
            }
        }
    }
}
