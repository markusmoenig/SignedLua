//
//  GPUMaterials.swift
//  Signed
//
//  Created by Markus Moenig on 21/1/21.
//

import MetalKit

final class GPUMaterialsShader : GPUBaseShader
{
    
    override init(pipeline: GPURenderPipeline)
    {
        super.init(pipeline: pipeline)
        
        createFragmentSource()
    }
    
    func createFragmentSource()
    {
        //let codeMap = sdfObject.generateMetalCode(context: pipeline.context)
                
        var findMaterialsCode = ""
        var materialsCode = ""
        for (index, node) in context.materialNodes.enumerated() {
            node.index = index
            materialsCode +=
            """

            Material material\(index)(DataIn dataIn)
            {
                Material material;

            """
            
            let codeMap = node.generateMetalCode(context: pipeline.context)
            materialsCode += "    " + codeMap["code"]!
            materialsCode +=
            """
                return material;
            }

            """
            
            if findMaterialsCode != "" { findMaterialsCode += "else\n" }
            findMaterialsCode += "    if (isEqual(depth.w, \(String(index)))) material = material\(String(index))(dataIn);\n"
        }
                
        let fragmentCode =
        """

        \(materialsCode)

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     constant float4 *data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<float, access::read> camOriginTexture [[texture(2)]],
                                     texture2d<float, access::read> camDirTexture [[texture(3)]],
                                     texture2d<float, access::read_write> depthTexture [[texture(4)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;

            \(getDataInCode())
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float3 rayOrigin = float3(camOriginTexture.read(textureUV).xyz);
            float3 rayDir = float3(camDirTexture.read(textureUV).xyz);
            float4 depth = float4(depthTexture.read(textureUV));

            Material material;
            material.albedo = float4(0,0,0,1);

            \(findMaterialsCode)

            return material.albedo;
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
            renderEncoder.setFragmentTexture(pipeline.camOriginTexture!, index: 2)
            renderEncoder.setFragmentTexture(pipeline.camDirTexture!, index: 3)
            renderEncoder.setFragmentTexture(pipeline.depthTexture!, index: 4)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
}
