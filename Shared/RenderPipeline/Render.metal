//
//  Render.metal
//  Signed
//
//  Created by Markus Moenig on 28/6/21.
//

#include <metal_stdlib>
using namespace metal;

#import "../Metal.h"

typedef struct
{
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
    float2 viewportSize;
} RasterizerData;

// Quad Vertex Function
vertex RasterizerData
renderQuadVertexShader(uint vertexID [[ vertex_id ]],
             constant VertexUniform *vertexArray [[ buffer(0) ]],
             constant vector_uint2 *viewportSizePointer  [[ buffer(1) ]])
{
    RasterizerData out;
    
    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
    float2 viewportSize = float2(*viewportSizePointer);
    
    out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize / 2.0);
    out.clipSpacePosition.z = 0.0;
    out.clipSpacePosition.w = 1.0;
    
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    out.viewportSize = viewportSize;
    return out;
}

float2 hitBBox( float3 rO, float3 rD, float3 min, float3 max )
{
    // --- aabb check

    float lo = -10000000000.0;
    float hi = +10000000000.0;

    float dimLoX=(min.x - rO.x ) / rD.x;
    float dimHiX=(max.x - rO.x ) / rD.x;

    if ( dimLoX > dimHiX )  {
        float tmp = dimLoX;
        dimLoX = dimHiX;
        dimHiX = tmp;
    }

    if (dimHiX < lo || dimLoX > hi ) return float2(-1);

    if (dimLoX > lo) lo = dimLoX;
    if (dimHiX < hi) hi = dimHiX;

    // ---

    float dimLoY=(min.y - rO.y ) / rD.y;
    float dimHiY=(max.y - rO.y ) / rD.y;

    if ( dimLoY > dimHiY )  {
        float tmp = dimLoY;
        dimLoY = dimHiY;
        dimHiY = tmp;
    }

    if (dimHiY < lo || dimLoY > hi ) return float2(-1);

    if (dimLoY > lo) lo = dimLoY;
    if (dimHiY < hi) hi = dimHiY;

    // ---

    float dimLoZ=(min.z - rO.z ) / rD.z;
    float dimHiZ=(max.z - rO.z ) / rD.z;

    if ( dimLoZ > dimHiZ )  {
        float tmp = dimLoZ;
        dimLoZ = dimHiZ;
        dimHiZ = tmp;
    }

    if (dimHiZ < lo || dimLoZ > hi ) return float2(-1);

    if (dimLoZ > lo) lo = dimLoZ;
    if (dimHiZ < hi) hi = dimHiZ;

    // ---

    if ( lo > hi ) return float2(-1);

    return float2(lo, hi);
}

float rand()
{
    return 0.5;
}

float3 getCamerayRay(float2 uv, float3 ro, float3 rd, float fov, float2 size) {

    float3 position = ro;
    float3 pivot = rd;
    float focalDist = 0.1;
    float aperture = 0;
    
    float3 dir = normalize(pivot - position);
    float pitch = asin(dir.y);
    float yaw = atan2(dir.z, dir.x);

    float radius = distance(position, pivot);

    float3 forward_temp = float3();
    
    forward_temp.x = cos(yaw) * cos(pitch);
    forward_temp.y = sin(pitch);
    forward_temp.z = sin(yaw) * cos(pitch);

    float3 worldUp = float3(0,1,0);
    float3 forward = normalize(forward_temp);
    position = pivot + (forward * -1.0) * radius;

    float3 right = normalize(cross(forward, worldUp));
    float3 up = normalize(cross(right, forward));

    float2 r2D = 2.0 * float2(rand(), rand());

    float2 jitter = float2();
    jitter.x = r2D.x < 1.0 ? sqrt(r2D.x) - 1.0 : 1.0 - sqrt(2.0 - r2D.x);
    jitter.y = r2D.y < 1.0 ? sqrt(r2D.y) - 1.0 : 1.0 - sqrt(2.0 - r2D.y);

    jitter /= (size * 0.5);
    float2 d = (2.0 * uv - 1.0) + jitter;

    float scale = tan(fov * 0.5);
    d.y *= size.y / size.x * scale;
    d.x *= scale;
    float3 rayDir = normalize(d.x * right + d.y * up + forward);

    float3 focalPoint = focalDist * rayDir;
    float cam_r1 = rand() * M_2_PI_F;
    float cam_r2 = rand() * aperture;
    float3 randomAperturePos = (cos(cam_r1) * right + sin(cam_r1) * up) * sqrt(cam_r2);
    float3 finalRayDir = normalize(focalPoint - randomAperturePos);
    
    return finalRayDir;
    
    //outOrigin = position + randomAperturePos;
    //outDirection = finalRayDir;
}

float getDistance(float3 p, texture3d<float> modelTexture, float scale = 1.0)
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
    float d = modelTexture.sample(textureSampler, (p / scale + float3(0.5))).x;
    return d;
}

float3 getNormal(float3 p, texture3d<float> modelTexture, float scale = 1.0)
{
    float3 epsilon = float3(0.001, 0., 0.);

    float3 n = float3(getDistance(p + epsilon.xyy, modelTexture, scale) - getDistance(p - epsilon.xyy, modelTexture, scale),
                      getDistance(p + epsilon.yxy, modelTexture, scale) - getDistance(p - epsilon.yxy, modelTexture, scale),
                      getDistance(p + epsilon.yyx, modelTexture, scale) - getDistance(p - epsilon.yyx, modelTexture, scale));

    return normalize(n);
}


/// Render
fragment float4 render(RasterizerData in [[stage_in]],
                               constant RenderUniform *data [[ buffer(0) ]],
                               texture3d<float> modelTexture [[ texture(1) ]] )
{
    float2 uv = float2(in.textureCoordinate.x, 1.0 - in.textureCoordinate.y);//* in.viewportSize) - in.viewportSize / 2;
    
    float3 ro = data->cameraOrigin;
    float3 rd = data->cameraLookAt;
    
    rd = getCamerayRay(uv, ro, rd, 80, in.viewportSize);

    float scale = 1.0;

    float r = 0.5 * scale;
    float2 d = hitBBox(ro, rd, float3(-r, -r, -r), float3(r, r, r));
    
    float4 color = float4(0,0,0,1);
    
    
    if (d.x > 0.0) {
        //color = float4(1);
        // Raymarch into the texture
    
        bool hit = false;
        
        float t = d.x;
        for(int i = 0; i < 120; ++i)
        {
            float3 p = ro + rd * t;
            float d = getDistance(p, modelTexture, scale);//map(p, dataIn);

            if (abs(d) < (0.0001*t)) {
                hit = true;
                break;
            }
            
            t += d * 0.6;

            //if (t >= maxDist)
            //    break;
        }
        
        if (hit == true) {
            color.xyz = getNormal(ro + rd * t, modelTexture, scale);
        }
    }

    return color;
}
