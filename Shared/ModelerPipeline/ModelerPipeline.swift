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
    var colorTexture    : MTLTexture? = nil

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
            colorTexture = allocateTexture3D(width: size, height: size, depth: size, format: .bgra8Unorm)
        }
        
        if let object = model.project.objects.first {
            executeObject(object)
        }
    }
    
    /// Executes all commands of the object
    func executeObject(_ object: SignedObject, until: SignedCommand? = nil)
    {
        clear()
        for cmd in object.commands {
            executeCommand(cmd)
            if cmd === until {
                break
            }
        }
    }
    
    /// Executes a single command
    func executeCommand(_ cmd: SignedCommand)
    {
        if let texture = texture {
            startCompute()

            if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
                if let state = modelingStates.getComputeState(stateName: "modelerCmd") {
                
                    computeEncoder.setComputePipelineState( state )
                    
                    var modelerUniform = createModelerUniform(cmd)
                    computeEncoder.setBytes(&modelerUniform, length: MemoryLayout<ModelerUniform>.stride, index: 0)
                    
                    computeEncoder.setTexture(texture, index: 1 )
                    computeEncoder.setTexture(colorTexture, index: 2 )

                    calculateThreadGroups(state, computeEncoder, texture)
                }
                computeEncoder.endEncoding()
            }            
            stopCompute(waitUntilCompleted: true)
        }
    }
    
    /// Accumulates the rendered texture into the target, placed here for convenience (compute)
    func accumulate(texture: MTLTexture, targetTexture: MTLTexture, samples: Int32)
    {
        startCompute()

        if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
            if let state = modelingStates.getComputeState(stateName: "modelerAccum") {
            
                computeEncoder.setComputePipelineState( state )
                
                var uniform = AccumUniform()
                uniform.samples = samples
                                
                computeEncoder.setBytes(&uniform, length: MemoryLayout<RenderUniform>.stride, index: 0)
                
                computeEncoder.setTexture(texture, index: 1 )
                computeEncoder.setTexture(targetTexture, index: 2 )

                calculateThreadGroups(state, computeEncoder, texture)
            }
            computeEncoder.endEncoding()
        }
        stopCompute(waitUntilCompleted: true)
    }
    
    /// Creates the uniform
    func createModelerUniform(_ cmd: SignedCommand) -> ModelerUniform
    {
        var modelerUniform = ModelerUniform()
                
        modelerUniform.actionType = cmd.action.rawValue
        modelerUniform.primitiveType = cmd.primitive.rawValue
        
        if let position = cmd.data.getFloat3("Position") {
            modelerUniform.position = position
        }
        
        if let size = cmd.data.getFloat3("Size") {
            modelerUniform.size = size
        }
        
        if let radius = cmd.data.getFloat("Radius") {
            modelerUniform.radius = radius
        }
        
        if let rounding = cmd.data.getFloat("Rounding") {
            modelerUniform.rounding = rounding
        }
        
        /*
        state.mat.albedo = colorAndRoughness.xyz;
        state.mat.specular = 0;
        state.mat.anisotropic = 0;
        state.mat.metallic = 0;
        state.mat.roughness = colorAndRoughness.w;
        state.mat.subsurface = 0;
        state.mat.specularTint = 0;
        state.mat.sheen = 0;
        state.mat.sheenTint = 0;
        state.mat.clearcoat = 0;
        state.mat.clearcoatGloss = 0;
        state.mat.specTrans = 0;
        state.mat.ior = 1.45;
        state.mat.emission = float3(0);
        state.mat.atDistance = 1.0;*/
        
        modelerUniform.material.albedo = float3(0.5,0.5,0.5);
        modelerUniform.material.roughness = 0.5;
        
        if cmd.primitive == .Sphere {
            modelerUniform.material.albedo = float3(1,0,1);
        }
        

        return modelerUniform
    }
    
    /// Clears the modeling textures
    func clear()
    {
        if let texture = texture {
            startCompute()

            if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
                
                if let state = modelingStates.getComputeState(stateName: "modelerClear") {
                    computeEncoder.setComputePipelineState( state )
                    computeEncoder.setTexture(texture, index: 0 )
                    computeEncoder.setTexture(colorTexture, index: 1 )
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
                    modelerHitUniform.scale = model.project.scale
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
                rc = (float3(hitPoint.x, hitPoint.y, hitPoint.z), float3(distAndNormal.y, distAndNormal.z, distAndNormal.w))
            }
        }
        return rc
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
