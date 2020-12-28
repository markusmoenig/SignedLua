//
//  Variables.swift
//  Signed
//
//  Created by Markus Moenig on 18/12/20.
//

import Foundation

class VariableContainer
{
    var variables           : [BaseVariable] = []

    /// Get the given variable
    func getVariableValue(_ name: String, parameters: [BaseVariable] = []) -> BaseVariable?
    {
        for v in variables {
            if v.name == name {
                return v
            }
        }
        return nil
    }
}

class BaseVariable {
    
    enum VariableType {
        case Invalid, Bool, Text, Int, Float, Float2, Float3, Float4
    }
    
    var context     : ExpressionContext? = nil    
    var name        : String = ""
    
    // If this variable is a reference to another variable
    var reference   : BaseVariable? = nil
    var qualifiers  : [Int] = []
    
    init(_ name: String)
    {
        self.name = name
    }
    
    /// Returns the variable type
    func getType() -> VariableType {
        return .Invalid
    }
    
    /// Return the typeName of the variable as a String, i.e. "Float1"
    func getTypeName() -> String {
        return "Invalid"
    }
    
    /// Return the variable in a readable form, like Float3<0, 1, 2>
    func toString() -> String {
        return ""
    }
    
    /// Creates a variables based on it's type, the context and it's string parameters, this is used to construct variables from text input
    static func createType(_ typeName: String, container: VariableContainer, parameters: String, error: inout CompileError) -> BaseVariable?
    {
        if typeName == "Float1" {
            return Float1(container: container, parameters: parameters, error: &error)
        }
        return nil
    }
    
    subscript(index: Int) -> Float {
        get {
            return 0
        }
    }
}

final class Float4 : BaseVariable
{
    var x           : Float = 1
    var y           : Float = 1
    var z           : Float = 1
    var w           : Float = 1

    init(_ name: String = "", _ x: Float = 1,_ y: Float = 1,_ z: Float = 1,_ w: Float = 1)
    {
        super.init(name)
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    
    init(_ x: Float = 1,_ y: Float = 1,_ z: Float = 1,_ w: Float = 1)
    {
        super.init("")
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    
    override func getType() -> VariableType {
        return .Float4
    }
    
    override func getTypeName() -> String {
        return "Float4"
    }
    
    @inlinable func toSIMD() -> SIMD4<Float>
    {
        if let ref = reference {
            return SIMD4<Float>(ref[qualifiers[0]], ref[qualifiers[1]], ref[qualifiers[2]], ref[qualifiers[3]])
        } else
        if let context = context {
            if let f4 = context.executeForFloat4() {
                return SIMD4<Float>(f4.x, f4.y, f4.z, f4.w)
            }
        }
        return SIMD4<Float>(x, y, z, w)
    }
    
    override subscript(index: Int) -> Float {
        get {
            if index == 1 {
                return y
            } else
            if index == 2 {
                return z
            } else
            if index == 3 {
                return w
            } else {
                return x
            }
        }
    }
}

final class Float3 : BaseVariable
{
    var x           : Float = 1
    var y           : Float = 1
    var z           : Float = 1

    init(_ name: String = "", _ x: Float = 1,_ y: Float = 1,_ z: Float = 1)
    {
        super.init(name)
        self.x = x
        self.y = y
        self.z = z
    }
    
    init(_ x: Float = 1,_ y: Float = 1,_ z: Float = 1)
    {
        super.init("")
        self.x = x
        self.y = y
        self.z = z
    }
    
    init(_ o: Float3)
    {
        super.init("")
        self.x = o.x
        self.y = o.y
        self.z = o.z
    }
    
    override func getType() -> VariableType {
        return .Float3
    }
    
    override func getTypeName() -> String {
        return "Float3"
    }
    
    @inlinable func toSIMD() -> SIMD3<Float>
    {
        if let ref = reference {
            return SIMD3<Float>(ref[qualifiers[0]], ref[qualifiers[1]], ref[qualifiers[2]])
        } else
        if let context = context {
            if let f3 = context.executeForFloat3() {
                return SIMD3<Float>(f3.x, f3.y, f3.z)
            }
        }
        return SIMD3<Float>(x, y, z)
    }
    
    @inlinable func fromSIMD(_ v: float3)
    {
        x = v.x
        y = v.y
        z = v.z
    }
    
    override subscript(index: Int) -> Float {
        get {
            if index == 1 {
                return y
            } else
            if index == 2 {
                return z
            } else {
                return x
            }
        }
    }
}

final class Float2 : BaseVariable
{
    var x           : Float = 0
    var y           : Float = 0

    init(_ name: String = "", _ x: Float = 1,_ y: Float = 1)
    {
        super.init(name)
        self.x = x
        self.y = y
    }
    
    init(_ x: Float = 0,_ y: Float = 0)
    {
        super.init("")
        self.x = x
        self.y = y
    }
    
    override func getType() -> VariableType {
        return .Float2
    }
    
    override func getTypeName() -> String {
        return "Float2"
    }
    
    @inlinable func toSIMD() -> SIMD2<Float>
    {
        if let ref = reference {
            return SIMD2<Float>(ref[qualifiers[0]], ref[qualifiers[1]])
        } else
        if let context = context {
            if let f2 = context.executeForFloat2() {
                return SIMD2<Float>(f2.x, f2.y)
            }
        }
        return SIMD2<Float>(x, y)
    }
    
    override subscript(index: Int) -> Float {
        get {
            if index == 1 {
                return y
            } else {
                return x
            }
        }
    }
}

final class Float1 : BaseVariable
{
    var x           : Float = 0

    init(_ name: String = "", _ x: Float = 1)
    {
        super.init(name)
        self.x = x
    }
    
    init(_ x: Float = 0)
    {
        super.init("")
        self.x = x
    }
    
    /// From text
    init(_ name: String = "", container: VariableContainer, parameters: String, error: inout CompileError)
    {
        super.init(name)
        let exp = ExpressionContext()
        exp.parse(expression: parameters, container: container, error: &error)
        if error.error == nil {
            if exp.resultType == .Constant {
                if let f1 = exp.executeForFloat1() {
                    x = f1.x
                }
            } else {
                self.context = exp
            }
        }
    }
    
    @inlinable func toSIMD() -> Float
    {
        if let ref = reference {
            return ref[qualifiers[0]]
        } else
        if let context = context {
            if let f1 = context.executeForFloat1() {
                return f1.x
            }
        }
        return x
    }
    
    override func getType() -> VariableType {
        return .Float
    }
    
    override func getTypeName() -> String {
        return "Float"
    }
    
    override func toString() -> String {
        return String(x)
    }
    
    override subscript(index: Int) -> Float {
        get {
            return x
        }
    }
}

class Int1 : BaseVariable
{
    var x           : Int = 0

    init(_ name: String = "", _ x: Int = 1)
    {
        super.init(name)
        self.x = x
    }
    
    init(_ x: Int = 0)
    {
        super.init("")
        self.x = x
    }
    
    @inlinable func toSIMD() -> Int
    {
        return x
    }
    
    override func getTypeName() -> String {
        return "Int"
    }
}

class Bool1 : BaseVariable
{
    var x           : Bool = false

    init(_ name: String = "", _ x: Bool = false)
    {
        super.init(name)
        self.x = x
    }
    
    init(_ x: Bool = false)
    {
        super.init("")
        self.x = x
    }
    
    @inlinable func toSIMD() -> Bool
    {
        return x
    }
    
    override func getType() -> VariableType {
        return .Bool
    }
    
    override func getTypeName() -> String {
        return "Bool"
    }
}

class Text1 : BaseVariable
{
    var text: String = ""

    init(_ name: String,_ text: String = "")
    {
        super.init(name)
        self.text = text
    }
    
    @inlinable func toSIMD() -> String
    {
        return text
    }
    
    override func getTypeName() -> String {
        return "Text"
    }
}
