//
//  SignedMaterial.swift
//  Signed
//
//  Created by Markus Moenig on 3/7/21.
//

import Foundation

class SignedMaterial: Codable {
    
    enum MaterialMixer: Int, Codable {
        case None, ValueNoise
    }
    
    var data            : SignedData
    var mixData         : SignedData
    
    var icon            : CGImage? = nil

    private enum CodingKeys: String, CodingKey {
        case data
        case mixData
    }
    
    init(albedo: float3 = float3(0.5, 0.5, 0.5), specular: Float = 0.5, anisotropic: Float = 0, metallic: Float = 0, roughness: Float = 0.5, subsurface: Float = 0, specularTint: Float = 0, sheen: Float = 0, sheenTint: Float = 0.5, clearcoat: Float = 0, clearcoatGloss: Float = 0, specTrans: Float = 0, ior: Float = 1.45, emission: float3 = float3(0,0,0)) {
        
        data = SignedData([])
        mixData = SignedData([])
        
        func initMaterialData(_ data: SignedData, mixer: Bool = false) {
            data.set("Color", albedo, float2(0,1), .Color)
            data.set("Specular", specular)
            data.set("Anisotropic", anisotropic)
            data.set("Metallic", metallic)
            data.set("Roughness", roughness)
            data.set("Subsurface", subsurface)
            data.set("SpecularTint", specularTint)
            data.set("Sheen", sheen)
            data.set("SheenTint", sheenTint)
            data.set("Clearcoat", clearcoat)
            data.set("Clearcoat Gloss", clearcoatGloss)
            data.set("Transmission", specTrans)
            data.set("IOR", ior, float2(0, 2))
            data.set("Emission", emission)
            
            if mixer {
                data.set("Color Mixer", Float(0))
                data.set("Specular Mixer", Float(0))
                data.set("Anisotropic Mixer", Float(0))
                data.set("Metallic Mixer", Float(0))
                data.set("Roughness Mixer", Float(0))
                data.set("Subsurface Mixer", Float(0))
                data.set("SpecularTint Mixer", Float(0))
                data.set("Sheen Mixer", Float(0))
                data.set("SheenTint Mixer", Float(0))
                data.set("Clearcoat Mixer", Float(0))
                data.set("Clearcoat Gloss Mixer", Float(0))
                data.set("Transmission Mixer", Float(0))
                data.set("IOR Mixer", Float(0))
                data.set("Emission Mixer", Float(0))
            }
        }
        
        initMaterialData(data)
        initMaterialData(mixData, mixer: true)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(SignedData.self, forKey: .data)
        mixData = try container.decode(SignedData.self, forKey: .mixData)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(mixData, forKey: .mixData)
    }
    
    func toMaterialStruct() -> Material {
        var material = Material()
        
        material.albedo = data.getFloat3("Color")
        material.specular = data.getFloat("Specular")
        material.anisotropic = data.getFloat("Anisotropic")
        material.metallic = data.getFloat("Metallic")
        material.roughness = data.getFloat("Roughness")
        material.subsurface = data.getFloat("Subsurface")
        material.specularTint = data.getFloat("SpecularTint")
        material.sheen = data.getFloat("Sheen")
        material.sheenTint = data.getFloat("SheenTint")
        material.clearcoat = data.getFloat("Clearcoat")
        material.clearcoatGloss = data.getFloat("Clearcoat Gloss")
        material.specTrans = data.getFloat("Transmission")
        material.ior = data.getFloat("IOR")
        material.emission = data.getFloat3("Emission")

        material.atDistance = 1.0

        return material
    }
    
    /// Copies itself to JSON
    func toJSON() -> String
    {
        if let data = try? JSONEncoder().encode(self) {
            return String(decoding: data, as: UTF8.self)
        }
        return ""
    }
}

