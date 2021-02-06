//
//  GPUCamera.swift
//  Signed
//
//  Created by Markus Moenig on 20/1/21.
//

import MetalKit

final class GPUCameraShader : GPUBaseShader
{            
    override init(pipeline: GPURenderPipeline)
    {                    
        super.init(pipeline: pipeline)
        
        if let camera = context.cameraNode {
            createFragmentSource(camera)
        }
    }
    
    func createFragmentSource(_ camera: GraphNode)
    {
        let code = camera.generateMetalCode(context: pipeline.context)
        
        let fragmentCode =
        """

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     constant float4 *data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<float, access::write> camOriginTexture [[texture(2)]])
        {
            float2 uv = float2(in.textureCoordinate.x, 1.0 - in.textureCoordinate.y);
            float2 size = in.viewportSize;

            \(getDataInCode())
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float3 outOrigin = float3();
            float3 outDirection = float3();
            \(code)

            camOriginTexture.write(float4(outOrigin, 1), textureUV);

            return float4(outDirection, 1);
        }

        """
        
        compile(code: GPUBaseShader.getQuadVertexSource() + fragmentCode, shaders: [
                GPUShader(id: "MAIN", blending: false),
        ])
    }
    
    override func render()
    {
        //updateData()
        
        if let mainShader = shaders["MAIN"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = pipeline.camDirTexture!
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
            renderEncoder.setFragmentTexture(pipeline.camOriginTexture!, index: 2)

            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
}
