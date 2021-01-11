//
//  GraphNodes.swift
//  Signed
//
//  Created by Markus Moenig on 15/12/20.
//

import MetalKit
import simd

/// DefaultSkyNode
final class DefaultSkyNode : GraphNode
{
    var sunDirection       : Float3 = Float3(0.243, 0.075, 0.512)
    var sunColor           : Float3 = Float3(0.966, 0.966, 0.966)
    var worldHorizonColor  : Float3 = Float3(0.852, 0.591, 0.367)
    var sunStrength        : Float1 = Float1(5)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Sky, .None, options)
        name = "DefaultSky"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        //if let value = extractFloat1Value(options, context: context, error: &error, name: "radius", isOptional: true) {
        //    radius = value
        //}
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        let sunDir = sunDirection.toSIMD()
        let skyColor = float3(0.38, 0.6, 1.0)
        let sunColor = self.sunColor.toSIMD()
        let horizonColor = worldHorizonColor.toSIMD()
        
        let sun : Float = simd_max(simd_dot(context.rayDir, simd_normalize(sunDir)), 0.0)
        let hor : Float = pow(1.0 - simd_max(context.rayDir.y, 0.0), 3.0)
        var col : float3 = simd_mix(skyColor, sunColor, sun * float3(0.5, 0.5, 0.5))
        col = simd_mix(col, horizonColor, float3(hor, hor, hor))
        
        col += 0.25 * float3(1.0, 0.7, 0.4) * pow(sun, 5.0)
        col += 0.25 * float3(1.0, 0.8, 0.6) * pow(sun, 5.0)
        col += 0.15 * float3(1.0, 0.9, 0.7) * simd_max(pow(sun, 512.0), 0.25)

        context.outColor.fromSIMD(float4(col.x, col.y, col.z, 1))
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates a sphere of a given radius."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(1), "Radius", "The radius of the sphere.")
        ]
        return options
    }
}

/// BaseCameraNode
class BaseCameraNode : GraphNode
{
    var origin       : Float3 = Float3(0, 0, -5)
    var lookAt       : Float3 = Float3(0, 0, 0)
    var fov          = Float1(80)
}

/// PinholeCameraNode
final class PinholeCameraNode : BaseCameraNode
{
    var mouseDownPos          = float2(0,0)
    
    var cameraHelper          : CameraHelper!
    
    var updateStarted         = false
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Camera, .None, options)
        name = "PinholeCamera"
        
        cameraHelper = CameraHelper(self)
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat3Value(options, container: context, error: &error, name: "origin", isOptional: true) {
            origin = value
        }
        if let value = extractFloat3Value(options, container: context, error: &error, name: "lookat", isOptional: true) {
            lookAt = value
        }
        if let value = extractFloat1Value(options, container: context, error: &error, name: "fov", isOptional: true) {
            fov = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        let ratio : Float = context.viewSize.x / context.viewSize.y
        let pixelSize : float2 = float2(1.0, 1.0) / context.viewSize

        let camOrigin = origin.toSIMD()
        let camLookAt = lookAt.toSIMD()

        let halfWidth : Float = tan(fov.x.degreesToRadians * 0.5)
        let halfHeight : Float = halfWidth / ratio
        
        let upVector = float3(0.0, 1.0, 0.0)

        let w : float3 = simd_normalize(camOrigin - camLookAt)
        let u : float3 = simd_cross(upVector, w)
        let v : float3 = simd_cross(w, u)

        var lowerLeft : float3 = camOrigin - halfWidth * u
        lowerLeft -= halfHeight * v - w
        
        let horizontal : float3 = u * halfWidth * 2.0
        
        let vertical : float3 = v * halfHeight * 2.0
        var dir : float3 = lowerLeft - camOrigin

        dir += horizontal * (pixelSize.x * context.camOffset.x + context.uv.x)
        dir += vertical * (pixelSize.y * context.camOffset.y + context.uv.y)
        
        context.camOrigin = camOrigin
        context.rayDir = simd_normalize(-dir)
        
        return .Success
    }
    
    /// toolTouchDown
    override func toolTouchDown(_ pos: float2,_ toolContext: ToolContext)
    {
        mouseDownPos = pos
        toolContext.checkIfTextureIsValid()
    }
    
    /// toolTouchMove
    override func toolTouchMove(_ pos: float2,_ toolContext: ToolContext)
    {
        cameraHelper.move(dx: (mouseDownPos.x - pos.x) * 0.003, dy: (mouseDownPos.y - pos.y) * 0.003, aspect: Float(toolContext.texture!.width) / Float(toolContext.texture!.height))
        mouseDownPos = pos
        
        if updateStarted == false {
            updateStarted = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 ) {
                toolContext.core.scriptProcessor.replaceFloat3InLine(["Origin": self.origin])
                toolContext.core.renderer.restart(.Preview)
                self.updateStarted = false
            }
        }
    }
    
    /// toolTouchUp
    override func toolTouchUp(_ pos: float2,_ toolContext: ToolContext)
    {
        toolContext.core.renderer.restart(.Normal)
    }
    
    override func getHelp() -> String
    {
        return "A standard Pinhole camera (the default camera for *Signed*)."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0, 0, -5), "Origin", "The camera origin (viewer position)."),
            GraphOption(Float3(0, 0, 0), "LookAt", "The position the camera is looking at."),
            GraphOption(Float1(80), "Fov", "The field of view of the camera.")
        ]
        return options
    }
}

/// VariableAssignmentNode, assign or modify a variable via assignment, =, *=, -= etc
final class VariableAssignmentNode : GraphNode
{
    enum AssignmentType {
        case Copy, Multiply, Divide, Add, Subtract
    }
    
    /// The right handed expression the variables gets assigned to
    var expression                  : ExpressionContext? = nil
    /// The components  of the assignment (like outColor.xyz has 3 assignment components)
    var assignmentComponents        : Int = 0
    /// The assignment type
    var assignmentType              : AssignmentType = .Copy
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Variable, .None, options)
        name = "VariableAsignment"
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        if let expression = expression {
            // Assign to existing variable
            if let existing = context.variables[givenName] {                        
                if let v = expression.execute() {
                    existing.role = expression.isConstant() ? .User : .System
                    if v.getType() == .Float && (assignmentType == .Multiply || assignmentType == .Divide) {
                        existing.assignFromFloat(from: v, using: assignmentType, upTo: assignmentComponents)
                    } else {
                        existing.role = expression.isConstant() ? .User : .System
                        existing.assign(from: v, using: assignmentType)
                    }
                }
            } else {
                // New variable
                context.variables[givenName] = expression.execute()
                context.variables[givenName]!.role = expression.isConstant() ? .User : .System
            }
        }
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates or modifies a variable."
    }
    
    override func getOptions() -> [GraphOption]
    {
        return []
    }
}
