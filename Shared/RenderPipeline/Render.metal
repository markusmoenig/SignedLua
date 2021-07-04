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

// MARK: Disney Start

// Based on the Disney BSDF Pathtracer at https://github.com/knightcrawler25/GLSL-PathTracer

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

// For passing globals around
struct DataIn {
    float2  seed;
    float3  randomVector;
    
    int     numOfLights;
};

// globals.glsl

#define PI        3.14159265358979323
#define TWO_PI    6.28318530717958648
//#define INFINITY  1000000.0
#define EPS       0.0001

#define QUAD_LIGHT 0
#define SPHERE_LIGHT 1
#define DISTANT_LIGHT 2

struct Ray
{
    float3 origin;
    float3 direction;
};

struct Camera
{
    float3 up;
    float3 right;
    float3 forward;
    float3 position;
    float fov;
    float focalDist;
    float aperture;
};

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

    float2 texCoord;
    float3 bary;
    //ivec3 triID;
    int matID;
    Material mat;
};

struct BsdfSampleRec
{
    float3 L;
    float3 f;
    float pdf;
};

struct LightSampleRec
{
    float3 normal;
    float3 emission;
    float3 direction;
    float dist;
    float pdf;
};

float rand(thread DataIn &dataIn)
{
    dataIn.seed -= dataIn.randomVector.xy;
    return fract(sin(dot(dataIn.seed, float2(12.9898, 78.233))) * 43758.5453);
}

float3 FaceForward(float3 a, float3 b)
{
    return dot(a, b) < 0.0 ? -b : b;
}

// sampling.glsl

//----------------------------------------------------------------------
float3 ImportanceSampleGTR1(float rgh, float r1, float r2)
//----------------------------------------------------------------------
{
   float a = max(0.001, rgh);
   float a2 = a * a;

   float phi = r1 * TWO_PI;

   float cosTheta = sqrt((1.0 - pow(a2, 1.0 - r1)) / (1.0 - a2));
   float sinTheta = clamp(sqrt(1.0 - (cosTheta * cosTheta)), 0.0, 1.0);
   float sinPhi = sin(phi);
   float cosPhi = cos(phi);

   return float3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
}

//----------------------------------------------------------------------
float3 ImportanceSampleGTR2_aniso(float ax, float ay, float r1, float r2)
//----------------------------------------------------------------------
{
   float phi = r1 * TWO_PI;

   float sinPhi = ay * sin(phi);
   float cosPhi = ax * cos(phi);
   float tanTheta = sqrt(r2 / (1 - r2));

   return float3(tanTheta * cosPhi, tanTheta * sinPhi, 1.0);
}

//----------------------------------------------------------------------
float3 ImportanceSampleGTR2(float rgh, float r1, float r2)
//----------------------------------------------------------------------
{
   float a = max(0.001, rgh);

   float phi = r1 * TWO_PI;

   float cosTheta = sqrt((1.0 - r2) / (1.0 + (a * a - 1.0) * r2));
   float sinTheta = clamp(sqrt(1.0 - (cosTheta * cosTheta)), 0.0, 1.0);
   float sinPhi = sin(phi);
   float cosPhi = cos(phi);

   return float3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
}

//-----------------------------------------------------------------------
float SchlickFresnel(float u)
//-----------------------------------------------------------------------
{
   float m = clamp(1.0 - u, 0.0, 1.0);
   float m2 = m * m;
   return m2 * m2 * m; // pow(m,5)
}

//-----------------------------------------------------------------------
float DielectricFresnel(float cos_theta_i, float eta)
//-----------------------------------------------------------------------
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

//-----------------------------------------------------------------------
float GTR1(float NDotH, float a)
//-----------------------------------------------------------------------
{
   if (a >= 1.0)
       return (1.0 / PI);
   float a2 = a * a;
   float t = 1.0 + (a2 - 1.0) * NDotH * NDotH;
   return (a2 - 1.0) / (PI * log(a2) * t);
}

//-----------------------------------------------------------------------
float GTR2(float NDotH, float a)
//-----------------------------------------------------------------------
{
   float a2 = a * a;
   float t = 1.0 + (a2 - 1.0) * NDotH * NDotH;
   return a2 / (PI * t * t);
}

//-----------------------------------------------------------------------
float GTR2_aniso(float NDotH, float HDotX, float HDotY, float ax, float ay)
//-----------------------------------------------------------------------
{
   float a = HDotX / ax;
   float b = HDotY / ay;
   float c = a * a + b * b + NDotH * NDotH;
   return 1.0 / (PI * ax * ay * c * c);
}

//-----------------------------------------------------------------------
float SmithG_GGX(float NDotV, float alphaG)
//-----------------------------------------------------------------------
{
   float a = alphaG * alphaG;
   float b = NDotV * NDotV;
   return 1.0 / (NDotV + sqrt(a + b - a * b));
}

//-----------------------------------------------------------------------
float SmithG_GGX_aniso(float NDotV, float VDotX, float VDotY, float ax, float ay)
//-----------------------------------------------------------------------
{
   float a = VDotX * ax;
   float b = VDotY * ay;
   float c = NDotV;
   return 1.0 / (NDotV + sqrt(a * a + b * b + c * c));
}

//-----------------------------------------------------------------------
float3 CosineSampleHemisphere(float r1, float r2)
//-----------------------------------------------------------------------
{
    float3 dir;
   float r = sqrt(r1);
   float phi = TWO_PI * r2;
   dir.x = r * cos(phi);
   dir.y = r * sin(phi);
   dir.z = sqrt(max(0.0, 1.0 - dir.x * dir.x - dir.y * dir.y));

   return dir;
}

//-----------------------------------------------------------------------
float3 UniformSampleHemisphere(float r1, float r2)
//-----------------------------------------------------------------------
{
   float r = sqrt(max(0.0, 1.0 - r1 * r1));
   float phi = TWO_PI * r2;

   return float3(r * cos(phi), r * sin(phi), r1);
}

//-----------------------------------------------------------------------
float3 UniformSampleSphere(float r1, float r2)
//-----------------------------------------------------------------------
{
   float z = 1.0 - 2.0 * r1;
   float r = sqrt(max(0.0, 1.0 - z * z));
   float phi = TWO_PI * r2;

   return float3(r * cos(phi), r * sin(phi), z);
}

//-----------------------------------------------------------------------
float powerHeuristic(float a, float b)
//-----------------------------------------------------------------------
{
   float t = a * a;
   return t / (b * b + t);
}

//-----------------------------------------------------------------------
void sampleSphereLight(Light light, float3 surfacePos, thread LightSampleRec &lightSampleRec, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
   // TODO: Pick a point only on the visible surface of the sphere

   float r1 = rand(dataIn);
   float r2 = rand(dataIn);

   float3 lightSurfacePos = light.position + UniformSampleSphere(r1, r2) * light.radius;
   lightSampleRec.direction = lightSurfacePos - surfacePos;
   lightSampleRec.dist = length(lightSampleRec.direction);
   float distSq = lightSampleRec.dist * lightSampleRec.dist;
   lightSampleRec.direction /= lightSampleRec.dist;
   lightSampleRec.normal = normalize(lightSurfacePos - light.position);
   lightSampleRec.emission = light.emission * float(dataIn.numOfLights);
   lightSampleRec.pdf = distSq / (light.area * abs(dot(lightSampleRec.normal, lightSampleRec.direction)));
}

//-----------------------------------------------------------------------
void sampleRectLight(Light light, float3 surfacePos, thread LightSampleRec &lightSampleRec, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
   float r1 = rand(dataIn);
   float r2 = rand(dataIn);

    float3 lightSurfacePos = light.position + light.u * r1 + light.v * r2;
   lightSampleRec.direction = lightSurfacePos - surfacePos;
   lightSampleRec.dist = length(lightSampleRec.direction);
   float distSq = lightSampleRec.dist * lightSampleRec.dist;
   lightSampleRec.direction /= lightSampleRec.dist;
   lightSampleRec.normal = normalize(cross(light.u, light.v));
   lightSampleRec.emission = light.emission * float(dataIn.numOfLights);
   lightSampleRec.pdf = distSq / (light.area * abs(dot(lightSampleRec.normal, lightSampleRec.direction)));
}

//-----------------------------------------------------------------------
void sampleDistantLight(Light light, float3 surfacePos, thread LightSampleRec &lightSampleRec, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
   lightSampleRec.direction = normalize(light.position - float3(0.0));
   lightSampleRec.normal = normalize(surfacePos - light.position);
   lightSampleRec.emission = light.emission * float(dataIn.numOfLights);
   lightSampleRec.dist = INFINITY;
   lightSampleRec.pdf = 1.0;
}

//-----------------------------------------------------------------------
void sampleOneLight(Light light, float3 surfacePos, thread LightSampleRec &lightSampleRec, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
   int type = int(light.type);

   if (type == QUAD_LIGHT)
       sampleRectLight(light, surfacePos, lightSampleRec, dataIn);
   else if (type == SPHERE_LIGHT)
       sampleSphereLight(light, surfacePos, lightSampleRec, dataIn);
   else
       sampleDistantLight(light, surfacePos, lightSampleRec, dataIn);
}

#ifdef ENVMAP
#ifndef CONSTANT_BG

//-----------------------------------------------------------------------
float EnvPdf(in Ray r)
//-----------------------------------------------------------------------
{
   float theta = acos(clamp(r.direction.y, -1.0, 1.0));
   vec2 uv = vec2((PI + atan(r.direction.z, r.direction.x)) * (1.0 / TWO_PI), theta * (1.0 / PI));
   float pdf = texture(hdrCondDistTex, uv).y * texture(hdrMarginalDistTex, vec2(uv.y, 0.)).y;
   return (pdf * hdrResolution) / (2.0 * PI * PI * sin(theta));
}

//-----------------------------------------------------------------------
vec4 EnvSample(inout vec3 color)
//-----------------------------------------------------------------------
{
   float r1 = rand();
   float r2 = rand();

   float v = texture(hdrMarginalDistTex, vec2(r1, 0.)).x;
   float u = texture(hdrCondDistTex, vec2(r2, v)).x;

   color = texture(hdrTex, vec2(u, v)).xyz * hdrMultiplier;
   float pdf = texture(hdrCondDistTex, vec2(u, v)).y * texture(hdrMarginalDistTex, vec2(v, 0.)).y;

   float phi = u * TWO_PI;
   float theta = v * PI;

   if (sin(theta) == 0.0)
       pdf = 0.0;

   return vec4(-sin(theta) * cos(phi), cos(theta), -sin(theta) * sin(phi), (pdf * hdrResolution) / (2.0 * PI * PI * sin(theta)));
}

#endif
#endif

//-----------------------------------------------------------------------
float3 EmitterSample(Ray r, State state, LightSampleRec lightSampleRec, BsdfSampleRec bsdfSampleRec)
//-----------------------------------------------------------------------
{
   float3 Le;

   if (state.depth == 0 || state.specularBounce)
       Le = lightSampleRec.emission;
   else
       Le = powerHeuristic(bsdfSampleRec.pdf, lightSampleRec.pdf) * lightSampleRec.emission;

   return Le;
}

// disney.glsl

//-----------------------------------------------------------------------
float3 EvalDielectricReflection(State state, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) <= 0.0)
        return float3(0.0);

    float F = DielectricFresnel(dot(V, H), state.eta);
    float D = GTR2(dot(N, H), state.mat.roughness);
    
    pdf = D * dot(N, H) * F / (4.0 * abs(dot(V, H)));

    float G = SmithG_GGX(abs(dot(N, L)), state.mat.roughness) * SmithG_GGX(abs(dot(N, V)), state.mat.roughness);
    return state.mat.albedo * F * D * G;
}

//-----------------------------------------------------------------------
float3 EvalDielectricRefraction(State state, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) >= 0.0)
        return float3(0.0);

    float F = DielectricFresnel(abs(dot(V, H)), state.eta);
    float D = GTR2(dot(N, H), state.mat.roughness);

    float denomSqrt = dot(L, H) + dot(V, H) * state.eta;
    pdf = D * dot(N, H) * (1.0 - F) * abs(dot(L, H)) / (denomSqrt * denomSqrt);

    float G = SmithG_GGX(abs(dot(N, L)), state.mat.roughness) * SmithG_GGX(abs(dot(N, V)), state.mat.roughness);
    return state.mat.albedo * (1.0 - F) * D * G * abs(dot(V, H)) * abs(dot(L, H)) * 4.0 * state.eta * state.eta / (denomSqrt * denomSqrt);
}

//-----------------------------------------------------------------------
float3 EvalSpecular(State state, float3 Cspec0, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) <= 0.0)
        return float3(0.0);

    float D = GTR2(dot(N, H), state.mat.roughness);
    pdf = D * dot(N, H) / (4.0 * dot(V, H));

    float FH = SchlickFresnel(dot(L, H));
    float3 F = mix(Cspec0, float3(1.0), FH);
    float G = SmithG_GGX(abs(dot(N, L)), state.mat.roughness) * SmithG_GGX(abs(dot(N, V)), state.mat.roughness);
    return F * D * G;
}

//-----------------------------------------------------------------------
float3 EvalClearcoat(State state, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) <= 0.0)
        return float3(0.0);

    float D = GTR1(dot(N, H), mix(0.1, 0.001, state.mat.clearcoatGloss));
    pdf = D * dot(N, H) / (4.0 * dot(V, H));

    float FH = SchlickFresnel(dot(L, H));
    float F = mix(0.04, 1.0, FH);
    float G = SmithG_GGX(dot(N, L), 0.25) * SmithG_GGX(dot(N, V), 0.25);
    return float3(0.25 * state.mat.clearcoat * F * D * G);
}

//-----------------------------------------------------------------------
float3 EvalDiffuse(State state, float3 Csheen, float3 V, float3 N, float3 L, float3 H, thread float &pdf)
//-----------------------------------------------------------------------
{
    pdf = 0.0;
    if (dot(N, L) <= 0.0)
        return float3(0.0);

    pdf = dot(N, L) * (1.0 / PI);

    // Diffuse
    float FL = SchlickFresnel(dot(N, L));
    float FV = SchlickFresnel(dot(N, V));
    float FH = SchlickFresnel(dot(L, H));
    float Fd90 = 0.5 + 2.0 * dot(L, H) * dot(L, H) * state.mat.roughness;
    float Fd = mix(1.0, Fd90, FL) * mix(1.0, Fd90, FV);

    // Fake Subsurface TODO: Replace with volumetric scattering
    float Fss90 = dot(L, H) * dot(L, H) * state.mat.roughness;
    float Fss = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
    float ss = 1.25 * (Fss * (1.0 / (dot(N, L) + dot(N, V)) - 0.5) + 0.5);

    float3 Fsheen = FH * state.mat.sheen * Csheen;
    return ((1.0 / PI) * mix(Fd, ss, state.mat.subsurface) * state.mat.albedo + Fsheen) * (1.0 - state.mat.metallic);
}

//-----------------------------------------------------------------------
float3 DisneySample(thread State &state, float3 V, float3 N, thread float3 &L, thread float &pdf, thread DataIn &dataIn)
//-----------------------------------------------------------------------
{
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

    // TODO: Reuse random numbers and reduce so many calls to rand()
    if (rand(dataIn) < transWeight)
    {
        float3 H = ImportanceSampleGTR2(state.mat.roughness, r1, r2);
        H = state.tangent * H.x + state.bitangent * H.y + N * H.z;

        if (dot(V, H) < 0.0)
            H = -H;

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
    else
    {
        if (rand(dataIn) < diffuseRatio)
        {
            L = CosineSampleHemisphere(r1, r2);
            L = state.tangent * L.x + state.bitangent * L.y + N * L.z;

            float3 H = normalize(L + V);

            f = EvalDiffuse(state, Csheen, V, N, L, H, pdf);
            pdf *= diffuseRatio;
        }
        else // Specular
        {
            float primarySpecRatio = 1.0 / (1.0 + state.mat.clearcoat);
            
            // Sample primary specular lobe
            if (rand(dataIn) < primarySpecRatio)
            {
                // TODO: Implement http://jcgt.org/published/0007/04/01/
                float3 H = ImportanceSampleGTR2(state.mat.roughness, r1, r2);
                H = state.tangent * H.x + state.bitangent * H.y + N * H.z;

                if (dot(V, H) < 0.0)
                    H = -H;

                L = normalize(reflect(-V, H));

                f = EvalSpecular(state, Cspec0, V, N, L, H, pdf);
                pdf *= primarySpecRatio * (1.0 - diffuseRatio);
            }
            else // Sample clearcoat lobe
            {
                float3 H = ImportanceSampleGTR1(mix(0.1, 0.001, state.mat.clearcoatGloss), r1, r2);
                H = state.tangent * H.x + state.bitangent * H.y + N * H.z;

                if (dot(V, H) < 0.0)
                    H = -H;

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

//-----------------------------------------------------------------------
float3 DisneyEval(State state, float3 V, float3 N, float3 L, thread float &pdf)
//-----------------------------------------------------------------------
{
    float3 H;
    bool refl = dot(N, L) > 0.0;

    if (refl)
        H = normalize(L + V);
    else
        H = normalize(L + V * state.eta);

    if (dot(V, H) < 0.0)
        H = -H;

    float diffuseRatio = 0.5 * (1.0 - state.mat.metallic);
    float primarySpecRatio = 1.0 / (1.0 + state.mat.clearcoat);
    float transWeight = (1.0 - state.mat.metallic) * state.mat.specTrans;

    float3 brdf = float3(0.0);
    float3 bsdf = float3(0.0);
    float brdfPdf = 0.0;
    float bsdfPdf = 0.0;

    if (transWeight > 0.0)
    {
        // Reflection
        if (refl)
        {
            bsdf = EvalDielectricReflection(state, V, N, L, H, bsdfPdf);
        }
        else // Transmission
        {
            bsdf = EvalDielectricRefraction(state, V, N, L, H, bsdfPdf);
        }
    }

    float m_pdf;

    if (transWeight < 1.0)
    {
        float3 Cdlin = state.mat.albedo;
        float Cdlum = 0.3 * Cdlin.x + 0.6 * Cdlin.y + 0.1 * Cdlin.z; // luminance approx.

        float3 Ctint = Cdlum > 0.0 ? Cdlin / Cdlum : float3(1.0f); // normalize lum. to isolate hue+sat
        float3 Cspec0 = mix(state.mat.specular * 0.08 * mix(float3(1.0), Ctint, state.mat.specularTint), Cdlin, state.mat.metallic);
        float3 Csheen = mix(float3(1.0), Ctint, state.mat.sheenTint);

        // Diffuse
        brdf += EvalDiffuse(state, Csheen, V, N, L, H, m_pdf);
        brdfPdf += m_pdf * diffuseRatio;
            
        // Specular
        brdf += EvalSpecular(state, Cspec0, V, N, L, H, m_pdf);
        brdfPdf += m_pdf * primarySpecRatio * (1.0 - diffuseRatio);
            
        // Clearcoat
        brdf += EvalClearcoat(state, V, N, L, H, m_pdf);
        brdfPdf += m_pdf * (1.0 - primarySpecRatio) * (1.0 - diffuseRatio);
    }

    pdf = mix(brdfPdf, bsdfPdf, transWeight);
    return mix(brdf, bsdf, transWeight);
}

//-----------------------------------------------------------------------
void Onb(float3 N, thread float3 &T, thread float3 &B)
//-----------------------------------------------------------------------
{
    float3 UpVector = abs(N.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
    T = normalize(cross(UpVector, N));
    B = cross(N, T);
}

// MARK: Disney End

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

float3 getCamerayRay(float2 uv, float3 ro, float3 rd, float fov, float2 size, thread DataIn &dataIn) {

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

    float2 r2D = 2.0 * float2(rand(dataIn), rand(dataIn));

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
    float cam_r1 = rand(dataIn) * M_2_PI_F;
    float cam_r2 = rand(dataIn) * aperture;
    float3 randomAperturePos = (cos(cam_r1) * right + sin(cam_r1) * up) * sqrt(cam_r2);
    float3 finalRayDir = normalize(focalPoint - randomAperturePos);
    
    return finalRayDir;
}

float applyModelerData(float3 uv, float dist, constant ModelerUniform  &mData, float scale);

/// Gets the distance at the given point
float getDistance(float3 p, texture3d<float> modelTexture, constant ModelerUniform &mData, float scale = 1.0)
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
    float d = modelTexture.sample(textureSampler, (p / scale + float3(0.5))).x * scale;
    d = applyModelerData(p, d, mData, scale);

    return d;
}

/// Gets the distance at the given point
float getDistance(float3 p, texture3d<float> modelTexture, float scale = 1.0)
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
    float d = modelTexture.sample(textureSampler, (p / scale + float3(0.5))).x;
    return d * scale;
}

/// Gets the color and roughness at the given point
float4 getColorAndRoughness(float3 p, texture3d<float> colorTexture, float scale = 1.0)
{
    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
    
    float4 color = colorTexture.sample(textureSampler, (p / scale + float3(0.5)));
    return color;
}

/// Calculates the normal at the given point
float3 getNormal(float3 p, texture3d<float> modelTexture, constant ModelerUniform  &mData, float scale = 1.0)
{
    float3 epsilon = float3(0.001, 0., 0.);

    float3 n = float3(getDistance(p + epsilon.xyy, modelTexture, mData, scale) - getDistance(p - epsilon.xyy, modelTexture, mData, scale),
                      getDistance(p + epsilon.yxy, modelTexture, mData, scale) - getDistance(p - epsilon.yxy, modelTexture, mData, scale),
                      getDistance(p + epsilon.yyx, modelTexture, mData, scale) - getDistance(p - epsilon.yyx, modelTexture, mData, scale));

    return normalize(n);
}

/// Calculates the normal at the given point
float3 getNormal(float3 p, texture3d<float> modelTexture, float scale = 1.0)
{
    float3 epsilon = float3(0.001, 0., 0.);

    float3 n = float3(getDistance(p + epsilon.xyy, modelTexture, scale) - getDistance(p - epsilon.xyy, modelTexture, scale),
                      getDistance(p + epsilon.yxy, modelTexture, scale) - getDistance(p - epsilon.yxy, modelTexture, scale),
                      getDistance(p + epsilon.yyx, modelTexture, scale) - getDistance(p - epsilon.yyx, modelTexture, scale));

    return normalize(n);
}

//-----------------------------------------------------------------------
float3 DirectLight(Ray ray, State state, thread DataIn &dataIn, constant RenderUniform &renderData, constant ModelerUniform  &mData, texture3d<float> modelTexture, float scale = 1.0)
//-----------------------------------------------------------------------
{
    float3 Li = float3(0.0);
    float3 surfacePos = state.fhp + state.normal * EPS;

    BsdfSampleRec bsdfSampleRec;

    // Environment Light
#ifdef ENVMAP
#ifndef CONSTANT_BG
    {
        vec3 color;
        vec4 dirPdf = EnvSample(color);
        vec3 lightDir = dirPdf.xyz;
        float lightPdf = dirPdf.w;

        Ray shadowRay = Ray(surfacePos, lightDir);
        bool inShadow = AnyHit(shadowRay, INFINITY - EPS);

        if (!inShadow)
        {
            bsdfSampleRec.f = DisneyEval(state, -r.direction, state.ffnormal, lightDir, bsdfSampleRec.pdf);

            if (bsdfSampleRec.pdf > 0.0)
            {
                float misWeight = powerHeuristic(lightPdf, bsdfSampleRec.pdf);
                if (misWeight > 0.0)
                    Li += misWeight * bsdfSampleRec.f * abs(dot(lightDir, state.ffnormal)) * color / lightPdf;
            }
        }
    }
#endif
#endif

    // Analytic Lights
//#ifdef LIGHTS
    {
        LightSampleRec lightSampleRec;

        //Pick a light to sample
        int index = int(rand(dataIn) * float(dataIn.numOfLights)) * 5;

        Light light = renderData.lights[index];

        // Fetch light Data
        /*
        vec3 position = texelFetch(lightsTex, ivec2(index + 0, 0), 0).xyz;
        vec3 emission = texelFetch(lightsTex, ivec2(index + 1, 0), 0).xyz;
        vec3 u        = texelFetch(lightsTex, ivec2(index + 2, 0), 0).xyz; // u vector for rect
        vec3 v        = texelFetch(lightsTex, ivec2(index + 3, 0), 0).xyz; // v vector for rect
        vec3 params   = texelFetch(lightsTex, ivec2(index + 4, 0), 0).xyz;
        float radius  = params.x;
        float area    = params.y;
        float type    = params.z; // 0->Rect, 1->Sphere, 2->Distant
        */

        float3 params   = light.params;//texelFetch(lightsTex, ivec2(index + 4, 0), 0).xyz;
        light.radius  = params.x;
        light.area    = params.y;
        light.type    = params.z; // 0->Rect, 1->Sphere, 2->Distant
        
        //light = Light(position, emission, u, v, radius, area, type);
        sampleOneLight(light, surfacePos, lightSampleRec, dataIn);

        if (dot(lightSampleRec.direction, lightSampleRec.normal) < 0.0)
        {
            //Ray shadowRay = Ray(surfacePos, lightSampleRec.direction);
            bool inShadow = false;//AnyHit(shadowRay, lightSampleRec.dist - EPS);

            float t = 0.0;
            for(int i = 0; i < 70; ++i)
            {
                float3 p = surfacePos + lightSampleRec.direction * t;
                float d = getDistance(p, modelTexture, mData, scale);//map(p, dataIn);

                if (abs(d) < (0.0001*t)) {
                    inShadow = true;
                    break;
                }
                
                t += d;
            }

            if (!inShadow)
            {
                bsdfSampleRec.f = DisneyEval(state, -ray.direction, state.ffnormal, lightSampleRec.direction, bsdfSampleRec.pdf);

                float weight = 1.0;
                if(light.area > 0.0)
                    weight = powerHeuristic(lightSampleRec.pdf, bsdfSampleRec.pdf);

                if (bsdfSampleRec.pdf > 0.0)
                    Li += weight * bsdfSampleRec.f * abs(dot(state.ffnormal, lightSampleRec.direction)) * lightSampleRec.emission / lightSampleRec.pdf;
            }
        }
    }
//#endif

    return Li;
}

// MARK: Render Entry Point
fragment float4 render(RasterizerData in [[stage_in]],
                               constant RenderUniform &renderData [[ buffer(0) ]],
                               constant ModelerUniform &mData [[ buffer(1) ]],
                               texture3d<float> modelTexture [[ texture(2) ]],
                               texture3d<float> colorTexture [[ texture(3) ]] )
{
    float2 uv = float2(in.textureCoordinate.x, 1.0 - in.textureCoordinate.y);
    
    float3 ro = renderData.cameraOrigin;
    float3 rd = renderData.cameraLookAt;
    float scale = renderData.scale;

    struct DataIn dataIn;
    
    dataIn.seed = uv;
    dataIn.randomVector = renderData.randomVector;
    dataIn.numOfLights = renderData.numOfLights;

    rd = getCamerayRay(uv, ro, rd, 80, in.viewportSize, dataIn);
        
    float3 radiance = float3(0.0);
    float3 throughput = float3(1.0);
    State state;
    LightSampleRec lightSampleRec;
    BsdfSampleRec bsdfSampleRec;
    float3 absorption = float3(0.0);
    state.specularBounce = false;
    state.isEmitter = false;
    
    Ray ray;
    ray.origin = ro;
    ray.direction = rd;
    
    int maxDepth = 4;

    for (int depth = 0; depth < maxDepth; depth++)
    {
        state.depth = depth;
     
        float r = 0.5 * scale;
        float2 bbox = hitBBox(ray.origin, ray.direction, float3(-r, -r, -r), float3(r, r, r));

        float t = INFINITY;
        
        if (bbox.y > 0.0) {
        
            t = bbox.x;
            bool hit = false;
            
            for(int i = 0; i < 200; ++i)
            {
                float3 p = ray.origin + ray.direction * t;
                float d = getDistance(p, modelTexture, mData, scale);//map(p, dataIn);

                if (abs(d) < (0.0001*t)) {
                    hit = true;
                    break;
                }
                
                t += d;

                if (t >= bbox.y)
                    break;
            }
            
            if (hit == true) {
                float3 position = ray.origin + ray.direction * t;
                float3 normal = getNormal(position, modelTexture, mData, scale);
                
                state.fhp = position;
                state.normal = normal;
                state.ffnormal = dot(normal, ray.direction) <= 0.0 ? normal : normal * -1.0;
                
                //radiance = float3(1);
                
            } else {
                t = INFINITY;
            }
        }
        
        if (t == INFINITY) {
            radiance += renderData.backgroundColor.xyz * throughput;
            return float4(radiance, 1.0);
        }
        
        Onb(state.normal, state.tangent, state.bitangent);
        
        // Get material
        
        float4 colorAndRoughness = getColorAndRoughness(state.fhp, colorTexture, scale);
        
        state.mat.albedo = colorAndRoughness.xyz;
        state.mat.specular = 0;
        state.mat.anisotropic = 0;
        state.mat.metallic = 0;
        state.mat.roughness = colorAndRoughness.w;
        state.mat.subsurface = 0;
        state.mat.specularTint = 0;
        state.mat.sheen = 0;
        state.mat.sheenTint = 0;
        state.mat.clearcoat = 0;
        state.mat.clearcoatGloss = 0;
        state.mat.specTrans = 0;
        state.mat.ior = 1.45;
        state.mat.emission = float3(0);
        state.mat.atDistance = 1.0;
        
        //state.isEmitter = false;
        state.eta = dot(state.normal, state.ffnormal) > 0.0 ? (1.0 / state.mat.ior) : state.mat.ior;

        // Reset absorption when ray is going out of surface
        if (dot(state.normal, state.ffnormal) > 0.0)
            absorption = float3(0.0);

        radiance += state.mat.emission * throughput;

//#ifdef LIGHTS
        if (state.isEmitter)
        {
            radiance += EmitterSample(ray, state, lightSampleRec, bsdfSampleRec) * throughput;
            break;
        }
//#endif
        
        // Add absoption
        throughput *= exp(-absorption * t);

        radiance += DirectLight(ray, state, dataIn, renderData, mData, modelTexture, scale) * throughput;

        bsdfSampleRec.f = DisneySample(state, -ray.direction, state.ffnormal, bsdfSampleRec.L, bsdfSampleRec.pdf, dataIn);

        // Set absorption only if the ray is currently inside the object.
        if (dot(state.ffnormal, bsdfSampleRec.L) < 0.0)
            absorption = -log(state.mat.extinction) / state.mat.atDistance;

        if (bsdfSampleRec.pdf > 0.0)
            throughput *= bsdfSampleRec.f * abs(dot(state.ffnormal, bsdfSampleRec.L)) / bsdfSampleRec.pdf;
        else
            break;

#ifdef RR
        // Russian roulette
        if (depth >= RR_DEPTH)
        {
            float q = min(max(throughput.x, max(throughput.y, throughput.z)) + 0.001, 0.95);
            if (rand() > q)
                break;
            throughput /= q;
        }
#endif

        ray.direction = bsdfSampleRec.L;
        ray.origin = state.fhp + ray.direction * EPS;
    }

    return float4(radiance, 1.0);
}

// MARK: Hit Scene Entry Point
kernel void modelerHitScene(constant ModelerHitUniform           &mData [[ buffer(0) ]],
                            texture3d<float>                     modelTexture [[ texture(1) ]],
                            device float4 *out                   [[ buffer(2) ]],
                            uint gid                             [[thread_position_in_grid]])
{
    float3 ro = mData.cameraOrigin;
    float3 rd = mData.cameraLookAt;
    
    struct DataIn dataIn;
    
    dataIn.seed = mData.uv;
    dataIn.randomVector = mData.randomVector;
    
    rd = getCamerayRay(mData.uv, ro, rd, 80, mData.size, dataIn);
    
    float scale = mData.scale;

    float r = 0.5 * scale;
    float2 bbox = hitBBox(ro, rd, float3(-r, -r, -r), float3(r, r, r));
    
    float4 result1 = float4(-1);
    float4 result2 = float4(-1);

    if (bbox.y > 0.0) {

        // Raymarch into the texture
        bool hit = false;
        
        float t = bbox.x;
        for(int i = 0; i < 120; ++i)
        {
            float3 p = ro + rd * t;
            float d = getDistance(p, modelTexture, scale);

            if (abs(d) < (0.0001*t)) {
                hit = true;
                break;
            }
            
            t += d;

            if (t >= bbox.y)
                break;
        }
        
        if (hit == true) {
            result1.x = t;
            float3 p = ro + rd * t;
            result1.yzw = getNormal(p, modelTexture, scale);
            result2.xyz = p / 3.0;
        }
    }
    
    out[gid] = float4(result1);
    out[gid+1] = float4(result2);
}

// MARK: Accumulation Entry Point
kernel void modelerAccum(constant AccumUniform                      &uniform [[ buffer(0) ]],
                         texture2d<float>                           sampleTexture [[texture(1)]],
                         texture2d<float, access::read_write>       finalTexture [[texture(2)]],
                         uint2 gid                                  [[thread_position_in_grid]])
{
    float4 sample = sampleTexture.read(gid);
    float4 final = finalTexture.read(gid);

    sample.xyz = pow(sample.xyz, 1.0 / 2.2);
    //sample = clamp(sample, 0, 1);

    float k = float(uniform.samples + 1);
    final = final * (1.0 - 1.0/k) + sample * (1.0/k);

    finalTexture.write(final, gid);
}

