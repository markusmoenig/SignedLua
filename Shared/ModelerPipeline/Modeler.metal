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

float valueNoise(float3 x) {
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

float valueNoiseFBM(float3 x, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float3 shift = float3(100);
    for (int i = 0; i < octaves; ++i) {
        v += a * valueNoise(x);
        x = x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

Material mixMaterials(Material materialA, Material materialB, float k)
{
    Material material;

    material.albedo = mix(materialA.albedo, materialB.albedo, k);
    material.specular = mix(materialA.specular, materialB.specular, k);

    material.emission = mix(materialA.emission, materialB.emission, k);
    material.anisotropic = mix(materialA.anisotropic, materialB.anisotropic, k);

    material.metallic = mix(materialA.metallic, materialB.metallic, k);
    material.roughness = mix(materialA.roughness, materialB.roughness, k);
    material.subsurface = mix(materialA.subsurface, materialB.subsurface, k);
    material.specularTint = mix(materialA.specularTint, materialB.specularTint, k);

    material.sheen = mix(materialA.sheen, materialB.sheen, k);
    material.sheenTint = mix(materialA.sheenTint, materialB.sheenTint, k);
    material.clearcoat = mix(materialA.clearcoat, materialB.clearcoat, k);
    material.clearcoatGloss = mix(materialA.clearcoatGloss, materialB.clearcoatGloss, k);

    material.specTrans = mix(materialA.specTrans, materialB.specTrans, k);
    material.ior = mix(materialA.ior, materialB.ior, k);
    material.extinction = mix(materialA.extinction, materialB.extinction, k);

    return material;
}

float degrees(float radians)
{
    return radians * 180.0 / M_PI_F;
}

float radians(float degrees)
{
    return degrees * M_PI_F / 180.0;
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

float2 rotate(float2 pos, float angle)
{
    float ca = cos(angle), sa = sin(angle);
    return pos * float2x2(ca, sa, -sa, ca);
}

float2 rotatePivot(float2 pos, float angle, float2 pivot)
{
    float ca = cos(angle), sa = sin(angle);
    return pivot + (pos-pivot) * float2x2(ca, sa, -sa, ca);
}

// generates a random radious at (integer) position p
float rad(float3 p)
{
    p  = 17.0*fract( p*0.3183099+float3(.11,.17,.13) );
    float r = fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
    return 0.7*r*r;
}

// https://www.shadertoy.com/view/Ws3XWl
float noiseSDF(float3 p, float level)
{
    float3 i = floor(p);
    float3 f = fract(p);
    #define SPH(i,f,c) length(f-c) - rad(i+c) * level
    return min(min(min(SPH(i,f,float3(0,0,0)),
                       SPH(i,f,float3(0,0,1))),
                   min(SPH(i,f,float3(0,1,0)),
                       SPH(i,f,float3(0,1,1)))),
               min(min(SPH(i,f,float3(1,0,0)),
                       SPH(i,f,float3(1,0,1))),
                   min(SPH(i,f,float3(1,1,0)),
                       SPH(i,f,float3(1,1,1)))));
}

// http://iquilezles.org/www/articles/smin/smin.htm
float smin( float a, float b, float k )
{
    float h = max(k-abs(a-b),0.0);
    return min(a, b) - h*h*0.25/k;
}

// http://iquilezles.org/www/articles/smin/smin.htm
float smax( float a, float b, float k )
{
    float h = max(k-abs(a-b),0.0);
    return max(a, b) + h*h*0.25/k;
}

float opSmoothUnion( float d1, float d2, float k, thread float &mixOut) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    mixOut = h;
    return mix( d2, d1, h ) - k*h*(1.0-h); }

float opSmoothSubtraction( float d1, float d2, float k, thread float &mixOut) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    mixOut = h;
    return mix( d2, -d1, h ) + k*h*(1.0-h); }

float opSmoothIntersection( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h); }

/// Computes the given distance for the given modeler cmd
float applyModelerData(float3 uv, float dist, constant ModelerUniform &mData, float scale, thread float &materialMixValue)
{    
    if (mData.actionType == Modeler_None) {
        materialMixValue = 1;
        return dist;
    }
    
    float newDist = INFINITY;

    /*
    float3 transformedPosition = (position - objectPosition) / objectScale * \(scale.toMetal());
    
    transformedPosition = translate(transformedPosition, \(position.toMetal()));
    float3 offsetFromCenter = objectPosition - \(position.toMetal());

    float3 rotation = objectRotation + \(rotation.toMetal());

    transformedPosition.yz = rotatePivot(transformedPosition.yz, radians(rotation.x), offsetFromCenter.yz );
    transformedPosition.xz = rotatePivot(transformedPosition.xz, radians(rotation.y), offsetFromCenter.xz );
    transformedPosition.xy = rotatePivot(transformedPosition.xy, radians(rotation.z), offsetFromCenter.xy );*/

    float3 position = mData.position * scale + mData.normal * mData.surfaceDistance * scale;
    
    float3 p = uv - position;
    
    p.yz = rotate(p.yz, radians(mData.rotation.x));
    p.xz = rotate(p.xz, radians(mData.rotation.y));
    p.xy = rotate(p.xy, radians(mData.rotation.z));
    
    if (mData.primitiveType == Modeler_Sphere) {
        newDist = sdSphere(p, mData.radius * scale / Modeler_Global_Scale);
    } else
    if (mData.primitiveType == Modeler_Box) {
        newDist = sdRoundBox(p, mData.size * scale / Modeler_Global_Scale, mData.rounding);
    }
    
    // Noise

    if (mData.noise > 0) {
        const float3x3 m = float3x3( 0.00,  1.60,  1.20,
                            -1.60,  0.72, -0.96,
                            -1.20, -0.96,  1.28 );

        newDist /= scale;
        float3  q = p / scale;
        
        float level = mData.noise;
        float t = 0.0;
        float s = 1;
        const int ioct = 11;
        for( int i=0; i<ioct; i++)
        {
            float n = noiseSDF(q, 1) * s * level;
            n = smax(n, newDist -0.1 * s * level, 0.3 * s * level);
            newDist = smin(n,newDist,0.3 * s * level);

            t += newDist;
            q = m * q;
            q.z += -1.8 * t * s * level;
            s = 0.415 * s;
        }
        
        /*
        // fbm
        float t = 0.0;
        float s = 1.0;
        for( int i=0; i<6; i++ )
        {
            newDist = smax( newDist, -noiseSDF(p)*s, 0.2*s );
            t += newDist;
            p = 2.01*m*p; // next octave
            s = 0.50*s;
        }
        */
        
        newDist *= scale;
    }
    
    float rc = INFINITY;
        
    if (mData.actionType == Modeler_Subtract) {
        rc = opSmoothSubtraction(newDist, dist, mData.smoothing * scale, materialMixValue);//max(dist, -newDist);
    } else {
        rc = opSmoothUnion(dist, newDist, mData.smoothing * scale, materialMixValue);//min(dist, newDist);
    }
    
    return rc;
}

/// Computes the given distance for the given modeler cmd
void computeModelerMaterial(float3 uv, constant ModelerUniform &mData, float scale, thread Material &material)
{
    material = mData.material;
    if (mData.mixer.albedoMixer != 0) {
        if (mData.mixer.albedoMixer == 1) {
            material.albedo = mix(material.albedo, mData.mixMaterial.albedo, valueNoiseFBM(uv * 100.0 * mData.mixer.albedoMixerScale / scale, mData.mixer.albedoMixerSmoothing));
        }
    }
    
    if (mData.mixer.specularMixer != 0) {
        if (mData.mixer.specularMixer == 1) {
            material.specular = mix(material.specular, mData.mixMaterial.specular, valueNoiseFBM(uv * 100.0 * mData.mixer.specularMixerScale / scale, mData.mixer.specularMixerSmoothing));
        }
    }
    
    if (mData.mixer.specularTintMixer != 0) {
        if (mData.mixer.specularTintMixer == 1) {
            material.specularTint = mix(material.specularTint, mData.mixMaterial.specularTint, valueNoiseFBM(uv * 100.0 * mData.mixer.specularTintMixerScale / scale, mData.mixer.specularTintMixerSmoothing));
        }
    }
    
    if (mData.mixer.anisotropicMixer != 0) {
        if (mData.mixer.anisotropicMixer == 1) {
            material.anisotropic = mix(material.anisotropic, mData.mixMaterial.anisotropic, valueNoiseFBM(uv * 100.0 * mData.mixer.anisotropicMixerScale / scale, mData.mixer.anisotropicMixerSmoothing));
        }
    }
    
    if (mData.mixer.metallicMixer != 0) {
        if (mData.mixer.metallicMixer == 1) {
            material.metallic = mix(material.metallic, mData.mixMaterial.metallic, valueNoiseFBM(uv * 100.0 * mData.mixer.metallicMixerScale / scale, mData.mixer.metallicMixerSmoothing));
        }
    }
    
    if (mData.mixer.roughnessMixer != 0) {
        if (mData.mixer.roughnessMixer == 1) {
            material.roughness = mix(material.roughness, mData.mixMaterial.roughness, valueNoiseFBM(uv * 100.0 * mData.mixer.roughnessMixerScale / scale, mData.mixer.roughnessMixerSmoothing));
        }
    }
    
    if (mData.mixer.subsurfaceMixer != 0) {
        if (mData.mixer.subsurfaceMixer == 1) {
            material.subsurface = mix(material.subsurface, mData.mixMaterial.subsurface, valueNoiseFBM(uv * 100.0 * mData.mixer.subsurfaceMixerScale / scale, mData.mixer.subsurfaceMixerSmoothing));
        }
    }
 
    if (mData.mixer.sheenMixer != 0) {
        if (mData.mixer.sheenMixer == 1) {
            material.sheen = mix(material.sheen, mData.mixMaterial.sheen, valueNoiseFBM(uv * 100.0 * mData.mixer.sheenMixerScale / scale, mData.mixer.sheenMixerSmoothing));
        }
    }
    
    if (mData.mixer.sheenTintMixer != 0) {
        if (mData.mixer.sheenTintMixer == 1) {
            material.sheenTint = mix(material.sheenTint, mData.mixMaterial.sheenTint, valueNoiseFBM(uv * 100.0 * mData.mixer.sheenTintMixerScale / scale, mData.mixer.sheenTintMixerSmoothing));
        }
    }
    
    if (mData.mixer.clearcoatMixer != 0) {
        if (mData.mixer.clearcoatMixer == 1) {
            material.clearcoat = mix(material.clearcoat, mData.mixMaterial.clearcoat, valueNoiseFBM(uv * 100.0 * mData.mixer.clearcoatMixerScale / scale, mData.mixer.clearcoatMixerSmoothing));
        }
    }
    
    if (mData.mixer.clearcoatGlossMixer != 0) {
        if (mData.mixer.clearcoatGlossMixer == 1) {
            material.clearcoatGloss = mix(material.clearcoatGloss, mData.mixMaterial.clearcoatGloss, valueNoiseFBM(uv * 100.0 * mData.mixer.clearcoatGlossMixerScale / scale, mData.mixer.clearcoatGlossMixerSmoothing));
        }
    }
    
    if (mData.mixer.specTransMixer != 0) {
        if (mData.mixer.specTransMixer == 1) {
            material.specTrans = mix(material.specTrans, mData.mixMaterial.specTrans, valueNoiseFBM(uv * 100.0 * mData.mixer.specTransMixerScale / scale, mData.mixer.specTransMixerSmoothing));
        }
    }
    
    if (mData.mixer.iorMixer != 0) {
        if (mData.mixer.iorMixer == 1) {
            material.ior = mix(material.ior, mData.mixMaterial.ior, valueNoiseFBM(uv * 100.0 * mData.mixer.iorMixerScale / scale, mData.mixer.iorMixerSmoothing));
        }
    }
    
    if (mData.mixer.emissionMixer != 0) {
        if (mData.mixer.emissionMixer == 1) {
            material.emission = mix(material.emission, mData.mixMaterial.emission, valueNoiseFBM(uv * 100.0 * mData.mixer.emissionMixerScale / scale, mData.mixer.emissionMixerSmoothing));
        }
    }
}

/// Executes one modeler command
kernel void modelerCmd(constant ModelerUniform                  &mData [[ buffer(0) ]],
                       texture3d<half, access::read_write>      modelTexture  [[texture(1)]],
                       texture3d<half, access::read_write>      colorTexture  [[texture(2)]],
                       texture3d<half, access::read_write>      materialTexture1  [[texture(3)]],
                       texture3d<half, access::read_write>      materialTexture2  [[texture(4)]],
                       texture3d<half, access::read_write>      materialTexture3  [[texture(5)]],
                       texture3d<half, access::read_write>      materialTexture4  [[texture(6)]],
                       uint3 gid                                [[thread_position_in_grid]])
{
    float3 size = float3(modelTexture.get_width(), modelTexture.get_height(), modelTexture.get_depth());
    float3 uv = float3(gid) / size - float3(0.5);

    float materialMixValue;
    
    float dist = modelTexture.read(gid).x;
    float newDist = applyModelerData(uv, dist, mData, 1.0, materialMixValue);
        
    if (mData.roleType == Modeler_GeometryAndMaterial) {
        // Geometry & Material
        
        if (dist != newDist && newDist < 0.001) {//}&& dist > 0) {
            
            float4 colorAndRoughness = float4(colorTexture.read(gid));
            float4 specularMetallicSubsurfaceClearcoat = float4(materialTexture1.read(gid));
            float4 anisotropicSpecularTintSheenSheenTint = float4(materialTexture2.read(gid));
            float4 clearcoatGlossSpecTransIor = float4(materialTexture3.read(gid));
            float3 emission = float4(materialTexture4.read(gid)).xyz;
            
            Material mat;
            
            mat.albedo = colorAndRoughness.xyz;
            mat.specular = specularMetallicSubsurfaceClearcoat.x;
            mat.anisotropic = anisotropicSpecularTintSheenSheenTint.x;
            mat.metallic = specularMetallicSubsurfaceClearcoat.y;
            mat.roughness = max(colorAndRoughness.w, 0.001);
            mat.subsurface = specularMetallicSubsurfaceClearcoat.z;
            mat.specularTint = anisotropicSpecularTintSheenSheenTint.y;
            mat.sheen = anisotropicSpecularTintSheenSheenTint.z;
            mat.sheenTint = anisotropicSpecularTintSheenSheenTint.w;
            mat.clearcoat = specularMetallicSubsurfaceClearcoat.w;
            mat.clearcoatGloss = clearcoatGlossSpecTransIor.x;
            mat.specTrans = clearcoatGlossSpecTransIor.y;
            mat.ior = clearcoatGlossSpecTransIor.z;
            mat.emission = emission;
            mat.atDistance = 1.0;
            
            Material material;
            computeModelerMaterial(uv, mData, 1.0, material);
            
            Material outMaterial = mixMaterials(mat, material, smoothstep(0.0, 1.0, 1.0 - materialMixValue));
            
            colorTexture.write(half4(float4(outMaterial.albedo, outMaterial.roughness)), gid);
            materialTexture1.write(half4(float4(outMaterial.specular, outMaterial.metallic, outMaterial.subsurface, outMaterial.clearcoat)), gid);
            materialTexture2.write(half4(float4(outMaterial.anisotropic, outMaterial.specularTint, outMaterial.sheen, outMaterial.sheenTint)), gid);
            materialTexture3.write(half4(float4(outMaterial.clearcoatGloss, outMaterial.specTrans, outMaterial.ior, 0)), gid);
            materialTexture4.write(half4(float4(outMaterial.emission, mData.id)), gid);
        }
    } else
    if (mData.roleType == Modeler_MaterialOnly) {
        // Material only on the given geometry id
        float4 emissionId = float4(materialTexture4.read(gid));

        if (emissionId.w == mData.id) {
            
            float4 colorAndRoughness = float4(colorTexture.read(gid));
            float4 specularMetallicSubsurfaceClearcoat = float4(materialTexture1.read(gid));
            float4 anisotropicSpecularTintSheenSheenTint = float4(materialTexture2.read(gid));
            float4 clearcoatGlossSpecTransIor = float4(materialTexture3.read(gid));
            
            Material mat;
            
            mat.albedo = colorAndRoughness.xyz;
            mat.specular = specularMetallicSubsurfaceClearcoat.x;
            mat.anisotropic = anisotropicSpecularTintSheenSheenTint.x;
            mat.metallic = specularMetallicSubsurfaceClearcoat.y;
            mat.roughness = max(colorAndRoughness.w, 0.001);
            mat.subsurface = specularMetallicSubsurfaceClearcoat.z;
            mat.specularTint = anisotropicSpecularTintSheenSheenTint.y;
            mat.sheen = anisotropicSpecularTintSheenSheenTint.z;
            mat.sheenTint = anisotropicSpecularTintSheenSheenTint.w;
            mat.clearcoat = specularMetallicSubsurfaceClearcoat.w;
            mat.clearcoatGloss = clearcoatGlossSpecTransIor.x;
            mat.specTrans = clearcoatGlossSpecTransIor.y;
            mat.ior = clearcoatGlossSpecTransIor.z;
            mat.emission = emissionId.xyz;
            mat.atDistance = 1.0;
            
            Material material;
            computeModelerMaterial(uv, mData, 1.0, material);
            
            Material outMaterial = mixMaterials(mat, material, smoothstep(0.0, 1.0, mData.materialOnlyMixerValue));
            
            colorTexture.write(half4(float4(outMaterial.albedo, outMaterial.roughness)), gid);
            materialTexture1.write(half4(float4(outMaterial.specular, outMaterial.metallic, outMaterial.subsurface, outMaterial.clearcoat)), gid);
            materialTexture2.write(half4(float4(outMaterial.anisotropic, outMaterial.specularTint, outMaterial.sheen, outMaterial.sheenTint)), gid);
            materialTexture3.write(half4(float4(outMaterial.clearcoatGloss, outMaterial.specTrans, outMaterial.ior, 0)), gid);
            materialTexture4.write(half4(float4(outMaterial.emission, mData.id)), gid);
        }
    }
    
    modelTexture.write(half4(newDist), gid);
}

/// Clears the texture
kernel void modelerClear(texture3d<half, access::write>    modelTexture  [[texture(0)]],
                         texture3d<half, access::write>    colorTexture  [[texture(1)]],
                         texture3d<half, access::write>    materialTexture1  [[texture(2)]],
                         texture3d<half, access::write>    materialTexture2  [[texture(3)]],
                         texture3d<half, access::write>    materialTexture3  [[texture(4)]],
                         texture3d<half, access::write>    materialTexture4  [[texture(5)]],
                         uint3 gid                         [[thread_position_in_grid]])
{
    modelTexture.write(half4(2), gid);
    colorTexture.write(half4(0.5), gid);
    materialTexture1.write(half4(0), gid);
    materialTexture2.write(half4(0), gid);
    materialTexture3.write(half4(0), gid);
    materialTexture4.write(half4(0, 0, 0, 255), gid);
}

/// Converts the image to the color space required to create an CGIImage
kernel void modelerMakeCGIImage(texture2d<half, access::write>          outTexture  [[texture(0)]],
                                texture2d<half, access::read>           inTexture [[texture(1)]],
                                uint2 gid                               [[thread_position_in_grid]])
{
    half4 color = inTexture.read(gid).zyxw;
    color.xyz = pow(color.xyz, 2.2);
    outTexture.write(color, gid);
}
