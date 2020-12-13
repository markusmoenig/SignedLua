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
    var black           : MTLTexture? = nil
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

    init()
    {
    }
    
    deinit
    {
        clear()
    }
    
    func clear() {
        if black != nil { black!.setPurgeableState(.empty); black = nil }
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

        if black == nil {
            black = allocateTexture(device, width: 10, height: 10)
            clear(black!)
        }

        if let final = assetFolder.getAsset("main", .Source) {
            size = viewSize
            
            if let customSize = final.size {
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
    
    func setBytes(game: Game)
    {
        var texArray = Array<SIMD4<UInt8>>(repeating: SIMD4<UInt8>(0, 0, 0, 0), count: texture!.width)
        
        let width: Float = Float(texture!.width)
        let height: Float = Float(texture!.height)

        let origin = float3(0,0,3)
        let lookAt = float3(0,0,0)

        for h in 0..<texture!.height {
            let fh : Float = Float(h) / height
            for w in 0..<texture!.width {
                
                let dir = getCameraDir(uv: float2(Float(w) / width, fh), origin: origin, lookAt: lookAt, size: float2(width, height))

                //if h == 100 && w == 100 {
                //    print(Float(w) / width, fh, dir.x, dir.y, dir.z)
                //}
                
                var color = SIMD4<UInt8>(255, 0, 0, 255)
                
                var t : Float = 0.001;
                for _ in 0..<70
                {
                    let d = simd_length(origin - t * dir) - 1.0
                    
                    if abs(d) < (0.0001*t) {
                        
                        color = SIMD4<UInt8>(255, 255, 255, 255)
                        break
                    }
                    t += d
                }
                
                texArray[w] = color
            }
            
            let region = MTLRegionMake2D(0, h, texture!.width, 1)
            
            texArray.withUnsafeMutableBytes { texArrayPtr in
                texture!.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<UInt8>>.size * texture!.width))
            }
            
            DispatchQueue.main.async {
                game.updateOnce()
            }
        }
                
        /*
        let region = MTLRegionMake2D(0, 0, texture!.width, texture!.height)
        
        texArray.withUnsafeMutableBytes { texArrayPtr in
            texture!.replace(region: region, mipmapLevel: 0, withBytes: texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<UInt8>>.size * texture!.width))
        }*/
    }
    
    // Create the camera dir, camera code is 3D, not really
    func getCameraDir(uv: float2, origin: float3, lookAt: float3, size: float2) -> float3
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
        let rand = float2(0.5, 0.5)

        dir += horizontal * (pixelSize.x * rand.x + uv.x)
        dir += vertical * (pixelSize.y * rand.y + uv.y)

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
        textureDescriptor.pixelFormat = MTLPixelFormat.bgra8Unorm
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
