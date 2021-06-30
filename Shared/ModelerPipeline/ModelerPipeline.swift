//
//  ModelerPipeline.swift
//  Signed
//
//  Created by Markus Moenig on 28/6/21.
//

import MetalKit

class ModelerPipeline
{
    var view            : MTKView
    var device          : MTLDevice
        
    var texture         : MTLTexture? = nil

    var commandQueue    : MTLCommandQueue!
    var commandBuffer   : MTLCommandBuffer!
    
    var model           : Model
    
    var semaphore       : DispatchSemaphore
    
    var modelingStates  : ModelerStates
    
    init(_ view: MTKView,_ model: Model)
    {
        self.view = view
        self.model = model
        
        device = view.device!
        semaphore = DispatchSemaphore(value: 1)
        
        modelingStates = ModelerStates(device)
        
        if texture == nil {
            let size = 512
            texture = allocateTexture3D(width: size, height: size, depth: size, format: .r16Float)            
        }
    }
    
    ///
    func executeCommand(_ cmd: SignedCommand)
    {
        if let texture = texture {
            startCompute()

            if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
                
                // Evaluate shapes
                if let state = modelingStates.getComputeState(stateName: "modelerCmd") {
                
                    computeEncoder.setComputePipelineState( state )
                    
                    var modelerUniform = createModelerUniform()
                    computeEncoder.setBytes(&modelerUniform, length: MemoryLayout<ModelerUniform>.stride, index: 0)
                    
                    computeEncoder.setTexture(texture, index: 1 )

                    calculateThreadGroups(state, computeEncoder, texture)
                }
                computeEncoder.endEncoding()
            }
            
            stopCompute(waitUntilCompleted: true)
        }
    }
    
    /// Returns the hit position and normal for a given screen position
    func getSceneHit(_ uv: float2, _ size: float2) -> (float3, float3)? {
        var rc : (float3, float3)? = nil
        
        if let texture = texture {
            
            let outBuffer = device.makeBuffer(length: 2 * MemoryLayout<SIMD4<Float>>.stride, options: [])!

            startCompute()

            if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
                
                // Evaluate shapes
                if let state = modelingStates.getComputeState(stateName: "modelerHitScene") {
                
                    computeEncoder.setComputePipelineState( state )
                    
                    var modelerHitUniform = ModelerHitUniform()

                    modelerHitUniform.randomVector = float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
                    
                    modelerHitUniform.uv = uv
                    modelerHitUniform.size = size
                    modelerHitUniform.scale = 3.0;
                    modelerHitUniform.cameraOrigin = model.project.camera.getPosition()
                    modelerHitUniform.cameraLookAt = float3(0, 0, 0);
                    
                    computeEncoder.setBytes(&modelerHitUniform, length: MemoryLayout<ModelerHitUniform>.stride, index: 0)
                    computeEncoder.setTexture(texture, index: 1 )
                    computeEncoder.setBuffer(outBuffer, offset: 0, index: 2)

                    let numThreadgroups = MTLSize(width: 1, height: 1, depth: 1)
                    let threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
                    computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerThreadgroup)

                }
                computeEncoder.endEncoding()
            }
            
            stopCompute(waitUntilCompleted: true)
            
            let result = outBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: 1)
            
            let distAndNormal = result[0]
            let hitPoint = result[1]
            
            if distAndNormal.x > 0 {
                
            }
            print(distAndNormal, hitPoint)
        }
        return rc
    }
    
    /// Creates the uniform
    func createModelerUniform() -> ModelerUniform
    {
        var modelerUniform = ModelerUniform()
        
        modelerUniform.actionType = Modeler_Add;
        modelerUniform.primitiveType = Modeler_Box;
        
        modelerUniform.size = float3(0.4, 0.4, 0.4);

        modelerUniform.position = float3(0, -0.9, 0);
        modelerUniform.radius = 0.0;

        return modelerUniform
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
    
    /// Compute the threads and thread groups for the given state and texture
    func calculateThreadGroups(_ state: MTLComputePipelineState, _ encoder: MTLComputeCommandEncoder,_ texture: MTLTexture)
    {
        
        let w = state.threadExecutionWidth//limitThreads ? 1 : state.threadExecutionWidth
        let h = state.maxTotalThreadsPerThreadgroup / w//limitThreads ? 1 : state.maxTotalThreadsPerThreadgroup / w
        let d = 1//
        let threadsPerThreadgroup = MTLSizeMake(w, h, d)
        
        let threadgroupsPerGrid = MTLSize(width: (texture.width + w - 1) / w, height: (texture.height + h - 1) / h, depth: (texture.depth + d - 1) / d)
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }
    
    /*
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
    }*/
    
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
    
    /// Allocate a texture of the given size
    func allocateTexture3D(width: Int, height: Int, depth: Int, format: MTLPixelFormat = .rgba16Float) -> MTLTexture?
    {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = MTLTextureType.type3D
        textureDescriptor.pixelFormat = format
        textureDescriptor.width = width == 0 ? 1 : width
        textureDescriptor.height = height == 0 ? 1 : height
        textureDescriptor.depth = depth == 0 ? 1 : depth

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
