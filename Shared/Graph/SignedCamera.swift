//
//  SignedGraphNodes.swift
//  Signed
//
//  Created by Markus Moenig on 11/1/2564 BE.
//

import Foundation

/// BaseCameraNode
class GraphBaseCameraNode : GraphNode
{
    var origin                : Float3 = Float3(0, 0, -5)
    var lookAt                : Float3 = Float3(0, 0, 0)
    var fov                   = Float1(80)
    
    var cameraHelper          : CameraHelper!
    
    override func getToolViewButtons() -> [ToolViewButton]
    {
        return [ToolViewButton(name: "Zoom"), ToolViewButton(name: "Move"), ToolViewButton(name: "Rotate")]
    }
    
    var maxDepthBuffer  : Int = 1
    var lastChanged     : Double? = nil
     
    var zoomBuffer      : SIMD3<Float> = SIMD3<Float>(0,0,0)
    
    override func toolViewButtonAction(_ button: ToolViewButton, state: ToolViewButton.State, delta: float2, toolContext: GraphToolContext)
    {
        if state == .Down || delta == float2(0,0) {
            toolContext.validate()
            maxDepthBuffer = toolContext.core.renderPipeline.maxDepth
            toolContext.core.renderPipeline.maxDepth = 1
            cameraHelper.update()
        } else
        if state == .Move {
            cameraHelper.update()
            if button.name == "Move" {
                let diffX : Float = delta.x * 0.003
                let diffY : Float = -delta.y * 0.003
                
                cameraHelper.move(dx: diffX, dy: diffY, aspect: toolContext.aspectRatio)
            } else
            if button.name == "Zoom" {
                cameraHelper.zoom(dx: 0, dy: delta.x * 0.003)
            } else
            if button.name == "Rotate" {
                cameraHelper.rotate(dx: delta.x * 0.003, dy: -delta.y * 0.003)
            }
            toolContext.core.renderPipeline.restart()
        } else
        if state == .Up {
            toolContext.core.scriptProcessor.replaceFloat3InLine(["Origin": origin, "LookAt": lookAt])
            toolContext.core.renderPipeline.maxDepth = maxDepthBuffer
            toolContext.core.renderPipeline.restart()
        }        
    }

    override func toolPinchGesture(_ scale: Float,_ firstTouch: Bool,_ toolContext: GraphToolContext)
    {
        func testEnd() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 ) {
                let time = Double(Date().timeIntervalSince1970)
                if let lastChanged = self.lastChanged {
                
                    if time - lastChanged > 1 {
                        toolContext.core.scriptProcessor.replaceFloat3InLine(["Origin": self.origin, "LookAt": self.lookAt])
                        toolContext.core.renderPipeline.maxDepth = self.maxDepthBuffer
                        toolContext.core.renderPipeline.restart()
                        self.lastChanged = nil
                    } else {
                        testEnd()
                    }
                }
            }
        }
        
        if lastChanged == nil {
            maxDepthBuffer = toolContext.core.renderPipeline.maxDepth
            toolContext.core.renderPipeline.maxDepth = 1
            testEnd()
            cameraHelper.update()
        }

        lastChanged = Double(Date().timeIntervalSince1970)
        
        if firstTouch == true {
            zoomBuffer = origin.toSIMD() - lookAt.toSIMD()
        }
        
        cameraHelper.zoomRelative(dx: 0, dy: scale, start: zoomBuffer)
        toolContext.core.renderPipeline.restart()
    }
    
    /*
    override func toolScrollWheel(_ delta: float3,_ toolContext: GraphToolContext)
    {
        toolContext.validate()
        
        func testEnd() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 ) {
                let time = Double(Date().timeIntervalSince1970)
                if let lastChanged = self.lastChanged {
                
                    if time - lastChanged > 1 {
                        toolContext.core.scriptProcessor.replaceFloat3InLine(["Origin": self.origin, "LookAt": self.lookAt])
                        toolContext.core.renderPipeline.maxDepth = self.maxDepthBuffer
                        toolContext.core.renderPipeline.restart()
                        self.lastChanged = nil
                    } else {
                        testEnd()
                    }
                }
            }
        }
        
        if lastChanged == nil {
            maxDepthBuffer = toolContext.core.renderPipeline.maxDepth
            toolContext.core.renderPipeline.maxDepth = 1
            testEnd()
            cameraHelper.update()
        }

        lastChanged = Double(Date().timeIntervalSince1970)

        #if os(iOS)
        let clickCount = Int(delta.z)
        if clickCount == 2 {
            cameraHelper.rotate(dx: delta.x * 0.003, dy: delta.y * 0.003)
        } else {
            cameraHelper.move(dx: delta.x * 0.0006, dy: delta.y * 0.0006, aspect: toolContext.aspectRatio)
        }
        #elseif os(OSX)
        if toolContext.commandIsDown {
            if delta.y != 0 {
                cameraHelper.zoom(dx: 0, dy: delta.y * 0.03)
            }
        } else
        if toolContext.shiftIsDown {
            cameraHelper.rotate(dx: delta.x * 0.003, dy: delta.y * 0.003)
        } else {
            cameraHelper.move(dx: delta.x * 0.003, dy: delta.y * 0.003, aspect: toolContext.aspectRatio)
        }
        #endif
        
        toolContext.core.renderPipeline.restart()
    }
    */
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
    var updateStarted         = false
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Camera, .None, options)
        name = "Camera"
        givenName = "Camera"
        
        cameraHelper = CameraHelper(self)
        hasToolUI = true
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
    override func generateMetalCode(context: GraphContext) -> String
    {
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
        float cam_r1 = rand(dataIn) * M_2_PI_F;
        float cam_r2 = rand(dataIn) * aperture;
        float3 randomAperturePos = (cos(cam_r1) * right + sin(cam_r1) * up) * sqrt(cam_r2);
        float3 finalRayDir = normalize(focalPoint - randomAperturePos);
        
        outOrigin = position + randomAperturePos;
        outDirection = finalRayDir;

        """
                
        return cameraCode
    }
    
    /// toolTouchDown
    override func toolTouchDown(_ pos: float2,_ toolContext: GraphToolContext)
    {
        //mouseDownPos = pos
        //toolContext.validate()
    }
    
    /// toolTouchMove
    override func toolTouchMove(_ pos: float2,_ toolContext: GraphToolContext)
    {
        /*
        cameraHelper.move(dx: (mouseDownPos.x - pos.x) * 0.003, dy: (mouseDownPos.y - pos.y) * 0.003, aspect: Float(toolContext.texture!.width) / Float(toolContext.texture!.height))
        mouseDownPos = pos
        
        if updateStarted == false {
            updateStarted = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 ) {
                toolContext.core.scriptProcessor.replaceFloat3InLine(["Origin": self.origin])
                toolContext.core.renderPipeline.restart()
                self.updateStarted = false
            }
        }*/
    }
    
    /// toolTouchUp
    override func toolTouchUp(_ pos: float2,_ toolContext: GraphToolContext)
    {
        //toolContext.core.renderPipeline.restart()
    }
    
    override func getHelp() -> String
    {
        return "A pinhole camera supporting focal distance and aperture."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0, 0, -5), "Origin", "The camera origin (viewer position)."),
            GraphOption(Float3(0, 0, 0), "LookAt", "The position the camera is looking at."),
            GraphOption(Float1(80), "Fov", "The field of view of the camera."),
            GraphOption(Float1(0.1), "FocalDistance", "The focal distance."),
            GraphOption(Float1(0), "Aperture", "The aperture of the camera.")
        ]
        return options
    }
}

/// IsometricCameraNode
final class GraphIsometricCameraNode : GraphBaseCameraNode
{
    var mouseDownPos          = float2(0,0)
    
    var updateStarted         = false
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Camera, .None, options)
        name = "Isometric Camera"
        givenName = "Isometric Camera"
        
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
        context.updateDataVariable(origin)
        context.updateDataVariable(lookAt)
        context.updateDataVariable(fov)

        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        context.addDataVariable(origin)
        context.addDataVariable(lookAt)
        context.addDataVariable(fov)

        let cameraCode =
        
        """

        float ratio = size.x / size.y;
        float2 pixelSize = float2(1) / size;
        float2 jitter = float2(rand(dataIn), rand(dataIn));

        float3 origin = data[\(origin.dataIndex!)].xyz;
        float3 lookAt = data[\(lookAt.dataIndex!)].xyz;
        const float fov = data[\(fov.dataIndex!)].x;

        float halfWidth = tan(radians(fov) * 0.5) * fov;
        float halfHeight = halfWidth / ratio;
        
        float3 upVector = float3(0,1,0);
        
        float3 w = normalize(origin - lookAt);
        float3 u = cross(upVector, w);
        float3 v = cross(w,u);

        float3 horizontal = u * halfWidth * 2.0;
        float3 vertical = v * halfHeight * 2.0;
        
        float3 dir = -w;

        outOrigin = origin;
        outOrigin += horizontal * (pixelSize.x * jitter.x + uv.x - 0.5);
        outOrigin += vertical * (pixelSize.y * jitter.y + uv.y - 0.5);
        outDirection = normalize(dir);

        """
                
        return cameraCode
    }
    
    override func getHelp() -> String
    {
        return "An isometric camera. Use the field of view to zoom in / out."
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
