//
//  Project.swift
//  Signed
//
//  Created by Markus Moenig on 19/11/20.
//

import Foundation

import MetalKit
import simd

class Project
{
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

    init()
    {
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
    
    func render(assetFolder: AssetFolder, device: MTLDevice, time: Float, frame: UInt32, viewSize: SIMD2<Int>, breakAsset: Asset? = nil) -> MTLTexture?
    {
        self.assetFolder = assetFolder
        self.time = time

        startDrawing(device)

        if let main = assetFolder.getAsset("main", .Source) {
            size = viewSize
            
            if let customSize = main.size {
                size = customSize
            }

            // Make sure texture is of size size
            if texture == nil || texture!.width != size.x || texture!.height != size.y {
                if texture != nil {
                    texture!.setPurgeableState(.empty)
                    texture = nil
                }
                texture = allocateTexture(device, width: size.x, height: size.y)
                clear(texture!)
                resChanged = true
            }
            //checkTextures(device)
            
            /*
            // Do buffers
            for asset in assetFolder.assets {
                if asset.type == .Buffer {
                    if asset === breakAsset {
                        drawShader(asset, texture!, device)
                        return texture
                    } else {
                        if let outputId = asset.output {
                            if let texture = textureCache[outputId] {
                                drawShader(asset, texture, device)
                            }
                        }
                    }
                }
            }
            
            // Final Shader
            drawShader(final, texture!, device)
            */
        }
        
        return texture
    }
    
    func render(game: Game)
    {
        guard let main = game.assetFolder.getAsset("main", .Source) else {
            return
        }
        
        guard let context = main.graph else {
            return
        }
        
        let processInfo = ProcessInfo()
        let cores = processInfo.activeProcessorCount
        
        //let width: Int = texture!.width
        let height: Int = texture!.height

        var lineCount : Int = 0
        let chunkHeight : Int = height / cores
        
        print("Cores", cores, chunkHeight)

        startTime = Double(Date().timeIntervalSince1970)
        totalTime = 0
        coresActive = cores
        
        semaphore = nil
        semaphore = DispatchSemaphore(value: 1)

        func startThread(_ chunk: SIMD4<Int>) {
            
            //let concurrentQueue = DispatchQueue(label: "com.test.concurrent", attributes: .concurrent)
            DispatchQueue.global(qos: .userInitiated).async {
            //concurrentQueue.async {
                self.renderChunk(context1: context, chunk: chunk)
            }
        }

        for _ in 0..<cores {
            startThread(SIMD4<Int>(0, lineCount, 0, lineCount + chunkHeight))
            lineCount += chunkHeight
        }
    }
    
    func renderChunk(context1: GraphContext, chunk: SIMD4<Int>)
    {
        let width: Float = Float(texture!.width)
        let height: Float = Float(texture!.height)
        
        let widthInt : Int = texture!.width
        //let heightInt : Int = texture!.height

        var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(0, 0, 0, 0), count: widthInt)
        
        guard let main = context1.game.assetFolder.getAsset("main", .Source) else {
            return
        }
        
        var asset = Asset(type: .Source, name: "", value: main.value, data: main.data)
        context1.game.graphBuilder.compile(asset, silent: true)
        
        let context = asset.graph!
        
        context.camOrigin = float3(0,5,-5)
        context.camDir = float3(0,0,0)
        
        print("Chunk start", chunk.y, chunk.w)
        
        //DispatchQueue.concurrentPerform(iterations: texture!.height) { h in
        for h in chunk.y..<chunk.w {
            let fh : Float = Float(h) / height
            for w in 0..<widthInt {
                
                let AA : Int = 2
                
                var tot = float4(0,0,0,0)
                
                for m in 0..<AA {
                    for n in 0..<AA {

                        let cameraOffset = float2(Float(m), Float(n)) / Float(AA) - 0.5
                        let dir = getCameraDir(uv: float2(Float(w) / width, fh), origin: context.camOrigin, lookAt: context.camDir, size: float2(width, height), offset: cameraOffset)
                        
                        var color = SIMD4<Float>(1, 0, 0, 1)
                        
                        var t : Float = 0.001;
                        for _ in 0..<70
                        {
                            context.reset(context.camOrigin - t * dir)
                            context.execute()

                            context.toggleRayIndex()

                            if abs(context.rayDist[context.rayIndex]) < (0.0001*t) {
                                         
                                let normal = calcNormal(context: context, position: context.camOrigin - t * dir)
                                
                                let output = 0.1 * simd_dot(normal, float3(0, 0, -10))
                                color = SIMD4<Float>(output, output, output, 1)
                                
                                break
                            } else
                            if t > 10 {
                                break
                            }
                            
                            t += context.rayDist[context.rayIndex]
                        }
                        
                        tot = tot + color
                    }
                }
                texArray[w] = tot / Float(AA*AA)
            }
            
            semaphore.wait()
            let region = MTLRegionMake2D(0, h, widthInt, 1)
            
            texArray.withUnsafeMutableBytes { texArrayPtr in
                texture!.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * widthInt))
            }
            
            DispatchQueue.main.async {
                context.game.updateOnce()
            }
            semaphore.signal()
        }
        
        coresActive -= 1
        if coresActive == 0 {
            DispatchQueue.main.async {
                context.game.updateOnce()
            }
        }
        
        let chunkTime = Double(Date().timeIntervalSince1970) - startTime
        totalTime += chunkTime
        print("Chunktime", chunkTime, totalTime)
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
        context.reset(eOff)
        context.execute()
        context.toggleRayIndex()
        var n1 = context.rayDist[context.rayIndex]
        
        eOff = position - float3(e.x, e.y, e.y)
        context.reset(eOff)
        context.execute()
        context.toggleRayIndex()
        n1 = n1 - context.rayDist[context.rayIndex]
        
        eOff = position + float3(e.y, e.x, e.y)
        context.reset(eOff)
        context.execute()
        context.toggleRayIndex()
        var n2 = context.rayDist[context.rayIndex]
        
        eOff = position - float3(e.y, e.x, e.y)
        context.reset(eOff)
        context.execute()
        context.toggleRayIndex()
        n2 = n2 - context.rayDist[context.rayIndex]
        
        eOff = position + float3(e.y, e.y, e.x)
        context.reset(eOff)
        context.execute()
        context.toggleRayIndex()
        var n3 = context.rayDist[context.rayIndex]
        
        eOff = position - float3(e.y, e.y, e.x)
        context.reset(eOff)
        context.execute()
        context.toggleRayIndex()
        n3 = n3 - context.rayDist[context.rayIndex]
        
        return simd_normalize(float3(n1, n2, n3))
    }
    
    // Create the camera dir, camera code is 3D, not really
    @inlinable public func getCameraDir(uv: float2, origin: float3, lookAt: float3, size: float2, offset: float2) -> float3
    {
        let ratio : Float = size.x / size.y
        let pixelSize : float2 = float2(1.0, 1.0) / size

        let fov : Float = 80.0
        let halfWidth : Float = tan(fov.degreesToRadians * 0.5)
        let halfHeight : Float = halfWidth / ratio
        
        let upVector = float3(0.0, 1.0, 0.0)

        let w : float3 = simd_normalize(origin - lookAt)
        let u : float3 = simd_cross(upVector, w)
        let v : float3 = simd_cross(w, u)

        var lowerLeft : float3 = origin - halfWidth * u
        lowerLeft -= halfHeight * v - w
        
        let horizontal : float3 = u * halfWidth * 2.0
        
        let vertical : float3 = v * halfHeight * 2.0
        var dir : float3 = lowerLeft - origin

        dir += horizontal * (pixelSize.x * offset.x + uv.x)
        dir += vertical * (pixelSize.y * offset.y + uv.y)

        return simd_normalize( dir );
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
    
    func clear(_ texture: MTLTexture, _ color: float4 = SIMD4<Float>(0,0,0,1))
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
