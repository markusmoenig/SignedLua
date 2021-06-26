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
    
    init(_ view: MTKView,_ model: Model)
    {
        self.view = view
        self.model = model
                
        device = view.device!
        semaphore = DispatchSemaphore(value: 1)
    }
    
    func compile() {
        testShader = TestShader(pipeline: self)
    }
    
    func render()
    {
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
                    
            self.compile()

            self.startCompute()
            //self.clearTexture(self.finalTexture!, float4(0, 0, 0, 0))
            self.testShader.render(outTexture: self.finalTexture!)

            self.depth = 0
            self.samples = 0
            //self.computePass()
            self.stopCompute()
        }
    }
    
    /// Starts compute operation
    func startCompute()
    {
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        commandBuffer = commandQueue.makeCommandBuffer()
    }
    
    /// Stops compute operation
    func stopCompute(syncTexture: MTLTexture? = nil, waitUntilCompleted: Bool = false)
    {
        #if os(OSX)
        if let texture = syncTexture {
            let blitEncoder = commandBuffer!.makeBlitCommandEncoder()!
            blitEncoder.synchronize(texture: texture, slice: 0, level: 0)
            blitEncoder.endEncoding()
        }
        #endif
        commandBuffer?.commit()
        if waitUntilCompleted {
            commandBuffer?.waitUntilCompleted()
        }
        commandBuffer = nil
    }
    
    /// Check and allocate all textures
    func checkTextures()
    {
        var resChanged = false

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
}
