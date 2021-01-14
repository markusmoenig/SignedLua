//
//  DenrimSpecific.swift
//  Signed
//
//  Created by Markus Moenig on 30/12/20.
//

import Foundation
import simd

class CastShadowRayFuncNode : ExpressionNode {
    
    var container : VariableContainer? = nil
        
    init()
    {
        super.init("castshadowray")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            self.container = container
            return Float1(0)
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        context.values[destIndex] = Float1(0)
        if let rayOrigin = argumentsIn[0].execute() as? Float3 {
            if let rayDirection = argumentsIn[1].execute() as? Float3 {

                if let container = container as? GraphContext {
                    
                    context.values[destIndex] = Float1(container.shadowRay(rayOrigin.toSIMD(), rayDirection.toSIMD()))
                }
            }
        }
    }
    
    override func getHelp() -> String
    {
        return "Casts a soft shadow ray."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Ray origin", ""),
            GraphOption(Float3(1,1,1), "Ray direction", "")
        ]
        return options
    }
}

class CastRayFuncNode : ExpressionNode {
    
    var container : VariableContainer? = nil
    
    init()
    {
        super.init("castray")
    }
    
    override func setupFunction(_ container: VariableContainer,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        if verifyOptions(name, container, parameters, &error) {
            self.container = container
            return Float4(0)
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let rayOrigin = argumentsIn[0].execute() as? Float3 {
            if let rayDirection = argumentsIn[1].execute() as? Float3 {

                if let container = container as? GraphContext {
                    
                    if container.reflectionDepth == 0 {
                        context.values[destIndex] = Float4(0,0,0,0)
                    }
                    
                    container.reflectionDepth += 1
                    
                    if container.reflectionDepth < 2 && container.hasHitSomething == true {
                            
                        let result = container.castRay(rayOrigin.toSIMD(), rayDirection.toSIMD())

                        if let outColor = context.values[destIndex] as? Float4 {
                            outColor.x += result.x
                            outColor.y += result.y
                            outColor.z += result.z
                        }
                    }
                }
            }
        }
    }
    
    /// Calculates the normal for the given hit position
    @inlinable public func calcNormal(context: GraphContext, position: float3) -> float3
    {
        /*
        vec3 epsilon = vec3(0.001, 0., 0.);
        
        vec3 n = vec3(map(p + epsilon.xyy).x - map(p - epsilon.xyy).x,
                      map(p + epsilon.yxy).x - map(p - epsilon.yxy).x,
                      map(p + epsilon.yyx).x - map(p - epsilon.yyx).x);
        
        return normalize(n);*/

        let e = float3(0.001, 0.0, 0.0)

        var eOff : float3 = position + float3(e.x, e.y, e.y)
        context.executeSDF(eOff)
        var n1 = context.rayDist[context.rayIndex]
        
        eOff = position - float3(e.x, e.y, e.y)
        context.executeSDF(eOff)
        n1 = n1 - context.rayDist[context.rayIndex]
        
        eOff = position + float3(e.y, e.x, e.y)
        context.executeSDF(eOff)
        var n2 = context.rayDist[context.rayIndex]
        
        eOff = position - float3(e.y, e.x, e.y)
        context.executeSDF(eOff)
        n2 = n2 - context.rayDist[context.rayIndex]
        
        eOff = position + float3(e.y, e.y, e.x)
        context.executeSDF(eOff)
        var n3 = context.rayDist[context.rayIndex]
        
        eOff = position - float3(e.y, e.y, e.x)
        context.executeSDF(eOff)
        n3 = n3 - context.rayDist[context.rayIndex]
        
        return simd_normalize(float3(n1, n2, n3))
    }
    
    override func getHelp() -> String
    {
        return "Casts a ray and returns the computed color."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(1,1,1), "Ray origin", ""),
            GraphOption(Float3(1,1,1), "Ray direction", "")
        ]
        return options
    }
}
