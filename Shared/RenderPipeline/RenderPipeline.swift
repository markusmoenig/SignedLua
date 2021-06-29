//
//  RenderPipeline.swift
//  Signed
//
//  Created by Markus Moenig on 26/6/21.
//

import MetalKit

class RenderPipeline
{
    enum Status {
        case Idle, Compiling, Rendering, Invalid
    }
    
    var view            : MTKView
    var device          : MTLDevice

    var status          : Status = .Idle
        
    var texture         : MTLTexture? = nil
    var finalTexture    : MTLTexture? = nil

    var commandQueue    : MTLCommandQueue!
    var commandBuffer   : MTLCommandBuffer!
    
    var quadVertexBuffer: MTLBuffer? = nil
    var quadViewport    : MTLViewport? = nil
    
    var model           : Model
    
    var renderSize      = SIMD2<Int>()
        
    var samples         : Int = 0
    var maxSamples      : Int = 10000
    
    var stopRendering   = false
    var isStopped       = false
    
    var depth           : Int = 0
    var maxDepth        : Int = 4
    
    var testShader      : TestShader!
    
    var semaphore       : DispatchSemaphore
        
    var renderStates    : RenderStates
    
    init(_ view: MTKView,_ model: Model)
    {
        self.view = view
        self.model = model
        
        device = view.device!
        semaphore = DispatchSemaphore(value: 1)
        
        renderStates = RenderStates(device)
        
        model.modeler = ModelerPipeline(view, model)
    }
    
    func render()
    {
        status = .Rendering
        stopRendering = false

        if let rSize = self.model.renderSize {
            renderSize.x = rSize.x
            renderSize.y = rSize.y
        } else {
            renderSize.x = Int(self.view.frame.width)
            renderSize.y = Int(self.view.frame.height)
        }
        
        checkTextures()
        
        if model.modeler?.texture != nil {
            startRendering()
            
            runRender()
            
            commitAndStopRendering()
        }
        
        /*
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {

            if self.status != .Idle && self.isStopped == false {
                return
            }
            
            if self.status == .Invalid {
                return
            }

            self.status = .Rendering
            self.stopRendering = false

            if let rSize = self.model.renderSize {
                self.renderSize.x = rSize.x
                self.renderSize.y = rSize.y
            } else {
                self.renderSize.x = Int(self.view.frame.width)
                self.renderSize.y = Int(self.view.frame.height)
            }
            
            self.checkTextures()
            
            //if self.update() == false {
            //    return
            //}
                    
            /*
            self.startCompute()
            
            if self.previewComponent != nil {

                if let previewShader = self.previewShader {
                    previewShader.render(outTexture: self.finalTexture!)
                }
            } else {
                self.compile()
                self.testShader.render(outTexture: self.finalTexture!)
            }
            */

            self.depth = 0
            self.samples = 0
            //self.computePass()
            self.stopCompute()
            
            self.status = .Idle
            self.updateOnce()
        }
         */
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
    
    func runRender() {
        if let renderState = renderStates.getState(stateName: "render") {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = finalTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(renderState)
            
            // ---
            renderEncoder.setViewport(quadViewport!)
            renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( finalTexture!.width ), UInt32( finalTexture!.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            var renderUniforms = createRenderUniform()
            renderEncoder.setFragmentBytes(&renderUniforms, length: MemoryLayout<RenderUniform>.stride, index: 0)
            
            renderEncoder.setFragmentTexture(model.modeler!.texture, index: 1)

            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    /// Create a uniform buffer containing general information about the current project
    func createRenderUniform() -> RenderUniform
    {
        var renderUniform = RenderUniform()

        renderUniform.randomVector = float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
        
        renderUniform.cameraOrigin = float3(0, 0, 4);
        renderUniform.cameraLookAt = float3(0, 0, 0);

        //fragmentUniforms.maxDepth = Int32(maxDepth);
        //fragmentUniforms.depth = Int32(depth);
        //fragmentUniforms.samples = Int32(samples);
        
        /*
        fragmentUniforms.screenSize = prtInstance.screenSize
        if let ambient = getGlobalVariableValue(withName: "World.worldAmbient") {
            fragmentUniforms.ambientColor = ambient
        }*/
        
        return renderUniform
    }
    
    /// Check and allocate all textures
    func checkTextures()
    {
        var resChanged = false

        func checkTexture(_ texture: MTLTexture?) -> MTLTexture? {
            if texture == nil || texture!.width != renderSize.x || texture!.height != renderSize.y {
                if let texture = texture {
                    //texture.setPurgeableState(.empty)
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

        if resChanged {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                //self.core.updateUI.send()
            }
        }
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
    func allocateTexture2D(width: Int, height: Int, format: MTLPixelFormat = .bgra8Unorm) -> MTLTexture?
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
