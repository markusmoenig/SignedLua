//
//  SignedMaterial.swift
//  Signed
//
//  Created by Markus Moenig on 3/7/21.
//

import Foundation

class SignedMaterial: Codable {
    
    enum ProceduralMixer: Int, Codable {
        case None, ValueNoise
    }
    
    var data            : SignedData
    
    private enum CodingKeys: String, CodingKey {
        case data
    }
    
    init(albedo: float3 = float3(0.5, 0.5, 0.5), specular: Float = 0.5, anisotropic: Float = 0, metallic: Float = 0, roughness: Float = 0.5, subsurface: Float = 0, specularTint: Float = 0, sheen: Float = 0, sheenTint: Float = 0.5, clearcoat: Float = 0, clearcoatGloss: Float = 0, specTrans: Float = 0, ior: Float = 1.45, emission: float3 = float3(0,0,0)) {
        
        data = SignedData([])
        
        func setColor(_ key: String,_ value: float3) {
            data.set(key, value, float2(0,1), .Color, .ProceduralMixer)
            if let e = data.getEntity(key) {
                e.subData = SignedData([])
                e.subData!.set("MixerType", Int(0))
                e.subData!.set(key, float3(0,0,0), float2(0,1), .Color)
                e.subData!.set("Scale", Float(1), float2(0.001, 5))
                e.subData!.set("Smoothing", Int(1), float2(1, 8), .Slider)
            }
        }
        
        func setFloat3(_ key: String,_ value: float3) {
            data.set(key, value, float2(0,1), .Numeric, .ProceduralMixer)
            if let e = data.getEntity(key) {
                e.subData = SignedData([])
                e.subData!.set("MixerType", Int(0))
                e.subData!.set(key, float3(0,0,0), float2(0,1), .Numeric)
                e.subData!.set("Scale", Float(1), float2(0.001, 5))
                e.subData!.set("Smoothing", Int(1), float2(1, 8), .Slider)
            }
        }
        
        func setFloat(_ key: String,_ value: Float,_ r: float2 = float2(0,1)) {
            data.set(key, value, r, .Slider, .ProceduralMixer)
            if let e = data.getEntity(key) {
                e.subData = SignedData([])
                e.subData!.set("MixerType", Int(0))
                e.subData!.set("Scale", Float(1), float2(0.001, 5))
                e.subData!.set("Smoothing", Int(1), float2(1, 8), .Slider)
                e.subData!.set(key, value, r)
            }
        }
        
        data.set("Name", "Material", .TextField, .MaterialLibrary)
        setColor("Color", albedo)
        setFloat("Metallic", metallic)
        setFloat("Roughness", roughness)
        setFloat("Subsurface", subsurface)
        setFloat("Anisotropic", anisotropic)
        setFloat("Specular", specular)
        setFloat("Specular Tint", specularTint)
        setFloat("Sheen", sheen)
        setFloat("Sheen Tint", sheenTint)
        setFloat("Clearcoat", clearcoat)
        setFloat("Clearcoat Gloss", clearcoatGloss)
        setFloat("Transmission", specTrans)
        setFloat("IOR", ior, float2(0, 2))
        setFloat3("Emission", emission)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(SignedData.self, forKey: .data)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
    }
    
    func toMaterialStruct() -> Material {
        var material = Material()
        
        material.albedo = data.getFloat3("Color")
        material.specular = data.getFloat("Specular")
        material.anisotropic = data.getFloat("Anisotropic")
        material.metallic = data.getFloat("Metallic")
        material.roughness = data.getFloat("Roughness")
        material.subsurface = data.getFloat("Subsurface")
        material.specularTint = data.getFloat("Specular Tint")
        material.sheen = data.getFloat("Sheen")
        material.sheenTint = data.getFloat("Sheen Tint")
        material.clearcoat = data.getFloat("Clearcoat")
        material.clearcoatGloss = data.getFloat("Clearcoat Gloss")
        material.specTrans = data.getFloat("Transmission")
        material.ior = data.getFloat("IOR")
        material.emission = data.getFloat3("Emission")

        material.atDistance = 1.0

        return material
    }
    
    func toMixMaterialStruct() -> Material {
        var material = Material()
        
        material.albedo = data.getEntity("Color")!.subData!.getFloat3("Color")
        material.specular = data.getEntity("Specular")!.subData!.getFloat("Specular")
        material.anisotropic = data.getEntity("Anisotropic")!.subData!.getFloat("Anisotropic")
        material.metallic = data.getEntity("Metallic")!.subData!.getFloat("Metallic")
        material.roughness = data.getEntity("Roughness")!.subData!.getFloat("Roughness")
        material.subsurface = data.getEntity("Subsurface")!.subData!.getFloat("Subsurface")
        material.specularTint = data.getEntity("Specular Tint")!.subData!.getFloat("Specular Tint")
        material.sheen = data.getEntity("Sheen")!.subData!.getFloat("Sheen")
        material.sheenTint = data.getEntity("Sheen Tint")!.subData!.getFloat("Sheen Tint")
        material.clearcoat = data.getEntity("Clearcoat")!.subData!.getFloat("Clearcoat")
        material.clearcoatGloss = data.getEntity("Clearcoat Gloss")!.subData!.getFloat("Clearcoat Gloss")
        material.specTrans = data.getEntity("Transmission")!.subData!.getFloat("Transmission")
        material.ior = data.getEntity("IOR")!.subData!.getFloat("IOR")
        material.emission = data.getEntity("Emission")!.subData!.getFloat3("Emission")

        material.atDistance = 1.0

        return material
    }
    
    func toMaterialMixerStruct() -> MaterialMixer {
        var materialMixer = MaterialMixer()
        
        materialMixer.albedoMixer = Int32(data.getEntity("Color")!.subData!.getInt("MixerType"))
        materialMixer.albedoMixerScale = data.getEntity("Color")!.subData!.getFloat("Scale", 1)
        materialMixer.albedoMixerSmoothing = Int32(data.getEntity("Color")!.subData!.getInt("Smoothing", 1))

        materialMixer.specularMixer = Int32(data.getEntity("Specular")!.subData!.getInt("MixerType"))
        materialMixer.specularMixerScale = data.getEntity("Specular")!.subData!.getFloat("Scale", 1)
        materialMixer.specularMixerSmoothing = Int32(data.getEntity("Specular")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.anisotropicMixer = Int32(data.getEntity("Anisotropic")!.subData!.getInt("MixerType"))
        materialMixer.anisotropicMixerScale = data.getEntity("Anisotropic")!.subData!.getFloat("Scale", 1)
        materialMixer.anisotropicMixerSmoothing = Int32(data.getEntity("Anisotropic")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.metallicMixer = Int32(data.getEntity("Metallic")!.subData!.getInt("MixerType"))
        materialMixer.metallicMixerScale = data.getEntity("Metallic")!.subData!.getFloat("Scale", 1)
        materialMixer.metallicMixerSmoothing = Int32(data.getEntity("Metallic")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.roughnessMixer = Int32(data.getEntity("Roughness")!.subData!.getInt("MixerType"))
        materialMixer.roughnessMixerScale = data.getEntity("Roughness")!.subData!.getFloat("Scale", 1)
        materialMixer.roughnessMixerSmoothing = Int32(data.getEntity("Roughness")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.subsurfaceMixer = Int32(data.getEntity("Subsurface")!.subData!.getInt("MixerType"))
        materialMixer.subsurfaceMixerScale = data.getEntity("Subsurface")!.subData!.getFloat("Scale", 1)
        materialMixer.subsurfaceMixerSmoothing = Int32(data.getEntity("Subsurface")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.specularTintMixer = Int32(data.getEntity("Specular Tint")!.subData!.getInt("MixerType"))
        materialMixer.specularTintMixerScale = data.getEntity("Specular Tint")!.subData!.getFloat("Scale", 1)
        materialMixer.specularTintMixerSmoothing = Int32(data.getEntity("Specular Tint")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.sheenMixer = Int32(data.getEntity("Sheen")!.subData!.getInt("MixerType"))
        materialMixer.sheenMixerScale = data.getEntity("Sheen")!.subData!.getFloat("Scale", 1)
        materialMixer.sheenMixerSmoothing = Int32(data.getEntity("Sheen")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.sheenTintMixer = Int32(data.getEntity("Sheen Tint")!.subData!.getInt("MixerType"))
        materialMixer.sheenTintMixerScale = data.getEntity("Sheen Tint")!.subData!.getFloat("Scale", 1)
        materialMixer.sheenTintMixerSmoothing = Int32(data.getEntity("Sheen Tint")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.clearcoatMixer = Int32(data.getEntity("Clearcoat")!.subData!.getInt("MixerType"))
        materialMixer.clearcoatMixerScale = data.getEntity("Clearcoat")!.subData!.getFloat("Scale", 1)
        materialMixer.clearcoatMixerSmoothing = Int32(data.getEntity("Clearcoat")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.clearcoatGlossMixer = Int32(data.getEntity("Clearcoat Gloss")!.subData!.getInt("MixerType"))
        materialMixer.clearcoatGlossMixerScale = data.getEntity("Clearcoat Gloss")!.subData!.getFloat("Scale", 1)
        materialMixer.clearcoatGlossMixerSmoothing = Int32(data.getEntity("Clearcoat Gloss")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.specTransMixer = Int32(data.getEntity("Transmission")!.subData!.getInt("MixerType"))
        materialMixer.specTransMixerScale = data.getEntity("Transmission")!.subData!.getFloat("Scale", 1)
        materialMixer.specTransMixerSmoothing = Int32(data.getEntity("Transmission")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.iorMixer = Int32(data.getEntity("IOR")!.subData!.getInt("MixerType"))
        materialMixer.iorMixerScale = data.getEntity("IOR")!.subData!.getFloat("Scale", 1)
        materialMixer.iorMixerSmoothing = Int32(data.getEntity("IOR")!.subData!.getInt("Smoothing", 1))
        
        materialMixer.emissionMixer = Int32(data.getEntity("Emission")!.subData!.getInt("MixerType"))
        materialMixer.emissionMixerScale = data.getEntity("Emission")!.subData!.getFloat("Scale", 1)
        materialMixer.emissionMixerSmoothing = Int32(data.getEntity("Emission")!.subData!.getInt("Smoothing", 1))
        
        return materialMixer
    }
    
    /// Creates a copy of itself
    func copy() -> SignedMaterial?
    {
        if let data = try? JSONEncoder().encode(self) {
            if let copied = try? JSONDecoder().decode(SignedMaterial.self, from: data) {
                return copied
            }
        }
        return nil
    }
    
    /// Copies itself to Data
    func toData() -> Data
    {
        if let data = try? JSONEncoder().encode(self) {
            return data
        }
        return Data()
    }
}

