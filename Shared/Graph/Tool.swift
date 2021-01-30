//
//  Tool.swift
//  Signed
//
//  Created by Markus Moenig on 7/1/21.
//

import MetalKit

class GraphToolContext {
    var texture             : MTLTexture? = nil

    var commandQueue        : MTLCommandQueue? = nil
    var commandBuffer       : MTLCommandBuffer? = nil
    
    // --- Key States
    var shiftIsDown         : Bool = false
    var commandIsDown       : Bool = false
    
    var aspectRatio         : Float = 0
    
    let core                : Core

    init(_ core: Core)
    {
        self.core = core
    }
    
    deinit {
        clear()
    }
    
    func clear() {
        if texture != nil { texture!.setPurgeableState(.empty); texture = nil }
    }
    
    func validate()
    {
        if texture == nil {
            texture = allocateTexture(core.device, width: Int(core.view.frame.width), height: Int(core.view.frame.height))
        }
        checkIfTextureIsValid(forceClear: true)
        aspectRatio = Float(core.view.frame.width) / Float(core.view.frame.height)
    }
    
    func startDrawing(_ device: MTLDevice)
    {
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        commandBuffer = commandQueue!.makeCommandBuffer()
    }
    
    func stopDrawing(syncTexture: MTLTexture? = nil, waitUntilCompleted: Bool = false)
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
    
    func allocateTexture(_ device: MTLDevice, width: Int, height: Int) -> MTLTexture?
    {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = MTLTextureType.type2D
        textureDescriptor.pixelFormat = MTLPixelFormat.rgba32Float
        textureDescriptor.width = width == 0 ? 1 : width
        textureDescriptor.height = height == 0 ? 1 : height
        
        textureDescriptor.usage = MTLTextureUsage.unknown
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    /// Creates vertex data for the given rectangle
    func createVertexData(texture: MTLTexture, rect: MMRect) -> [Float]
    {
        let left: Float  = -Float(texture.width) / 2.0 + rect.x
        let right: Float = left + rect.width//self.width / 2 - x
        
        let top: Float = Float(texture.height) / 2.0 - rect.y
        let bottom: Float = top - rect.height

        let quadVertices: [Float] = [
            right, bottom, 1.0, 0.0,
            left, bottom, 0.0, 0.0,
            left, top, 0.0, 1.0,
            
            right, bottom, 1.0, 0.0,
            left, top, 0.0, 1.0,
            right, top, 1.0, 1.0,
        ]
        
        return quadVertices
    }
    
    /// Checks if the texture size is valid and if not stop rendering and resize and clear the texture
    @discardableResult func checkIfTextureIsValid(forceClear: Bool = true) -> Bool
    {
        let size = SIMD2<Int>(Int(core.view.frame.width), Int(core.view.frame.height))
        
        if size.x == 0 || size.y == 0 {
            return false
        }
        
        // Make sure texture is of size size
        if texture == nil || texture!.width != size.x || texture!.height != size.y {
                        
            if texture != nil {
                texture!.setPurgeableState(.empty)
                texture = nil
            }
            texture = allocateTexture(core.device, width: size.x, height: size.y)
            
            startDrawing(core.device)
            clearTexture()
            stopDrawing(syncTexture: texture!, waitUntilCompleted: true)
        } else {
            if forceClear {
                startDrawing(core.device)
                clearTexture()
                stopDrawing(syncTexture: texture!, waitUntilCompleted: true)
            }
        }
        return true
    }
    
    /// Clears the textures
    func clearTexture(_ color: float4 = SIMD4<Float>(0,0,0,0))
    {
        if let texture = texture {
            let renderPassDescriptor = MTLRenderPassDescriptor()

            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(Double(color.x), Double(color.y), Double(color.z), Double(color.w))
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            let renderEncoder = commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.endEncoding()
        }
    }
}
