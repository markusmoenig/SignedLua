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
        if let leftResult = arguments!.0.execute() {
            if leftResult.getType() == .Float3 {
                if let rightResult = arguments!.1.execute() {
                    context.values[destIndex] = Float1(simd_dot(leftResult.toSIMD3(), rightResult.toSIMD3()))
                }
            } else
            if leftResult.getType() == .Float4 {
                if let rightResult = arguments!.1.execute() {
                    context.values[destIndex] = Float1(simd_dot(leftResult.toSIMD4(), rightResult.toSIMD4()))
                }
            } else
            if leftResult.getType() == .Float2 {
                if let rightResult = arguments!.1.execute() {
                    context.values[destIndex] = Float1(simd_dot(leftResult.toSIMD2(), rightResult.toSIMD2()))
                }
            }
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
                
                if input.getType() == .Float3 {
                    if let r3 = arguments!.0.execute() {
                        let v = Float3()
                        
                        v.fromSIMD(r3.toSIMD3().clamped(lowerBound: float3(r12, r12, r12), upperBound: float3(r13, r13, r13)))
                        context.values[destIndex] = v
                    }
                } else
                if input.getType() == .Float {
                    if let r1 = arguments!.0.execute() {
                        let v = Float1()
                        
                        v.x = simd_clamp(r1.toSIMD1(), r12, r13)
                        context.values[destIndex] = v
                    }
                } else
                if input.getType() == .Float4 {
                    if let r4 = arguments!.0.execute() {
                        let v = Float4()
                        
                        v.fromSIMD(r4.toSIMD4().clamped(lowerBound: float4(repeating: r12), upperBound: float4(repeating: r13)))
                        context.values[destIndex] = v
                    }
                } else
                if input.getType() == .Float2 {
                    if let r2 = arguments!.0.execute() {
                        let v = Float2()
                        
                        v.fromSIMD(r2.toSIMD2().clamped(lowerBound: float2(r12, r12), upperBound: float2(r13, r13)))
                        context.values[destIndex] = v
                    }
                }
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
            if a1 != nil && a2 != nil && a1!.getType() == a2!.getType() {
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
        if let f41 = arguments!.0.execute() as? Float4 {
            if let f42 = arguments!.1.execute() as? Float4 {
                let r41 = f41.toSIMD()
                let r42 = f42.toSIMD()
                
                let v = Float4();
                v.x = pow(r41.x, r42.x)
                v.y = pow(r41.y, r42.y)
                v.z = pow(r41.z, r42.z)
                v.z = pow(r41.w, r42.w)

                context.values[destIndex] = v
            }
        } else
        if let f31 = arguments!.0.execute() as? Float3 {
            if let f32 = arguments!.1.execute() as? Float3 {
                let r31 = f31.toSIMD()
                let r32 = f32.toSIMD()
                
                let v = Float3();
                v.x = pow(r31.x, r32.x)
                v.y = pow(r31.y, r32.y)
                v.z = pow(r31.z, r32.z)

                context.values[destIndex] = v
            }
        } else
        if let f21 = arguments!.0.execute() as? Float2 {
            if let f22 = arguments!.1.execute() as? Float2 {
                let r21 = f21.toSIMD()
                let r22 = f22.toSIMD()
                
                let v = Float2();
                v.x = pow(r21.x, r22.x)
                v.y = pow(r21.y, r22.y)

                context.values[destIndex] = v
            }
        } else
        if let f11 = arguments!.0.execute() as? Float1 {
            if let f12 = arguments!.1.execute() as? Float1 {
                let r11 = f11.toSIMD()
                let r12 = f12.toSIMD()
                
                let v = Float1();
                v.x = pow(r11, r12)

                context.values[destIndex] = v
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
        if let result = argument!.execute() {
            if result.getType() == .Float3 {
                let rc = simd_normalize(result.toSIMD3()); let v = Float3(); v.fromSIMD(rc)
                context.values[destIndex] = v
            }
            if result.getType() == .Float4 {
                let rc = simd_normalize(result.toSIMD4()); let v = Float4(); v.fromSIMD(rc)
                context.values[destIndex] = v
            }
            if result.getType() == .Float2 {
                let rc = simd_normalize(result.toSIMD2()); let v = Float2(); v.fromSIMD(rc)
                context.values[destIndex] = v
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
