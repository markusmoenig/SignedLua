//
//  FunctionNodes.swift
//  Signed
//
//  Created by Markus Moenig on 30/12/20.
//

import Foundation
import simd

class DotFuncNode : ExpressionNode {
    
    var cResult   : BaseVariable? = nil

    init()
    {
        super.init("dot")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return Float1(0)
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let leftResult = argumentsIn[0].execute() else {
            return
        }
        
        guard let rightResult = argumentsIn[1].execute() else {
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
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "dot(\(argumentsIn[0].toMetal(embedded: true)), \(argumentsIn[1].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Dot product between two vectors."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Vector", "", optionals: [Float2(), Float4()]),
            GraphOption(Float3(1,1,1), "Vector", "", optionals: [Float2(), Float4()], rules: .SameTypeAsPrevious)
        ]
        return options
    }
}

class MixFuncNode : ExpressionNode {
    
    init()
    {
        super.init("mix")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let mixValue = argumentsIn[2].executeForFloat1()?.x {

            guard let in1 = argumentsIn[0].execute() else {
                return
            }
            
            guard let in2 = argumentsIn[1].execute() else {
                return
            }
            
            let v = in1.createType()
            
            for i in 0..<v.components {
                v[i] = simd_mix(in1[i], in2[i], mixValue)
            }
            context.values[destIndex] = v
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "mix(\(argumentsIn[0].toMetal(embedded: true)), \(argumentsIn[1].toMetal(embedded: true)), \(argumentsIn[2].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Mixes two values."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Value 1", "", optionals: [Float1(), Float2(), Float4()]),
            GraphOption(Float3(1,1,1), "Value 2", "", optionals: [Float1(), Float2(), Float4()], rules: .SameTypeAsPrevious),
            GraphOption(Float3(1,1,1), "Mix Factor", "", optionals: [Float1()])
        ]
        return options
    }
}

class ClampFuncNode : ExpressionNode {
    
    init()
    {
        super.init("clamp")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let lower = argumentsIn[1].executeForFloat1()?.x {
            if let upper = argumentsIn[2].executeForFloat1()?.x {

                guard let input = argumentsIn[0].execute() else {
                    return
                }
                
                let v = input.createType()
                
                for i in 0..<v.components {
                    v[i] = simd_clamp(input[i], lower, upper)
                }
                context.values[destIndex] = v
            }
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "clamp(\(argumentsIn[0].toMetal(embedded: true)), \(argumentsIn[1].toMetal(embedded: true)), \(argumentsIn[2].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Clamps a value between a lower and upper bound."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Value", "", optionals: [Float1(), Float2(), Float4()]),
            GraphOption(Float1(0), "Lower Bound", "", optionals: [Float3(), Float2(), Float4()]),
            GraphOption(Float1(0), "Upper Bound", "", optionals: [Float3(), Float2(), Float4()])
        ]
        return options
    }
}

class PowFuncNode : ExpressionNode {
    
    init()
    {
        super.init("pow")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let p = argumentsIn[1].executeForFloat1() {
            guard let input = argumentsIn[0].execute() else {
                return
            }
            
            let v = input.createType()
            
            for i in 0..<v.components {
                v[i] = pow(input[i], p.x)
            }
            context.values[destIndex] = v
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "pow(\(argumentsIn[0].toMetal(embedded: true)), \(argumentsIn[1].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Raises the value of the first parameter to the power of the second."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Value", "", optionals: [Float1(), Float2(), Float4()]),
            GraphOption(Float1(0), "Power", "")
        ]
        return options
    }
}

class Rotate2DFuncNode : ExpressionNode {
    
    init()
    {
        super.init("rotate2D")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "rotate(\(argumentsIn[0].toMetal(embedded: true)), radians(\(argumentsIn[1].toMetal(embedded: true))))"
    }
    
    override func getHelp() -> String
    {
        return "Raises the value of the first parameter to the power of the second."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float2(1,1), "Domain", ""),
            GraphOption(Float1(0), "Angle", "")
        ]
        return options
    }
}

class ModFuncNode : ExpressionNode {
    
    init()
    {
        super.init("mod")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let p = argumentsIn[1].executeForFloat1() {
            guard let input = argumentsIn[0].execute() else {
                return
            }
            
            let v = input.createType()
            
            for i in 0..<v.components {
                v[i] = fmod(input[i], p.x)
            }
            context.values[destIndex] = v
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "mod(\(argumentsIn[0].toMetal(embedded: true)), \(argumentsIn[1].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Computes the value of one parameter modulo another."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Value", "", optionals: [Float1(), Float2(), Float4()]),
            GraphOption(Float1(0), "Modulo", "")
        ]
        return options
    }
}

class StepFuncNode : ExpressionNode {
    
    init()
    {
        super.init("step")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let edge = argumentsIn[0].executeForFloat1() {
            guard let value = argumentsIn[1].execute() else {
                return
            }
            
            let v = value.createType()
            
            for i in 0..<v.components {
                v[i] = simd_step(edge.x, value[i])
            }
            context.values[destIndex] = v
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "step(\(argumentsIn[0].toMetal(embedded: true)), \(argumentsIn[1].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Generate a step function by comparing two values."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(0), "Edge", ""),
            GraphOption(Float3(1,1,1), "Value", "", optionals: [Float1(), Float2(), Float4()])
        ]
        return options
    }
}

class SinFuncNode : ExpressionNode {
    
    init()
    {
        super.init("sin")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let value = argumentsIn[0].execute() else {
            return
        }
        
        let v = value.createType()
        
        for i in 0..<v.components {
            v[i] = sin(value[i])
        }
        context.values[destIndex] = v
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "sin(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns the sin of the given value."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(0), "Value", "", optionals: [Float2(), Float3(), Float4()]),
        ]
        return options
    }
}

class CosFuncNode : ExpressionNode {
    
    init()
    {
        super.init("cos")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let value = argumentsIn[0].execute() else {
            return
        }
        
        let v = value.createType()
        
        for i in 0..<v.components {
            v[i] = cos(value[i])
        }
        context.values[destIndex] = v
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "cos(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns the cos of the given value."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(0), "Value", "", optionals: [Float2(), Float3(), Float4()]),
        ]
        return options
    }
}

class MinFuncNode : ExpressionNode {
    
    init()
    {
        super.init("min")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let edge = argumentsIn[0].executeForFloat1() {
            guard let value = argumentsIn[1].execute() else {
                return
            }
            
            let v = value.createType()
            
            for i in 0..<v.components {
                v[i] = min(edge.x, value[i])
            }
            context.values[destIndex] = v
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "min(\(argumentsIn[0].toMetal(embedded: true)), \(argumentsIn[1].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns the minimum of the two values."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(0), "Value1", "", optionals: [Float2(), Float3(), Float4()]),
            GraphOption(Float1(1), "Value2", "", optionals: [Float2(), Float3(), Float4()], rules: .SameTypeAsPrevious)
        ]
        return options
    }
}

class MaxFuncNode : ExpressionNode {
    
    init()
    {
        super.init("max")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let edge = argumentsIn[0].executeForFloat1() {
            guard let value = argumentsIn[1].execute() else {
                return
            }
            
            let v = value.createType()
            
            for i in 0..<v.components {
                v[i] = max(edge.x, value[i])
            }
            context.values[destIndex] = v
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "max(\(argumentsIn[0].toMetal(embedded: true)), \(argumentsIn[1].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns the maximum of the two values."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(0), "Value1", "", optionals: [Float2(), Float3(), Float4()]),
            GraphOption(Float1(1), "Value2", "", optionals: [Float2(), Float3(), Float4()], rules: .SameTypeAsPrevious)
        ]
        return options
    }
}

class AbsFuncNode : ExpressionNode {
    
    init()
    {
        super.init("abs")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let result = argumentsIn[0].execute() else {
            return
        }
        
        if result.getType() == .Float3 {
            context.values[destIndex] = Float3(abs(result.toSIMD3()))
        } else
        if result.getType() == .Float4 {
            context.values[destIndex] = Float4(abs(result.toSIMD4()))
        } else
        if result.getType() == .Float2 {
            context.values[destIndex] = Float2(abs(result.toSIMD2()))
        } else
        if result.getType() == .Float {
            context.values[destIndex] = Float1(abs(result.toSIMD1()))
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "abs(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns the absolute value of the parameter."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Value", "", optionals: [Float1(), Float2(), Float4()])
        ]
        return options
    }
}

class NormalizeFuncNode : ExpressionNode {
    
    init()
    {
        super.init("normalize")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let result = argumentsIn[0].execute() else {
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
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "normalize(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Normalizes a vector."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Vector", "", optionals: [Float2(), Float4()])
        ]
        return options
    }
}

class FractFuncNode : ExpressionNode {
    
    init()
    {
        super.init("fract")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let result = argumentsIn[0].execute() else {
            return
        }
        
        if result.getType() == .Float3 {
            context.values[destIndex] = Float3(fract(result.toSIMD3()))
        } else
        if result.getType() == .Float4 {
            context.values[destIndex] = Float4(fract(result.toSIMD4()))
        } else
        if result.getType() == .Float2 {
            context.values[destIndex] = Float2(fract(result.toSIMD2()))
        } else
        if result.getType() == .Float {
            context.values[destIndex] = Float1(simd_fract(result.toSIMD1()))
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "fract(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns the fractional part of the value."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Value", "", optionals: [Float1(), Float2(), Float4()])
        ]
        return options
    }
}

class FloorFuncNode : ExpressionNode {
    
    init()
    {
        super.init("floor")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let result = argumentsIn[0].execute() else {
            return
        }
        
        if result.getType() == .Float3 {
            context.values[destIndex] = Float3(floor(result.toSIMD3()))
        } else
        if result.getType() == .Float4 {
            context.values[destIndex] = Float4(floor(result.toSIMD4()))
        } else
        if result.getType() == .Float2 {
            context.values[destIndex] = Float2(floor(result.toSIMD2()))
        } else
        if result.getType() == .Float {
            context.values[destIndex] = Float1(floor(result.toSIMD1()))
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "floor(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns the integer part of the value."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Value", "", optionals: [Float1(), Float2(), Float4()])
        ]
        return options
    }
}

class RoundFuncNode : ExpressionNode {
    
    init()
    {
        super.init("round")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let input = argumentsIn[0].execute() else {
            return
        }
        
        let v = input.createType()
        
        for i in 0..<v.components {
            v[i] = round(input[i])
        }
        context.values[destIndex] = v
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "round(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns the rounded integer part of the value."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Value", "", optionals: [Float1(), Float2(), Float4()])
        ]
        return options
    }
}

class LengthFuncNode : ExpressionNode {
    
    init()
    {
        super.init("length")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let result = argumentsIn[0].execute() else {
            return
        }
        
        if result.getType() == .Float3 {
            context.values[destIndex] = Float1(simd_length(result.toSIMD3()))
        } else
        if result.getType() == .Float4 {
            context.values[destIndex] = Float1(simd_length(result.toSIMD4()))
        } else
        if result.getType() == .Float2 {
            context.values[destIndex] = Float1(simd_length(result.toSIMD2()))
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "length(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns the length of a vector."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Vector", "", optionals: [Float2(), Float4()])
        ]
        return options
    }
}

class Hash13FuncNode : ExpressionNode {
    
    init()
    {
        super.init("hash13")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return Float1(0)
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "hash13(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns a Float hash value for a Float3 value."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Value", "")
        ]
        return options
    }
}

class Hash31FuncNode : ExpressionNode {
    
    init()
    {
        super.init("hash31")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return Float3(0, 0, 0)
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "hash31(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Returns a Float3 hash value for a Float value.."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(1), "Value", "")
        ]
        return options
    }
}

class ReflectFuncNode : ExpressionNode {
        
    init()
    {
        super.init("reflect")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult?.createType()
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let leftResult = argumentsIn[0].execute() else {
            return
        }
        
        guard let rightResult = argumentsIn[1].execute() else {
            return
        }
        
        context.values[destIndex] = Float3(simd_reflect(leftResult.toSIMD3(), rightResult.toSIMD3()))
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "reflect(\(argumentsIn[0].toMetal(embedded: true)), \(argumentsIn[1].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "Calculate the reflection direction for an incident vector."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Incident vector", "", optionals: [Float2(), Float4()]),
            GraphOption(Float3(1,1,1), "Normal", "", optionals: [Float2(), Float4()])
        ]
        return options
    }
}

class ParamFloatFuncNode : ExpressionNode {
    
    init()
    {
        super.init("ParamFloat")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            resultType = .Variable
            let result = argumentsIn[1].lastResult
            if let text = argumentsIn[0].values[0] as? Text1, result != nil {

                result!.name = text.name.lowercased()
            }
            return result
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        context.funcParams.append(self)

        guard let result = argumentsIn[1].execute() else {
            return
        }
        
        if result.getType() == .Float {
            context.values[destIndex] = result
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return argumentsIn[1].toMetal(embedded: true)
    }
    
    override func getHelp() -> String
    {
        return "A named Float parameter."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Text1(""), "Name", ""),
            GraphOption(Float1(1), "Default", ""),
        ]
        return options
    }
}

class ParamFloat3FuncNode : ExpressionNode {
    
    init()
    {
        super.init("ParamFloat3")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            resultType = .Variable
            let result = argumentsIn[1].lastResult
            if let text = argumentsIn[0].values[0] as? Text1, result != nil {
                result!.name = text.name.lowercased()
            }
            return result
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        context.funcParams.append(self)

        guard let result = argumentsIn[1].execute() else {
            return
        }
        
        if result.getType() == .Float {
            context.values[destIndex] = result
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return argumentsIn[1].toMetal(embedded: true)
    }
    
    override func getHelp() -> String
    {
        return "A named Float3 parameter."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Text1(""), "Name", ""),
            GraphOption(Float3(1), "Default", ""),
        ]
        return options
    }
}

class Float3FuncNode : ExpressionNode {
    
    init()
    {
        super.init("Float3")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let result = argumentsIn[0].execute() else {
            return
        }
        
        if result.getType() == .Float3 {
            context.values[destIndex] = result
        }
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "float3(\(argumentsIn[0].toMetal(embedded: true)))"
    }
    
    override func getHelp() -> String
    {
        return "A Float3 variable consisting of 3 float values (x, y, z)."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0, 0, 0), "Value", ""),
        ]
        return options
    }
}

class BracketNode : ExpressionNode {
    
    init()
    {
        super.init("<>")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            return argumentsIn[0].lastResult
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        guard let result = argumentsIn[0].execute() else {
            return
        }
        
        context.values[destIndex] = result
    }
    
    override func toMetal(_ context: ExpressionContext) -> String
    {
        return "(" + argumentsIn[0].toMetal(embedded: true) + ")"
    }
    
    override func getHelp() -> String
    {
        return "A bracket."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Unknown1(""), "Expression", ""),
        ]
        return options
    }
}
