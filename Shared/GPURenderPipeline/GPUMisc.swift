//
//  GPUMisc.swift
//  Signed
//
//  Created by Markus Moenig on 22/1/21.
//

import MetalKit

final class GPUAccumShader : GPUBaseShader
{
    override init(pipeline: GPURenderPipeline)
    {
        super.init(pipeline: pipeline)
        
        createFragmentSource()
    }
    
    func createFragmentSource()
    {
        let fragmentCode =
        """

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     constant float4 *data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<float, access::read> sampleTexture [[texture(2)]],
                                     texture2d<float, access::read_write> finalTexture [[texture(3)]])
        {
            float2 uv = float2(in.textureCoordinate.x, 1.0 - in.textureCoordinate.y);
            float2 size = in.viewportSize;

            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 sample = sampleTexture.read(textureUV);
            float4 final = finalTexture.read(textureUV);

            sample.xyz = pow(sample.xyz, 2.2);
            sample = clamp(sample, 0, 1);

            float k = float(uniforms.passes + 1);
            final.xyz = final.xyz * (1.0 - 1.0/k) + sample.xyz * (1.0/k);
            final.w = 1.0;

            finalTexture.write(final, textureUV);

            return float4(1);
        }

        """
        
        compile(code: GPUBaseShader.getQuadVertexSource() + fragmentCode, shaders: [
                GPUShader(id: "MAIN", blending: false),
        ])
    }
    
    func render(finalTexture: MTLTexture, sampleTexture: MTLTexture)
    {
        //updateData()
        
        if let mainShader = shaders["MAIN"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = pipeline.utilityTexture1!
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
            renderEncoder.setFragmentTexture(sampleTexture, index: 2)
            renderEncoder.setFragmentTexture(finalTexture, index: 3)

            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
}
