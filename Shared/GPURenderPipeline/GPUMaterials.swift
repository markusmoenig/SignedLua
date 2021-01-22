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

        float3 UniformSampleSphere(float u1, float u2)
        {
            float z = 1.0 - 2.0 * u1;
            float r = sqrt(max(0.f, 1.0 - z * z));
            float phi = 2.0 * PI * u2;
            float x = r * cos(phi);
            float y = r * sin(phi);

            return float3(x, y, z);
        }

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     constant float4 *data [[ buffer(0) ]],
                                     constant float4 *lightsData [[ buffer(1) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(2) ]],
                                     texture2d<float, access::read_write> depthTexture [[texture(3)]],
                                     texture2d<float, access::write> paramsTexture1 [[texture(4)]],
                                     texture2d<float, access::write> paramsTexture2 [[texture(5)]],
                                     texture2d<float, access::write> paramsTexture3 [[texture(6)]],
                                     texture2d<float, access::write> paramsTexture4 [[texture(7)]],
                                     texture2d<float, access::write> paramsTexture5 [[texture(8)]],
                                     texture2d<float, access::write> paramsTexture6 [[texture(9)]],
                                     texture2d<float, access::read> camOriginTexture [[texture(10)]],
                                     texture2d<float, access::read> camDirTexture [[texture(11)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;

            \(getDataInCode())
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 depth = float4(depthTexture.read(textureUV));
                
            Material material;
            material.albedo = float3(0,0,0);
            float3 lightDir = float3(0,0,0);

            if (depth.w > -1) {

                \(findMaterialsCode)

                float3 rayOrigin = float3(camOriginTexture.read(textureUV).xyz);
                float3 rayDir = float3(camDirTexture.read(textureUV).xyz);

                int lightsCount = int(lightsData[0].x);
                if (lightsCount > 0) {
                    int lightIndex = 1 + (rand(dataIn) * lightsCount) * 2;

                    float4 lightData1 = lightsData[lightIndex];

                    if (isEqual(lightData1.x, 1.0)) {
                        // Sphere Light

                        float3 lightPosition = data[int(lightData1.y)].xyz;
                        float lightRadius = lightData1.w;

                        float3 surfacePosition = rayOrigin + rayDir * depth.x;

                        float3 lightSurfacePos = lightPosition + UniformSampleSphere(rand(dataIn), rand(dataIn)) * lightRadius;
                        //lightSampleRec.normal = normalize(lightSampleRec.surfacePos - light.position);
                        //lightSampleRec.emission = light.emission * float(numOfLights);
                        
                        float3 lightDir = lightSurfacePos - surfacePosition;
                        float lightDist = length(lightDir);
                        float lightDistSq = lightDist * lightDist;
                        lightDir /= sqrt(lightDistSq);

                        /*
                        if (dot(lightDir, state.ffnormal) <= 0.0 || dot(lightDir, lightSampleRec.normal) >= 0.0)
                            return L;
                        */

                    }
                }

                paramsTexture1.write(float4(material.albedo, material.specular), textureUV);
                paramsTexture2.write(float4(material.emission, material.anisotropic), textureUV);
                paramsTexture3.write(float4(material.metallic, material.roughness, material.subsurface, material.specularTint), textureUV);
                paramsTexture4.write(float4(material.sheen, material.sheenTint, material.clearcoat, material.clearcoatGloss), textureUV);
                paramsTexture5.write(float4(material.transmission, lightDir), textureUV);
                paramsTexture6.write(float4(material.ior, material.extinction), textureUV);
            }

            return float4(material.albedo, 1.0);
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
            renderEncoder.setFragmentBuffer(pipeline.lightsDataBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<GPUFragmentUniforms>.stride, index: 2)
            renderEncoder.setFragmentTexture(pipeline.depthTexture!, index: 3)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture1!, index: 4)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture2!, index: 5)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture3!, index: 6)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture4!, index: 7)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture5!, index: 8)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture6!, index: 9)
            renderEncoder.setFragmentTexture(pipeline.camOriginTexture!, index: 10)
            renderEncoder.setFragmentTexture(pipeline.camDirTexture!, index: 11)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
}
