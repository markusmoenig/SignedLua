//
//  MiscShader.swift
//  Signed
//
//  Created by Markus Moenig on 26/6/21.
//

import MetalKit

final class TestShader : BaseShader
{
    override init(pipeline: RenderPipeline)
    {
        super.init(pipeline: pipeline)

        let code =
        """

        #include <metal_stdlib>
        using namespace metal;
        
        kernel void reset(texture2d<half, access::write>  valueTexture  [[texture(0)]],
                                 uint2 gid                       [[thread_position_in_grid]])
        {
            valueTexture.write(half4(0,0,1,1), gid);
        }

        """
        
        compile(code: code, shaders: [
            Shader(id: "MAIN", computeName: "reset"),
        ])
    }
    
    func render(outTexture: MTLTexture)
    {
        if let shader = shaders["MAIN"] {
            
            if let computeEncoder = pipeline.commandBuffer?.makeComputeCommandEncoder() {
                computeEncoder.setComputePipelineState( shader.state )
                computeEncoder.setTexture( outTexture, index: 0 )

                calculateThreadGroups(shader.state, computeEncoder, outTexture.width, outTexture.height)
                
                computeEncoder.endEncoding()
            }
        }
    }
}
