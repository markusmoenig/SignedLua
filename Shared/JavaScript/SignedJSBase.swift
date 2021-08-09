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
}
