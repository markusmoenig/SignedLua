//
//  Modeling.metal
//  Signed
//
//  Created by Markus Moenig on 28/6/21.
//

#include <metal_stdlib>
using namespace metal;

kernel void test(texture3d<half, access::write>  modelTexture  [[texture(0)]],
                         uint3 gid                       [[thread_position_in_grid]])
{
    /*
    //float2 size = float2(valueTexture.get_width(), valueTexture.get_height());
    float2 uv = float2(float(gid.x), float(gid.y));
    
    float v = round(hash21(uv));
    
    valueTexture.write(color, gid);*/
    
    float3 size = float3(modelTexture.get_width(), modelTexture.get_height(), modelTexture.get_depth());

    half4 color = half4(-1000);

    modelTexture.write(color, gid);
}
