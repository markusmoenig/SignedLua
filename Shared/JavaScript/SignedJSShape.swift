//
//  SignedJSShape.swift
//  SignedJSShape
//
//  Created by Markus Moenig on 8/8/21.
//

import Foundation
import JavaScriptCore

@objc protocol SignedJSShapeJSExports: JSExport {

    func getVector3(_ name: String) -> Any

    static func getInstance() -> SignedJSShape
}

class SignedJSShape: SignedJSBase, SignedJSShapeJSExports {
    
    func getVector3(_ name: String) -> Any {
        if let handler = getHandler() {
        }
        
        return ""
    }
    
    /// Class initializer
    class func getInstance() -> SignedJSShape {
        return SignedJSShape()
    }
}