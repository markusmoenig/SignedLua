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
    
    var icon            : CGImage? = nil

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
                e.subData!.set(key, value)
            }
        }
        
        func setFloat(_ key: String,_ value: Float,_ r: float2 = float2(0,1)) {
            data.set(key, value, r, .Slider, .ProceduralMixer)
            if let e = data.getEntity(key) {
                e.subData = SignedData([])
                e.subData!.set("MixerType", Int(0))
                e.subData!.set(key, value, r)
            }
        }
        
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
        setColor("Emission", emission)
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
        materialMixer.specularMixer = Int32(data.getEntity("Specular")!.subData!.getInt("MixerType"))
        materialMixer.anisotropicMixer = Int32(data.getEntity("Anisotropic")!.subData!.getInt("MixerType"))
        materialMixer.metallicMixer = Int32(data.getEntity("Metallic")!.subData!.getInt("MixerType"))
        materialMixer.roughnessMixer = Int32(data.getEntity("Roughness")!.subData!.getInt("MixerType"))
        materialMixer.subsurfaceMixer = Int32(data.getEntity("Subsurface")!.subData!.getInt("MixerType"))
        materialMixer.specularTintMixer = Int32(data.getEntity("Specular Tint")!.subData!.getInt("MixerType"))
        materialMixer.sheenMixer = Int32(data.getEntity("Sheen")!.subData!.getInt("MixerType"))
        materialMixer.sheenTintMixer = Int32(data.getEntity("Sheen Tint")!.subData!.getInt("MixerType"))
        materialMixer.clearcoatMixer = Int32(data.getEntity("Clearcoat")!.subData!.getInt("MixerType"))
        materialMixer.clearcoatGlossMixer = Int32(data.getEntity("Clearcoat Gloss")!.subData!.getInt("MixerType"))
        materialMixer.specTransMixer = Int32(data.getEntity("Transmission")!.subData!.getInt("MixerType"))
        materialMixer.iorMixer = Int32(data.getEntity("IOR")!.subData!.getInt("MixerType"))
        materialMixer.emissionMixer = Int32(data.getEntity("Emission")!.subData!.getInt("MixerType"))

        return materialMixer
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

