//
//  ComponentParser.swift
//  Signed
//
//  Created by Markus Moenig on 27/6/21.
//

import Foundation
import Metal

/// Possible compile errors returned by component verification
struct SignedCompileError
{
    var component       : SignedCommand? = nil
    var line            : Int32? = nil
    var column          : Int32? = 0
    var error           : String? = nil
    var type            : String = "error"
}

/// Parses and verifies SignedComponent code
class ComponentParser {
    
    var component           : SignedCommand
    
    init(_ comp: SignedCommand) {
        component = comp
    }
    
    /// Verify the component code and pass possible errors in the callback
    func verify(_ device: MTLDevice,_ cb: @escaping ([SignedCompileError]) -> ())
    {
        var code = """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        """

        code += component.code
        
        let lineNumbers: Int32 = 3
        
        let compiledCB : MTLNewLibraryCompletionHandler = { (library, error) in
            
            var errors: [SignedCompileError] = []
                        
            if let error = error {
                let str = error.localizedDescription
                let arr = str.components(separatedBy: "program_source:")
                for str in arr {
                    if str.starts(with: "Compilation failed:") == false && (str.contains("error:") || str.contains("warning:")) {
                        let arr = str.split(separator: ":")
                        let errorArr = String(arr[3].trimmingCharacters(in: .whitespaces)).split(separator: "\n")
                        var errorText = ""
                        if errorArr.count > 0 {
                            errorText = String(errorArr[0])
                        }
                        if arr.count >= 4 {
                            var er = SignedCompileError()
                            er.component = self.component
                            er.line = Int32(arr[0])! - lineNumbers - 1
                            er.column = Int32(arr[1])
                            er.type = arr[2].trimmingCharacters(in: .whitespaces)
                            er.error = errorText
                            if er.line != nil && er.column != nil && er.line! >= 0 && er.column! >= 0 {
                                errors.append(er)
                            }
                        }
                    }
                }
            }
            
            cb(errors)
        }
            
        //if cb == false {
        device.makeLibrary( source: code, options: nil, completionHandler: compiledCB)
        //} else {
        //    do {
        //        let library = try device.makeLibrary( source: code, options: nil)
        //        compiledCB(library, nil)
        //    } catch {
                //print(error)
        //    }
        //}
    }
}
