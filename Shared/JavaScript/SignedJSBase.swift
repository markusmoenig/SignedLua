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
}
