//
//  ModelerPipeline.swift
//  Signed
//
//  Created by Markus Moenig on 28/6/21.
//

import MetalKit

/// Holds all the textures needed to model and render
class ModelerKit {
    
    // For modeling
    var modelTexture    : MTLTexture? = nil
    var colorTexture    : MTLTexture? = nil
    var materialTexture1: MTLTexture? = nil
    var materialTexture2: MTLTexture? = nil
    var materialTexture3: MTLTexture? = nil
    var materialTexture4: MTLTexture? = nil

    // For rendering
    var sampleTexture   : MTLTexture? = nil
    var outputTexture   : MTLTexture? = nil
    
    var samples         : Int32 = 0
    var maxSamples      : Int32 = 400

    func isValid() -> Bool {
        return modelTexture != nil && colorTexture != nil
    }
}

class ModelerPipeline
{
    var view            : MTKView
    var device          : MTLDevice

    var commandQueue    : MTLCommandQueue!
    var commandBuffer   : MTLCommandBuffer!
    
    var model           : Model
    
    var semaphore       : DispatchSemaphore
    
    var modelingStates  : ModelerStates
    
    /// The main kit for rendering the preview
    var mainKit         : ModelerKit!
    
    /// The kit used to render previews
    var iconKit         : ModelerKit!
    
    /// The script handler
    var scriptHandler   : ScriptHandler? = nil
    
    static var IconSize : Int = 80
    static var IconSamples : Int = 40
    
    var buildIndex      : Int? = nil
    var buildTo         : SignedCommand? = nil
    var buildIndexFinished : Bool = true

    init(_ view: MTKView,_ model: Model)
    {
        self.view = view
        self.model = model
        
        device = view.device!
        semaphore = DispatchSemaphore(value: 1)
        
        modelingStates = ModelerStates(device)
        
        mainKit = allocateKit(512)
        iconKit = allocateKit(ModelerPipeline.IconSize)
        
        iconKit.sampleTexture = allocateTexture2D(width: ModelerPipeline.IconSize, height: ModelerPipeline.IconSize)
        iconKit.outputTexture = allocateTexture2D(width: ModelerPipeline.IconSize, height: ModelerPipeline.IconSize)

        if let object = model.project.objects.first {
            executeObject(object)
        }
        
        scriptHandler = ScriptHandler(self)
    }
    
    ///
    func executeNext()
    {
        if buildIndexFinished == false {
            // Still rendering
            return
        }
        
        guard let object = model.selectedObject else {
            buildTo = nil
            buildIndex = nil
            model.renderer?.restart()
            return
        }
        
        buildIndexFinished = false
            
        if buildIndex == nil {
            if let first = object.commands.first {
                executeCommand(first, clearFirst: true)
                if buildTo === object.commands.first {
                    buildTo = nil
                    buildIndex = nil
                    model.renderer?.restart()
                } else
                if object.commands.count > 1 {
                    buildIndex = 1
                }
            }
        } else {
            let cmd = object.commands[buildIndex!]
            executeCommand(cmd)
            if cmd === buildTo || buildIndex == object.commands.count - 1 {
                buildTo = nil
                buildIndex = nil
                model.renderer?.restart()
            } else {
                buildIndex! += 1
            }
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
    func executeCommand(_ cmd: SignedCommand,_ modelerKit: ModelerKit? = nil, clearFirst: Bool = false)
    {
        let kitToUse : ModelerKit? = modelerKit == nil ? mainKit : modelerKit
        
        if clearFirst {
            clear(kitToUse)
        }
        
        if let kit = kitToUse, kit.isValid() {
            startCompute()
            
            let jsSupport = scriptHandler?.setup(cmd)

            if jsSupport?.0 == true {
                // Script handles geometry creation
            } else {
                // No script, execute the geometry command
                if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
                    if let state = modelingStates.getComputeState(stateName: "modelerCmd") {
                    
                        computeEncoder.setComputePipelineState( state )
                        
                        var modelerUniform = createModelerUniform(cmd)
                        computeEncoder.setBytes(&modelerUniform, length: MemoryLayout<ModelerUniform>.stride, index: 0)
                        
                        computeEncoder.setTexture(kit.modelTexture!, index: 1 )
                        computeEncoder.setTexture(kit.colorTexture, index: 2 )
                        computeEncoder.setTexture(kit.materialTexture1!, index: 3 )
                        computeEncoder.setTexture(kit.materialTexture2!, index: 4 )
                        computeEncoder.setTexture(kit.materialTexture3!, index: 5 )
                        computeEncoder.setTexture(kit.materialTexture4!, index: 6 )

                        calculateThreadGroups(state, computeEncoder, kit.modelTexture!)
                    }
                    computeEncoder.endEncoding()
                }
                
                commandBuffer?.addCompletedHandler { cb in
                    print("Rendering Time:", (cb.gpuEndTime - cb.gpuStartTime) * 1000)
                    self.buildIndexFinished = true
                }
            }
            
            stopCompute(waitUntilCompleted: false)
            
            scriptHandler?.close()
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
                
        modelerUniform.roleType = cmd.role.rawValue
        modelerUniform.actionType = cmd.action.rawValue
        modelerUniform.primitiveType = cmd.primitive.rawValue
        
        //modelerUniform.brushHit = model.editingHit
        //modelerUniform.writeBrush = model.writeAction
        modelerUniform.materialOnlyMixerValue = model.materialOnlyMixer
        
        if let transformData = cmd.dataGroups.getGroup("Transform") {
            modelerUniform.position = transformData.getFloat3("Position")
            modelerUniform.rotation = transformData.getFloat3("Rotation")
        }
        
        if let modifierData = cmd.dataGroups.getGroup("Modifier") {
            modelerUniform.noise = modifierData.getFloat("Noise")
            modelerUniform.surfaceDistance = modifierData.getFloat("Surface Distance", 0)
        }
        
        if let geometryData = cmd.dataGroups.getGroup("Geometry") {
            modelerUniform.size = geometryData.getFloat3("Size", float3(1,1,1))
            modelerUniform.radius = geometryData.getFloat("Radius", 1)
            modelerUniform.rounding = geometryData.getFloat("Rounding", 0)
        }
        
        if let booleanData = cmd.dataGroups.getGroup("Boolean") {
            modelerUniform.smoothing = booleanData.getFloat("Smoothing", 0.1)
        }
        
        modelerUniform.normal = cmd.normal                
        modelerUniform.material = cmd.material.toMaterialStruct()
        modelerUniform.mixer = cmd.material.toMaterialMixerStruct()
        
        if cmd.role == .GeometryAndMaterial {
            cmd.geometryId = model.getNextGeometryId()
            modelerUniform.id = Int32(cmd.geometryId)
        } else {
            modelerUniform.id = Int32(cmd.geometryId)
        }

        return modelerUniform
    }
    
    /// Clears the modeling textures
    func clear(_ modelerKit: ModelerKit? = nil)
    {
        let kitToUse : ModelerKit? = modelerKit == nil ? mainKit : modelerKit
        
        if let kit = kitToUse, kit.isValid() {
            startCompute()

            if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
                
                if let state = modelingStates.getComputeState(stateName: "modelerClear") {
                    computeEncoder.setComputePipelineState( state )
                    computeEncoder.setTexture(kit.modelTexture!, index: 0 )
                    computeEncoder.setTexture(kit.colorTexture!, index: 1 )
                    computeEncoder.setTexture(kit.materialTexture1!, index: 2 )
                    computeEncoder.setTexture(kit.materialTexture2!, index: 3 )
                    computeEncoder.setTexture(kit.materialTexture3!, index: 4 )
                    computeEncoder.setTexture(kit.materialTexture4!, index: 5 )
                    calculateThreadGroups(state, computeEncoder, kit.modelTexture!)
                }
                computeEncoder.endEncoding()
            }
            
            stopCompute(waitUntilCompleted: true)
        }
    }
    
    /// Returns the hit position and normal for a given screen position
    func getSceneHit(_ uv: float2, _ size: float2) -> (float3, float3, Float)? {
        var rc : (float3, float3, Float)? = nil
        
        if let kit = mainKit {
            
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
                    modelerHitUniform.scale = model.project.getWorldScale()
                    modelerHitUniform.cameraOrigin = model.project.camera.getPosition()
                    modelerHitUniform.cameraLookAt = model.project.camera.getLookAt()
                    modelerHitUniform.cameraFov = model.project.camera.getFov()

                    computeEncoder.setBytes(&modelerHitUniform, length: MemoryLayout<ModelerHitUniform>.stride, index: 0)
                    computeEncoder.setTexture(kit.modelTexture, index: 1 )
                    computeEncoder.setTexture(kit.materialTexture4, index: 2 )
                    computeEncoder.setBuffer(outBuffer, offset: 0, index: 3)

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
                rc = (float3(hitPoint.x, hitPoint.y, hitPoint.z), float3(distAndNormal.y, distAndNormal.z, distAndNormal.w), hitPoint.w)
            }
        }
        return rc
    }
    
    /// Allocates a set of textures needed for modeling
    func allocateKit(_ size: Int) -> ModelerKit {
        let modelerKit = ModelerKit()
        
        //print(device.supportsFeatureSet(.macOS_GPUFamily2_v1))
        modelerKit.modelTexture = allocateTexture3D(width: size, height: size, depth: size, format: .r16Float)
        modelerKit.colorTexture = allocateTexture3D(width: size, height: size, depth: size, format: .rgba16Float);////.bgra8Unorm)
        modelerKit.materialTexture1 = allocateTexture3D(width: size, height: size, depth: size, format: .rgba16Float)
        modelerKit.materialTexture2 = allocateTexture3D(width: size, height: size, depth: size, format: .rgba16Float)
        modelerKit.materialTexture3 = allocateTexture3D(width: size, height: size, depth: size, format: .rgba16Float)
        modelerKit.materialTexture4 = allocateTexture3D(width: size, height: size, depth: size, format: .rgba16Float)
        
        /*
        modelerKit.colorTexture = allocateTexture3D(width: size, height: size, depth: size, format: .bgra8Unorm);////.bgra8Unorm)
        modelerKit.materialTexture1 = allocateTexture3D(width: size, height: size, depth: size, format: .bgra8Unorm)
        modelerKit.materialTexture2 = allocateTexture3D(width: size, height: size, depth: size, format: .bgra8Unorm)
        modelerKit.materialTexture3 = allocateTexture3D(width: size, height: size, depth: size, format: .bgra8Unorm)
        modelerKit.materialTexture4 = allocateTexture3D(width: size, height: size, depth: size, format: .bgra8Unorm)*/
        
        return modelerKit
    }
    
    /// Converts a kit to a CGIImage
    func kitToImage(_ modelerKit: ModelerKit? = nil) -> CGImage? {
        let kitToUse : ModelerKit? = modelerKit == nil ? mainKit : modelerKit

        if let kit = kitToUse {
            func makeCGIImage(texture: MTLTexture) -> CGImage?
            {
                let width = texture.width
                let height = texture.height
                let pixelByteCount = 4 * MemoryLayout<UInt8>.size
                let imageBytesPerRow = width * pixelByteCount
                let imageByteCount = imageBytesPerRow * height
                
                let imageBytes = UnsafeMutableRawPointer.allocate(byteCount: imageByteCount, alignment: pixelByteCount)
                defer {
                    imageBytes.deallocate()
                }

                texture.getBytes(imageBytes,
                                 bytesPerRow: imageBytesPerRow,
                                 from: MTLRegionMake2D(0, 0, width, height),
                                 mipmapLevel: 0)
                guard let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB) else { return nil }
                let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
                guard let bitmapContext = CGContext(data: nil,
                                                    width: width,
                                                    height: height,
                                                    bitsPerComponent: 8,
                                                    bytesPerRow: imageBytesPerRow,
                                                    space: colorSpace,
                                                    bitmapInfo: bitmapInfo) else { return nil }
                bitmapContext.data?.copyMemory(from: imageBytes, byteCount: imageByteCount)
                let image = bitmapContext.makeImage()
                return image
            }
            
            startCompute()

            if let texture = allocateTexture2D(width: kit.outputTexture!.width, height: kit.outputTexture!.height, format: .bgra8Unorm) {
                
                if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
                    
                    // Evaluate shapes
                    if let state = modelingStates.getComputeState(stateName: "modelerMakeCGIImage") {
                    
                        computeEncoder.setComputePipelineState( state )
                        computeEncoder.setTexture(texture, index: 0)
                        computeEncoder.setTexture(kit.outputTexture, index: 1)

                        calculateThreadGroups(state, computeEncoder, kit.outputTexture!)
                    }
                    computeEncoder.endEncoding()
                }
                
                stopCompute(syncTexture: texture, waitUntilCompleted: true)
                
                return makeCGIImage(texture: texture)
            }
        }
        return nil
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
