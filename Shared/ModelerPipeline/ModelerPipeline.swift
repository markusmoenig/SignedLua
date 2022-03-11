//
//  ModelerPipeline.swift
//  Signed
//
//  Created by Markus Moenig on 28/6/21.
//

import MetalKit

/// Holds all the textures and metadata needed to model
class ModelerKit {
    
    enum Role {
        case main, icon
    }
    
    enum Content {
        case project, object, material
    }
    
    enum Status {
        case ready, running, rendering
    }
    
    var role            : Role = .main
    var status          : Status = .ready
    var content         : Content = .project
    
    /// Scale of the kit
    var scale           = Float(1)

    var modelGPUBusy    : Bool = false
    var renderGPUBusy   : Bool = false

    // For modeling
    var modelTexture    : MTLTexture? = nil
    var colorTexture    : MTLTexture? = nil
    var materialTexture1: MTLTexture? = nil
    var materialTexture2: MTLTexture? = nil
    var materialTexture3: MTLTexture? = nil
    var materialTexture4: MTLTexture? = nil

    var pipeline        : [SignedCommand] = []

    // For rendering
    
    var renderKits      : [RenderKit] = []
    var currentRenderKit: RenderKit? = nil
    
    var renderName      : String = "renderBSDF"

    func isValid() -> Bool {
        return modelTexture != nil && colorTexture != nil
    }
    
    // If this pass computes an object, put the pointer to it here to install the icon
    var objectEntity    : ObjectEntity? = nil
    
    // If this pass computes a material, put the pointer to it here to install the icon
    var materialEntity  : MaterialEntity? = nil
    
    /// Installes the next available renderkit if any, returns true if the rendered kit was a preview kit (icon)
    func installNextRenderKit() -> Bool {
        var wasIcon = false
        if renderKits.count > 0 {
            if let renderKit = currentRenderKit {
                wasIcon = renderKit.icon
            }
            currentRenderKit = renderKits.removeFirst()
            currentRenderKit?.samples = 0
        } else {
            if let renderKit = currentRenderKit {
                wasIcon = renderKit.icon
            }
            currentRenderKit = nil
        }
        return wasIcon
    }
}

class ModelerPipeline
{
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
    
    static var IconSize : Int = 80
        
    init(_ model: Model)
    {
        self.model = model
        
        device = model.renderView.device!
        semaphore = DispatchSemaphore(value: 1)
        
        modelingStates = ModelerStates(device)

        mainKit = allocateKit(width: model.project.resolution, height: model.project.resolution, depth: model.project.resolution)
        iconKit = allocateKit(width: ModelerPipeline.IconSize, height: ModelerPipeline.IconSize, depth: ModelerPipeline.IconSize)
        iconKit.role = .icon
        iconKit.renderName = "renderPBR"

        clear()
    }
    
    /// Executes the next command in the pipeline of the kit
    func executeNext(kit: ModelerKit)
    {
        if kit.pipeline.isEmpty { return }
        
        executeCommand(kit.pipeline.removeFirst(), kit)
    }
    
    /// Executes a single command
    func executeCommand(_ cmd: SignedCommand,_ modelerKit: ModelerKit? = nil, clearFirst: Bool = false)
    {
        let kitToUse : ModelerKit? = modelerKit == nil ? mainKit : modelerKit
        
        if clearFirst {
            clear(kitToUse)
        }
        
        if let kit = kitToUse, kit.isValid() {
            
            if cmd.action == .Clear {
                clear(kit)
                kit.modelGPUBusy = false
                if kit.role == .main {
                    self.model.progressCurrent += 1
                    self.model.builder?.context.sendProgressNotification()
                }
                return
            }
            
            startCompute()
            
            // No script, execute the geometry command
            if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
                if let state = modelingStates.getComputeState(stateName: "modelerCmd") {
                
                    computeEncoder.setComputePipelineState( state )
                    
                    var modelerUniform = createModelerUniform(cmd, kit: kit)
                    computeEncoder.setBytes(&modelerUniform, length: MemoryLayout<ModelerUniform>.stride, index: 0)
                    
                    computeEncoder.setTexture(kit.modelTexture!, index: 1 )
                    computeEncoder.setTexture(kit.colorTexture, index: 2 )
                    computeEncoder.setTexture(kit.materialTexture1!, index: 3 )
                    computeEncoder.setTexture(kit.materialTexture2!, index: 4 )
                    computeEncoder.setTexture(kit.materialTexture3!, index: 5 )
                    computeEncoder.setTexture(kit.materialTexture4!, index: 6 )

                    calculateThreadGroups(state, computeEncoder, kit.modelTexture!)
                }
                kit.modelGPUBusy = true
                computeEncoder.endEncoding()
            }
            
            commandBuffer?.addCompletedHandler { cb in
                kit.modelGPUBusy = false
                if kit.role == .main {
                    self.model.progressCurrent += 1
                    self.model.builder?.context.sendProgressNotification()
                }
                print("Modeling Time:", (cb.gpuEndTime - cb.gpuStartTime) * 1000)
            }
            
            stopCompute(waitUntilCompleted: false)            
        }
    }
    
    /// Creates the uniform
    func createModelerUniform(_ cmd: SignedCommand, kit: ModelerKit, forPreview: Bool = false) -> ModelerUniform
    {
        var modelerUniform = ModelerUniform()
                
        modelerUniform.roleType = cmd.role.rawValue
        modelerUniform.actionType = cmd.action.rawValue
        modelerUniform.primitiveType = cmd.primitive.rawValue
        
        let scale = kit.scale
        
        if cmd.role == .GeometryAndMaterial {
            if let transformData = cmd.dataGroups.getGroup("Transform") {
                modelerUniform.position = transformData.getFloat3("position") / scale
                modelerUniform.rotation = transformData.getFloat3("rotation")
                modelerUniform.pivot = transformData.getFloat3("pivot") / scale
            }
            
            if let modifierData = cmd.dataGroups.getGroup("Modifier") {
                modelerUniform.noise = modifierData.getFloat("noise", 0.3)
                modelerUniform.depth = modifierData.getFloat2("depth", float2(-5, 5))
                modelerUniform.onion = modifierData.getFloat("onion", 0.0)
                modelerUniform.max = modifierData.getFloat3("max", float3(10, 10, 10))
            }
            
            if let geometryData = cmd.dataGroups.getGroup("Geometry") {
                modelerUniform.size = geometryData.getFloat3("size", float3(4,4,4)) / scale / 2
                modelerUniform.radius = geometryData.getFloat("radius", 1) / scale
                modelerUniform.height = geometryData.getFloat("height", 1) / scale / 2
                modelerUniform.rounding = geometryData.getFloat("rounding", 0)
                
                modelerUniform.heightFrequency = geometryData.getFloat("frequency", 2)
                modelerUniform.heightOctaves = geometryData.getFloat("octaves", 5)
                modelerUniform.heightScale = geometryData.getFloat("scale", 0.2)
            }
            
            if let booleanData = cmd.dataGroups.getGroup("Boolean") {
                modelerUniform.smoothing = booleanData.getFloat("smoothing", 0.1)
                if cmd.action != .Clear {
                    let booleanMode = booleanData.getText("mode")
                    switch booleanMode {
                    case "subtract":
                        modelerUniform.actionType = SignedCommand.Action.Subtract.rawValue
                    default:
                        modelerUniform.actionType = SignedCommand.Action.Add.rawValue
                    }
                }
            }
            
            if let repetitionData = cmd.dataGroups.getGroup("Repetition") {
                modelerUniform.repDistance = repetitionData.getFloat("distance", 0)
                modelerUniform.repLowerLimit = repetitionData.getFloat3("lowerLimit", float3(0,0,0))
                modelerUniform.repUpperLimit = repetitionData.getFloat3("upperLimit", float3(0,0,0))
            }
        } else {
            if let modifierData = cmd.dataGroups.getGroup("Modifier") {
                modelerUniform.noise = modifierData.getFloat("noise", 0.3)
                modelerUniform.depth = modifierData.getFloat2("depth", float2(-5, 5))
            }
        }
        
        modelerUniform.material = cmd.material.toMaterialStruct()
        
        modelerUniform.blendMode = cmd.blendMode.rawValue
        
        modelerUniform.blendLinearValue = cmd.blendOptions.getFloat("value", 1)
        
        modelerUniform.blendOffset = cmd.blendOptions.getFloat3("offset", float3(0,0,0))
        modelerUniform.blendFrequency = cmd.blendOptions.getFloat("frequency", 1)
        modelerUniform.blendSmoothing = cmd.blendOptions.getFloat("smoothing", 5)

        modelerUniform.id = Int32(cmd.materialId)

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
                    modelerHitUniform.scale = 1
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
    func allocateKit(width: Int, height: Int, depth: Int) -> ModelerKit {
        let modelerKit = ModelerKit()
        
        print("allocateKit", width, height, depth)
                
        //print(device.supportsFeatureSet(.macOS_GPUFamily2_v1))
        modelerKit.modelTexture = allocateTexture3D(width: width, height: height, depth: depth, format: .r16Float)
//        #if os(OSX)
//        modelerKit.colorTexture = allocateTexture3D(width: width, height: height, depth: depth, format: .rgba16Float)
//        modelerKit.materialTexture1 = allocateTexture3D(width: width, height: height, depth: depth, format: .rgba16Float)
//        modelerKit.materialTexture2 = allocateTexture3D(width: width, height: height, depth: depth, format: .rgba16Float)
//        modelerKit.materialTexture3 = allocateTexture3D(width: width, height: height, depth: depth, format: .rgba16Float)
//        modelerKit.materialTexture4 = allocateTexture3D(width: width, height: height, depth: depth, format: .rgba16Float)
//        #elseif os(iOS)
        modelerKit.colorTexture = allocateTexture3D(width: width, height: height, depth: depth, format: .bgra8Unorm)
        modelerKit.materialTexture1 = allocateTexture3D(width: width, height: height, depth: depth, format: .bgra8Unorm)
        modelerKit.materialTexture2 = allocateTexture3D(width: width, height: height, depth: depth, format: .bgra8Unorm)
        modelerKit.materialTexture3 = allocateTexture3D(width: width, height: height, depth: depth, format: .bgra8Unorm)
        modelerKit.materialTexture4 = allocateTexture3D(width: width, height: height, depth: depth, format: .bgra8Unorm)
//        #endif
        
        return modelerKit
    }
    
    func freeKit(_ kit: ModelerKit) {
        kit.modelTexture?.setPurgeableState(.volatile);
        kit.colorTexture?.setPurgeableState(.volatile);
        kit.materialTexture1?.setPurgeableState(.volatile);
        kit.materialTexture2?.setPurgeableState(.volatile);
        kit.materialTexture3?.setPurgeableState(.volatile);
        kit.materialTexture4?.setPurgeableState(.volatile);

        kit.modelTexture = nil
        kit.colorTexture = nil
        kit.materialTexture1 = nil
        kit.materialTexture2 = nil
        kit.materialTexture3 = nil
        kit.materialTexture4 = nil
    }
    
    /// Converts a kit to a CGIImage
    func kitToImage(renderKit: RenderKit) -> CGImage? {

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

        if let texture = allocateTexture2D(width: renderKit.outputTexture!.width, height: renderKit.outputTexture!.height, format: .bgra8Unorm) {
            
            if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
                
                // Evaluate shapes
                if let state = modelingStates.getComputeState(stateName: "modelerMakeCGIImage") {
                
                    computeEncoder.setComputePipelineState( state )
                    computeEncoder.setTexture(texture, index: 0)
                    computeEncoder.setTexture(renderKit.outputTexture, index: 1)

                    calculateThreadGroups(state, computeEncoder, renderKit.outputTexture!)
                }
                computeEncoder.endEncoding()
            }
            
            stopCompute(syncTexture: texture, waitUntilCompleted: true)
            
            return makeCGIImage(texture: texture)
        }

        return nil
    }
    
    /// Convert a CGImage to Data
    func cgiImageToData(image: CGImage) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
            let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
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
        let nsrect : NSRect = NSRect(x:0, y: 0, width: model.renderView.frame.width, height: model.renderView.frame.height)
        model.renderView.setNeedsDisplay(nsrect)
        #else
        model.renderView.setNeedsDisplay()
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
