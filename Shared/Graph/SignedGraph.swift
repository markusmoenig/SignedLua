//
//  SignedGraphNodes.swift
//  Signed
//
//  Created by Markus Moenig on 11/1/2564 BE.
//

import Foundation

/// DefaultSkyNode
final class GraphDefaultSkyNode : GraphNode
{
    var sunDirection       : Float3 = Float3(0.243, 0.075, 0.512)
    var sunColor           : Float3 = Float3(0.966, 0.966, 0.966)
    var worldHorizonColor  : Float3 = Float3(0.852, 0.591, 0.367)
    var sunStrength        : Float1 = Float1(5)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Sky, .None, options)
        name = "DefaultSky"
        givenName = "Default Sky"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        //if let value = extractFloat1Value(options, context: context, error: &error, name: "radius", isOptional: true) {
        //    radius = value
        //}
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        let camDir = context.rayDirection.toSIMD()
        
        let sunDir = sunDirection.toSIMD()
        let skyColor = float3(0.38, 0.6, 1.0)
        let sunColor = self.sunColor.toSIMD()
        let horizonColor = worldHorizonColor.toSIMD()
        
        let sun : Float = simd_max(simd_dot(camDir, simd_normalize(sunDir)), 0.0)
        let hor : Float = pow(1.0 - simd_max(camDir.y, 0.0), 3.0)
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
class GraphBaseCameraNode : GraphNode
{
    var origin       : Float3 = Float3(0, 0, -5)
    var lookAt       : Float3 = Float3(0, 0, 0)
    var fov          = Float1(80)
}

/// PinholeCameraNode
final class GraphPinholeCameraNode : GraphBaseCameraNode
{
    var mouseDownPos          = float2(0,0)
    
    var cameraHelper          : CameraHelper!
    
    var updateStarted         = false
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Camera, .None, options)
        name = "PinholeCamera"
        givenName = "Pinhole Camera"
        
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
        
        context.rayOrigin.fromSIMD(camOrigin)
        context.rayDirection.fromSIMD(simd_normalize(-dir))
        
        return .Success
    }
    
    /// toolTouchDown
    override func toolTouchDown(_ pos: float2,_ toolContext: GraphToolContext)
    {
        mouseDownPos = pos
        toolContext.checkIfTextureIsValid()
    }
    
    /// toolTouchMove
    override func toolTouchMove(_ pos: float2,_ toolContext: GraphToolContext)
    {
        cameraHelper.move(dx: (mouseDownPos.x - pos.x) * 0.003, dy: (mouseDownPos.y - pos.y) * 0.003, aspect: Float(toolContext.texture!.width) / Float(toolContext.texture!.height))
        mouseDownPos = pos
        
        if updateStarted == false {
            updateStarted = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 ) {
                toolContext.core.scriptProcessor.replaceFloat3InLine(["Origin": self.origin])
                toolContext.core.renderPipeline.restart()
                self.updateStarted = false
            }
        }
    }
    
    /// toolTouchUp
    override func toolTouchUp(_ pos: float2,_ toolContext: GraphToolContext)
    {
        toolContext.core.renderPipeline.restart()
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

/// CameraNode
final class GraphCameraNode : GraphBaseCameraNode
{
    var position     = float3(0, 0, 0)
    
    var up           = float3(0, 0, 0)
    var right        = float3(0, 0, 0)
    var forward      = float3(0, 0, 0)

    var pivot        = float3(0, 0, 0)
    let worldUp      = float3(0, 1, 0)
    
    var focalDistance = Float1(0.1)
    var aperture     = Float1(0)

    var pitch        : Float = 0
    var radius       : Float = 0
    var yaw          : Float = 0
    
    var seed         = float2()

    var mouseDownPos          = float2(0,0)
    var cameraHelper          : CameraHelper!
    var updateStarted         = false
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Camera, .None, options)
        name = "Camera"
        givenName = "Camera"
        
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
        if let value = extractFloat1Value(options, container: context, error: &error, name: "focaldistance", isOptional: true) {
            focalDistance = value
        }
        if let value = extractFloat1Value(options, container: context, error: &error, name: "aperture", isOptional: true) {
            aperture = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.updateDataVariable(origin)
        context.updateDataVariable(lookAt)
        context.updateDataVariable(fov)
        context.updateDataVariable(focalDistance)
        context.updateDataVariable(aperture)

        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> [String: String]
    {
        var codeMap : [String:String] = [:]
        
        context.addDataVariable(origin)
        context.addDataVariable(lookAt)
        context.addDataVariable(fov)
        context.addDataVariable(focalDistance)
        context.addDataVariable(aperture)

        let cameraCode =
        
        """

        const float fov = data[\(fov.dataIndex!)].x;

        float3 position = data[\(origin.dataIndex!)].xyz;
        float3 pivot = data[\(lookAt.dataIndex!)].xyz;
        float focalDist = data[\(focalDistance.dataIndex!)].x;
        float aperture = data[\(aperture.dataIndex!)].x;
        
        float3 dir = normalize(pivot - position);
        float pitch = asin(dir.y);
        float yaw = atan2(dir.z, dir.x);

        float radius = distance(position, pivot);

        float3 forward_temp = float3();
        
        forward_temp.x = cos(yaw) * cos(pitch);
        forward_temp.y = sin(pitch);
        forward_temp.z = sin(yaw) * cos(pitch);

        float3 worldUp = float3(0,1,0);
        float3 forward = normalize(forward_temp);
        position = pivot + (forward * -1.0) * radius;

        float3 right = normalize(cross(forward, worldUp));
        float3 up = normalize(cross(right, forward));

        float2 r2D = 2.0 * float2(rand(dataIn), rand(dataIn));

        float2 jitter = float2();
        jitter.x = r2D.x < 1.0 ? sqrt(r2D.x) - 1.0 : 1.0 - sqrt(2.0 - r2D.x);
        jitter.y = r2D.y < 1.0 ? sqrt(r2D.y) - 1.0 : 1.0 - sqrt(2.0 - r2D.y);

        jitter /= (size * 0.5);
        float2 d = (2.0 * uv - 1.0) + jitter;

        float scale = tan(fov * 0.5);
        d.y *= size.y / size.x * scale;
        d.x *= scale;
        float3 rayDir = normalize(d.x * right + d.y * up + forward);

        float3 focalPoint = focalDist * rayDir;
        float cam_r1 = rand(dataIn) * TWO_PI;
        float cam_r2 = rand(dataIn) * aperture;
        float3 randomAperturePos = (cos(cam_r1) * right + sin(cam_r1) * up) * sqrt(cam_r2);
        float3 finalRayDir = normalize(focalPoint - randomAperturePos);
        
        outOrigin = position + randomAperturePos;
        outDirection = finalRayDir;

        """
        
        codeMap["camera"] = cameraCode
        
        return codeMap
    }
    
    /// toolTouchDown
    override func toolTouchDown(_ pos: float2,_ toolContext: GraphToolContext)
    {
        mouseDownPos = pos
        toolContext.core.renderQuality = .Fastest
        toolContext.checkIfTextureIsValid()
    }
    
    /// toolTouchMove
    override func toolTouchMove(_ pos: float2,_ toolContext: GraphToolContext)
    {
        cameraHelper.move(dx: (mouseDownPos.x - pos.x) * 0.003, dy: (mouseDownPos.y - pos.y) * 0.003, aspect: Float(toolContext.texture!.width) / Float(toolContext.texture!.height))
        mouseDownPos = pos
        
        if updateStarted == false {
            updateStarted = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 ) {
                toolContext.core.scriptProcessor.replaceFloat3InLine(["Origin": self.origin])
                toolContext.core.renderPipeline.restart()
                self.updateStarted = false
            }
        }
    }
    
    /// toolTouchUp
    override func toolTouchUp(_ pos: float2,_ toolContext: GraphToolContext)
    {
        toolContext.core.renderQuality = .Fast
        toolContext.core.renderPipeline.restart()
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
            GraphOption(Float1(80), "Fov", "The field of view of the camera."),
            GraphOption(Float1(0.1), "FocalDistance", "The focal distance."),
            GraphOption(Float1(80), "Aperture", "The aperture of the camera.")
        ]
        return options
    }
}
