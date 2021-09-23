//
//  RenderPipeline.swift
//  Signed
//
//  Created by Markus Moenig on 26/6/21.
//

import MetalKit

/// Holds all the textures and metadata needed to render
class RenderKit {
    
    
    init(maxSamples: Int32) {
        self.maxSamples = maxSamples
    }
    
    var sampleTexture   : MTLTexture? = nil
    var outputTexture   : MTLTexture? = nil
    
    var samples         : Int32 = 0
    var maxSamples      : Int32

    func isValid() -> Bool {
        return sampleTexture != nil && outputTexture != nil
    }
}

class RenderPipeline
{
    var device          : MTLDevice

    var commandQueue    : MTLCommandQueue!
    var commandBuffer   : MTLCommandBuffer!
    
    var model           : Model
    
    var renderSize      = SIMD2<Int>()
            
    var depth           : Int = 0
    var maxDepth        : Int = 4
        
    var semaphore       : DispatchSemaphore
        
    var renderStates    : RenderStates
    
    var needsRestart    : Bool = true
        
    /// The queue for shape icons
    var iconQueue       : [SignedCommand] = []
    
    /// The main render kit
    var mainRenderKit   : RenderKit
    
    /// The icon render kit
    var iconRenderKit   : RenderKit
    
    var iconBuilder     : SignedBuilder
        
    init(_ model: Model)
    {
        self.model = model
        
        device = model.renderView!.device!
        semaphore = DispatchSemaphore(value: 1)
        
        renderStates = RenderStates(device)
        
        mainRenderKit = RenderKit(maxSamples: model.project.getMaxSamples())
        iconRenderKit = RenderKit(maxSamples: 50)
        
        model.modeler = ModelerPipeline(model)

        if let modeler = model.modeler {
            iconRenderKit.sampleTexture = modeler.allocateTexture2D(width: ModelerPipeline.IconSize, height: ModelerPipeline.IconSize)
            iconRenderKit.outputTexture = modeler.allocateTexture2D(width: ModelerPipeline.IconSize, height: ModelerPipeline.IconSize)
            
            modeler.mainKit.currentRenderKit = mainRenderKit
            modeler.iconKit.currentRenderKit = iconRenderKit
        }
        
        iconBuilder = SignedBuilder(model)
    }
    
    /// Restarts the path tracer
    func restart()
    {
        model.renderView?.isPaused = false
        if let modeler = model.modeler {
            if modeler.mainKit.currentRenderKit == nil {
                modeler.mainKit.currentRenderKit = mainRenderKit
            }
        }
        
        mainRenderKit.samples = 0
        mainRenderKit.maxSamples = model.project.getMaxSamples()
        
        if model.progress != .modelling {
            model.progress = .rendering
            model.progressCurrent = 0
            model.progressTotal = model.project.getMaxSamples()
        }
    }
    
    /// Resumes the renderer
    func resume()
    {
        model.renderView?.isPaused = false
    }
    
    /// Restarts the renderer
    func performRestart(_ started: Bool = false, clear: Bool = false)
    {        
        _ = checkMainKitTextures()
        
        if started == false {
            startCompute()
        }
        
        if clear {
            if let outputTexture = model.modeler?.mainKit.currentRenderKit?.outputTexture {
                var color = float4(0.25,0.25,0.25,1)
                if let renderData = model.project.dataGroups.getGroup("Renderer") {
                    color = renderData.getFloat4("Background")
                }
                clearTexture(outputTexture, color)
            }
        }
        
        if started == false {
            stopCompute()
        }
    
        mainRenderKit.samples = 0
    }
    
    /// Render a single sample
    func renderSample()
    {
        if let mainKit = model.modeler?.mainKit {
            if mainKit.pipeline.isEmpty == false {
                if mainKit.modelGPUBusy == false {
                    model.modeler?.executeNext(kit: mainKit)
                    if mainKit.pipeline.isEmpty {
                        model.currentRenderName = "renderPBR"
                        needsRestart = true
                        
                        model.progress = .rendering
                        model.progressCurrent = 0
                        model.progressTotal = mainRenderKit.maxSamples
                        
                        model.modellingEnded.send()
                    }
                    mainRenderKit.samples = 0
                }
            }
        }
        
        startCompute()

        if checkMainKitTextures() {
            performRestart(true, clear: true)
            needsRestart = false
        } else
        if needsRestart {
            performRestart(true, clear: true)
            needsRestart = false
        }
                                
        if let mainKit = model.modeler?.mainKit, mainKit.renderGPUBusy == false {
            
            if let renderKit = mainKit.currentRenderKit {
                if renderKit.samples < renderKit.maxSamples {
                    
                    mainKit.renderGPUBusy = true
                    commandBuffer?.addCompletedHandler { cb in
                        mainKit.renderGPUBusy = false
                        //print("Rendering Time:", (cb.gpuEndTime - cb.gpuStartTime) * 1000, renderKit.samples)
                    }
                    
                    runRender(mainKit)
                    accumulate(renderKit: mainRenderKit)
                    mainRenderKit.samples += 1
                    
                    if model.progress == .rendering {
                        model.progressCurrent += 1
                        model.progressChanged.send()
                    }
                } else {
                    
                    model.progress = .none
                    model.progressCurrent = 0
                    model.progressTotal = 0
                    
                    self.model.progressChanged.send()
                    
                    mainKit.installNextRenderKit()
                    if mainKit.content == .object && mainKit.currentRenderKit == nil {
                        if let objectEntity = mainKit.objectEntity {
                            if let image = model.modeler!.kitToImage(renderKit: iconRenderKit) {
                                objectEntity.icon = model.modeler!.cgiImageToData(image: image)
                                model.iconFinished.send(objectEntity.id!)
                                mainKit.objectEntity = nil
                                
                                // Save the icon in DB
                                let managedObjectContext = PersistenceController.shared.container.viewContext
                                do {
                                    try managedObjectContext.save()
                                } catch {}
                            }
                        }
                    } else
                    if mainKit.content == .material && mainKit.currentRenderKit == nil {
                        if let materialEntity = mainKit.materialEntity {
                            if let image = model.modeler!.kitToImage(renderKit: iconRenderKit) {
                                materialEntity.icon = model.modeler!.cgiImageToData(image: image)
                                model.iconFinished.send(materialEntity.id!)
                                mainKit.materialEntity = nil
                                
                                // Save the icon in DB
                                let managedObjectContext = PersistenceController.shared.container.viewContext
                                do {
                                    try managedObjectContext.save()
                                } catch {}
                            }
                        }
                    }
                }
            }
        }
        
        stopCompute()//waitUntilCompleted: true)
        
        // Render a shape icon sample ? These icons don't use Lua or public modules and are just based on their single SignedCommand
        
        if let icon = iconQueue.first {
            //startRendering(SIMD2<Int>(ModelerPipeline.IconSize, ModelerPipeline.IconSize))
            startCompute()
                    
            if let iconKit = model.modeler?.iconKit, iconKit.isValid(),
               let renderKit = iconKit.currentRenderKit {
                
                if renderKit.samples == 0 {
                    clearTexture(renderKit.outputTexture!)
                }
                
                runRender(iconKit)
                
                accumulate(renderKit: renderKit)
                renderKit.samples += 1
                
                if renderKit.samples == renderKit.maxSamples {
                    iconQueue.removeFirst()
                    
                    icon.icon = model.modeler?.kitToImage(renderKit: iconRenderKit)
                    model.iconFinished.send(icon.id)
                    
                    // Init the next one to render
                    renderKit.samples = 0
                    installNextShapeIconCmd(iconQueue.first)
                    
                    iconKit.status = .ready
                }
            }
            
            stopCompute()
        } else {
            iconRenderKit.maxSamples = 400
            if let mainKit = model.modeler?.mainKit {
                if mainKit.pipeline.isEmpty && mainKit.currentRenderKit == nil && iconQueue.isEmpty {
                    model.renderView?.isPaused = true
                    print("paused")
                }
           }
        }
    }
    
    /// Installs the next shape icon command
    func installNextShapeIconCmd(_ cmd: SignedCommand?) {
        if let cmd = cmd {
            model.iconCmd = cmd//.copy()!
            model.modeler?.clear(model.modeler?.iconKit)
        } else {
            model.iconCmd.action = .None
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
    
    func runRender(_ kit: ModelerKit) {
        if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
            
            var renderName = kit.renderName
            if kit.role == .main {
                renderName = model.currentRenderName
            }
            
            if let state = renderStates.getComputeState(stateName: renderName) {
                
                computeEncoder.setComputePipelineState( state )
                
                var renderUniforms = createRenderUniform(kit: kit)
                computeEncoder.setBytes(&renderUniforms, length: MemoryLayout<RenderUniform>.stride, index: 0)
                
                if kit.role == .main {
                    var modelerUniform = ModelerUniform()
                    modelerUniform.actionType = 0
                    computeEncoder.setBytes(&modelerUniform, length: MemoryLayout<ModelerUniform>.stride, index: 1)
                } else {
                    var modelerUniform = model.modeler?.createModelerUniform(model.iconCmd, kit: kit, forPreview: true)
                    computeEncoder.setBytes(&modelerUniform, length: MemoryLayout<ModelerUniform>.stride, index: 1)
                }
                
                computeEncoder.setTexture(kit.modelTexture, index: 2)
                computeEncoder.setTexture(kit.colorTexture, index: 3)
                computeEncoder.setTexture(kit.materialTexture1, index: 4)
                computeEncoder.setTexture(kit.materialTexture2, index: 5)
                computeEncoder.setTexture(kit.materialTexture3, index: 6)
                computeEncoder.setTexture(kit.materialTexture4, index: 7)
                
                if let renderKit = kit.currentRenderKit {
                    computeEncoder.setTexture(renderKit.sampleTexture, index: 8)
                    calculateThreadGroups(state, computeEncoder, renderKit.sampleTexture!)
                }
            }
            computeEncoder.endEncoding()
        }
    }
    
    /// Create a uniform buffer containing general information about the current project
    func createRenderUniform(kit: ModelerKit) -> RenderUniform
    {
        var renderUniform = RenderUniform()
        
        if kit.role == .main {

            if model.progress == .modelling {
                renderUniform.randomVector = float3(0.5, 0.5, 0.5)
                renderUniform.noShadows = 1;
            } else {
                renderUniform.randomVector = float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
                renderUniform.noShadows = 0;
            }
            
            if kit.content == .project {
                renderUniform.cameraOrigin = model.project.camera.getPosition()
                renderUniform.cameraLookAt = model.project.camera.getLookAt()
                renderUniform.cameraFov = model.project.camera.getFov()
            } else
            if kit.content == .object {
                renderUniform.cameraOrigin = model.project.objectCamera.getPosition()
                renderUniform.cameraLookAt = model.project.objectCamera.getLookAt()
                renderUniform.cameraFov = model.project.objectCamera.getFov()
            } else
            if kit.content == .material {
                renderUniform.cameraOrigin = model.project.materialCamera.getPosition()
                renderUniform.cameraLookAt = model.project.materialCamera.getLookAt()
                renderUniform.cameraFov = model.project.materialCamera.getFov()
                if kit.currentRenderKit?.outputTexture?.width == 80 {
                    renderUniform.cameraOrigin = float3(0, 0, -0.8)
                    renderUniform.cameraLookAt = float3(0, 0, 0)
                }
            }
            
            renderUniform.scale = kit.scale
            
            renderUniform.maxDepth = 6;
            renderUniform.backgroundColor = float4(0.25, 0.25, 0.25, 1)

            renderUniform.showBBox = 0

            if kit.content == .project {
                if let rendererData = model.project.dataGroups.getGroup("Renderer") {
                    renderUniform.backgroundColor = rendererData.getFloat4("Background")
                    renderUniform.maxDepth = Int32(rendererData.getInt("Reflections", 6))
                    renderUniform.showBBox = rendererData.getBool("Bounding Box", false) ? 1 : 0
                }
            } else {
                if let rendererData = model.project.dataGroups.getGroup("Renderer") {
                    renderUniform.showBBox = rendererData.getBool("Bounding Box", false) ? 1 : 0
                }
            }
            
            /*
            renderUniform.lights.0.position = float3(0,1,0)
            renderUniform.lights.0.emission = float3(10,10,10)
            renderUniform.lights.0.params.x = 1
            renderUniform.lights.0.params.y = 4.0 * Float.pi * 1 * 1;//light.radius * light.radius;
            renderUniform.lights.0.params.z = 1
             */
            /*
            type Quad
            position -2.04973 5 -8
            v1 2.040 5 -8
            v2 -2.04973 5 -7.5
            emission 5 5 5*/
            
            //let v1 = float3(2, 0, 0)
            //let v2 = float3(0, 0, 2)
            
            //let v1 = float3(1, 1, 1)
            //let v2 = float3(1, 1, 1)

            /*
            renderUniform.lights.0.position = float3(-1, 1, -1)
            renderUniform.lights.0.emission = float3(10, 10, 10)
            renderUniform.lights.0.u = v1// - renderUniform.lights.0.position
            renderUniform.lights.0.v = v2// - renderUniform.lights.0.position
            renderUniform.lights.0.params.x = 1
            renderUniform.lights.0.params.y = length(cross(renderUniform.lights.0.u, renderUniform.lights.0.v));
            renderUniform.lights.0.params.z = 0 */
            
            renderUniform.numOfLights = 1
            renderUniform.lights.0.params.z = 2

            if kit.content == .project {
                if let sunData = model.project.dataGroups.getGroup("Sun") {
                    renderUniform.lights.0.position = sunData.getFloat3("Sun Position", float3(0, 100, -100))
                    renderUniform.lights.0.emission = sunData.getFloat3("Sun Emission", float3(4, 4, 4))
                }
            } else {
                renderUniform.lights.0.position = float3(0, 100, -100)
                renderUniform.lights.0.emission = float3(4, 4, 4)
                renderUniform.noShadows = 1;
            }
        } else {
            
            renderUniform.randomVector = float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))

            //renderUniform.cameraOrigin = float3(0, -0.012, -0.07)
            //renderUniform.cameraLookAt = float3(0, -0.012, 0)
            renderUniform.cameraOrigin = float3(0, 0, -0.07 * 7)
            renderUniform.cameraLookAt = float3(0, 0, 0)
            renderUniform.cameraFov = 80
            renderUniform.scale = 1
            
            renderUniform.maxDepth = 2;

            renderUniform.noShadows = 1;
            renderUniform.backgroundColor = float4(0.25, 0.25, 0.25, 1)
            
            renderUniform.numOfLights = 1

            /*
            renderUniform.lights.0.position = float3(0,1.5,0)
            renderUniform.lights.0.emission = float3(10,10,10)
            renderUniform.lights.0.params.x = 1
            renderUniform.lights.0.params.y = 4.0 * Float.pi * 1 * 1;//light.radius * light.radius;
            renderUniform.lights.0.params.z = 1*/
            
            //let v1 = float3(2, 0, 0)
            //let v2 = float3(0, 0, 2)
            
            //let v1 = float3(1, 1, 1)
            //let v2 = float3(1, 1, 1)

            /*
            renderUniform.lights.0.position = float3(-1, 1, -1)
            renderUniform.lights.0.emission = float3(10, 10, 10)
            renderUniform.lights.0.u = v1// - renderUniform.lights.0.position
            renderUniform.lights.0.v = v2// - renderUniform.lights.0.position
            renderUniform.lights.0.params.x = 1
            renderUniform.lights.0.params.y = length(cross(renderUniform.lights.0.u, renderUniform.lights.0.v));
            renderUniform.lights.0.params.z = 0
            */
            
            renderUniform.lights.0.position = float3(0.6, 0.7, -0.7);
            renderUniform.lights.0.emission = float3(4, 4, 4)
            renderUniform.lights.0.params.z = 2
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

            
        // Get the renderSize
        if let rSize = self.model.renderSize {
            renderSize.x = rSize.x
            renderSize.y = rSize.y
        } else {
            renderSize.x = Int(model.renderView!.frame.width)
            renderSize.y = Int(model.renderView!.frame.height)
        }

        func checkTexture(_ texture: MTLTexture?) -> MTLTexture? {
            if texture == nil || texture!.width != renderSize.x || texture!.height != renderSize.y {
                //if let texture = texture {
                    //texture.setPurgeableState(.empty)
                //}
                resChanged = true
                let texture = allocateTexture2D(width: renderSize.x, height: renderSize.y)
                if let texture = texture {
                    var color = float4(0.25,0.25,0.25,1)
                    if let renderData = model.project.dataGroups.getGroup("Renderer") {
                        color = renderData.getFloat4("Background")
                    }
                    clearTexture(texture, color)
                    restart()
                } else {
                    print("error allocating texture")
                }
                return texture
            } else {
                return texture
            }
        }

        mainRenderKit.sampleTexture = checkTexture(mainRenderKit.sampleTexture)
        mainRenderKit.outputTexture = checkTexture(mainRenderKit.outputTexture)
        
        if resChanged {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.model.updateUI.send()
            }
        }

        return resChanged
    }
    
    /// Accumulates the rendered texture into the target, placed here for convenience (compute)
    func accumulate(renderKit: RenderKit)
    {
        if let computeEncoder = commandBuffer?.makeComputeCommandEncoder() {
            if let state = renderStates.getComputeState(stateName: "renderAccum") {
            
                computeEncoder.setComputePipelineState( state )
                
                var uniform = AccumUniform()
                uniform.samples = Float(renderKit.samples)
                computeEncoder.setBytes(&uniform, length: MemoryLayout<AccumUniform>.stride, index: 0)
                
                computeEncoder.setTexture(renderKit.sampleTexture!, index: 1 )
                computeEncoder.setTexture(renderKit.outputTexture!, index: 2 )

                calculateThreadGroups(state, computeEncoder, renderKit.sampleTexture!)
            }
            computeEncoder.endEncoding()
        }
    }
    
    /// Updates the view once
    func updateOnce()
    {
        #if os(OSX)
        let nsrect : NSRect = NSRect(x:0, y: 0, width: model.renderView!.frame.width, height: model.renderView!.frame.height)
        model.renderView?.setNeedsDisplay(nsrect)
        #else
        model.renderView?.setNeedsDisplay()
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
}
