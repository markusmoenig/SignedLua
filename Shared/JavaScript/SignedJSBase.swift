//
//  SignedJSBase.swift
//  SignedJSBase
//
//  Created by Markus Moenig on 8/8/21.
//

import Foundation

import JavaScriptCore

class SignedJSBase: NSObject {
    
    /// Return a reference to the embedded CarthageEntity
    func getHandler() -> ScriptHandler? {
        
        // Get the reference from the JS context
        let context = JSContext.current()
        if let handler = context?.objectForKeyedSubscript("__handler").toObject() as? ScriptHandler {
            return handler
        }
        return nil
    }
    
    func getFloat(name: String, groups: [SignedData]) -> Double {
        
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float {
                    return Double(entity.value.x)
                }
            }
        }
        
        return 0
    }
    
    func getVec3(name: String, groups: [SignedData]) -> Any {
        
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float3 {
                    let p = entity.value
                    if let object = JSContext.current().evaluateScript("new SI.Math.Vector3(\(p.x), \(p.y), \(p.z))") {
                        return object
                    }
                }
            }
        }
        
        return JSContext.current().evaluateScript("new SI.Math.Vector3(0, 0, 0)")!
    }
    
    func setFloat(name: String, value: Double, groups: [SignedData]) {
        
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float {
                    entity.value.x = Float(value)
                }
            }
        }
    }
    
    func setVec3(name: String, value: Any, groups: [SignedData]) {
        
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float3 {
                    let v = toFloat3(value)
                    entity.value.x = v.x
                    entity.value.y = v.y
                    entity.value.z = v.z
                }
            }
        }        
    }
    
    /// Converts a JSValue to Float
    func toFloat(_ o: AnyObject) -> Float {
        var v : Float = 0
        if let value = JSValue(object: o, in: JSContext.current()) {
            v = Float(value.toDouble())
        }
        return v
    }
    
    /// Converts a JSValue to float3
    func toFloat3(_ o: Any) -> float3 {
        if let o = o as? [String: AnyObject] {
            var p = float3(0,0,0)
            if let x = o["x"] { p.x = toFloat(x) }
            if let y = o["y"] { p.y = toFloat(y) }
            if let z = o["z"] { p.z = toFloat(z) }
            return p
        }
        return float3()
    }
}
