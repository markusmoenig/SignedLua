//
//  ScriptHandler.swift
//  ScriptHandler
//
//  Created by Markus Moenig on 6/8/21.
//

import Foundation
import JavaScriptCore

/// So that we can pass and retreive a reference to the ScriptHandler class via JS
@objc protocol ScriptHandlerJSExports: JSExport {
}

class ScriptHandler: NSObject, ScriptHandlerJSExports {
    
    var jsContext               : JSContext? = nil
    
    var modeler                 : ModelerPipeline
    var model                   : Model
    
    weak var cmd                : SignedCommand? = nil
    
    init(_ modeler: ModelerPipeline) {
        self.modeler = modeler
        self.model = modeler.model
    }
    
    /// Load and execute the given module
    func require(_ input: String) {
        guard let path = Bundle.main.path(forResource: input, ofType: "js", inDirectory: "Files/jslibs") else {
            return
        }
            
        if let value = try? String(contentsOfFile: path, encoding: String.Encoding.utf8) {
            jsContext?.evaluateScript(value)
        }
    }
    
    /// Sets up script support for this cmd and checks if the script supports geometry and / or material creation
    func setup(_ cmd: SignedCommand) -> (Bool, Bool)
    {
        var rc  = (false, false)
     
        if cmd.code.isEmpty == true { return rc }
        
        self.cmd = cmd
        
        jsContext = JSContext()
        
        // Exception handler
        jsContext?.exceptionHandler = { context, exception in
            if let exc = exception {
                if let str = exc.toString() {
                    DispatchQueue.main.async {
                        print("Error: \(str) \n")
                    }
                }
            }
        }
        
        jsContext?.setObject(self, forKeyedSubscript: "__handler" as NSString)

        jsContext?.setObject(SignedJSShape.self, forKeyedSubscript: "Shape" as NSString)
        jsContext?.evaluateScript("shape = Shape.getInstance();")

        jsContext?.setObject(printConsole, forKeyedSubscript: "print" as NSString)
        jsContext?.setObject(printConsole, forKeyedSubscript: "console" as NSString)
        
        jsContext?.evaluateScript("SI = {};")
        require("SI.Math")
        jsContext?.evaluateScript(cmd.code)
        
        if jsContext?.objectForKeyedSubscript("createGeometry").isUndefined == false {
            rc.0 = true
        }
        
        if jsContext?.objectForKeyedSubscript("createMaterial").isUndefined == false {
            rc.1 = true
        }
        
        return rc
    }
    
    /// Dealloc the script support
    func close() {
        jsContext = nil
        cmd = nil
    }
    
    /// JavaScript print
    let printConsole: @convention(block) (String) -> () = { input in
        /*
        if let model = getModel() {
            DispatchQueue.main.async {
                model.logText.append(input + "\n")
                model.logChanged.send()
            }
        }*/
        print(input)
    }
}
