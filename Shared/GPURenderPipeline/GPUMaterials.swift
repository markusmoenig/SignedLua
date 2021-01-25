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
                
                float2 uv = dataIn.uv;
                float2 viewSize = dataIn.viewSize;

                material.albedo = float3(0);
                material.specular = 0;

                material.emission = float3(0);
                material.anisotropic = 0;

                material.metallic = 0;
                material.roughness = 0.5;
                material.subsurface = 0;
                material.specularTint = 0;

                material.sheen = 0;
                material.sheenTint = 0;
                material.clearcoat = 0;
                material.clearcoatGloss = 0;

                material.transmission = 0.0;

                material.ior = 1.45;
                material.extinction = float3(1);

            """
            
            let codeMap = node.generateMetalCode(context: pipeline.context)
            materialsCode += "    " + codeMap["code"]!
            materialsCode +=
            """
                return material;
            }

            """
            
            print(codeMap["code"]!)
            
            if findMaterialsCode != "" { findMaterialsCode += "else\n" }
            findMaterialsCode += "    if (isEqual(depth.w, \(String(index)))) material = material\(String(index))(dataIn);\n"
        }
        
        // --- Background / Sky code
        
        var backgroundCode = ""
        
        if let skyNode = context.skyNode {
        
            var codeMap : [String:String] = [:]
            
            codeMap = skyNode.generateMetalCode(context: context)
            backgroundCode = codeMap["sky"]!
        }
                
        let fragmentCode =
        """

        \(materialsCode)
        \(getDisney())

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
                                     texture2d<float, access::read_write> camOriginTexture [[texture(10)]],
                                     texture2d<float, access::read> camDirTexture [[texture(11)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;

            \(getDataInCode())
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 depth = float4(depthTexture.read(textureUV));

            Material material;

            float3 lightDir = float3(0,0,0);

            if (depth.w > -1) {

                \(findMaterialsCode)

                float3 rayOrigin = camOriginTexture.read(textureUV).xyz;
                float3 rayDir = camDirTexture.read(textureUV).xyz;

                int lightsCount = int(lightsData[0].x);
                if (lightsCount > 0) {
                    int lightIndex = 1 + int((rand(dataIn) * lightsCount)) * 2;

                    float4 lightData1 = lightsData[lightIndex];

                    if (isEqual(lightData1.x, 1.0)) {
                        // Sphere Light

                        float3 lightPosition = data[int(lightData1.y)].xyz;
                        float lightRadius = lightData1.w;
                        float lightMaterialIndex = lightData1.z;

                        float3 surfacePosition = rayOrigin + rayDir * depth.x;

                        float3 lightSurfacePos = lightPosition + UniformSampleSphere(rand(dataIn), rand(dataIn)) * lightRadius;
                        //lightSampleRec.normal = normalize(lightSampleRec.surfacePos - light.position);
                        //lightSampleRec.emission = light.emission * float(numOfLights);
                        
                        lightDir = lightSurfacePos - surfacePosition;
                        float lightDist = length(lightDir);
                        float lightDistSq = lightDist * lightDist;
                        lightDir /= sqrt(lightDistSq);
                        //lightDir = normalize(lightDir);

                        //surfacePosition += lightDir * EPS;

                        camOriginTexture.write(float4(surfacePosition, float(lightIndex)), textureUV);

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
                paramsTexture5.write(float4(lightDir, material.transmission), textureUV);
                paramsTexture6.write(float4(material.ior, material.extinction), textureUV);
            }

            return float4(material.albedo, 1.0);
        }

        fragment float4 directLight( RasterizerData in [[stage_in]],
                                     constant float4 *data [[ buffer(0) ]],
                                     constant float4 *lightsData [[ buffer(1) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(2) ]],
                                     texture2d<float, access::read> depthTexture [[texture(3)]],
                                     texture2d<float, access::read> normalTexture [[texture(4)]],
                                     texture2d<float, access::read> lightDepthTexture [[texture(5)]],
                                     texture2d<float, access::read> lightNormalTexture [[texture(6)]],
                                     texture2d<float, access::read> camOriginTexture [[texture(7)]],
                                     texture2d<float, access::read> camDirTexture [[texture(8)]],
                                     texture2d<float, access::read> paramsTexture1 [[texture(9)]],
                                     texture2d<float, access::read> paramsTexture2 [[texture(10)]],
                                     texture2d<float, access::read> paramsTexture3 [[texture(11)]],
                                     texture2d<float, access::read> paramsTexture4 [[texture(12)]],
                                     texture2d<float, access::read> paramsTexture5 [[texture(13)]],
                                     texture2d<float, access::read> paramsTexture6 [[texture(14)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;

            float4 L = float4(0,0,0,1);
            State state;

            \(getDataInCode())
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 depth = depthTexture.read(textureUV);
            float3 normal = normalTexture.read(textureUV).xyz;

            float4 camOrigin = camOriginTexture.read(textureUV);
            float3 surfacePos = camOrigin.xyz;
            int lightIndex = int(camOrigin.w);

            float3 camDir = camDirTexture.read(textureUV).xyz;

            float4 lightData1 = lightsData[lightIndex];

            float3 lightPosition = data[int(lightData1.y)].xyz;
            float lightRadius = lightData1.w;
            float lightMaterialIndex = lightData1.z;
            float lightArea = 4.0 * M_PI_F * lightRadius * lightRadius;

            float4 lightDepth = lightDepthTexture.read(textureUV);
            float3 lightNormal = lightNormalTexture.read(textureUV).xyz;

            float4 params1 = paramsTexture1.read(textureUV);
            float4 params2 = paramsTexture2.read(textureUV);
            float4 params3 = paramsTexture3.read(textureUV);
            float4 params4 = paramsTexture4.read(textureUV);
            float4 params5 = paramsTexture5.read(textureUV);
            float4 params6 = paramsTexture6.read(textureUV);

            bool isVisible = isEqual(lightDepth.w, lightMaterialIndex);
            
            if (isVisible) {
                state.mat.albedo = params1.xyz;
                state.mat.specular = params1.w;

                state.mat.emission = params2.xyz;
                state.mat.anisotropic = params2.w;

                state.mat.metallic = params3.x;
                state.mat.roughness = params3.y;
                state.mat.subsurface = params3.z;
                state.mat.specularTint = params3.w;

                state.mat.sheen = params4.x;
                state.mat.sheenTint = params4.y;
                state.mat.clearcoat = params4.z;
                state.mat.clearcoatGloss = params4.w;

                state.mat.transmission = params5.w;

                state.mat.ior = params6.x;
                state.mat.extinction = params6.yzw;

                Ray r;
                r.direction = camDir;

                state.texCoord = uv;
                state.normal = normal;
                state.ffnormal = dot(normal, r.direction) <= 0.0 ? normal : normal * -1.0;
                state.hitDist = depth.x;
                state.rayType = REFL;

                state.eta = dot(state.normal, state.ffnormal) > 0.0 ? (1.0 / state.mat.ior) : state.mat.ior;

                float3 UpVector = abs(state.ffnormal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
                state.tangent = normalize(cross(UpVector, state.ffnormal));
                state.bitangent = cross(state.ffnormal, state.tangent);

                float3 lightDir = params5.xyz;
                float3 lightSurfacePos = surfacePos + lightDir * depth.x;

                float3 ld = lightSurfacePos - surfacePos;
                float lightDist = length(ld);
                float lightDistSq = lightDist * lightDist;

                if (dot(lightDir, state.ffnormal) <= 0.0 || dot(lightDir, lightNormal) >= 0.0)
                    return L;

                float bsdfPdf = DisneyPdf(r, state, lightDir);
                float3 f = DisneyEval(r, state, lightDir);
                float lightPdf = lightDistSq / (lightArea * abs(dot(lightNormal, lightDir)));

                Material material;
                depth.w = lightMaterialIndex;
                \(findMaterialsCode)

                L.xyz += powerHeuristic(lightPdf, bsdfPdf) * f * abs(dot(state.ffnormal, lightDir)) * material.emission / lightPdf;
            }

            return L;
        }

        fragment float4 pathTrace(   RasterizerData in [[stage_in]],
                                     constant float4 *data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<float, access::read_write> radianceTexture [[texture(2)]],
                                     texture2d<float, access::read_write> throughputTexture [[texture(3)]],
                                     texture2d<float, access::read> depthTexture [[texture(4)]],
                                     texture2d<float, access::read> normalTexture [[texture(5)]],
                                     texture2d<float, access::read_write> camOriginTexture [[texture(6)]],
                                     texture2d<float, access::read_write> camDirTexture [[texture(7)]],
                                     texture2d<float, access::read> directLightTexture [[texture(8)]],
                                     texture2d<float, access::read> paramsTexture1 [[texture(9)]],
                                     texture2d<float, access::read> paramsTexture2 [[texture(10)]],
                                     texture2d<float, access::read> paramsTexture3 [[texture(11)]],
                                     texture2d<float, access::read> paramsTexture4 [[texture(12)]],
                                     texture2d<float, access::read> paramsTexture5 [[texture(13)]],
                                     texture2d<float, access::read> paramsTexture6 [[texture(14)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;

            \(getDataInCode())
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float3 radiance = radianceTexture.read(textureUV).xyz;
            float3 throughput = throughputTexture.read(textureUV).xyz;

            float4 depth = depthTexture.read(textureUV);
            float3 normal = normalTexture.read(textureUV).xyz;

            float3 directLight = directLightTexture.read(textureUV).xyz;

            State state;

            float4 camOrigin = camOriginTexture.read(textureUV);
            float3 surfacePos = camOrigin.xyz;

            float3 camDir = camDirTexture.read(textureUV).xyz;

            float4 params1 = paramsTexture1.read(textureUV);
            float4 params2 = paramsTexture2.read(textureUV);
            float4 params3 = paramsTexture3.read(textureUV);
            float4 params4 = paramsTexture4.read(textureUV);
            float4 params5 = paramsTexture5.read(textureUV);
            float4 params6 = paramsTexture6.read(textureUV);

            state.mat.albedo = params1.xyz;
            state.mat.specular = params1.w;

            state.mat.emission = params2.xyz;
            state.mat.anisotropic = params2.w;

            state.mat.metallic = params3.x;
            state.mat.roughness = params3.y;
            state.mat.subsurface = params3.z;
            state.mat.specularTint = params3.w;

            state.mat.sheen = params4.x;
            state.mat.sheenTint = params4.y;
            state.mat.clearcoat = params4.z;
            state.mat.clearcoatGloss = params4.w;

            state.mat.transmission = params5.w;

            state.mat.ior = params6.x;
            state.mat.extinction = params6.yzw;

            Ray r;
            r.direction = camDir;

            state.texCoord = uv;
            state.normal = normal;
            state.ffnormal = dot(normal, r.direction) <= 0.0 ? normal : normal * -1.0;
            state.hitDist = depth.x;
            state.rayType = REFL;

            state.eta = dot(state.normal, state.ffnormal) > 0.0 ? (1.0 / state.mat.ior) : state.mat.ior;

            float3 UpVector = abs(state.ffnormal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
            state.tangent = normalize(cross(UpVector, state.ffnormal));
            state.bitangent = cross(state.ffnormal, state.tangent);

            // ---

            if (depth.w > -1) {

                // We hit something, get the direct light and calculate the new throughput

                radiance += state.mat.emission * throughput;
                radiance += directLight * throughput;

                float3 bsdfDir = DisneySample(r, state, dataIn);

                float pdf = DisneyPdf(r, state, bsdfDir);

                if (pdf > 0.0)
                    throughput *= DisneyEval(r, state, bsdfDir) * abs(dot(state.ffnormal, bsdfDir)) / pdf;
                else
                    throughput = float3(0);

                radianceTexture.write(float4(radiance, 1), textureUV);
                throughputTexture.write(float4(throughput, 1), textureUV);

                surfacePos += EPS * bsdfDir;

                camOriginTexture.write(float4(surfacePos, 1), textureUV);
                camDirTexture.write(float4(bsdfDir, 1), textureUV);
            } else {

                // We did not hit something, calculate background
                // Have to find a way to terminate processing for these pixels

                float3 rayDir = camDir;
                float4 outColor = float4(0,0,0,1);

                \(backgroundCode)
                
                outColor.xyz *= throughput;
                radianceTexture.write(outColor, textureUV);
            }

            return float4(1);
        }

        """
        
        compile(code: GPUBaseShader.getQuadVertexSource() + fragmentCode, shaders: [
                GPUShader(id: "MAIN", blending: false),
                GPUShader(id: "DIRECTLIGHT", fragmentName: "directLight", blending: false),
                GPUShader(id: "PATHTRACE", fragmentName: "pathTrace", blending: false),
        ])
    }
    
    override func render()
    {
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
    
    func directLight(depthTexture: MTLTexture, normalTexture: MTLTexture, lightDepthTexture: MTLTexture, lightNormalTexture: MTLTexture)
    {
        if let mainShader = shaders["DIRECTLIGHT"] {
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
            renderEncoder.setFragmentTexture(depthTexture, index: 3)
            renderEncoder.setFragmentTexture(normalTexture, index: 4)
            renderEncoder.setFragmentTexture(lightDepthTexture, index: 5)
            renderEncoder.setFragmentTexture(lightNormalTexture, index: 6)
            renderEncoder.setFragmentTexture(pipeline.camOriginTexture!, index: 7)
            renderEncoder.setFragmentTexture(pipeline.camDirTexture!, index: 8)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture1!, index: 9)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture2!, index: 10)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture3!, index: 11)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture4!, index: 12)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture5!, index: 13)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture6!, index: 14)

            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    func pathTracer()
    {
        if let mainShader = shaders["PATHTRACE"] {
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
            renderEncoder.setFragmentTexture(pipeline.radianceTexture!, index: 2)
            renderEncoder.setFragmentTexture(pipeline.throughputTexture!, index: 3)
            renderEncoder.setFragmentTexture(pipeline.depthTexture!, index: 4)
            renderEncoder.setFragmentTexture(pipeline.normalTexture!, index: 5)
            renderEncoder.setFragmentTexture(pipeline.camOriginTexture!, index: 6)
            renderEncoder.setFragmentTexture(pipeline.camDirTexture!, index: 7)
            renderEncoder.setFragmentTexture(pipeline.texture!, index: 8)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture1!, index: 9)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture2!, index: 10)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture3!, index: 11)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture4!, index: 12)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture5!, index: 13)
            renderEncoder.setFragmentTexture(pipeline.paramsTexture6!, index: 14)

            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    func getDisney() -> String
    {
        return """

        float3 ImportanceSampleGGX(float rgh, float r1, float r2)
        {
            float a = max(0.001, rgh);

            float phi = r1 * M_2_PI_F;

            float cosTheta = sqrt((1.0 - r2) / (1.0 + (a * a - 1.0) * r2));
            float sinTheta = clamp(sqrt(1.0 - (cosTheta * cosTheta)), 0.0, 1.0);
            float sinPhi = sin(phi);
            float cosPhi = cos(phi);

            return float3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
        }

        float SchlickFresnel(float u)
        {
            float m = clamp(1.0 - u, 0.0, 1.0);
            float m2 = m * m;
            return m2 * m2 * m; // pow(m,5)
        }

        float DielectricFresnel(float cos_theta_i, float eta)
        {
            float sinThetaTSq = eta * eta * (1.0f - cos_theta_i * cos_theta_i);

            // Total internal reflection
            if (sinThetaTSq > 1.0)
                return 1.0;

            float cos_theta_t = sqrt(max(1.0 - sinThetaTSq, 0.0));

            float rs = (eta * cos_theta_t - cos_theta_i) / (eta * cos_theta_t + cos_theta_i);
            float rp = (eta * cos_theta_i - cos_theta_t) / (eta * cos_theta_i + cos_theta_t);

            return 0.5f * (rs * rs + rp * rp);
        }

        float GTR1(float NDotH, float a)
        {
            if (a >= 1.0)
                return (1.0 / M_PI_F);
            float a2 = a * a;
            float t = 1.0 + (a2 - 1.0) * NDotH * NDotH;
            return (a2 - 1.0) / (M_PI_F * log(a2) * t);
        }

        float GTR2(float NDotH, float a)
        {
            float a2 = a * a;
            float t = 1.0 + (a2 - 1.0) * NDotH * NDotH;
            return a2 / (M_PI_F * t * t);
        }

        float GTR2_aniso(float NDotH, float HDotX, float HDotY, float ax, float ay)
        {
            float a = HDotX / ax;
            float b = HDotY / ay;
            float c = a * a + b * b + NDotH * NDotH;
            return 1.0 / (M_PI_F * ax * ay * c * c);
        }

        float SmithG_GGX(float NDotV, float alphaG)
        {
            float a = alphaG * alphaG;
            float b = NDotV * NDotV;
            return 1.0 / (NDotV + sqrt(a + b - a * b));
        }

        float SmithG_GGX_aniso(float NDotV, float VDotX, float VDotY, float ax, float ay)
        {
            float a = VDotX * ax;
            float b = VDotY * ay;
            float c = NDotV;
            return 1.0 / (NDotV + sqrt(a * a + b * b + c * c));
        }

        float3 CosineSampleHemisphere(float u1, float u2)
        {
            float3 dir;
            float r = sqrt(u1);
            float phi = 2.0 * M_PI_F * u2;
            dir.x = r * cos(phi);
            dir.y = r * sin(phi);
            dir.z = sqrt(max(0.0, 1.0 - dir.x * dir.x - dir.y * dir.y));

            return dir;
        }

        float3 UniformSampleSphere(float u1, float u2)
        {
            float z = 1.0 - 2.0 * u1;
            float r = sqrt(max(0.f, 1.0 - z * z));
            float phi = 2.0 * M_PI_F * u2;
            float x = r * cos(phi);
            float y = r * sin(phi);

            return float3(x, y, z);
        }

        float powerHeuristic(float a, float b)
        {
            float t = a * a;
            return t / (b * b + t);
        }

        float DisneyPdf(Ray ray, State state, float3 bsdfDir)
        {
            float3 N = state.ffnormal;
            float3 V = -ray.direction;
            float3 L = bsdfDir;
            float3 H;

            if (state.rayType == REFR)
                H = normalize(L + V * state.eta);
            else
                H = normalize(L + V);

            float NDotH = abs(dot(N, H));
            float VDotH = abs(dot(V, H));
            float LDotH = abs(dot(L, H));
            float NDotL = abs(dot(N, L));
            float NDotV = abs(dot(N, V));

            float specularAlpha = max(0.001, state.mat.roughness);

            // Handle transmission separately
            if (state.rayType == REFR)
            {
                float pdfGTR2 = GTR2(NDotH, specularAlpha) * NDotH;
                float F = DielectricFresnel(VDotH, state.eta);
                float denomSqrt = LDotH + VDotH * state.eta;
                return pdfGTR2 * (1.0 - F) * LDotH / (denomSqrt * denomSqrt) * state.mat.transmission;
            }

            // Reflection
            float brdfPdf = 0.0;
            float bsdfPdf = 0.0;

            float clearcoatAlpha = mix(0.1, 0.001, state.mat.clearcoatGloss);

            float diffuseRatio = 0.5 * (1.0 - state.mat.metallic);
            float specularRatio = 1.0 - diffuseRatio;

            float aspect = sqrt(1.0 - state.mat.anisotropic * 0.9);
            float ax = max(0.001, state.mat.roughness / aspect);
            float ay = max(0.001, state.mat.roughness * aspect);

            // PDFs for brdf
            float pdfGTR2_aniso = GTR2_aniso(NDotH, dot(H, state.tangent), dot(H, state.bitangent), ax, ay) * NDotH;
            float pdfGTR1 = GTR1(NDotH, clearcoatAlpha) * NDotH;
            float ratio = 1.0 / (1.0 + state.mat.clearcoat);
            float pdfSpec = mix(pdfGTR1, pdfGTR2_aniso, ratio) / (4.0 * VDotH);
            float pdfDiff = NDotL * (1.0 / M_PI_F);
            brdfPdf = diffuseRatio * pdfDiff + specularRatio * pdfSpec;

            // PDFs for bsdf
            float pdfGTR2 = GTR2(NDotH, specularAlpha) * NDotH;
            float F = DielectricFresnel(VDotH, state.eta);
            bsdfPdf = pdfGTR2 * F / (4.0 * VDotH);

            return mix(brdfPdf, bsdfPdf, state.mat.transmission);
        }

        float3 DisneySample(Ray ray, State state, DataIn dataIn)
        {
            float3 N = state.ffnormal;
            float3 V = -ray.direction;
            state.specularBounce = false;
            state.rayType = REFL;

            float3 dir;

            float r1 = rand(dataIn);
            float r2 = rand(dataIn);

            // BSDF
            if (rand(dataIn) < state.mat.transmission)
            {
                float3 H = ImportanceSampleGGX(state.mat.roughness, r1, r2);
                H = state.tangent * H.x + state.bitangent * H.y + N * H.z;

                float3 R = reflect(-V, H);
                float F = DielectricFresnel(dot(R, H), state.eta);

                // Reflection/Total internal reflection
                if (rand(dataIn) < F)
                    dir = normalize(R);
                // Transmission
                else
                {
                    dir = normalize(refract(-V, H, state.eta));
                    state.specularBounce = true;
                    state.rayType = REFR;
                }
            }
            // BRDF
            else
            {
                float diffuseRatio = 0.5 * (1.0 - state.mat.metallic);

                if (rand(dataIn) < diffuseRatio)
                {
                    float3 H = CosineSampleHemisphere(r1, r2);
                    H = state.tangent * H.x + state.bitangent * H.y + N * H.z;
                    dir = H;
                }
                else
                {
                    //TODO: Switch to sampling visible normals
                    float3 H = ImportanceSampleGGX(state.mat.roughness, r1, r2);
                    H = state.tangent * H.x + state.bitangent * H.y + N * H.z;
                    dir = reflect(-V, H);
                }

            }
            return dir;
        }

        float3 DisneyEval(Ray ray, State state, float3 bsdfDir)
        {
            float3 N = state.ffnormal;
            float3 V = -ray.direction;
            float3 L = bsdfDir;
            float3 H;

            if (state.rayType == REFR)
                H = normalize(L + V * state.eta);
            else
                H = normalize(L + V);

            float NDotL = abs(dot(N, L));
            float NDotV = abs(dot(N, V));
            float NDotH = abs(dot(N, H));
            float VDotH = abs(dot(V, H));
            float LDotH = abs(dot(L, H));

            float3 brdf = float3(0.0);
            float3 bsdf = float3(0.0);

            if (state.mat.transmission > 0.0)
            {
                float3 transmittance = float3(1.0);
                float3 extinction = log(state.mat.extinction);

                if (dot(state.normal, state.ffnormal) < 0.0)
                    transmittance = exp(extinction * state.hitDist);

                float a = max(0.001, state.mat.roughness);
                float F = DielectricFresnel(VDotH, state.eta);
                float D = GTR2(NDotH, a);
                float G = SmithG_GGX(NDotL, a) * SmithG_GGX(NDotV, a);

                // TODO: Include subsurface scattering
                if (state.rayType == REFR)
                {
                    float denomSqrt = LDotH + VDotH * state.eta;
                    bsdf = state.mat.albedo * transmittance * (1.0 - F) * D * G * VDotH * LDotH * 4.0 * state.eta * state.eta / (denomSqrt * denomSqrt);
                }
                else
                {
                    bsdf = state.mat.albedo * transmittance * F * D * G;
                }
            }

            if (state.mat.transmission < 1.0 && dot(N, L) > 0.0 && dot(N, V) > 0.0)
            {
                float3 Cdlin = state.mat.albedo;
                float Cdlum = 0.3 * Cdlin.x + 0.6 * Cdlin.y + 0.1 * Cdlin.z; // luminance approx.

                float3 Ctint = Cdlum > 0.0 ? Cdlin / Cdlum : float3(1.0f); // normalize lum. to isolate hue+sat
                float3 Cspec0 = mix(state.mat.specular * 0.08 * mix(float3(1.0), Ctint, state.mat.specularTint), Cdlin, state.mat.metallic);
                float3 Csheen = mix(float3(1.0), Ctint, state.mat.sheenTint);

                // Diffuse fresnel - go from 1 at normal incidence to .5 at grazing
                // and mix in diffuse retro-reflection based on roughness
                float FL = SchlickFresnel(NDotL);
                float FV = SchlickFresnel(NDotV);
                float Fd90 = 0.5 + 2.0 * LDotH * LDotH * state.mat.roughness;
                float Fd = mix(1.0, Fd90, FL) * mix(1.0, Fd90, FV);

                // Based on Hanrahan-Krueger brdf approximation of isotropic bssrdf
                // 1.25 scale is used to (roughly) preserve albedo
                // Fss90 used to "flatten" retroreflection based on roughness
                float Fss90 = LDotH * LDotH * state.mat.roughness;
                float Fss = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
                float ss = 1.25 * (Fss * (1.0 / (NDotL + NDotV) - 0.5) + 0.5);

                // TODO: Add anisotropic rotation
                // specular
                float aspect = sqrt(1.0 - state.mat.anisotropic * 0.9);
                float ax = max(0.001, state.mat.roughness / aspect);
                float ay = max(0.001, state.mat.roughness * aspect);
                float Ds = GTR2_aniso(NDotH, dot(H, state.tangent), dot(H, state.bitangent), ax, ay);
                float FH = SchlickFresnel(LDotH);
                float3 Fs = mix(Cspec0, float3(1.0), FH);
                float Gs = SmithG_GGX_aniso(NDotL, dot(L, state.tangent), dot(L, state.bitangent), ax, ay);
                Gs *= SmithG_GGX_aniso(NDotV, dot(V, state.tangent), dot(V, state.bitangent), ax, ay);

                // sheen
                float3 Fsheen = FH * state.mat.sheen * Csheen;

                // clearcoat (ior = 1.5 -> F0 = 0.04)
                float Dr = GTR1(NDotH, mix(0.1, 0.001, state.mat.clearcoatGloss));
                float Fr = mix(0.04, 1.0, FH);
                float Gr = SmithG_GGX(NDotL, 0.25) * SmithG_GGX(NDotV, 0.25);

                brdf = ((1.0 / M_PI_F) * mix(Fd, ss, state.mat.subsurface) * Cdlin + Fsheen) * (1.0 - state.mat.metallic)
                        + Gs * Fs * Ds
                        + 0.25 * state.mat.clearcoat * Gr * Fr * Dr;
            }

            return mix(brdf, bsdf, state.mat.transmission);
        }
            
        """
    }
}
