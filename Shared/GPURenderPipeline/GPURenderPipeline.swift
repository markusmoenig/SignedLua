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
    
    var finalTexture    : MTLTexture? = nil

    var texture         : MTLTexture? = nil
    var depthTexture    : MTLTexture? = nil
    var normalTexture   : MTLTexture? = nil

    var camOriginTexture: MTLTexture? = nil
    var camDirTexture   : MTLTexture? = nil
    
    var paramsTexture1  : MTLTexture? = nil
    var paramsTexture2  : MTLTexture? = nil
    var paramsTexture3  : MTLTexture? = nil
    var paramsTexture4  : MTLTexture? = nil
    var paramsTexture5  : MTLTexture? = nil
    var paramsTexture6  : MTLTexture? = nil
    
    var utilityTexture1 : MTLTexture? = nil
    var utilityTexture2 : MTLTexture? = nil

    var commandQueue    : MTLCommandQueue!
    var commandBuffer   : MTLCommandBuffer!
    
    var context         : GraphContext! = nil
    
    var quadVertexBuffer: MTLBuffer? = nil
    var quadViewport    : MTLViewport? = nil
    
    var dataBuffer      : MTLBuffer? = nil
    var lightsDataBuffer: MTLBuffer? = nil

    var materialsShader : GPUMaterialsShader? = nil
    
    // Global Uniforms
    var cameraOrigin    = float3()
    var cameraLookAt    = float3()
    
    var gpuAccum        : GPUAccumShader!
    
    var passes          : Int = 0
    var depth           : Int = 0
    var maxDepth        : Int = 0

    init(_ view: MTKView)
    {
        self.view = view
        device = view.device!
    }
    
    func update()
    {
        if let cameraNode = context.cameraNode {
            cameraNode.execute(context: context)
        }
        
        for node in context.sdfNodes {
            node.execute(context: context)
        }
                
        if dataBuffer != nil {
            dataBuffer!.setPurgeableState(.empty)
            dataBuffer = nil
        }
        
        dataBuffer = device.makeBuffer(bytes: context.data, length: context.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        
        if lightsDataBuffer != nil {
            lightsDataBuffer!.setPurgeableState(.empty)
            lightsDataBuffer = nil
        }
        lightsDataBuffer = device.makeBuffer(bytes: context.lightsData, length: context.lightsData.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
    }
    
    func compile(_ ctx: GraphContext)
    {
        context = ctx        
        
        context.setupBeforeCompiling()
        
        gpuAccum = GPUAccumShader(pipeline: self)

        if let cameraNode = context.cameraNode {
            cameraNode.gpuShader = GPUCameraShader(pipeline: self)
        }
        
        materialsShader = GPUMaterialsShader(pipeline: self)
        
        for node in context.analyticalNodes {
            node.gpuShader = GPUAnalyticalShader(pipeline: self, object: node)
        }
        
        for node in context.sdfNodes {
            node.gpuShader = GPUSDFShader(pipeline: self, object: node)
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
                
        update()
        
        startRendering()
        
        clearTexture(finalTexture!, float4(0, 0, 0, 0))

        passes = 0;
        computeL()
    }
    
    func startRendering()
    {
        commandQueue = device.makeCommandQueue()
        commandBuffer = commandQueue.makeCommandBuffer()
        quadVertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(renderSize.x), Float(renderSize.y)))
        quadViewport = MTLViewport( originX: 0.0, originY: 0.0, width: Double(renderSize.x), height: Double(renderSize.y), znear: 0.0, zfar: 1.0 )
    }
    
    func computeL()
    {
        clearTexture(texture!, float4(0, 0, 0, 0))
        clearTexture(depthTexture!, float4(1000,-1,-1,-1))
        
        if let cameraNode = context.cameraNode {
            if let cameraShader = cameraNode.gpuShader as? GPUCameraShader {
                cameraShader.render()
            }
        }
        
        for node in context.analyticalNodes {
            if let object = node.gpuShader as? GPUAnalyticalShader {
                object.render(camOriginTexture: camOriginTexture!, camDirTexture: camDirTexture!, depthTexture: depthTexture!, normalTexture: normalTexture!)
            }
        }
        
        for node in context.sdfNodes {
            if let object = node.gpuShader as? GPUSDFShader {
                object.render(camOriginTexture: camOriginTexture!, camDirTexture: camDirTexture!, depthTexture: depthTexture!, normalTexture: normalTexture!)
            }
        }
        
        materialsShader!.render()
        
        // New we have the new hit in camOrigin and the light sampling direction in params5: Shadow pass
        
        clearTexture(utilityTexture1!, float4(1000,-1,-1,-1))

        for node in context.analyticalNodes {
            if let object = node.gpuShader as? GPUAnalyticalShader {
                object.render(camOriginTexture: camOriginTexture!, camDirTexture: paramsTexture5!, depthTexture: utilityTexture1!, normalTexture: utilityTexture2!)
            }
        }
        
        for node in context.sdfNodes {
            if let object = node.gpuShader as? GPUSDFShader {
                object.render(camOriginTexture: camOriginTexture!, camDirTexture: paramsTexture5!, depthTexture: utilityTexture1!, normalTexture: utilityTexture2!)
            }
        }
        
        materialsShader!.directLight(depthTexture: depthTexture!, normalTexture: normalTexture!, lightDepthTexture: utilityTexture1!, lightNormalTexture: utilityTexture2!)
        
        gpuAccum.render(finalTexture: finalTexture!, sampleTexture: texture!)
        passes += 1
        
        print(passes)
        
        commandBuffer.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.startRendering()
            self.computeL()
            self.updateOnce()
        }
    }
    
    func updateOnce()
    {
        #if os(OSX)
        let nsrect : NSRect = NSRect(x:0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        self.view.setNeedsDisplay(nsrect)
        #else
        self.view.setNeedsDisplay()
        #endif
    }
    
    /// Create a uniform buffer containing general information about the current project
    func createFragmentUniform() -> GPUFragmentUniforms
    {
        var fragmentUniforms = GPUFragmentUniforms()

        fragmentUniforms.randomVector = float3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
        
        fragmentUniforms.maxDepth = Int32(maxDepth);
        fragmentUniforms.depth = Int32(depth);
        fragmentUniforms.passes = Int32(passes);
        
        /*
        fragmentUniforms.screenSize = prtInstance.screenSize
        if let ambient = getGlobalVariableValue(withName: "World.worldAmbient") {
            fragmentUniforms.ambientColor = ambient
        }*/
        
        return fragmentUniforms
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
    
    /// Check and allocate all textures
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

        finalTexture = checkTexture(finalTexture)

        texture = checkTexture(texture)
        depthTexture = checkTexture(depthTexture)
        normalTexture = checkTexture(normalTexture)
        camOriginTexture = checkTexture(camOriginTexture)
        camDirTexture = checkTexture(camDirTexture)
        
        paramsTexture1 = checkTexture(paramsTexture1)
        paramsTexture2 = checkTexture(paramsTexture2)
        paramsTexture3 = checkTexture(paramsTexture3)
        paramsTexture4 = checkTexture(paramsTexture4)
        paramsTexture5 = checkTexture(paramsTexture5)
        paramsTexture6 = checkTexture(paramsTexture6)
        
        utilityTexture1 = checkTexture(utilityTexture1)
        utilityTexture2 = checkTexture(utilityTexture2)
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
