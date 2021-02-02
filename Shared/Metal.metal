//
//  Metal.metal
//  Signed
//
//  Created by Markus Moenig on 25/8/20.
//

#include <metal_stdlib>
using namespace metal;

#import "Metal.h"

typedef struct
{
    float4 clipSpacePosition [[position]];
    float2 textureCoordinate;
    float2 viewportSize;
} RasterizerData;

// Quad Vertex Function
vertex RasterizerData
m4mQuadVertexShader(uint vertexID [[ vertex_id ]],
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

// --- SDF utilities

float m4mFillMask(float dist)
{
    return clamp(-dist, 0.0, 1.0);
}

float m4mBorderMask(float dist, float width)
{
    dist += 1.0;
    return clamp(dist + width, 0.0, 1.0) - clamp(dist, 0.0, 1.0);
}

float2 m4mRotateCCW(float2 pos, float angle)
{
    float ca = cos(angle), sa = sin(angle);
    return pos * float2x2(ca, sa, -sa, ca);
}

float2 m4mRotateCCWPivot(float2 pos, float angle, float2 pivot)
{
    float ca = cos(angle), sa = sin(angle);
    return pivot + (pos-pivot) * float2x2(ca, sa, -sa, ca);
}

float2 m4mRotateCW(float2 pos, float angle)
{
    float ca = cos(angle), sa = sin(angle);
    return pos * float2x2(ca, -sa, sa, ca);
}

float2 m4mRotateCWPivot(float2 pos, float angle, float2 pivot)
{
    float ca = cos(angle), sa = sin(angle);
    return pivot + (pos-pivot) * float2x2(ca, -sa, sa, ca);
}

// Disc
fragment float4 m4mDiscDrawable(RasterizerData in [[stage_in]],
                               constant DiscUniform *data [[ buffer(0) ]],
                               texture2d<float> inTexture [[ texture(1) ]] )
{
    float2 uv = in.textureCoordinate * float2( data->radius * 2 + data->borderSize, data->radius * 2 + data->borderSize);
    uv -= float2( data->radius + data->borderSize / 2 );
    
    float dist = length( uv ) - data->radius + data->onion;
    if (data->onion > 0.0)
        dist = abs(dist) - data->onion;
    
    const float mask = m4mFillMask( dist );
    float4 col = float4( data->fillColor.xyz, data->fillColor.w * mask);
    
    float borderMask = m4mBorderMask(dist, data->borderSize);
    float4 borderColor = data->borderColor;
    borderColor.w *= borderMask;
    col = mix( col, borderColor, borderMask );

    if (data->hasTexture == 1 && col.w > 0.0) {
        constexpr sampler textureSampler (mag_filter::linear,
                                          min_filter::linear);
        
        float2 uv = in.textureCoordinate;
        uv.y = 1 - uv.y;
        uv = m4mRotateCCWPivot(uv, data->rotation, 0.5);

        float4 sample = float4(inTexture.sample(textureSampler, uv));
        
        col.xyz = sample.xyz;
        col.w = col.w * sample.w;
    }
    
    return col;
}

// Box
fragment float4 m4mBoxDrawable(RasterizerData in [[stage_in]],
                               constant BoxUniform *data [[ buffer(0) ]],
                               texture2d<float> inTexture [[ texture(1) ]] )
{
    float2 uv = in.textureCoordinate * ( data->size );
    uv -= float2( data->size / 2.0 );
    
    float2 d = abs( uv ) - data->size / 2 + data->onion + data->round;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - data->round;
    
    if (data->onion > 0.0)
        dist = abs(dist) - data->onion;
    
    const float mask = m4mFillMask( dist );
    float4 col = float4( data->fillColor.xyz, data->fillColor.w * mask);
    
    float borderMask = m4mBorderMask(dist, data->borderSize);
    float4 borderColor = data->borderColor;
    borderColor.w *= borderMask;
    col = mix( col, borderColor, borderMask );
    
    if (data->hasTexture == 1 && col.w > 0.0) {
        constexpr sampler textureSampler (mag_filter::linear,
                                          min_filter::linear);
        
        float2 uv = in.textureCoordinate;
        uv.y = 1 - uv.y;
        uv = m4mRotateCCWPivot(uv, data->rotation, 0.5);

        float4 sample = float4(inTexture.sample(textureSampler, uv));
        
        col.xyz = sample.xyz;
        col.w = col.w * sample.w;
    }

    //float4 col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, m4mFillMask( dist ) * data->fillColor.w );
    //float4 col = float4( data->fillColor.x, data->fillColor.y, data->fillColor.z, smoothstep(0.0, -0.1, dist) * data->fillColor.w );
    //col = mix( col, data->borderColor, m4mBorderMask( dist, data->borderSize ) );
    //col = mix( col, data->borderColor, 1.0-smoothstep(0.0, data->borderSize, abs(dist)) );
    return col;
}

// Rotated Box
fragment float4 m4mBoxDrawableExt(RasterizerData in [[stage_in]],
                               constant BoxUniform *data [[ buffer(0) ]],
                               texture2d<float> inTexture [[ texture(1) ]] )
{
    float2 uv = in.textureCoordinate * data->screenSize;
    uv.y = data->screenSize.y - uv.y;
    uv -= float2(data->size / 2.0);
    uv -= float2(data->pos.x, data->pos.y);

    uv = m4mRotateCCW(uv, data->rotation);
    
    float2 d = abs( uv ) - data->size / 2.0 + data->onion + data->round;// - data->borderSize;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - data->round;
    
    if (data->onion > 0.0)
        dist = abs(dist) - data->onion;

    const float mask = m4mFillMask( dist );//smoothstep(0.0, pixelSize, -dist);
    float4 col = float4( data->fillColor.xyz, data->fillColor.w * mask);
    
    const float borderMask = m4mBorderMask(dist, data->borderSize);
    float4 borderColor = data->borderColor;
    borderColor.w *= borderMask;
    col = mix( col, borderColor, borderMask );
    
    if (data->hasTexture == 1 && col.w > 0.0) {
        constexpr sampler textureSampler (mag_filter::linear,
                                          min_filter::linear);
        
        float2 uv = in.textureCoordinate;
        uv.y = 1 - uv.y;
        
        uv -= data->pos / data->screenSize;
        uv *= data->screenSize / data->size;
        
        uv = m4mRotateCCWPivot(uv, data->rotation, (data->size / 2.0) / data->screenSize * (data->screenSize / data->size));
        
        float4 sample = float4(inTexture.sample(textureSampler, uv));
        
        col.xyz = sample.xyz;
        col.w = col.w * sample.w;
    }

    return col;
}

// --- Box Drawable
fragment float4 m4mBoxPatternDrawable(RasterizerData in [[stage_in]],
                               constant BoxUniform *data [[ buffer(0) ]] )
{
    float2 uv = in.textureCoordinate * ( data->screenSize );
    uv -= float2( data->screenSize / 2.0 );
    
    float2 d = abs( uv ) - data->size / 2.0;
    float dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
    
    float4 checkerColor1 = data->fillColor;
    float4 checkerColor2 = data->borderColor;
    
    //uv = fragCoord;
    //uv -= float2( data->size / 2 );
    
    float4 col = checkerColor1;
    
    float cWidth = 12.0;
    float cHeight = 12.0;
    
    if ( fmod( floor( uv.x / cWidth ), 2.0 ) == 0.0 ) {
        if ( fmod( floor( uv.y / cHeight ), 2.0 ) != 0.0 ) col=checkerColor2;
    } else {
        if ( fmod( floor( uv.y / cHeight ), 2.0 ) == 0.0 ) col=checkerColor2;
    }
    
    return float4( col.xyz, m4mFillMask( dist ) );
}

// Copy texture
fragment float4 m4mCopyTextureDrawable(RasterizerData in [[stage_in]],
                                constant TextureUniform *data [[ buffer(0) ]],
                                texture2d<half, access::read> inTexture [[ texture(1) ]])
{
    float2 uv = in.textureCoordinate * data->size;
    uv.y = data->size.y - uv.y;
    
    const half4 colorSample = inTexture.read(uint2(uv));
    float4 sample = float4( colorSample );
    
    sample.xyz = pow(sample.xyz, 1.0 / 2.2);
    sample = clamp(sample, 0, 1);
    
    sample.w *= data->globalAlpha;

    return float4(sample.x / sample.w, sample.y / sample.w, sample.z / sample.w, sample.w);
}

fragment float4 m4mTextureDrawable(RasterizerData in [[stage_in]],
                                constant TextureUniform *data [[ buffer(0) ]],
                                texture2d<half> inTexture [[ texture(1) ]])
{
    //constexpr sampler textureSampler (mag_filter::linear,
    //                                  min_filter::linear);
    
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    float2 uv = in.textureCoordinate;
    uv.y = 1 - uv.y;
    
    uv.x *= data->size.x;
    uv.y *= data->size.y;

    uv.x += data->pos.x;
    uv.y += data->pos.y;
    
    float4 sample = float4(inTexture.sample(textureSampler, uv));
    sample.w *= data->globalAlpha;

    return sample;
}

float m4mMedian(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

fragment float4 m4mTextDrawable(RasterizerData in [[stage_in]],
                                constant TextUniform *data [[ buffer(0) ]],
                                texture2d<float> inTexture [[ texture(1) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);
    
    float2 uv = in.textureCoordinate;
    uv.y = 1 - uv.y;

    uv /= data->atlasSize / data->fontSize;
    uv += data->fontPos / data->atlasSize;

    float4 sample = inTexture.sample(textureSampler, uv );
        
    float d = m4mMedian(sample.r, sample.g, sample.b) - 0.5;
    float w = clamp(d/fwidth(d) + 0.5, 0.0, 1.0);
    return float4( data->color.x, data->color.y, data->color.z, w * data->color.w );
}

fragment float4 m4mMakeCGIImage(RasterizerData in [[stage_in]],
                             texture2d<float, access::read> inTexture [[ texture(0) ]])
{
    float2 uv = float2(in.textureCoordinate.x, 1.0 - in.textureCoordinate.y);
    float2 size = in.viewportSize;

    ushort2 textureUV = ushort2(uv.x * size.x, uv.y * size.y);
    float4 color = inTexture.read(textureUV).zyxw;
    //color.xyz = pow(color.xyz, 2.2);
    color.xyz = clamp(color.xyz, 0, 1);

    return color;
}

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

typedef struct
{
    float3 albedo;
    float specular;

    float3 emission;
    float anisotropic;

    float metallic;
    float roughness;
    float subsurface;
    float specularTint;

    float sheen;
    float sheenTint;
    float clearcoat;
    float clearcoatRoughness;

    float specTrans;

    float ior;
    float3 extinction;
    
    float ax;
    float ay;
} Material;

struct State
{
    int depth;
    float eta;
    float hitDist;

    float3 fhp;
    float3 normal;
    float3 ffnormal;
    float3 tangent;
    float3 bitangent;

    bool isEmitter;
    bool specularBounce;
    bool isSubsurface;

    float2 texCoord;
    Material mat;
};

struct Ray
{
    float3 origin;
    float3 direction;
};

struct BsdfSampleRec
{
    float3 L;
    float3 f;
    float pdf;
};

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
    return sqrt(state.mat.albedo) * state.mat.subsurface * (1.0 / M_PI_F) * Fd * (1.0 - state.mat.metallic) * (1.0 - state.mat.specTrans);
}

typedef struct
{
    float               time;

    float2              uv;
    float2              viewSize;
    
    float2              seed;
    float3              randomVector;
    constant float4    *data;
} DataIn;

float rand(DataIn dataIn)
{
    dataIn.seed -= dataIn.randomVector.xy;
    return fract(sin(dot(dataIn.seed, float2(12.9898, 78.233))) * 43758.5453);
}

float3 DisneySample(thread State &state, float3 V, float3 N, thread float3 &L, thread float &pdf, DataIn dataIn)
{
    state.isSubsurface = false;
    pdf = 0.0;
    float3 f = float3(0.0);

    float r1 = rand(dataIn);
    float r2 = rand(dataIn);

    float diffuseRatio = 0.5 * (1.0 - state.mat.metallic);
    float transWeight = (1.0 - state.mat.metallic) * state.mat.specTrans;

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
    float transWeight = (1.0 - state.mat.metallic) * state.mat.specTrans;

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
