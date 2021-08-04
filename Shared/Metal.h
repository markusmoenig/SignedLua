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
    
    int                 numOfLights;
    Light               lights[4];
    
    simd_float4         backgroundColor;
    
    float               scale;
        
    int                 samples;
    int                 depth;
    int                 maxDepth;
        
    int                 noShadows;
    
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
    
} ModelerHitUniform;

#define Modeler_Global_Scale                10.0

#define Modeler_GeometryAndMaterial         0
#define Modeler_MaterialOnly                1

#define Modeler_None                        0
#define Modeler_Add                         1
#define Modeler_Subtract                    2

#define Modeler_Sphere                      0
#define Modeler_Box                         1

typedef struct
{
    int                 albedoMixer;
    int                 specularMixer;
    int                 emissionMixer;
    int                 anisotropicMixer;
    int                 metallicMixer;
    int                 roughnessMixer;
    int                 subsurfaceMixer;
    int                 specularTintMixer;
    int                 sheenMixer;
    int                 sheenTintMixer;
    int                 clearcoatMixer;
    int                 clearcoatGlossMixer;
    int                 specTransMixer;
    int                 iorMixer;
    
    float               albedoMixerScale;
    int                 albedoMixerSmoothing;
    
    float               specularMixerScale;
    int                 specularMixerSmoothing;
    
    float               emissionMixerScale;
    int                 emissionMixerSmoothing;
    
    float               anisotropicMixerScale;
    int                 anisotropicMixerSmoothing;
    
    float               metallicMixerScale;
    int                 metallicMixerSmoothing;
    
    float               roughnessMixerScale;
    int                 roughnessMixerSmoothing;
    
    float               subsurfaceMixerScale;
    int                 subsurfaceMixerSmoothing;
    
    float               specularTintMixerScale;
    int                 specularTintMixerSmoothing;
    
    float               sheenMixerScale;
    int                 sheenMixerSmoothing;
    
    float               sheenTintMixerScale;
    int                 sheenTintMixerSmoothing;
    
    float               clearcoatMixerScale;
    int                 clearcoatMixerSmoothing;
    
    float               clearcoatGlossMixerScale;
    int                 clearcoatGlossMixerSmoothing;
    
    float               specTransMixerScale;
    int                 specTransMixerSmoothing;
    
    float               iorMixerScale;
    int                 iorMixerSmoothing;
} MaterialMixer;

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

    float               radius;
    
    simd_float3         size;
    float               rounding;
    
    simd_float3         normal;
    float               surfaceDistance;
        
    Material            material;
    Material            mixMaterial;
    MaterialMixer       mixer;

    float               materialOnlyMixerValue;

    // If we are using a brush, the brush hit is used to render a preview
    simd_float3         brushHit;
    
    int                 writeBrush;
    float               brushSize;
} ModelerUniform;

#endif /* Metal_h */
