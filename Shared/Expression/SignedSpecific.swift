//
//  DenrimSpecific.swift
//  Signed
//
//  Created by Markus Moenig on 30/12/20.
//

import Foundation
import simd

class CastShadowRayFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext)? = nil
    var container : VariableContainer? = nil
    var destIndex : Int = 0
        
    init()
    {
        super.init("castshadowray")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.container = container
        self.destIndex = destIndex
        if let args = splitIntoTwo(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute(); let a2 = arguments!.1.execute()
            if a1 != nil && a2 != nil && a1!.getType() == a2!.getType() && a1!.getType() == .Float3 {
                return Float1(1)
            } else { error.error = "castshadowray<> expects two Float3 parameters" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        context.values[destIndex] = Float1(0)
        if let rayOrigin = arguments!.0.execute() as? Float3 {
            if let rayDirection = arguments!.1.execute() as? Float3 {

                if let container = container as? GraphContext {
                    
                    if container.hasHitSomething == true {//&& container.insideShadowRay == false {
                                            
                        container.insideShadowRay = true
                        let backup = container.createVariableBackup()
                        
                        container.rayOrigin.fromSIMD(rayOrigin.toSIMD() + rayDirection.toSIMD())
                        container.rayDirection.fromSIMD(rayDirection.toSIMD())
                        
                        container.camOrigin = rayOrigin.toSIMD() + rayDirection.toSIMD()
                        container.rayDir = rayDirection.toSIMD()

                        // Analytical Objects
                        container.executeAnalytical()
                        let h = container.analyticalDist
                        
                        let tmin : Float = 0.02
                        let tmax : Float = min(2.5, container.analyticalDist)
                        var t : Float = tmin
                        let k : Float = 4
                        var ph : Float = 1e20

                        var result : Float = 1
                                                
                        if( h < 0.001 ) {
                            result = 0
                        }

                        while t < tmax && result > 0.0 {
                            container.executeSDF(container.camOrigin + t * container.rayDir)
                            let h = container.rayDist[container.rayIndex]
                            if( h < 0.001 ) {
                                result = 0
                                break
                            }
                            let y : Float = h*h/(2.0*ph)
                            let d : Float = sqrt(h*h-y*y)
                            result = min( result, k*d/max(0.0,t-y) )
                            ph = h
                            t += h
                        }
                                                
                        context.values[destIndex] = Float1(result)

                        container.restoreVariableBackup(backup)
                        //container.insideShadowRay = false
                    } else {
                        //container.insideShadowRay = true
                        context.values[destIndex] = Float1(1)
                        //container.insideShadowRay = false
                    }
                }
            }
        }
    }
}

class CastRayFuncNode : ExpressionNode {
    
    var arguments : (ExpressionContext, ExpressionContext)? = nil
    var container : VariableContainer? = nil
    var destIndex : Int = 0
    
    init()
    {
        super.init("castray")
    }
    
    override func setupFunction(_ container: VariableContainer,_ destIndex: Int,_ parameters: String,_ error: inout CompileError) -> BaseVariable?
    {
        self.container = container
        self.destIndex = destIndex
        if let args = splitIntoTwo(self.name, container, parameters, &error) {
            arguments = args
            let a1 = arguments!.0.execute(); let a2 = arguments!.1.execute()
            if a1 != nil && a2 != nil && a1!.getType() == a2!.getType() && a1!.getType() == .Float3 {
                return a1
            } else { error.error = "castray<> expects two Float3 parameters" }
        }
        return nil
    }
    
    @inlinable override func execute(_ context: ExpressionContext)
    {
        if let rayOrigin = arguments!.0.execute() as? Float3 {
            if let rayDirection = arguments!.1.execute() as? Float3 {

                if let container = container as? GraphContext {
                    
                    if container.reflectionDepth == 0 {
                        context.values[destIndex] = Float4(0,0,0,0)
                    }
                    
                    container.reflectionDepth += 1
                    
                    if container.reflectionDepth < 2 && container.hasHitSomething == true {
                        
                        let hasHitSomethingBuffer = container.hasHitSomething
                        container.hasHitSomething = false
                        
                        let backup = container.createVariableBackup()
                        
                        container.rayOrigin.fromSIMD(rayOrigin.toSIMD() + rayDirection.toSIMD() * 0.0001)
                        container.rayDirection.fromSIMD(rayDirection.toSIMD())
                        
                        container.camOrigin = rayOrigin.toSIMD() + rayDirection.toSIMD() * 0.0001
                        container.rayDir = rayDirection.toSIMD()

                        if let skyNode = container.skyNode {
                            skyNode.execute(context: container)
                        }
                        
                        // Analytical Objects
                        container.executeAnalytical()
                        let maxDist : Float = simd_min(10.0, container.analyticalDist)
                        
                        var material : GraphNode? = nil

                        var hit = false
                        
                        var t : Float = 0.001
                        for _ in 0..<70
                        {
                            container.executeSDF(container.camOrigin + t * container.rayDir)

                            if abs(container.rayDist[container.rayIndex]) < (0.0001*t) {
                                hit = true
                                material = container.hitMaterial[container.rayIndex]
                                break
                            } else
                            if t > maxDist {
                                break
                            }
                            
                            t += container.rayDist[container.rayIndex]
                        }
                        
                        if hit && t < container.analyticalDist {
                            
                            let p = container.camOrigin + t * container.rayDir
                            container.rayPosition.fromSIMD(p)
                            let normal = calcNormal(context: container, position: p)
                            container.normal.fromSIMD(normal)

                            if let material = material {
                                material.execute(context: container)
                            }
                            container.hasHitSomething = true
                            container.executeRender()
                        } else
                        if container.analyticalDist != .greatestFiniteMagnitude {
                            
                            let p = container.camOrigin + container.analyticalDist * container.rayDir
                            container.rayPosition.fromSIMD(p)

                            let normal = container.analyticalNormal
                            container.normal.fromSIMD(normal)

                            if let material = container.analyticalMaterial {
                                material.execute(context: container)
                            }
                            container.hasHitSomething = true
                            container.executeRender()
                        }
                        
                        var result = container.outColor!.toSIMD()
                        
                        result.x = simd_clamp(result.x, 0.0, 1.0)
                        result.y = simd_clamp(result.y, 0.0, 1.0)
                        result.z = simd_clamp(result.z, 0.0, 1.0)
                        
                        if let outColor = context.values[destIndex] as? Float4 {
                            outColor.x += result.x
                            outColor.y += result.y
                            outColor.z += result.z
                        }

                        container.hasHitSomething = hasHitSomethingBuffer
                        container.restoreVariableBackup(backup)
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
}
