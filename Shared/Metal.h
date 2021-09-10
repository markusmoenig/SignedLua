//
//  Metal.h
//  Signed
//
//  Created by Markus Moenig on 25/8/20.
//

#ifndef Metal_h
#define Metal_h

#include <simd/simd.h>

typedef struct
{
    vector_float2   position;
    vector_float2   textureCoordinate;
} VertexUniform;

typedef struct
{
    vector_float2   screenSize;
    vector_float2   pos;
    vector_float2   size;
    float           globalAlpha;

} TextureUniform;

typedef struct
{
    vector_float4   fillColor;
    vector_float4   borderColor;
    float           radius;
    float           borderSize;
    float           rotation;
    float           onion;
    
    int             hasTexture;
    vector_float2   textureSize;
} DiscUniform;

typedef struct
{
    vector_float2   screenSize;
    vector_float2   pos;
    vector_float2   size;
    float           round;
    float           borderSize;
    vector_float4   fillColor;
    vector_float4   borderColor;
    float           rotation;
    float           onion;
    
    int             hasTexture;
    vector_float2   textureSize;

} BoxUniform;

typedef struct
{
    vector_float2   atlasSize;
    vector_float2   fontPos;
    vector_float2   fontSize;
    vector_float4   color;
} TextUniform;

typedef struct
{
    float           time;
    unsigned int    frame;
} MetalData;

typedef struct {
    
    simd_float3         randomVector;

    int                 samples;
    int                 depth;
    int                 maxDepth;
        
    // bbox
    simd_float3         P;
    simd_float3         L;
    matrix_float3x3     F;
    
    float               maxDistance;
} GPUFragmentUniforms;

// For passing globals
typedef struct DataIn {
    simd_float2     seed;
    simd_float3     randomVector;
    
    int             numOfLights;
} DataIn;

typedef struct {
    
    simd_float3     position;
    simd_float3     emission;

    simd_float3     u; // u vector for rect
    simd_float3     v; // v vector for rect
    simd_float3     params;
    
    float           radius;
    float           area;
    float           type; // 0->Rect, 1->Sphere, 2->Distant
    
} Light;

typedef struct Material
{
    simd_float3 albedo;
    float       specular;
    simd_float3 emission;
    float       anisotropic;
    float       metallic;
    float       roughness;
    float       subsurface;
    float       specularTint;
    float       sheen;
    float       sheenTint;
    float       clearcoat;
    float       clearcoatGloss;
    float       specTrans;
    float       ior;
    float       atDistance;
    simd_float3 extinction;
    simd_float3 texIDs;
    // Roughness calculated from anisotropic param
    float       ax;
    float       ay;
} Material;

typedef struct {
    
    simd_float3         randomVector;

    simd_float3         cameraOrigin;
    simd_float3         cameraLookAt;
    float               cameraFov;
    
    int                 numOfLights;
    Light               lights[4];
    
    simd_float4         backgroundColor;
    
    simd_float3         scale;
        
    int                 samples;
    int                 depth;
    int                 maxDepth;
        
    int                 noShadows;
    int                 showBBox;
    
    // bbox
    simd_float3         P;
    simd_float3         L;
    matrix_float3x3     F;
    
    float               maxDistance;
    
} RenderUniform;

typedef struct {
    int                 samples;
} AccumUniform;

typedef struct {
    
    simd_float3         randomVector;
    
    simd_float2         uv;
    simd_float2         size;
    
    float               scale;
    
    simd_float3         cameraOrigin;
    simd_float3         cameraLookAt;
    float               cameraFov;
    
} ModelerHitUniform;

#define Modeler_GeometryAndMaterial         0
#define Modeler_MaterialOnly                1

#define Modeler_None                        0
#define Modeler_Clear                       1
#define Modeler_Add                         2
#define Modeler_Subtract                    3

#define Modeler_Shape_Heightfield           0
#define Modeler_Shape_Sphere                1
#define Modeler_Shape_Box                   2
#define Modeler_Shape_Cylinder              3

#define Modeler_BlendMode_Linear            0
#define Modeler_BlendMode_ValueNoise        1
#define Modeler_BlendMode_Depth             2

typedef struct {
    
    int                 roleType;
    int                 actionType;
    int                 primitiveType;
    
    int                 id;
    
    simd_float3         randomVector;

    simd_float3         position;
    simd_float3         rotation;

    float               noise;
    float               smoothing;
    simd_float2         depth;
    float               onion;

    float               height;
    float               radius;
    
    simd_float3         size;
    float               rounding;
            
    Material            material;
    
    float               repDistance;
    simd_float3         repLowerLimit;
    simd_float3         repUpperLimit;
    
    // heightfield
    
    float               heightFrequency;
    float               heightOctaves;
    float               heightScale;
        
    // All possible blend options
    
    int                 blendMode;
    
    float               blendLinearValue;
    
    simd_float3         blendOffset;
    float               blendFrequency;
    float               blendSmoothing;

} ModelerUniform;

#endif /* Metal_h */
