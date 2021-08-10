//
//  SignedJSShape.swift
//  SignedJSShape
//
//  Created by Markus Moenig on 8/8/21.
//

import Foundation
import JavaScriptCore

@objc protocol SignedJSShapeJSExports: JSExport {

    func getFloat(_ name: String) -> Double
    func getVector3(_ name: String) -> Any
    
    func setFloat(_ name: String,_ value: Double)
    func setVector3(_ name: String,_ value: Any)
    
    func create(_ id: Int32)

    static func getInstance() -> SignedJSShape
}

class SignedJSShape: SignedJSBase, SignedJSShapeJSExports {
    
    func getFloat(_ name: String) -> Double {
        if let handler = getHandler() {
            if let cmd = handler.cmd {
                return getFloat(name: name, groups: cmd.dataGroups.flat())
            }
        }
        
        return 0
    }
    
    func getVector3(_ name: String) -> Any {
        if let handler = getHandler() {
            if let cmd = handler.cmd {
                return getVec3(name: name, groups: cmd.dataGroups.flat())
            }
        }
        
        return [:]
    }
    
    func setFloat(_ name: String,_ value: Double) {
        if let handler = getHandler() {
            if let cmd = handler.cmd {
                setFloat(name: name, value: value, groups: cmd.dataGroups.flat())
            }
        }
    }
    
    func setVector3(_ name: String,_ value: Any) {
        if let handler = getHandler() {
            if let cmd = handler.cmd {
                setVec3(name: name, value: value, groups: cmd.dataGroups.flat())
            }
        }        
    }
    
    func create(_ id: Int32)
    {
        if let handler = getHandler() {
            if let cmd = handler.cmd {
                handler.model.modeler?.executeCommand(cmd)
                handler.model.renderer?.restart()
            }
        }
    }
    
    /// Class initializer
    class func getInstance() -> SignedJSShape {
        return SignedJSShape()
    }
}
