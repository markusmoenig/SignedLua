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
        case Idle, Compiling, Rendering
    }
    
    var view            : MTKView
    var device          : MTLDevice

    var status          : Status = .Idle
    
    var renderSize      = SIMD2<Int>()
    
    var texture         : MTLTexture? = nil
    var backTexture     : MTLTexture? = nil
    
    var commandQueue    : MTLCommandQueue!
    var commandBuffer   : MTLCommandBuffer!
    
    var context         : GraphContext! = nil
    
    var quadVertexBuffer: MTLBuffer? = nil
    var quadViewport    : MTLViewport? = nil
    
    init(_ view: MTKView)
    {
        self.view = view
        device = view.device!
    }
    
    func compile(_ ctx: GraphContext)
    {
        context = ctx
        
        if let cameraNode = context.cameraNode {
            cameraNode.gpuShader = GPUCameraShader(pipeline: self)
        }
    }
    
    func render(_ size: SIMD2<Int>? = nil)
    {
        if let rSize = size {
            renderSize.x = rSize.x
            renderSize.y = rSize.y
        } else {
            renderSize.x = Int(view.frame.width)
            renderSize.y = Int(view.frame.height)
        }
        
        checkTextures()
        
        commandQueue = device.makeCommandQueue()
        commandBuffer = commandQueue.makeCommandBuffer()
        quadVertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(renderSize.x), Float(renderSize.y)))
        quadViewport = MTLViewport( originX: 0.0, originY: 0.0, width: Double(renderSize.x), height: Double(renderSize.y), znear: 0.0, zfar: 1.0 )
        
        clearTexture(texture!, float4(1,0,0,1))
        if let cameraNode = context.cameraNode {
            if let cameraShader = cameraNode.gpuShader as? GPUCameraShader {
                cameraShader.render(texture: texture!)
            }
        }
        
        commandBuffer.commit()
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
    
    func checkTextures()
    {
        func checkTexture(_ texture: MTLTexture?) -> MTLTexture? {
            if texture == nil || texture!.width != renderSize.x || texture!.height != renderSize.y {
                if texture != nil {
                    texture!.setPurgeableState(.empty)
                }
                return allocateTexture2D(width: renderSize.x, height: renderSize.y)
            } else {
                return texture
            }
        }

        texture = checkTexture(texture)
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
