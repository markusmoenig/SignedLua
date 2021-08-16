//
//  SignedContext.swift
//  SignedContext
//
//  Created by Markus Moenig on 16/8/21.
//

import Foundation

class SignedContext {
    let model           : Model
    /// One meter is 0.1 inside the texture by default
    let meterScale      : Float = 10
    
    init(model: Model) {
        self.model = model
    }
    
    /// Adds the given cmd to the modeler pipeline
    func addToPipeline(cmd: SignedCommand) {
        model.modeler?.pipeline.append(cmd)
    }
    
    /// Converts meter to the internal texture representation
    func convertMeter(_ m: Float) -> Float {
        return m / meterScale
    }
    
    /// Converts meter to the internal texture representation
    func convertMeter(_ m: float3) -> float3 {
        return m / meterScale
    }
}
