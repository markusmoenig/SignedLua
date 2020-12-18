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
    func getVariableValue(_ name: String) -> BaseVariable?
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
    
    init(_ name: String)
    {
        self.name = name
    }
    
    func getType() -> VariableType {
        return .Invalid
    }
    
    func getTypeName() -> String {
        return ""
    }
    
    func toString() -> String {
        return ""
    }
}

class Float4 : BaseVariable
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
        return SIMD4<Float>(x, y, z, w)
    }
    
    subscript(index: Int) -> Float {
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

class Float3 : BaseVariable
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
        return SIMD3<Float>(x, y, z)
    }
    
    subscript(index: Int) -> Float {
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

class Float2 : BaseVariable
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
        return SIMD2<Float>(x, y)
    }
    
    subscript(index: Int) -> Float {
        get {
            if index == 1 {
                return y
            } else {
                return x
            }
        }
    }
}

class Float1 : BaseVariable
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
    
    @inlinable func toSIMD() -> Float
    {
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
