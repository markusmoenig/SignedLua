//
//  Modeling.metal
//  Signed
//
//  Created by Markus Moenig on 28/6/21.
//

#include <metal_stdlib>
using namespace metal;

#import "../Metal.h"

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

// Thanks Inigo, https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm

float sdSphere(float3 p, float s)
{
    return length(p)-s;
}

float sdBox(float3 p, float3 b)
{
    float3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdRoundBox(float3 p, float3 b, float r )
{
    float3 q = abs(p) - b + r;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

/// Executes one modeler command
kernel void modelerCmd(constant ModelerUniform                  &mData [[ buffer(0) ]],
                       texture3d<half, access::read_write>      modelTexture  [[texture(1)]],
                       texture3d<half, access::write>           colorTexture  [[texture(2)]],
                       uint3 gid                                [[thread_position_in_grid]])
{
    float3 size = float3(modelTexture.get_width(), modelTexture.get_height(), modelTexture.get_depth());
    float3 uv = float3(gid) / size - float3(0.5);

    float dist = modelTexture.read(gid).x, newDist = INFINITY;
    
    if (mData.primitiveType == Modeler_Sphere) {
        newDist = sdSphere(uv - mData.position, mData.radius);
    } else
    if (mData.primitiveType == Modeler_Box) {
        newDist = sdRoundBox(uv - mData.position, mData.size, mData.rounding);
    }
    
    dist = min(dist, newDist);
    
    if (dist == newDist) {
        colorTexture.write(half4(float4(mData.material.albedo, mData.material.roughness)), gid);
    }
    
    modelTexture.write(half4(dist), gid);
}

/// Clears the texture
kernel void modelerClear(texture3d<half, access::write>    modelTexture  [[texture(0)]],
                         texture3d<half, access::write>    colorTexture  [[texture(1)]],
                         uint3 gid                         [[thread_position_in_grid]])
{
    modelTexture.write(half4(1000), gid);
    colorTexture.write(half4(0.5), gid);
}
