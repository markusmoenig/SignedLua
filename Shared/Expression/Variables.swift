//
//  Variables.swift
//  Signed
//
//  Created by Markus Moenig on 18/12/20.
//

import MetalKit

class VariableContainer
{
    /// The variables of this container
    var variables           : [String:BaseVariable] = [:]
    
    /// Optional  parameters, for example inside Denrim trees
    var parameters          : [BaseVariable]? = nil

    /// Get the given variable
    func getVariableValue(_ name: String) -> BaseVariable?
    {
        if let params = self.parameters {
            for p in params {
                if p.name == name {
                    return p
                }
            }
        }
        return variables[name]
    }
}

class BaseVariable {
    
    enum VariableType {
        case Invalid, Bool, Text, Int, Float, Float2, Float3, Float4
    }
    
    enum VariableRole {
        case User, System
    }
    
    var role        : VariableRole = .User
    
    var context     : ExpressionContext? = nil
    var name        : String = ""
        
    // How many components does this variable have
    var components  : Int = 1
    
    // If this variable is a reference to another variable
    var reference   : BaseVariable? = nil
    var qualifiers  : [Int] = []
    
    // The data index of the variable
    var dataIndex   : Int? = nil
    
    init(_ name: String, components: Int = 1)
    {
        self.name = name
        self.components = components
    }
    
    /// Returns the variable type
    func getType() -> VariableType {
        return .Invalid
    }
    
    /// Return the typeName of the variable as a String, i.e. "Float1"
    func getTypeName() -> String {
        return "Invalid"
    }
    
    /// Return the SIMD / Metal name of the variable, i.e. float2
    func getSIMDName() -> String {
        return "Invalid"
    }
    
    /// Return the variable in a readable form, like Float3<0, 1, 2>
    func toString() -> String {
        return ""
    }
    
    /// Creates a new empty variable from the type of this variable
    func createType() -> BaseVariable
    {
        let v : BaseVariable
        
        if getType() == .Float3 {
            v = Float3()
        } else
        if getType() == .Float4 {
            v = Float4()
        } else
        if getType() == .Float2 {
            v = Float2()
        } else {
            v = Float1()
        }
        
        return v
    }
    
    /// Creates a variables based on it's type, the context and it's string parameters, this is used to construct variables from text input
    static func createTypeFromParameters(_ typeName: String, container: VariableContainer, parameters: String, error: inout CompileError) -> BaseVariable?
    {
        if typeName == "Float" {
            return Float1(container: container, parameters: parameters, error: &error)
        } else
        if typeName == "Float2" {
            return Float2(container: container, parameters: parameters, error: &error)
        } else
        if typeName == "Float3" {
            return Float3(container: container, parameters: parameters, error: &error)
        } else
        if typeName == "Float4" {
            return Float4(container: container, parameters: parameters, error: &error)
        } else
        if typeName == "Int" {
            return Int1(container: container, parameters: parameters, error: &error)
        } else
        if typeName == "Bool" {
            return Bool1(container: container, parameters: parameters, error: &error)
        }
        return nil
    }
    
    func isConstant() -> Bool
    {
        return role == .User
    }
    
    func toSIMD1() -> Float
    {
        return 0
    }
    
    func toSIMD2() -> SIMD2<Float>
    {
        return SIMD2<Float>(0,0)
    }
    
    func toSIMD3() -> SIMD3<Float>
    {
        return SIMD3<Float>(0,0,0)
    }
    
    func toSIMD4() -> SIMD4<Float>
    {
        return SIMD4<Float>(0,0,0,0)
    }
    
    /// Subscript stub
    subscript(index: Int) -> Float {
        get {
            return 0
        }
        set(v) {
        }
    }
    
    /// Assign another variable value to this variable
    func assign(from: BaseVariable, using: GraphVariableAssignmentNode.AssignmentType)
    {
        if using == .Copy {
            copy(from: from)
        } else
        if using == .Multiply {
            multiply(with: from)
        } else
        if using == .Divide {
            divide(with: from)
        } else
        if using == .Add {
            add(with: from)
        } else
        if using == .Subtract {
            subtract(with: from)
        }
    }
    
    /// Assign another variable float value to this variable up to the given components
    func assignFromFloat(from: BaseVariable, using: GraphVariableAssignmentNode.AssignmentType, upTo: Int)
    {
        if using == .Multiply {
            multiplyWithFloat(with: from, upTo: upTo)
        } else
        if using == .Divide {
            divideByFloat(with: from, upTo: upTo)
        }
    }
    
    /// copy
    func copy(from: BaseVariable) {
        let comp = min(components, from.components)
        for i in 0..<comp {
            self[i] = from[i]
        }
    }
    
    /// Multply
    func multiply(with: BaseVariable) {
        let comp = min(components, with.components)
        for i in 0..<comp {
            self[i] *= with[i]
        }
    }
    
    /// Divide
    func divide(with: BaseVariable) {
        let comp = min(components, with.components)
        for i in 0..<comp {
            self[i] /= with[i]
        }
    }
    
    /// Add
    func add(with: BaseVariable) {
        let comp = min(components, with.components)
        for i in 0..<comp {
            self[i] += with[i]
        }
    }
    
    /// Subtract
    func subtract(with: BaseVariable) {
        let comp = min(components, with.components)
        for i in 0..<comp {
            self[i] -= with[i]
        }
    }
    
    /// Multply with a float value up to the given component count
    func multiplyWithFloat(with: BaseVariable, upTo: Int) {
        for i in 0..<upTo {
            self[i] *= with[0]
        }
    }
    
    /// Division by a float value up to the given component count
    func divideByFloat(with: BaseVariable, upTo: Int) {
        for i in 0..<upTo {
            self[i] *= with[0]
        }
    }
}

// MARK: - Float4
final class Float4 : BaseVariable
{
    var x           : Float = 1
    var y           : Float = 1
    var z           : Float = 1
    var w           : Float = 1

    var isColor     = false

    init(_ name: String = "", _ x: Float = 1,_ y: Float = 1,_ z: Float = 1,_ w: Float = 1)
    {
        super.init(name, components: 4)
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    
    init(_ x: Float = 1,_ y: Float = 1,_ z: Float = 1,_ w: Float = 1)
    {
        super.init("", components: 4)
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    
    init(_ o: Float4)
    {
        super.init("", components: 4)
        self.x = o.x
        self.y = o.y
        self.z = o.z
        self.w = o.w
    }
    
    init(_ o: float4)
    {
        super.init("", components: 4)
        self.x = o.x
        self.y = o.y
        self.z = o.z
        self.w = o.w
    }
    
    var expressions : Int = 0
    var context1    : ExpressionContext? = nil
    var context2    : ExpressionContext? = nil
    var context3    : ExpressionContext? = nil
    var context4    : ExpressionContext? = nil

    /// From a hex color
    init(_ hexString: String)
    {
        func intFromHexString(hexStr: String) -> UInt64 {
            var hexInt: UInt64 = 0
            // Create scanner
            let scanner: Scanner = Scanner(string: hexStr)
            // Tell scanner to skip the # character
            scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")
            // Scan hex value
            scanner.scanHexInt64(&hexInt)
            return hexInt
        }
        
        let hexint = Int(intFromHexString(hexStr: hexString))
        x = Float((hexint & 0xff000000) >> 32) / 255.0
        y = Float((hexint & 0xff0000) >> 16) / 255.0
        z = Float((hexint & 0xff00) >> 8) / 255.0
        w = Float((hexint & 0xff) >> 0) / 255.0
        
        super.init("", components: 4)
        isColor = true
    }
    
    /// From text
    init(_ name: String = "", container: VariableContainer, parameters: String, error: inout CompileError)
    {
        super.init(name, components: 4)
        
        let array = parameters.split(separator: ",")
        
        if array.count == 0 {
            expressions = 0
            let exp = ExpressionContext()
            exp.parse(expression: parameters, container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f4 = exp.executeForFloat4() {
                        x = f4.x
                        y = f4.y
                        z = f4.z
                        z = f4.z
                    }
                } else {
                    self.context = exp
                }
            }
        } else
        if array.count == 4 {
            expressions = 4

            var exp = ExpressionContext()
            exp.parse(expression: array[0].trimmingCharacters(in: .whitespaces), container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f1 = exp.executeForFloat1() {
                        x = f1.x
                    }
                } else {
                    self.context1 = exp
                    if let f1 = exp.execute() {
                        if f1.getType() != .Float { error.error = "Parameter #1 for \(getTypeName()) does not evaluate to Float (is \(f1.getTypeName()))" }
                    }
                }
            }
            
            exp = ExpressionContext()
            exp.parse(expression: array[1].trimmingCharacters(in: .whitespaces), container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f1 = exp.executeForFloat1() {
                        y = f1.x
                    }
                } else {
                    self.context2 = exp
                }
            }
            
            exp = ExpressionContext()
            exp.parse(expression: array[2].trimmingCharacters(in: .whitespaces), container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f1 = exp.executeForFloat1() {
                        z = f1.x
                    }
                } else {
                    self.context3 = exp
                }
            }
            
            exp = ExpressionContext()
            exp.parse(expression: array[3].trimmingCharacters(in: .whitespaces), container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f1 = exp.executeForFloat1() {
                        w = f1.x
                    }
                } else {
                    self.context4 = exp
                }
            }
        } else {
            error.error = "A Float4 value cannot be constructed from \(array.count) parameters"
        }
    }
    
    override func getType() -> VariableType {
        return .Float4
    }
    
    override func getTypeName() -> String {
        return "Float4"
    }
    
    override func getSIMDName() -> String {
        return "float4"
    }
    
    @inlinable override func isConstant() -> Bool {
        if let reference = reference {
            return reference.isConstant()
        } else
        if role == .User && context1 == nil && context2 == nil && context3 == nil && context4 == nil {
            return true
        }
        return false
    }
    
    override func toString() -> String {
        return "\(String(x)), \((String(y))), \((String(z))), \((String(w)))"
    }
    
    @inlinable override func toSIMD4() -> SIMD4<Float>
    {
        return toSIMD()
    }
    
    @inlinable override func toSIMD3() -> SIMD3<Float>
    {
        let simd = toSIMD()
        return float3(simd.x, simd.y, simd.z)
    }
    
    @inlinable func toSIMD() -> SIMD4<Float>
    {
        if isConstant() {
            return SIMD4<Float>(x, y, z, w)
        }
        // One big expression for all 3 components
        if expressions == 0 {
            if let ref = reference {
                return SIMD4<Float>(ref[qualifiers[0]], ref[qualifiers[1]], ref[qualifiers[2]], ref[qualifiers[3]])
            } else
            if let context = context {
                if let f4 = context.executeForFloat4() {
                    return SIMD4<Float>(f4.x, f4.y, f4.z, f4.w)
                }
            }
        } else
        if expressions == 4 {
            var rc = SIMD4<Float>(x,y,z, w)
    
            if let context = context1 {
                if let f1 = context.executeForFloat1() {
                    rc.x = f1.toSIMD()
                }
            }
            if let context = context2 {
                if let f1 = context.executeForFloat1() {
                    rc.y = f1.toSIMD()
                }
            }
            if let context = context3 {
                if let f1 = context.executeForFloat1() {
                    rc.z = f1.toSIMD()
                }
            }
            if let context = context4 {
                if let f1 = context.executeForFloat1() {
                    rc.w = f1.toSIMD()
                }
            }
            
            return rc
        }
        return SIMD4<Float>(x, y, z, w)
    }
    
    @inlinable func fromSIMD(_ v: float4)
    {
        x = v.x
        y = v.y
        z = v.z
        w = v.w
    }
    
    @inlinable override subscript(index: Int) -> Float {
        get {
            if let reference = reference {
                return reference[index]
            } else {
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
        set(v) {
            if index == 1 {
                y = Float(v)
            } else
            if index == 2 {
                z = Float(v)
            } else
            if index == 3 {
                w = Float(v)
            } else {
                x = Float(v)
            }
        }
    }
}

// MARK: - Float3
final class Float3 : BaseVariable
{
    var x           : Float = 1
    var y           : Float = 1
    var z           : Float = 1
    
    var isColor     = false

    init(_ name: String = "", _ x: Float = 1,_ y: Float = 1,_ z: Float = 1)
    {
        super.init(name, components: 3)
        self.x = x
        self.y = y
        self.z = z
    }
    
    init(_ x: Float = 1,_ y: Float = 1,_ z: Float = 1)
    {
        super.init("", components: 3)
        self.x = x
        self.y = y
        self.z = z
    }
    
    init(_ o: Float3)
    {
        super.init("", components: 3)
        self.x = o.x
        self.y = o.y
        self.z = o.z
    }
    
    init(_ o: float3)
    {
        super.init("", components: 3)
        self.x = o.x
        self.y = o.y
        self.z = o.z
    }
    
    var expressions : Int = 0
    var context1    : ExpressionContext? = nil
    var context2    : ExpressionContext? = nil
    var context3    : ExpressionContext? = nil

    /// From a hex color
    init(_ hexString: String)
    {
        func intFromHexString(hexStr: String) -> UInt64 {
            var hexInt: UInt64 = 0
            // Create scanner
            let scanner: Scanner = Scanner(string: hexStr)
            // Tell scanner to skip the # character
            scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")
            // Scan hex value
            scanner.scanHexInt64(&hexInt)
            return hexInt
        }
        
        let hexint = Int(intFromHexString(hexStr: hexString))
        x = Float((hexint & 0xff0000) >> 16) / 255.0
        y = Float((hexint & 0xff00) >> 8) / 255.0
        z = Float((hexint & 0xff) >> 0) / 255.0
        
        super.init("", components: 3)
        isColor = true
    }
    
    /// From text
    init(_ name: String = "", container: VariableContainer, parameters: String, error: inout CompileError)
    {
        super.init(name, components: 3)
        
        let array = parameters.split(separator: ",")
        
        if array.count == 0 {
            expressions = 0
            let exp = ExpressionContext()
            exp.parse(expression: parameters, container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f3 = exp.executeForFloat3() {
                        x = f3.x
                        y = f3.y
                        z = f3.z
                    }
                } else {
                    self.context = exp
                }
            }
        } else
        if array.count == 3 {
            expressions = 3

            var exp = ExpressionContext()
            exp.parse(expression: array[0].trimmingCharacters(in: .whitespaces), container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f1 = exp.executeForFloat1() {
                        x = f1.x
                    }
                } else {
                    self.context1 = exp
                }
            }
            
            exp = ExpressionContext()
            exp.parse(expression: array[1].trimmingCharacters(in: .whitespaces), container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f1 = exp.executeForFloat1() {
                        y = f1.x
                    }
                } else {
                    self.context2 = exp
                }
            }
            
            exp = ExpressionContext()
            exp.parse(expression: array[2].trimmingCharacters(in: .whitespaces), container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f1 = exp.executeForFloat1() {
                        z = f1.x
                    }
                } else {
                    self.context3 = exp
                }
            }
        } else {
            error.error = "A Float3 value cannot be constructed from \(array.count) parameters"
        }
    }
    
    override func getType() -> VariableType {
        return .Float3
    }
    
    override func getTypeName() -> String {
        return "Float3"
    }
    
    override func getSIMDName() -> String {
        return "float3"
    }
    
    @inlinable override func isConstant() -> Bool {
        if let reference = reference {
            return reference.isConstant()
        } else
        if role == .User && context1 == nil && context2 == nil && context3 == nil {
            return true
        }
        return false
    }
    
    override func toString() -> String {
        if name.isEmpty == false {
            return name
        } else
        if isConstant() {
            return "\(String(format: "%.03g", x)), \(String(format: "%.03g", y)), \(String(format: "%.03g", z))"
        } else
        if expressions == 0 {
            if let context = context {
                return context.toMetal()
            }
        } else
        if expressions == 3 {
        
            var stringX = "0"
            var stringY = "0"
            var stringZ = "0"
            
            if let c1 = context1 {
                stringX = c1.toMetal(embedded: true)
            } else {
                stringX = String(format: "%.03g", x)
             }
            
            if let c2 = context2 {
                stringY = c2.toMetal(embedded: true)
            } else {
                stringY = String(format: "%.03g", y)
             }
            
            if let c3 = context3 {
                stringZ = c3.toMetal(embedded: true)
            } else {
               stringZ = String(format: "%.03g", z)
            }
            
            return "\(stringX), \(stringY), \(stringZ)"
        }
        return ""
    }
    
    func toHexString() -> String {
        let r:CGFloat = CGFloat(x)
        let g:CGFloat = CGFloat(y)
        let b:CGFloat = CGFloat(z)
        //let a:CGFloat = 1
        
        //getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return NSString(format:"#%06x", rgb) as String
    }
    
    @inlinable override func toSIMD3() -> SIMD3<Float>
    {
        return toSIMD()
    }
    
    @inlinable override func toSIMD4() -> SIMD4<Float>
    {
        let v = toSIMD()
        return float4(v.x, v.y, v.z, 0)
    }
    
    @inlinable func toSIMD() -> SIMD3<Float>
    {
        if isConstant() {
            return SIMD3<Float>(x, y, z)
        }
        // One big expression for all 3 components
        if expressions == 0 {
            if let ref = reference {
                return SIMD3<Float>(ref[qualifiers[0]], ref[qualifiers[1]], ref[qualifiers[2]])
            } else
            if let context = context {
                if let f3 = context.executeForFloat3() {
                    return SIMD3<Float>(f3.x, f3.y, f3.z)
                }
            }
        } else
        if expressions == 3 {
            var rc = SIMD3<Float>(x,y,z)
            
            if let context = context1 {
                if let f1 = context.executeForFloat1() {
                    rc.x = f1.toSIMD()
                }
            }
            if let context = context2 {
                if let f1 = context.executeForFloat1() {
                    rc.y = f1.toSIMD()
                }
            }
            if let context = context3 {
                if let f1 = context.executeForFloat1() {
                    rc.z = f1.toSIMD()
                }
            }
            
            return rc
        }
        return SIMD3<Float>(x, y, z)
    }
    
    @inlinable func fromSIMD(_ v: float3)
    {
        x = v.x
        y = v.y
        z = v.z
    }
    
    @inlinable override subscript(index: Int) -> Float {
        get {
            if let reference = reference {
                return reference[index]
            } else {
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
        set(v) {
            if index == 1 {
                y = Float(v)
            } else
            if index == 2 {
                z = Float(v)
            } else {
                x = Float(v)
            }
        }
    }
}

// MARK: - Float2
final class Float2 : BaseVariable
{
    var x           : Float = 0
    var y           : Float = 0

    init(_ name: String = "", _ x: Float = 1,_ y: Float = 1)
    {
        super.init(name, components: 2)
        self.x = x
        self.y = y
    }
    
    init(_ x: Float = 0,_ y: Float = 0)
    {
        super.init("", components: 2)
        self.x = x
        self.y = y
    }
    
    init(_ o: Float2)
    {
        super.init("", components: 2)
        self.x = o.x
        self.y = o.y
    }
    
    init(_ o: float2)
    {
        super.init("", components: 2)
        self.x = o.x
        self.y = o.y
    }
    
    var expressions : Int = 0
    var context1    : ExpressionContext? = nil
    var context2    : ExpressionContext? = nil

    /// From text
    init(_ name: String = "", container: VariableContainer, parameters: String, error: inout CompileError)
    {
        super.init(name, components: 2)
        
        let array = parameters.split(separator: ",")
        
        if array.count == 0 {
            expressions = 0
            let exp = ExpressionContext()
            exp.parse(expression: parameters, container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f2 = exp.executeForFloat2() {
                        x = f2.x
                        y = f2.y
                    }
                } else {
                    self.context = exp
                }
            }
        } else
        if array.count == 2 {
            expressions = 2

            var exp = ExpressionContext()
            exp.parse(expression: array[0].trimmingCharacters(in: .whitespaces), container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f1 = exp.executeForFloat1() {
                        x = f1.x
                    }
                } else {
                    self.context1 = exp
                }
            }
            
            exp = ExpressionContext()
            exp.parse(expression: array[1].trimmingCharacters(in: .whitespaces), container: container, error: &error)
            if error.error == nil {
                if exp.resultType == .Constant {
                    if let f1 = exp.executeForFloat1() {
                        y = f1.x
                    }
                } else {
                    self.context2 = exp
                }
            }
        } else {
            error.error = "A Float2 value cannot be constructed from \(array.count) parameters"
        }
    }
    
    override func getType() -> VariableType {
        return .Float2
    }
    
    override func getTypeName() -> String {
        return "Float2"
    }
    
    override func getSIMDName() -> String {
        return "float2"
    }
    
    @inlinable override func isConstant() -> Bool {
        if let reference = reference {
            return reference.isConstant()
        } else
        if role == .User && context1 == nil && context2 == nil {
            return true
        }
        return false
    }
    
    override func toString() -> String {
        if name.isEmpty == false {
            return name
        } else
        if isConstant() {
            return "\(String(x)), \((String(y)))"
        } else {
            var stringX = "0"
            var stringY = "0"
            
            if let c1 = context1 {
                stringX = c1.toMetal()
            }
            
            if let c2 = context1 {
                stringY = c2.toMetal()
            }
            
            return "\(stringX), \(stringY)"
        }
    }
    
    @inlinable override func toSIMD2() -> SIMD2<Float>
    {
        return toSIMD()
    }
    
    @inlinable func toSIMD() -> SIMD2<Float>
    {
        if isConstant() {
            return SIMD2<Float>(x, y)
        }
        // One big expression for all 2 components
        if expressions == 0 {
            if let ref = reference {
                return SIMD2<Float>(ref[qualifiers[0]], ref[qualifiers[1]])
            } else
            if let context = context {
                if let f2 = context.executeForFloat2() {
                    return SIMD2<Float>(f2.x, f2.y)
                }
            }
        } else
        if expressions == 2 {
            var rc = SIMD2<Float>(x,y)
            
            if let context = context1 {
                if let f1 = context.executeForFloat1() {
                    rc.x = f1.toSIMD()
                }
            }
            if let context = context2 {
                if let f1 = context.executeForFloat1() {
                    rc.y = f1.toSIMD()
                }
            }
            
            return rc
        }
        return SIMD2<Float>(x, y)
    }
    
    @inlinable func fromSIMD(_ v: float2)
    {
        x = v.x
        y = v.y
    }
    
    @inlinable override subscript(index: Int) -> Float {
        get {
            if let reference = reference {
                return reference[index]
            } else {
                if index == 1 {
                    return y
                } else {
                    return x
                }
            }
        }
        set(v) {
            if index == 1 {
                y = Float(v)
            } else {
                x = Float(v)
            }
        }
    }
}

// MARK: - Float1
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
    
    @inlinable override func isConstant() -> Bool {
        if let reference = reference {
            return reference.isConstant()
        } else
        if role == .User && context == nil {
            return true
        }
        return false
    }
    
    @inlinable override func toSIMD1() -> Float
    {
        return toSIMD()
    }
    
    @inlinable func toSIMD() -> Float
    {
        if isConstant() {
            return x
        }
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
    
    @inlinable override func toSIMD4() -> SIMD4<Float>
    {
        let v = toSIMD()
        return float4(v, 0, 0, 0)
    }
    
    override func getType() -> VariableType {
        return .Float
    }
    
    override func getTypeName() -> String {
        return "Float"
    }
    
    override func getSIMDName() -> String {
        return "float"
    }
    
    override func toString() -> String {
        if name.isEmpty == false {
            return name
        } else
        if isConstant() {
            return String(x)//format: "%.03f", x)
        } else {
            var stringX = "0"
            
            if let ref = reference {
                stringX = ref.name
                if qualifiers.count == 1 {
                    let a = ["x", "y", "z", "w"]
                    stringX += "." + a[qualifiers[0]]
                }
            } else
            if let c = context {
                stringX = c.toMetal()
            }
            
            return "\(stringX)"
        }
    }
    
    @inlinable func fromSIMD(_ v: Float)
    {
        x = v
    }
    
    @inlinable override subscript(index: Int) -> Float {
        get {
            if let reference = reference {
                return reference[index]
            } else {
                return x
            }
        }
        set(v) {
            x = Float(v)
        }
    }
}

// MARK - Int1
final class Int1 : BaseVariable
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
    
    /// From text
    init(_ name: String = "", container: VariableContainer, parameters: String, error: inout CompileError)
    {
        super.init(name)
        let exp = ExpressionContext()
        exp.parse(expression: parameters, container: container, defaultVariableType: .Int, error: &error)
        if error.error == nil {
            if exp.resultType == .Constant {
                if let i1 = exp.executeForInt1() {
                    x = i1.x
                }
            } else {
                self.context = exp
            }
        }
    }
    
    @inlinable func toSIMD() -> Int
    {
        if isConstant() {
            return x
        }
        if let ref = reference {
            return Int(ref[qualifiers[0]])
        } else
        if let context = context {
            if let i1 = context.executeForInt1() {
                return i1.x
            }
        }
        return x
    }
    
    override func getType() -> VariableType {
        return .Int
    }
    
    override func getTypeName() -> String {
        return "Int"
    }
    
    override func getSIMDName() -> String {
        return "float"
    }
    
    override func toString() -> String {
        return String(x)
    }
    
    @inlinable func fromSIMD(_ v: Int)
    {
        x = v
    }
    
    @inlinable override subscript(index: Int) -> Float {
        get {
            if let reference = reference {
                return reference[index]
            } else {
                return Float(x)
            }
        }
        set(v) {
            x = Int(v)
        }
    }
}

final class Bool1 : BaseVariable
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
    
    /// From text
    init(_ name: String = "", container: VariableContainer, parameters: String, error: inout CompileError)
    {
        super.init(name)
        let exp = ExpressionContext()
        exp.parse(expression: parameters, container: container, defaultVariableType: .Bool, error: &error)
        if error.error == nil {
            if exp.resultType == .Constant {
                if let b1 = exp.executeForBool1() {
                    x = b1.x
                }
            } else {
                self.context = exp
            }
        }
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

final class Text1 : BaseVariable
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
