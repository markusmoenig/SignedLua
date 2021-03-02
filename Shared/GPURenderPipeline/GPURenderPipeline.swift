//
//  RenderPipeline.swift
//  Signed
//
//  Created by Markus Moenig on 20/1/21.
//

import MetalKit

class GPURenderPipeline
{
    enum Status {
        case Idle, Compiling, Rendering, Invalid
    }
    
    var view            : MTKView
    var device          : MTLDevice

    var status          : Status = .Idle
    
    var renderSize      = SIMD2<Int>()
    
    var finalTexture    : MTLTexture? = nil

    var radianceTexture : MTLTexture? = nil
    var throughputTexture: MTLTexture? = nil

    var texture         : MTLTexture? = nil
    var depthTexture    : MTLTexture? = nil
    var normalTexture   : MTLTexture? = nil

    var camOriginTexture: MTLTexture? = nil
    var camOriginTexture2: MTLTexture? = nil
    var camDirTexture   : MTLTexture? = nil
    
    var paramsTexture1  : MTLTexture? = nil
    var paramsTexture2  : MTLTexture? = nil
    var paramsTexture3  : MTLTexture? = nil
    var paramsTexture4  : MTLTexture? = nil
    var paramsTexture5  : MTLTexture? = nil
    var paramsTexture6  : MTLTexture? = nil
    
    var utilityTexture1 : MTLTexture? = nil
    var utilityTexture2 : MTLTexture? = nil
    
    var absorptionTexture : MTLTexture? = nil

    var commandQueue    : MTLCommandQueue!
    var commandBuffer   : MTLCommandBuffer!
    
    var context         : GraphContext! = nil
    
    var quadVertexBuffer: MTLBuffer? = nil
    var quadViewport    : MTLViewport? = nil
    
    var dataBuffer      : MTLBuffer? = nil
    var lightsDataBuffer: MTLBuffer? = nil

    var materialsShader : GPUMaterialsShader? = nil
    
    // Global Uniforms
    var cameraOrigin    = float3()
    var cameraLookAt    = float3()
    
    var gpuAccum        : GPUAccumShader!
    
    var stopRendering   : Bool = false
    
    var samples         : Int = 0
    var maxSamples      : Int = 10000
    
    var isStopped       = false
    
    var depth           : Int = 0
    var maxDepth        : Int = 4
    
    var resChanged      = true
    
    var core            : Core
    
    var semaphore       : DispatchSemaphore

    init(_ view: MTKView,_ core: Core)
    {
        self.view = view
        self.core = core
        device = view.device!
        semaphore = DispatchSemaphore(value: 1)
    }
    
    func update() -> Bool
    {
        if let cameraNode = context.cameraNode {
            cameraNode.execute(context: context)
        }
        
        if let environmentNode = context.environmentNode {
            environmentNode.execute(context: context)
        }
        
        for node in context.analyticalNodes {
            context.position = float3(0,0,0)
            context.rotation = float3(0,0,0)
            context.scale = 1
            node.execute(context: context)
        }
        
        for node in context.sdfNodes {
            context.position = float3(0,0,0)
            context.rotation = float3(0,0,0)
            context.scale = 1
            node.execute(context: context)
        }
                
        if dataBuffer != nil {
            dataBuffer!.setPurgeableState(.empty)
            dataBuffer = nil
        }
        
        if context.data.count == 0 { context.data.append(float4()) }//return false }
        dataBuffer = device.makeBuffer(bytes: context.data, length: context.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        
        if lightsDataBuffer != nil {
            lightsDataBuffer!.setPurgeableState(.empty)
            lightsDataBuffer = nil
        }
        lightsDataBuffer = device.makeBuffer(bytes: context.lightsData, length: context.lightsData.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        
        return true
    }
    
    func compile(_ ctx: GraphContext)
    {
        context = ctx        
        
        stop()
        status = .Compiling
        context.setupBeforeCompiling()
        
        gpuAccum = GPUAccumShader(pipeline: self)

        if let cameraNode = context.cameraNode {
            cameraNode.gpuShader = GPUCameraShader(pipeline: self)
        }
        
        if let node = context.sunNode {
            _ = node.generateMetalCode(context: context)
        }
        
        materialsShader = GPUMaterialsShader(pipeline: self)
        
        for node in context.analyticalNodes {
            node.gpuShader = GPUAnalyticalShader(pipeline: self, object: node)
        }
        
        for node in context.sdfNodes {
            node.gpuShader = GPUSDFShader(pipeline: self, object: node)
        }
        
        status = .Idle
        restart()
    }
    
    func getTexture() -> MTLTexture? {
        if samples < 1 {
            // Return nil if no sample has been calculated yet
            return nil
        } else {
            return finalTexture
        }
    }
    
    func render()
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {

            if (self.status != .Idle && self.status != .Invalid) && self.isStopped == false {
                return
            }

            self.status = .Rendering
            self.stopRendering = false

            if let rSize = self.core.customRenderSize {
                self.renderSize.x = rSize.x
                self.renderSize.y = rSize.y
            } else {
                self.renderSize.x = Int(self.view.frame.width)
                self.renderSize.y = Int(self.view.frame.height)
            }
            
            self.checkTextures()
            
            if self.update() == false {
                return
            }
                    
            self.startRendering()
            self.clearTexture(self.finalTexture!, float4(0, 0, 0, 0))

            self.depth = 0
            self.samples = 0
            self.computePass()
        }
    }
    
    func stop()
    {
        if status == .Rendering {
            stopRendering = true
        }
    }
    
    func restart()
    {
        stop()
        render()
    }
    
    func setInvalid(_ text: String)
    {
        stop()
        status = .Invalid
        startRendering()
        if let finalTexture = finalTexture {
            clearTexture(finalTexture, float4(0, 0, 0, 1))
        }
        commitAndStopRendering()
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
    
    func computePass()
    {
        if depth == 0 && stopRendering == false {
            
            clearTexture(radianceTexture!, float4(0, 0, 0, 0))
            clearTexture(throughputTexture!, float4(1, 1, 1, 1))
            clearTexture(absorptionTexture!, float4(0, 0, 0, 0))
            clearTexture(normalTexture!, float4(1, 1, 1, 1))

            if let cameraNode = context.cameraNode {
                if let cameraShader = cameraNode.gpuShader as? GPUCameraShader, stopRendering == false {
                    cameraShader.render()
                }
            }
        }

        computeL()
        materialsShader!.pathTracer()
        
        depth += 1
        
        if depth >= maxDepth && stopRendering == false {
            gpuAccum.render(finalTexture: finalTexture!, sampleTexture: radianceTexture!)
            self.depth = 0
            self.samples += 1
        }
        
        commandBuffer.addCompletedHandler { cb in            
            if self.stopRendering == false && self.samples < self.maxSamples {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    self.startRendering()
                    self.computePass()
                    self.updateOnce()
                    self.core.samplesChanged.send(SIMD2<Double>(Double(self.samples), (cb.gpuEndTime - cb.gpuStartTime) * 1000))
                }
            } else {
                self.status = .Idle
                if self.stopRendering == true && self.isStopped == false {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        self.render()
                    }
                }
            }
        }
            
        commitAndStopRendering()
    }
    
    func computeL()
    {
        clearTexture(texture!, float4(0, 0, 0, 0))
        clearTexture(depthTexture!, float4(1000,-1,-1,-1))
        
        for node in context.analyticalNodes {
            if let object = node.gpuShader as? GPUAnalyticalShader, stopRendering == false {
                object.render(camOriginTexture: camOriginTexture!, camDirTexture: camDirTexture!, depthTexture: depthTexture!, normalTexture: normalTexture!)
            }
        }
        
        for node in context.sdfNodes {
            if let object = node.gpuShader as? GPUSDFShader, stopRendering == false {
                object.render(camOriginTexture: camOriginTexture!, camDirTexture: camDirTexture!, depthTexture: depthTexture!, normalTexture: normalTexture!)
                commandBuffer.addCompletedHandler { cb in
                    self.semaphore.signal()
                }
                commitAndStopRendering()
                semaphore.wait()
                startRendering()
            }
        }
        
        if stopRendering == false {
            materialsShader!.render()
        }
        
        // Now we have the new hit in camOrigin and the light sampling direction in params5: Shadow pass
        
        if stopRendering == false {
            clearTexture(utilityTexture1!, float4(1000,-1,-1,-1))
        }

        for node in context.analyticalNodes {
            if let object = node.gpuShader as? GPUAnalyticalShader, stopRendering == false {
                object.render(camOriginTexture: camOriginTexture2!, camDirTexture: paramsTexture5!, depthTexture: utilityTexture1!, normalTexture: utilityTexture2!)
            }
        }
        
        for node in context.sdfNodes {
            if let object = node.gpuShader as? GPUSDFShader, stopRendering == false {
                object.render(camOriginTexture: camOriginTexture2!, camDirTexture: paramsTexture5!, depthTexture: utilityTexture1!, normalTexture: utilityTexture2!)
                commandBuffer.addCompletedHandler { cb in
                    self.semaphore.signal()
                }
                commitAndStopRendering()
                semaphore.wait()
                startRendering()
            }
        }
        
        if stopRendering == false {
            materialsShader!.directLight(depthTexture: depthTexture!, normalTexture: normalTexture!, lightDepthTexture: utilityTexture1!, lightNormalTexture: utilityTexture2!)
        }
    }
    
    func updateOnce()
    {
        #if os(OSX)
        let nsrect : NSRect = NSRect(x:0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        self.view.setNeedsDisplay(nsrect)
        #else
        self.view.setNeedsDisplay()
        #endif
    }
    
    /// Create a uniform buffer containing general information about the current project
    func createFragmentUniform() -> GPUFragmentUniforms
    {
        var fragmentUniforms = GPUFragmentUniforms()

        fragmentUniforms.randomVector = float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
        
        fragmentUniforms.maxDepth = Int32(maxDepth);
        fragmentUniforms.depth = Int32(depth);
        fragmentUniforms.samples = Int32(samples);
        
        /*
        fragmentUniforms.screenSize = prtInstance.screenSize
        if let ambient = getGlobalVariableValue(withName: "World.worldAmbient") {
            fragmentUniforms.ambientColor = ambient
        }*/
        
        return fragmentUniforms
    }
    
    /// Clears the textures
    func clearTexture(_ texture: MTLTexture,_ color: float4 = SIMD4<Float>(0,0,0,1))
    {
        let renderPassDescriptor = MTLRenderPassDescriptor()

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(Double(color.x), Double(color.y), Double(color.z), Double(color.w))
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.endEncoding()
    }
    
    /// Checks if the current texture size is valid
    func checkIfTextureIsValid() -> Bool
    {
        if texture == nil { return false }
        
        if let customRenderSize = core.customRenderSize {
            if customRenderSize.x != texture?.width || customRenderSize.y != texture?.height {
                return false
            }
        } else {
            if Int(view.frame.width) != texture?.width || Int(view.frame.height) != texture?.height {
                return false
            }
        }
        return true
    }
    
    /// Check and allocate all textures
    func checkTextures()
    {
        resChanged = false

        func checkTexture(_ texture: MTLTexture?) -> MTLTexture? {
            if texture == nil || texture!.width != renderSize.x || texture!.height != renderSize.y {
                if let texture = texture {
                    texture.setPurgeableState(.empty)
                }
                resChanged = true
                let texture = allocateTexture2D(width: renderSize.x, height: renderSize.y)
                if texture == nil { print("error allocating texture") }
                return texture
            } else {
                return texture
            }
        }

        finalTexture = checkTexture(finalTexture)

        texture = checkTexture(texture)
        
        radianceTexture = checkTexture(radianceTexture)
        throughputTexture = checkTexture(throughputTexture)

        depthTexture = checkTexture(depthTexture)
        normalTexture = checkTexture(normalTexture)
        camOriginTexture = checkTexture(camOriginTexture)
        camOriginTexture2 = checkTexture(camOriginTexture2)
        camDirTexture = checkTexture(camDirTexture)
        
        paramsTexture1 = checkTexture(paramsTexture1)
        paramsTexture2 = checkTexture(paramsTexture2)
        paramsTexture3 = checkTexture(paramsTexture3)
        paramsTexture4 = checkTexture(paramsTexture4)
        paramsTexture5 = checkTexture(paramsTexture5)
        paramsTexture6 = checkTexture(paramsTexture6)
        
        utilityTexture1 = checkTexture(utilityTexture1)
        utilityTexture2 = checkTexture(utilityTexture2)

        absorptionTexture = checkTexture(absorptionTexture)

        if resChanged {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.core.updateUI.send()
            }
        }
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
