//
//  RandomShader.swift
//  Signed
//
//  Created by Markus Moenig on 27/6/21.
//

import MetalKit

final class RandomPreviewShader : BaseShader
{
    init(pipeline: RenderPipeline, component: SignedComponent)
    {
        super.init(pipeline: pipeline)

        let code =
        """

        #include <metal_stdlib>
        using namespace metal;
        
        \(component.code)
        
        kernel void random(texture2d<half, access::write>  valueTexture  [[texture(0)]],
                                 uint2 gid                       [[thread_position_in_grid]])
        {
            Random random = Random();
            float value = random.hash12(float2(gid));
            valueTexture.write(half4(value), gid);
        }

        """
        
        compile(code: code, shaders: [
            Shader(id: "MAIN", computeName: "random"),
        ], sync: true)
    }
    
    override func render(outTexture: MTLTexture)
    {
        if let shader = shaders["MAIN"] {
            
            print("render random")
            if let computeEncoder = pipeline.commandBuffer?.makeComputeCommandEncoder() {
                computeEncoder.setComputePipelineState( shader.state )
                computeEncoder.setTexture( outTexture, index: 0 )

                calculateThreadGroups(shader.state, computeEncoder, outTexture.width, outTexture.height)
                
                computeEncoder.endEncoding()
            }
        }
    }
}
