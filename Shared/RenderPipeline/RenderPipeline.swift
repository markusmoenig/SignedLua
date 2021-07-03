//
//  RenderPipeline.swift
//  Signed
//
//  Created by Markus Moenig on 26/6/21.
//

import MetalKit

class RenderPipeline
{
    var view            : MTKView
    var device          : MTLDevice

    var commandQueue    : MTLCommandQueue!
    var commandBuffer   : MTLCommandBuffer!
    
    var quadVertexBuffer: MTLBuffer? = nil
    var quadViewport    : MTLViewport? = nil
    
    var model           : Model
    
    var renderSize      = SIMD2<Int>()
        
    var maxSamples      : Int = 10000
    
    var depth           : Int = 0
    var maxDepth        : Int = 4
        
    var semaphore       : DispatchSemaphore
        
    var renderStates    : RenderStates
        
    ///
    var iconQueue       : [SignedCommand] = []
        
    init(_ view: MTKView,_ model: Model)
    {
        self.view = view
        self.model = model
        
        device = view.device!
        semaphore = DispatchSemaphore(value: 1)
        
        renderStates = RenderStates(device)
        
        model.modeler = ModelerPipeline(view, model)
    }
    
    /// Restarts the renderer
    func restart(_ started: Bool = false)
    {        
        _ = checkMainKitTextures()
        
        if let mainKit = model.modeler?.mainKit {

            if started == false {
                startRendering()
            }
            
            clearTexture(mainKit.outputTexture!)
            
            if started == false {
                commitAndStopRendering()
            }
        
            mainKit.samples = 0
        }
    }
    
    /// Render a single sample
    func renderSample()
    {
        startRendering()

        if checkMainKitTextures() {
            restart(true)
        }
                
        if let mainKit = model.modeler?.mainKit {
            runRender(mainKit)
            
            model.modeler?.accumulate(texture: mainKit.sampleTexture!, targetTexture: mainKit.outputTexture!, samples: mainKit.samples)
            mainKit.samples += 1
        }
        
        commitAndStopRendering()
        
        // Render an icon sample ?
        if let icon = iconQueue.first {
            startRendering()
                    
            if let iconKit = model.modeler?.iconKit, iconKit.isValid() {
                
                if iconKit.samples == 0 {
                    clearTexture(iconKit.outputTexture!)
                }
                
                runRender(iconKit)
                
                model.modeler?.accumulate(texture: iconKit.sampleTexture!, targetTexture: iconKit.outputTexture!, samples: iconKit.samples)
                iconKit.samples += 1
                
                if iconKit.samples == ModelerPipeline.IconSamples {
                    iconQueue.removeFirst()
                    
                    icon.icon = model.modeler?.kitToImage(iconKit)
                    model.iconFinished.send(icon)
                    
                    // Init the next one to render
                    iconKit.samples = 0
                    if let next = iconQueue.first {
                        model.modeler?.executeCommand(next, iconKit, clearFirst: true)
                    }
                }
            }
            
            commitAndStopRendering()
        }
    }
    
    func startRendering()
    {
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        commandBuffer = commandQueue.makeCommandBuffer()
        quadVertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(renderSize.x), Float(renderSize.y)))
        quadViewport = MTLViewport( originX: 0.0, originY: 0.0, width: Double(renderSize.x), height: Double(renderSize.y), znear: 0.0, zfar: 1.0)
    }
    
    func commitAndStopRendering()
    {
        commandBuffer.commit()
        commandBuffer = nil
        quadVertexBuffer = nil
        quadViewport = nil
    }
    
    func runRender(_ kit: ModelerKit) {
        if let renderState = renderStates.getState(stateName: "render") {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = kit.sampleTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(renderState)
            
            // ---
            renderEncoder.setViewport(quadViewport!)
            renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( kit.outputTexture!.width ), UInt32( kit.outputTexture!.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            var renderUniforms = createRenderUniform(model.modeler?.mainKit !== kit)
            renderEncoder.setFragmentBytes(&renderUniforms, length: MemoryLayout<RenderUniform>.stride, index: 0)
            
            var modelerUniform = model.modeler?.createModelerUniform(model.editingCmd)
            renderEncoder.setFragmentBytes(&modelerUniform, length: MemoryLayout<ModelerUniform>.stride, index: 1)
            
            renderEncoder.setFragmentTexture(kit.modelTexture, index: 2)
            renderEncoder.setFragmentTexture(kit.colorTexture, index: 3)

            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    /// Create a uniform buffer containing general information about the current project
    func createRenderUniform(_ icon: Bool = false) -> RenderUniform
    {
        var renderUniform = RenderUniform()

        renderUniform.randomVector = float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
        
        if icon == false {
            renderUniform.cameraOrigin = model.project.camera.getPosition()
            renderUniform.cameraLookAt = model.project.camera.getLookAt()
            renderUniform.scale = model.project.scale
            
            renderUniform.backgroundColor = float4(0.02, 0.02, 0.02, 1);
            
            renderUniform.numOfLights = 1
            renderUniform.lights.0.position = float3(0,2,0)
            renderUniform.lights.0.emission = float3(10,10,10)
            renderUniform.lights.0.params.x = 1
            renderUniform.lights.0.params.y = 4.0 * Float.pi * 1 * 1;//light.radius * light.radius;
            renderUniform.lights.0.params.z = 1
        } else {
            renderUniform.cameraOrigin = float3(0, 0, 2)
            renderUniform.cameraLookAt = float3(0, 0, 0);
            renderUniform.scale = 1
            
            renderUniform.backgroundColor = float4(0,0,0,1);
            
            renderUniform.numOfLights = 1
            renderUniform.lights.0.position = float3(0,2,0)
            renderUniform.lights.0.emission = float3(10,10,10)
            renderUniform.lights.0.params.x = 1
            renderUniform.lights.0.params.y = 4.0 * Float.pi * 1 * 1;//light.radius * light.radius;
            renderUniform.lights.0.params.z = 1
            
        }
                
        /*
        if (strcmp(light_type, "Quad") == 0)
         {
             light.type = LightType::RectLight;
             light.u = v1 - light.position;
             light.v = v2 - light.position;
             light.area = Vec3::Length(Vec3::Cross(light.u, light.v));
         }
         else if (strcmp(light_type, "Sphere") == 0)
         {
             light.type = LightType::SphereLight;
             light.area = 4.0f * PI * light.radius * light.radius;
         }*/
        
        return renderUniform
    }
    
    
    /// Check and allocate all textures, returns true if the textures had to be changed / reallocated
    func checkMainKitTextures() -> Bool
    {
        var resChanged = false

        if let mainKit = model.modeler?.mainKit {
            
            // Get the renderSize
            if let rSize = self.model.renderSize {
                renderSize.x = rSize.x
                renderSize.y = rSize.y
            } else {
                renderSize.x = Int(self.view.frame.width)
                renderSize.y = Int(self.view.frame.height)
            }

            func checkTexture(_ texture: MTLTexture?) -> MTLTexture? {
                if texture == nil || texture!.width != renderSize.x || texture!.height != renderSize.y {
                    //if let texture = texture {
                        //texture.setPurgeableState(.empty)
                    //}
                    resChanged = true
                    let texture = allocateTexture2D(width: renderSize.x, height: renderSize.y)
                    if texture == nil { print("error allocating texture") }
                    return texture
                } else {
                    return texture
                }
            }

            mainKit.sampleTexture = checkTexture(mainKit.sampleTexture)
            mainKit.outputTexture = checkTexture(mainKit.outputTexture)
        }
        
        if resChanged {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.model.updateUI.send()
            }
        }

        return resChanged
    }
    
    /// Updates the view once
    func updateOnce()
    {
        #if os(OSX)
        let nsrect : NSRect = NSRect(x:0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        self.view.setNeedsDisplay(nsrect)
        #else
        self.view.setNeedsDisplay()
        #endif
    }
    
    /// Allocate a texture of the given size
    func allocateTexture2D(width: Int, height: Int, format: MTLPixelFormat = .rgba16Float) -> MTLTexture?
    {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = MTLTextureType.type2D
        textureDescriptor.pixelFormat = format
        textureDescriptor.width = width == 0 ? 1 : width
        textureDescriptor.height = height == 0 ? 1 : height
        
        textureDescriptor.usage = MTLTextureUsage.unknown
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    /// Clears the texture
    func clearTexture(_ texture: MTLTexture,_ color: float4 = SIMD4<Float>(0,0,0,1))
    {
        let renderPassDescriptor = MTLRenderPassDescriptor()

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(Double(color.x), Double(color.y), Double(color.z), Double(color.w))
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.endEncoding()
    }
    
    /// Creates a vertex buffer for a quad shader
    func getQuadVertexBuffer(_ rect: MMRect ) -> MTLBuffer?
    {
        let left = -rect.width / 2 + rect.x
        let right = left + rect.width//self.width / 2 - x
        
        let top = rect.height / 2 - rect.y
        let bottom = top - rect.height
        
        let quadVertices: [Float] = [
            right, bottom, 1.0, 0.0,
            left, bottom, 0.0, 0.0,
            left, top, 0.0, 1.0,
            
            right, bottom, 1.0, 0.0,
            left, top, 0.0, 1.0,
            right, top, 1.0, 1.0,
            ]
        
        return device.makeBuffer(bytes: quadVertices, length: quadVertices.count * MemoryLayout<Float>.stride, options: [])!
    }
}
