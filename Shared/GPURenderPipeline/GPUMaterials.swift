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

            Material material\(index)(DataIn dataIn, float3 rayPosition)
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
                material.clearcoatRoughness = 0;

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
            
            //print(codeMap["code"]!)
            
            if findMaterialsCode != "" { findMaterialsCode += "else\n" }
            findMaterialsCode += "    if (isEqual(depth.w, \(String(index)))) material = material\(String(index))(dataIn, surfacePosition);\n"
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
                                     texture2d<float, access::read> camOriginTexture [[texture(10)]],
                                     texture2d<float, access::read> camDirTexture [[texture(11)]],
                                     texture2d<float, access::write> camOriginTexture2 [[texture(12)]],
                                     texture2d<float, access::read> normalTexture[[texture(13)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;

            \(getDataInCode())
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 depth = depthTexture.read(textureUV);
            float3 normal = normalTexture.read(textureUV).xyz;

            if (depth.x < 0.0) { return float4(0); }

            float4 camOrigin = camOriginTexture.read(textureUV);

            Material material;

            float3 lightDir = float3(0,0,0);

            if (depth.w > -1) {

                float3 rayOrigin = camOrigin.xyz;
                float3 rayDir = camDirTexture.read(textureUV).xyz;

                float3 surfacePosition = rayOrigin + rayDir * depth.x;

                \(findMaterialsCode)

                int lightsCount = int(lightsData[0].x);
                if (lightsCount > 0) {
                    int lightIndex = 1 + int((rand(dataIn) * lightsCount)) * 2;

                    float4 lightData1 = lightsData[lightIndex];

                    if (isEqual(lightData1.x, 0.0)) {
                        // Sun Light

                        lightDir = lightData1.yzw;

                        float sunDist = 100;
                        float sunRadius = 10;
                        float sunAngle = 0.0047; //0.54 / 2 in radians

                        float2 hash = float2(rand(dataIn), rand(dataIn));

                        // Sample disk
                        float2 diskSample = sqrt(hash.x) * cos( 2. * M_PI_F * hash.y + float2( 0, M_PI_F / 2.) );

                        float a = sunAngle;
                        float2 r = a * diskSample;

                        float3 sampleDir = lightDir;

                        float b = 1./sqrt(1.+dot(r,r));
                        float c = 1. - a * a;
                        float d = b * b - c;
                        if (d > 0.0)
                            lightDir = normalize(surfacePosition - (sunDist * ( -b - sqrt(d) ) * sampleDir));

                        surfacePosition += FaceForward(normal, lightDir) * EPS;//0.120;
                        camOriginTexture2.write(float4(float3(surfacePosition), float(lightIndex)), textureUV);
                    } else
                    if (isEqual(lightData1.x, 1.0)) {
                    
                        // Sphere Light

                        float3 lightPosition = data[int(lightData1.y)].xyz;
                        float lightRadius = lightData1.w;
                        float lightMaterialIndex = lightData1.z;

                        float3 lightSurfacePos = lightPosition + UniformSampleSphere(rand(dataIn), rand(dataIn)) * lightRadius;
                        //lightSampleRec.normal = normalize(lightSampleRec.surfacePos - light.position);
                        //lightSampleRec.emission = light.emission * float(numOfLights);
                        
                        lightDir = lightSurfacePos - surfacePosition;
                        float lightDist = length(lightDir);
                        float lightDistSq = lightDist * lightDist;
                        lightDir /= sqrt(lightDistSq);
                        //lightDir = normalize(lightDir);

                        surfacePosition += FaceForward(normal, lightDir) * EPS;//0.120;
                        camOriginTexture2.write(float4(surfacePosition, float(lightIndex)), textureUV);
                    }
                }

                paramsTexture1.write(float4(material.albedo, material.specular), textureUV);
                paramsTexture2.write(float4(material.emission, material.anisotropic), textureUV);
                paramsTexture3.write(float4(material.metallic, material.roughness, material.subsurface, material.specularTint), textureUV);
                paramsTexture4.write(float4(material.sheen, material.sheenTint, material.clearcoat, material.clearcoatRoughness), textureUV);
                paramsTexture5.write(float4(lightDir, material.transmission), textureUV);
                paramsTexture6.write(float4(material.ior, material.extinction), textureUV);
            }

            return float4(1);
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

            float4 Li = float4(0,0,0,1);
            State state;

            \(getDataInCode())
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 depth = depthTexture.read(textureUV);
            float3 normal = normalTexture.read(textureUV).xyz;

            if (depth.x < 0.0) { return float4(0); }

            float4 camOrigin = camOriginTexture.read(textureUV);
            float3 surfacePosition = camOrigin.xyz;
            int lightIndex = int(camOrigin.w);

            float3 camDir = camDirTexture.read(textureUV).xyz;

            float4 lightData1 = lightsData[lightIndex];
            float4 lightData2 = lightsData[lightIndex+1];

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

            bool isVisible = false;

            if (isEqual(lightData1.x, 0.0)) {
                // Sun Light

                if (lightDepth.x >= 1000) {
                    isVisible = true;

                    float3 lightDir = params5.xyz;
                    lightRadius = 10;
                    lightNormal = normalize(surfacePosition - (surfacePosition + 100.0 * lightDir));
                    lightArea = 4.0 * M_PI_F * lightRadius * lightRadius;
                }
            } else {
                // Any other light has to be hit
                isVisible = isEqual(lightDepth.w, lightMaterialIndex);
            }
            
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
                state.mat.clearcoatRoughness = params4.w;

                state.mat.transmission = params5.w;

                state.mat.ior = params6.x;
                state.mat.extinction = params6.yzw;

                state.isSubsurface = false;
                state.isEmitter = false;
                state.specularBounce = false;

                Ray r;
                r.direction = camDir;

                state.texCoord = uv;
                state.normal = normal;
                state.ffnormal = dot(normal, r.direction) <= 0.0 ? normal : normal * -1.0;
                state.hitDist = depth.x;

                float aspect = sqrt(1.0 - state.mat.anisotropic * 0.9);
                state.mat.ax = max(0.001, state.mat.roughness / aspect);
                state.mat.ay = max(0.001, state.mat.roughness * aspect);

                state.eta = dot(state.normal, state.ffnormal) > 0.0 ? (1.0 / state.mat.ior) : state.mat.ior;

                float3 UpVector = abs(state.ffnormal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
                state.tangent = normalize(cross(UpVector, state.ffnormal));
                state.bitangent = cross(state.ffnormal, state.tangent);

                float3 lightDir = params5.xyz;
                float3 lightSurfacePos = surfacePosition + lightDir * depth.x;

                float3 ld = lightSurfacePos - surfacePosition;
                float lightDist = length(ld);

                float3 emission = float3(0);
                
                if (isEqual(lightData1.x, 0.0)) {
                    // Sun Light
                    emission = lightData2.xyz * lightsData[0].x;
                    lightDist = 1;
                } else {
                    Material material;
                    depth.w = lightMaterialIndex;
                    \(findMaterialsCode)
                    emission = material.emission * lightsData[0].x;
                }

                float lightDistSq = lightDist * lightDist;

                if (!state.isSubsurface && (dot(lightDir, state.ffnormal) <= 0.0 || dot(lightDir, lightNormal) >= 0.0))
                    return Li;

                BsdfSampleRec bsdfSampleRec;
                bsdfSampleRec.f = DisneyEval(state, -r.direction, state.ffnormal, lightDir, bsdfSampleRec.pdf);
                float lightPdf = lightDistSq / (lightArea * abs(dot(lightNormal, lightDir)));

                if (bsdfSampleRec.pdf > 0.0)
                    Li.xyz += powerHeuristic(lightPdf, bsdfSampleRec.pdf) * bsdfSampleRec.f * abs(dot(state.ffnormal, lightDir)) * emission / lightPdf;

            }

            return Li;
        }

        fragment float4 pathTrace(   RasterizerData in [[stage_in]],
                                     constant float4 *data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<float, access::read_write> radianceTexture [[texture(2)]],
                                     texture2d<float, access::read_write> throughputTexture [[texture(3)]],
                                     texture2d<float, access::read_write> depthTexture [[texture(4)]],
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

            if (depth.x < 0.0) { return float4(0); }

            float3 directLight = directLightTexture.read(textureUV).xyz;

            State state;

            float4 camOrigin = camOriginTexture.read(textureUV);
            float3 camDir = camDirTexture.read(textureUV).xyz;

            float3 surfacePos = camOrigin.xyz + camDir.xyz * depth.x;

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
            state.mat.clearcoatRoughness = params4.w;

            state.mat.transmission = params5.w;

            state.mat.ior = params6.x;
            state.mat.extinction = params6.yzw;

            state.isSubsurface = false;
            state.isEmitter = false;
            state.specularBounce = false;

            Ray r;
            r.direction = camDir;

            state.texCoord = uv;
            state.normal = normal;
            state.ffnormal = dot(normal, r.direction) <= 0.0 ? normal : normal * -1.0;
            state.hitDist = depth.x;

            float aspect = sqrt(1.0 - state.mat.anisotropic * 0.9);
            state.mat.ax = max(0.001, state.mat.roughness / aspect);
            state.mat.ay = max(0.001, state.mat.roughness * aspect);

            state.eta = dot(state.normal, state.ffnormal) > 0.0 ? (1.0 / state.mat.ior) : state.mat.ior;

            float3 UpVector = abs(state.ffnormal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
            state.tangent = normalize(cross(UpVector, state.ffnormal));
            state.bitangent = cross(state.ffnormal, state.tangent);

            BsdfSampleRec bsdfSampleRec;
            float3 absorption = float3(0.0);

            // ---

            if (depth.w > -1) {

                // We hit something, get the direct light and calculate the new throughput

                // Reset absorption when ray is going out of surface
                if (dot(state.normal, state.ffnormal) > 0.0)
                    absorption = float3(0.0);

                radiance += state.mat.emission * throughput;

                // Add absoption
                //throughput *= exp(-absorption * depth.x);
            
                if (length(state.mat.emission) > 0) {
                    throughput = float3(0);
                    depth.x = -10;
                    depthTexture.write(depth, textureUV);
                    radianceTexture.write(float4(radiance, 1), textureUV);
                    throughputTexture.write(float4(throughput, 1), textureUV);
                    return float4(1);
                }

                radiance += directLight * throughput;

                bsdfSampleRec.f = DisneySample(state, -r.direction, state.ffnormal, bsdfSampleRec.L, bsdfSampleRec.pdf, dataIn);

                // Set absorption only if the ray is currently inside the object.
                if (dot(state.ffnormal, bsdfSampleRec.L) < 0.0)
                    absorption = -log(state.mat.extinction) / float3(0.2); // TODO: Add atDistance

                if (bsdfSampleRec.pdf > 0.0)
                    throughput *= bsdfSampleRec.f * abs(dot(state.ffnormal, bsdfSampleRec.L)) / bsdfSampleRec.pdf;
                else {
                    //throughput = float3(0);
                    depth.x = -10;
                    depthTexture.write(depth, textureUV);
                }

                radianceTexture.write(float4(radiance, 1), textureUV);
                throughputTexture.write(float4(throughput, 1), textureUV);

                surfacePos += bsdfSampleRec.L * EPS;

                camOriginTexture.write(float4(surfacePos, 1), textureUV);
                camDirTexture.write(float4(bsdfSampleRec.L, 1), textureUV);
            } else {

                // We did not hit something, calculate background
                // Have to find a way to terminate processing for these pixels

                float3 rayDir = camDir;
                float4 outColor = float4(0,0,0,1);

                \(backgroundCode)
                
                outColor.xyz *= throughput;
                radianceTexture.write(outColor, textureUV);

                //throughput = float3(0);
                throughputTexture.write(float4(throughput, 1), textureUV);

                depth.x = -10;
                depthTexture.write(depth, textureUV);
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
            renderEncoder.setFragmentTexture(pipeline.camOriginTexture2!, index: 12)
            renderEncoder.setFragmentTexture(pipeline.normalTexture!, index: 13)
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
            renderEncoder.setFragmentTexture(pipeline.camOriginTexture2!, index: 7)
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

        /*
         * MIT License
         *
         * Copyright(c) 2019-2021 Asif Ali
         *
         * Permission is hereby granted, free of charge, to any person obtaining a copy
         * of this softwareand associated documentation files(the "Software"), to deal
         * in the Software without restriction, including without limitation the rights
         * to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
         * copies of the Software, and to permit persons to whom the Software is
         * furnished to do so, subject to the following conditions :
         *
         * The above copyright notice and this permission notice shall be included in all
         * copies or substantial portions of the Software.
         *
         * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
         * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
         * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
         * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
         * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
         * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
         * SOFTWARE.
         */


        float3 ImportanceSampleGTR1(float rgh, float r1, float r2)
        {
           float a = max(0.001, rgh);
           float a2 = a * a;

           float phi = r1 * M_2_PI_F;

           float cosTheta = sqrt((1.0 - pow(a2, 1.0 - r1)) / (1.0 - a2));
           float sinTheta = clamp(sqrt(1.0 - (cosTheta * cosTheta)), 0.0, 1.0);
           float sinPhi = sin(phi);
           float cosPhi = cos(phi);

           return float3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
        }

        float3 ImportanceSampleGTR2_aniso(float ax, float ay, float r1, float r2)
        {
           float phi = r1 * M_2_PI_F;

           float sinPhi = ay * sin(phi);
           float cosPhi = ax * cos(phi);
           float tanTheta = sqrt(r2 / (1 - r2));

           return float3(tanTheta * cosPhi, tanTheta * sinPhi, 1.0);
        }

        float3 ImportanceSampleGTR2(float rgh, float r1, float r2)
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

        float3 CosineSampleHemisphere(float r1, float r2)
        {
           float3 dir;
           float r = sqrt(r1);
           float phi = M_2_PI_F * r2;
           dir.x = r * cos(phi);
           dir.y = r * sin(phi);
           dir.z = sqrt(max(0.0, 1.0 - dir.x * dir.x - dir.y * dir.y));

           return dir;
        }

        float3 UniformSampleHemisphere(float r1, float r2)
        {
           float r = sqrt(max(0.0, 1.0 - r1 * r1));
           float phi = M_2_PI_F * r2;

           return float3(r * cos(phi), r * sin(phi), r1);
        }

        float3 UniformSampleSphere(float r1, float r2)
        {
           float z = 1.0 - 2.0 * r1;
           float r = sqrt(max(0.0, 1.0 - z * z));
           float phi = M_2_PI_F * r2;

           return float3(r * cos(phi), r * sin(phi), z);
        }

        float powerHeuristic(float a, float b)
        {
           float t = a * a;
           return t / (b * b + t);
        }

        float3 EvalDielectricReflection(State state, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
        {
            if (dot(N, L) < 0.0) return float3(0.0);

            float F = DielectricFresnel(dot(V, H), state.eta);
            float D = GTR2(dot(N, H), state.mat.roughness);
            
            pdf = D * dot(N, H) * F / (4.0 * dot(V, H));

            float G = SmithG_GGX(abs(dot(N, L)), state.mat.roughness) * SmithG_GGX(dot(N, V), state.mat.roughness);
            return state.mat.albedo * F * D * G;
        }

        float3 EvalDielectricRefraction(State state, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
        {
            float F = DielectricFresnel(abs(dot(V, H)), state.eta);
            float D = GTR2(dot(N, H), state.mat.roughness);

            float denomSqrt = dot(L, H) * state.eta + dot(V, H);
            pdf = D * dot(N, H) * (1.0 - F) * abs(dot(L, H)) / (denomSqrt * denomSqrt);

            float G = SmithG_GGX(abs(dot(N, L)), state.mat.roughness) * SmithG_GGX(dot(N, V), state.mat.roughness);
            return state.mat.albedo * (1.0 - F) * D * G * abs(dot(V, H)) * abs(dot(L, H)) * 4.0 * state.eta * state.eta / (denomSqrt * denomSqrt);
        }

        float3 EvalSpecular(State state, float3 Cspec0, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
        {
            if (dot(N, L) < 0.0) return float3(0.0);

            float D = GTR2_aniso(dot(N, H), dot(H, state.tangent), dot(H, state.bitangent), state.mat.ax, state.mat.ay);
            pdf = D * dot(N, H) / (4.0 * dot(V, H));

            float FH = SchlickFresnel(dot(L, H));
            float3 F = mix(Cspec0, float3(1.0), FH);
            float G = SmithG_GGX_aniso(dot(N, L), dot(L, state.tangent), dot(L, state.bitangent), state.mat.ax, state.mat.ay);
            G *= SmithG_GGX_aniso(dot(N, V), dot(V, state.tangent), dot(V, state.bitangent), state.mat.ax, state.mat.ay);
            return F * D * G;
        }

        float3 EvalClearcoat(State state, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
        {
            if (dot(N, L) < 0.0) return float3(0.0);

            float D = GTR1(dot(N, H), state.mat.clearcoatRoughness);
            pdf = D * dot(N, H) / (4.0 * dot(V, H));

            float FH = SchlickFresnel(dot(L, H));
            float F = mix(0.04, 1.0, FH);
            float G = SmithG_GGX(dot(N, L), 0.25) * SmithG_GGX(dot(N, V), 0.25);
            return float3(0.25 * state.mat.clearcoat * F * D * G);
        }

        float3 EvalDiffuse(State state, float3 Csheen, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
        {
            if (dot(N, L) < 0.0) return float3(0.0);

            pdf = dot(N, L) * (1.0 / M_PI_F);

            float FL = SchlickFresnel(dot(N, L));
            float FV = SchlickFresnel(dot(N, V));
            float FH = SchlickFresnel(dot(L, H));
            float Fd90 = 0.5 + 2.0 * dot(L, H) * dot(L, H) * state.mat.roughness;
            float Fd = mix(1.0, Fd90, FL) * mix(1.0, Fd90, FV);
            float3 Fsheen = FH * state.mat.sheen * Csheen;
            return ((1.0 / M_PI_F) * Fd * (1.0 - state.mat.subsurface) * state.mat.albedo + Fsheen) * (1.0 - state.mat.metallic);
        }

        float3 EvalSubsurface(State state, float3 V, float3 N, float3 L, thread float &pdf)
        {
            pdf = (1.0 / M_2_PI_F);

            float FL = SchlickFresnel(abs(dot(N, L)));
            float FV = SchlickFresnel(dot(N, V));
            float Fd = (1.0f - 0.5f * FL) * (1.0f - 0.5f * FV);
            return sqrt(state.mat.albedo) * state.mat.subsurface * (1.0 / M_PI_F) * Fd * (1.0 - state.mat.metallic) * (1.0 - state.mat.transmission);
        }

        float3 DisneySample(thread State &state, float3 V, float3 N, thread float3 &L, thread float &pdf, DataIn dataIn)
        {
            state.isSubsurface = false;
            pdf = 0.0;
            float3 f = float3(0.0);

            float r1 = rand(dataIn);
            float r2 = rand(dataIn);

            float diffuseRatio = 0.5 * (1.0 - state.mat.metallic);
            float transWeight = (1.0 - state.mat.metallic) * state.mat.transmission;

            float3 Cdlin = state.mat.albedo;
            float Cdlum = 0.3 * Cdlin.x + 0.6 * Cdlin.y + 0.1 * Cdlin.z; // luminance approx.

            float3 Ctint = Cdlum > 0.0 ? Cdlin / Cdlum : float3(1.0f); // normalize lum. to isolate hue+sat
            float3 Cspec0 = mix(state.mat.specular * 0.08 * mix(float3(1.0), Ctint, state.mat.specularTint), Cdlin, state.mat.metallic);
            float3 Csheen = mix(float3(1.0), Ctint, state.mat.sheenTint);

            // BSDF
            if (rand(dataIn) < transWeight)
            {
                float3 H = ImportanceSampleGTR2(state.mat.roughness, r1, r2);
                H = state.tangent * H.x + state.bitangent * H.y + N * H.z;

                float3 R = reflect(-V, H);
                float F = DielectricFresnel(abs(dot(R, H)), state.eta);

                // Reflection/Total internal reflection
                if (rand(dataIn) < F)
                {
                    L = normalize(R);
                    f = EvalDielectricReflection(state, V, N, L, H, pdf);
                }
                else // Transmission
                {
                    L = normalize(refract(-V, H, state.eta));
                    f = EvalDielectricRefraction(state, V, N, L, H, pdf);
                }

                f *= transWeight;
                pdf *= transWeight;
            }
            else // BRDF
            {
                if (rand(dataIn) < diffuseRatio)
                {
                    // Diffuse transmission. A way to approximate subsurface scattering
                    if (rand(dataIn) < state.mat.subsurface)
                    {
                        L = UniformSampleHemisphere(r1, r2);
                        L = state.tangent * L.x + state.bitangent * L.y - N * L.z;

                        f = EvalSubsurface(state, V, N, L, pdf);
                        pdf *= state.mat.subsurface * diffuseRatio;

                        state.isSubsurface = true; // Required when sampling lights from inside surface
                    }
                    else // Diffuse
                    {
                        L = CosineSampleHemisphere(r1, r2);
                        L = state.tangent * L.x + state.bitangent * L.y + N * L.z;

                        float3 H = normalize(L + V);

                        f = EvalDiffuse(state, Csheen, V, N, L, H, pdf);
                        pdf *= (1.0 - state.mat.subsurface) * diffuseRatio;
                    }
                }
                else // Specular
                {
                    float primarySpecRatio = 1.0 / (1.0 + state.mat.clearcoat);
                    
                    // Sample primary specular lobe
                    if (rand(dataIn) < primarySpecRatio)
                    {
                        // TODO: Implement http://jcgt.org/published/0007/04/01/
                        float3 H = ImportanceSampleGTR2_aniso(state.mat.ax, state.mat.ay, r1, r2);
                        H = state.tangent * H.x + state.bitangent * H.y + N * H.z;
                        L = normalize(reflect(-V, H));

                        f = EvalSpecular(state, Cspec0, V, N, L, H, pdf);
                        pdf *= primarySpecRatio * (1.0 - diffuseRatio);
                    }
                    else // Sample clearcoat lobe
                    {
                        float3 H = ImportanceSampleGTR1(state.mat.clearcoatRoughness, r1, r2);
                        H = state.tangent * H.x + state.bitangent * H.y + N * H.z;
                        L = normalize(reflect(-V, H));

                        f = EvalClearcoat(state, V, N, L, H, pdf);
                        pdf *= (1.0 - primarySpecRatio) * (1.0 - diffuseRatio);
                    }
                }

                f *= (1.0 - transWeight);
                pdf *= (1.0 - transWeight);
            }
            return f;
        }

        float3 DisneyEval(State state, float3 V, float3 N, float3 L, thread float &pdf)
        {
            float3 H;

            if (dot(N, L) < 0.0)
                H = normalize(L * (1.0 / state.eta) + V);
            else
                H = normalize(L + V);

            if (dot(N, H) < 0.0)
                H = -H;

            float diffuseRatio = 0.5 * (1.0 - state.mat.metallic);
            float primarySpecRatio = 1.0 / (1.0 + state.mat.clearcoat);
            float transWeight = (1.0 - state.mat.metallic) * state.mat.transmission;

            float3 brdf = float3(0.0);
            float3 bsdf = float3(0.0);
            float brdfPdf = 0.0;
            float bsdfPdf = 0.0;

            // BSDF
            if (transWeight > 0.0)
            {
                // Transmission
                if (dot(N, L) < 0.0)
                {
                    bsdf = EvalDielectricRefraction(state, V, N, L, H, bsdfPdf);
                }
                else // Reflection
                {
                    bsdf = EvalDielectricReflection(state, V, N, L, H, bsdfPdf);
                }
            }

            float m_pdf;

            if (transWeight < 1.0)
            {
                // Subsurface
                if (dot(N, L) < 0.0)
                {
                    // TODO: Double check this. Fails furnace test when used with rough transmission
                    if (state.mat.subsurface > 0.0)
                    {
                        brdf = EvalSubsurface(state, V, N, L, m_pdf);
                        brdfPdf = m_pdf * state.mat.subsurface * diffuseRatio;
                    }
                }
                // BRDF
                else
                {
                    float3 Cdlin = state.mat.albedo;
                    float Cdlum = 0.3 * Cdlin.x + 0.6 * Cdlin.y + 0.1 * Cdlin.z; // luminance approx.

                    float3 Ctint = Cdlum > 0.0 ? Cdlin / Cdlum : float3(1.0f); // normalize lum. to isolate hue+sat
                    float3 Cspec0 = mix(state.mat.specular * 0.08 * mix(float3(1.0), Ctint, state.mat.specularTint), Cdlin, state.mat.metallic);
                    float3 Csheen = mix(float3(1.0), Ctint, state.mat.sheenTint);

                    // Diffuse
                    brdf += EvalDiffuse(state, Csheen, V, N, L, H, m_pdf);
                    brdfPdf += m_pdf * (1.0 - state.mat.subsurface) * diffuseRatio;
                    
                    // Specular
                    brdf += EvalSpecular(state, Cspec0, V, N, L, H, m_pdf);
                    brdfPdf += m_pdf * primarySpecRatio * (1.0 - diffuseRatio);
                    
                    // Clearcoat
                    brdf += EvalClearcoat(state, V, N, L, H, m_pdf);
                    brdfPdf += m_pdf * (1.0 - primarySpecRatio) * (1.0 - diffuseRatio);
                }
            }

            pdf = mix(brdfPdf, bsdfPdf, transWeight);
            return mix(brdf, bsdf, transWeight);
        }
            
        """
    }
}
