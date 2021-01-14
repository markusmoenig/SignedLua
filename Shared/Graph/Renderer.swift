//
//  Renderer.swift
//  Signed
//
//  Created by Markus Moenig on 19/11/20.
//

import Foundation

import MetalKit
import simd

class Renderer
{
    enum RenderMode {
        case Normal, Preview
    }
    
    var renderMode      : RenderMode = .Normal
    
    var texture         : MTLTexture? = nil
    var temp            : MTLTexture? = nil

    var commandQueue    : MTLCommandQueue? = nil
    var commandBuffer   : MTLCommandBuffer? = nil
    
    var size            = SIMD2<Int>(0,0)
    var time            = Float(0)
    var frame           = UInt32(0)

    var assetFolder     : AssetFolder? = nil
    
    var textureCache    : [UUID:MTLTexture] = [:]
    var textureLoader   : MTKTextureLoader? = nil
    
    var resChanged      : Bool = false
    
    var startTime       : Double = 0
    var totalTime       : Double = 0
    var coresActive     : Int = 0
    
    var semaphore       : DispatchSemaphore!
    var dispatchGroup   : DispatchGroup!
    
    var isRunning       : Bool = false
    var stopRunning     : Bool = false
    
    let core            : Core
        
    var lines           : [Int] = []

    init(_ core: Core)
    {
        self.core = core
        semaphore = DispatchSemaphore(value: 1)
        dispatchGroup = DispatchGroup()
    }
    
    deinit
    {
        clear()
    }
    
    func clear() {
        if texture != nil { texture!.setPurgeableState(.empty); texture = nil }
        if temp != nil { temp!.setPurgeableState(.empty); temp = nil }

        for (id, _) in textureCache {
            if textureCache[id] != nil {
                textureCache[id]!.setPurgeableState(.empty)
            }
        }
        textureCache = [:]
    }
    
    func start()
    {
        guard let main = core.assetFolder.getAsset("main", .Source) else {
            return
        }
        
        guard let context = main.graph else {
            return
        }

        if checkIfTextureIsValid(core, forceClear: true) == false {
            return
        }

        let cores = ProcessInfo().activeProcessorCount + 1
        
        //let width: Int = texture!.width
        let height: Int = texture!.height
        
        lines = []
        for i in 0..<height {
            lines.append(i)
        }
        
        var lineCount : Int = 0
        let chunkHeight : Int = height / cores + cores
        
        //print("Cores", cores, chunkHeight)

        startTime = Double(Date().timeIntervalSince1970)
        totalTime = 0
        coresActive = 0
                
        isRunning = true
        stopRunning = false

        func startThread(_ chunk: SIMD4<Int>) {
            //print("Chunk start", chunk.y, chunk.w)

            coresActive += 1
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.renderChunk(context1: context, chunk: chunk)
            }
        }

        for _ in 0..<cores {
            if lineCount < height {
                startThread(SIMD4<Int>(0, lineCount, 0, min(lineCount + chunkHeight, height)))
                lineCount += chunkHeight
            }
        }
    }
    
    func getNextLine() -> Int?
    {
        semaphore.wait()
        var line : Int? = nil
        if lines.isEmpty == false {
            line = lines.removeFirst()
        }
        semaphore.signal()
        return line
    }
    
    func renderChunk(context1: GraphContext, chunk: SIMD4<Int>)
    {
        guard let texture = texture else {
            return
        }
        
        let width: Float = Float(texture.width)
        let height: Float = Float(texture.height)
        
        let widthInt : Int = texture.width
        //let heightInt : Int = texture!.height

        var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: widthInt)
        
        guard let main = core.assetFolder.getAsset("main", .Source) else {
            return
        }
        
        let asset = Asset(type: .Source, name: "", value: main.value, data: main.data)
        core.graphBuilder.compile(asset, silent: true)
        
        let context = asset.graph!
        
        context.viewSize = float2(width, height)
                
    
        func renderPixel()
        {
            context.reflectionDepth = 0
            context.hasHitSomething = false
            
            context.normal.fromSIMD(float3(0.0, 0.0, 0.0))
            context.rayPosition.fromSIMD(float3(0.0, 0.0, 0.0))
            context.outColor.fromSIMD(float4(0.0, 0.0, 0.0, 0.0))

            if let cameraNode = context.cameraNode {
                cameraNode.execute(context: context)
            }
            
            context.rayOrigin.fromSIMD(context.camOrigin)
            context.rayDirection.fromSIMD(context.rayDir)
            
            if let skyNode = context.skyNode {
                skyNode.execute(context: context)
            }
            
            // Analytical Objects
            context.executeAnalytical()
            let maxDist : Float = simd_min(12.0, context.analyticalDist)
            
            var material : GraphNode? = nil

            var hit = false
            
            var t : Float = 0.001;
            for _ in 0..<70
            {
                context.executeSDF(context.camOrigin + t * context.rayDir)

                if abs(context.rayDist[context.rayIndex]) < (0.0001*t) {
                    hit = true
                    material = context.hitMaterial[context.rayIndex]
                    break
                } else
                if t > maxDist {
                    break
                }
                
                t += context.rayDist[context.rayIndex]
            }
            
            if hit && t < context.analyticalDist {
                
                let p = context.camOrigin + t * context.rayDir
                context.rayPosition.fromSIMD(p)
                let normal = calcNormal(context: context, position: p)
                context.normal.fromSIMD(normal)

                if let material = material {
                    context.executeMaterial(material)
                }
                context.hasHitSomething = true
                if renderMode == .Normal {
                    context.executeRender()
                } else {
                    previewRender()
                }
            } else
            if context.analyticalDist != .greatestFiniteMagnitude {
                
                let p = context.camOrigin + context.analyticalDist * context.rayDir
                context.rayPosition.fromSIMD(p)

                let normal = context.analyticalNormal
                context.normal.fromSIMD(normal)

                if let material = context.analyticalMaterial {
                    context.executeMaterial(material)
                }
                context.hasHitSomething = true
                if renderMode == .Normal {
                    context.executeRender()
                } else {
                    previewRender()
                }
            }
        }
        
        // Extract Render Options
        var AA : Int = 1
        var renderType : GraphNode.NodeRenderType = .Normal
        if let renderNode = context.renderNode {
            renderType = renderNode.renderType
            
            if renderType == .Normal {
                if let line = core.scriptProcessor.getLine(renderNode.lineNr) {
                    let options = core.scriptProcessor.extractOptionsFromLine(renderNode, line)
                    for o in options {
                        if o.name.lowercased().contains("aliasing") {
                            if let i1 = o.variable as? Int1 {
                                AA = i1.x
                            }
                        }
                    }
                }
            }
        }
            
        while let h = getNextLine() {

            let fh : Float = Float(h) / height
            for w in 0..<widthInt {
                
                if stopRunning {
                    break
                }
                

                if renderType == .Normal {
                    var tot = float4(0,0,0,0)
                    
                    for m in 0..<AA {
                        for n in 0..<AA {

                            if stopRunning {
                                break
                            }

                            context.uv = float2(Float(w) / width, fh)
                            context.camOffset = float2(Float(m), Float(n)) / Float(AA) - 0.5
                            
                            renderPixel()
                            
                            let result = context.outColor!.toSIMD().clamped(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
                            tot += result
                        }
                    }
                    texArray[w] = tot / Float(AA*AA)
                } else
                if renderType == .PathTracer {
                    
                    context.uv = float2(Float(w) / width, fh)
                    context.camOffset = float2(Float.random(in: 0...1), Float.random(in: 0...1))
                    renderPixel()
                    let result = context.outColor!.toSIMD().clamped(lowerBound: float4(0,0,0,0), upperBound: float4(1,1,1,1))
                    texArray[w] = result
                }
            }
            
            if stopRunning {
                break
            }
            
            semaphore.wait()
            let region = MTLRegionMake2D(0, h, widthInt, 1)
            
            texArray.withUnsafeMutableBytes { texArrayPtr in
                texture.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * widthInt))
            }
            
            if renderMode == .Normal {
                DispatchQueue.main.async {
                    self.core.updateOnce()
                }
            }
            semaphore.signal()
        }
        
        coresActive -= 1
        if coresActive == 0 && stopRunning == false {
            
            let chunkTime = Double(Date().timeIntervalSince1970) - startTime
            totalTime += chunkTime
            
            if renderMode == .Normal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 / 60.0) {
                    self.core.updateOnce()
                }
            } else {
                DispatchQueue.main.async {
                    self.core.updateOnce()
                }
            }
            
            isRunning = false
            print(totalTime)
        }
        
        dispatchGroup.leave()
    }
    
    func restart(_ renderMode : RenderMode = .Normal)
    {
        stop()
        dispatchGroup.wait()
            
        self.renderMode = renderMode
        self.start()
    }
    
    func stop()
    {
        stopRunning = true
    }
    
    /// Render a preview during camera actions
    func previewRender()
    {
        
    }
    
    /// Calculates the normal for the given hit position
    @inlinable public func calcNormal(context: GraphContext, position: float3) -> float3
    {
        /*
        vec3 epsilon = vec3(0.001, 0., 0.);
        
        vec3 n = vec3(map(p + epsilon.xyy).x - map(p - epsilon.xyy).x,
                      map(p + epsilon.yxy).x - map(p - epsilon.yxy).x,
                      map(p + epsilon.yyx).x - map(p - epsilon.yyx).x);
        
        return normalize(n);*/

        let e = float3(0.001, 0.0, 0.0)

        var eOff : float3 = position + float3(e.x, e.y, e.y)
        context.executeSDF(eOff)
        var n1 = context.rayDist[context.rayIndex]
        
        eOff = position - float3(e.x, e.y, e.y)
        context.executeSDF(eOff)
        n1 = n1 - context.rayDist[context.rayIndex]
        
        eOff = position + float3(e.y, e.x, e.y)
        context.executeSDF(eOff)
        var n2 = context.rayDist[context.rayIndex]
        
        eOff = position - float3(e.y, e.x, e.y)
        context.executeSDF(eOff)
        n2 = n2 - context.rayDist[context.rayIndex]
        
        eOff = position + float3(e.y, e.y, e.x)
        context.executeSDF(eOff)
        var n3 = context.rayDist[context.rayIndex]
        
        eOff = position - float3(e.y, e.y, e.x)
        context.executeSDF(eOff)
        n3 = n3 - context.rayDist[context.rayIndex]
        
        return simd_normalize(float3(n1, n2, n3))
    }
    
    func startDrawing(_ device: MTLDevice)
    {
        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }
        commandBuffer = commandQueue!.makeCommandBuffer()
        resChanged = false
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
    func checkIfTextureIsValid(_ core: Core, forceClear: Bool = false) -> Bool
    {
        let size = SIMD2<Int>(Int(core.view.frame.width), Int(core.view.frame.height))
        
        if size.x == 0 || size.y == 0 {
            return false
        }
        
        // Make sure texture is of size size
        if texture == nil || texture!.width != size.x || texture!.height != size.y {
            
            stopRunning = true
            
            if texture != nil {
                texture!.setPurgeableState(.empty)
                texture = nil
            }
            texture = allocateTexture(core.device, width: size.x, height: size.y)
            resChanged = true
            
            startDrawing(core.device)
            clearTexture(texture!)
            stopDrawing(syncTexture: texture!, waitUntilCompleted: true)
        } else {
            if forceClear {
                startDrawing(core.device)
                clearTexture(texture!)
                stopDrawing(syncTexture: texture!, waitUntilCompleted: true)
            }
        }
        return true
    }
    
    /// Clears the textures
    func clearTexture(_ texture: MTLTexture, _ color: float4 = SIMD4<Float>(0,0,0,1))
    {
        let renderPassDescriptor = MTLRenderPassDescriptor()

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(Double(color.x), Double(color.y), Double(color.z), Double(color.w))
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        let renderEncoder = commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.endEncoding()
    }
    
    func makeCGIImage(_ device: MTLDevice,_ state: MTLComputePipelineState,_ texture: MTLTexture) -> MTLTexture?
    {
        if temp != nil { temp!.setPurgeableState(.empty); temp = nil }

        temp = allocateTexture(device, width: texture.width, height: texture.height)
        runComputeState(device, state, outTexture: temp!, inTexture: texture, syncronize: true)
        return temp
    }
    
    /// Run the given state
    func runComputeState(_ device: MTLDevice,_ state: MTLComputePipelineState?, outTexture: MTLTexture, inBuffer: MTLBuffer? = nil, inTexture: MTLTexture? = nil, inTextures: [MTLTexture] = [], outTextures: [MTLTexture] = [], inBuffers: [MTLBuffer] = [], syncronize: Bool = false, finishedCB: ((Double)->())? = nil )
    {
        // Compute the threads and thread groups for the given state and texture
        func calculateThreadGroups(_ state: MTLComputePipelineState, _ encoder: MTLComputeCommandEncoder,_ width: Int,_ height: Int, limitThreads: Bool = false)
        {
            let w = limitThreads ? 1 : state.threadExecutionWidth
            let h = limitThreads ? 1 : state.maxTotalThreadsPerThreadgroup / w
            let threadsPerThreadgroup = MTLSizeMake(w, h, 1)

            let threadgroupsPerGrid = MTLSize(width: (width + w - 1) / w, height: (height + h - 1) / h, depth: 1)
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        }
        
        startDrawing(device)
        
        let computeEncoder = commandBuffer?.makeComputeCommandEncoder()!
        
        computeEncoder?.setComputePipelineState( state! )
        
        computeEncoder?.setTexture( outTexture, index: 0 )
        
        if let buffer = inBuffer {
            computeEncoder?.setBuffer(buffer, offset: 0, index: 1)
        }
        
        var texStartIndex : Int = 2
        
        if let texture = inTexture {
            computeEncoder?.setTexture(texture, index: 2)
            texStartIndex = 3
        }
        
        for (index,texture) in inTextures.enumerated() {
            computeEncoder?.setTexture(texture, index: texStartIndex + index)
        }
        
        texStartIndex += inTextures.count

        for (index,texture) in outTextures.enumerated() {
            computeEncoder?.setTexture(texture, index: texStartIndex + index)
        }
        
        texStartIndex += outTextures.count

        for (index,buffer) in inBuffers.enumerated() {
            computeEncoder?.setBuffer(buffer, offset: 0, index: texStartIndex + index)
        }
        
        calculateThreadGroups(state!, computeEncoder!, outTexture.width, outTexture.height)
        computeEncoder?.endEncoding()

        stopDrawing(syncTexture: outTexture, waitUntilCompleted: true)
        
        /*
        if let finished = finishedCB {
            commandBuffer?.addCompletedHandler { cb in
                let executionDuration = cb.gpuEndTime - cb.gpuStartTime
                //print(executionDuration)
                finished(executionDuration)
            }
        } */
    }
}
