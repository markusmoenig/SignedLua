//
//  Modeling.metal
//  Signed
//
//  Created by Markus Moenig on 28/6/21.
//

#include <metal_stdlib>
using namespace metal;

// Precision-adjusted variations of https://www.shadertoy.com/view/4djSRW
float hash(float p) { p = fract(p * 0.011); p *= p + 7.5; p *= p + p; return fract(p); }
float hash(float2 p) {float3 p3 = fract(float3(p.xyx) * 0.13); p3 += dot(p3, p3.yzx + 3.333); return fract((p3.x + p3.y) * p3.z); }


float noise(float3 x) {
    const float3 step = float3(110, 241, 171);

    float3 i = floor(x);
    float3 f = fract(x);
 
    // For performance, compute the base input to a 1D hash from the integer part of the argument and the
    // incremental change to the 1D based on the 3D -> 1D wrapping
    float n = dot(i, step);

    float3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix( hash(n + dot(step, float3(0, 0, 0))), hash(n + dot(step, float3(1, 0, 0))), u.x),
                   mix( hash(n + dot(step, float3(0, 1, 0))), hash(n + dot(step, float3(1, 1, 0))), u.x), u.y),
               mix(mix( hash(n + dot(step, float3(0, 0, 1))), hash(n + dot(step, float3(1, 0, 1))), u.x),
                   mix( hash(n + dot(step, float3(0, 1, 1))), hash(n + dot(step, float3(1, 1, 1))), u.x), u.y), u.z);
}

kernel void test(texture3d<half, access::write>  modelTexture  [[texture(0)]],
                         uint3 gid                       [[thread_position_in_grid]])
{
    /*
    //float2 size = float2(valueTexture.get_width(), valueTexture.get_height());
    float2 uv = float2(float(gid.x), float(gid.y));
    
    float v = round(hash21(uv));
    
    valueTexture.write(color, gid);*/
    
    float3 size = float3(modelTexture.get_width(), modelTexture.get_height(), modelTexture.get_depth());
    float3 uv = float3(gid) / size - float3(0.5);// - 0.5;// * size / 2.0;// - size / 2.0;

    half4 color = half4(length(uv) - 0.495) + noise(uv * 160) / 80;

    modelTexture.write(color, gid);
}
