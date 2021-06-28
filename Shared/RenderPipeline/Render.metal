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

/// Render
fragment float4 render(RasterizerData in [[stage_in]],
//                               constant BoxUniform *data [[ buffer(0) ]],
                               texture3d<float> inTexture [[ texture(0) ]] )
{
    return float4(0, 1, 0, 1);
}
