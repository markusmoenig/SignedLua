//
//  GPUAnalytical.swift
//  Signed
//
//  Created by Markus Moenig on 21/1/21.
//

import MetalKit

final class GPUAnalyticalShader : GPUBaseShader
{
    let analyticalObject   : GraphNode
    
    init(pipeline: GPURenderPipeline, object: GraphNode)
    {
        analyticalObject = object
        super.init(pipeline: pipeline)
        
        createFragmentSource()
    }
    
    func createFragmentSource()
    {
        let code = analyticalObject.generateMetalCode(context: pipeline.context)
        
        let fragmentCode =
        """

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     constant float4 *data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<float, access::read> camOriginTexture [[texture(2)]],
                                     texture2d<float, access::read> camDirTexture [[texture(3)]],
                                     texture2d<float, access::read_write> depthTexture [[texture(4)]],
                                     texture2d<float, access::read_write> normalTexture [[texture(5)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;

            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);
            \(getDataInCode())

            float3 rayOrigin = float3(camOriginTexture.read(textureUV).xyz);
            float3 rayDir = float3(camDirTexture.read(textureUV).xyz);
            float4 depth = float4(depthTexture.read(textureUV));
            float4 normal = float4(normalTexture.read(textureUV));

            if (depth.x < 0.0) { return float4(0); }

            float4 analyticalMap = float4(10000, 0, -1, -1);
            float3 analyticalNormal = float3();

            \(code)

            if (analyticalMap.x < depth.x) {
                depth = analyticalMap;
                normal.xyz = analyticalNormal;
            }

            depthTexture.write(depth, textureUV);
            normalTexture.write(normal, textureUV);
            return depth;
        }

        """
                
        compile(code: GPUBaseShader.getQuadVertexSource() + fragmentCode, shaders: [
                GPUShader(id: "MAIN", blending: false),
        ])
    }
    
    func render(camOriginTexture: MTLTexture, camDirTexture: MTLTexture, depthTexture: MTLTexture, normalTexture: MTLTexture)
    {
        //updateData()
        
        if let mainShader = shaders["MAIN"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = pipeline.texture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let renderEncoder = pipeline.commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
            // ---
            renderEncoder.setViewport(pipeline.quadViewport!)
            renderEncoder.setVertexBuffer(pipeline.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( pipeline.texture!.width ), UInt32( pipeline.texture!.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            var fragmentUniforms = pipeline.createFragmentUniform()

            renderEncoder.setFragmentBuffer(pipeline.dataBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<GPUFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentTexture(camOriginTexture, index: 2)
            renderEncoder.setFragmentTexture(camDirTexture, index: 3)
            renderEncoder.setFragmentTexture(depthTexture, index: 4)
            renderEncoder.setFragmentTexture(normalTexture, index: 5)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
}
