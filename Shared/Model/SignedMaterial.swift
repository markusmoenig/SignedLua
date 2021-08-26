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
    var libraryData     : SignedData

    private enum CodingKeys: String, CodingKey {
        case data
        case libraryData
    }
    
    init(albedo: float3 = float3(0.5, 0.5, 0.5), specular: Float = 0.0, anisotropic: Float = 0, metallic: Float = 0, roughness: Float = 0.5, subsurface: Float = 0, specularTint: Float = 0, sheen: Float = 0, sheenTint: Float = 0.0, clearcoat: Float = 0, clearcoatGloss: Float = 0, specTrans: Float = 0, ior: Float = 1.45, emission: float3 = float3(0,0,0)) {
        
        data = SignedData([])
        libraryData = SignedData([])

        func setColor(_ key: String,_ value: float3) {
            data.set(key, value, float2(0,1), .Color, .ProceduralMixer)
            if let e = data.getEntity(key) {
                e.subData = SignedData([])
                e.subData!.set("MixerType", Int(0))
                e.subData!.set("Scale", Float(1), float2(0.001, 5))
                e.subData!.set("Smoothing", Int(1), float2(1, 8), .Slider)
            }
        }
        
        func setFloat3(_ key: String,_ value: float3) {
            data.set(key, value, float2(0,1), .Numeric, .ProceduralMixer)
            if let e = data.getEntity(key) {
                e.subData = SignedData([])
                e.subData!.set("MixerType", Int(0))
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
        setFloat3("Emission", emission)
        libraryData.set("Name", "Material", .TextField, .MaterialLibrary)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(SignedData.self, forKey: .data)
        
        if let libraryData = try container.decodeIfPresent(SignedData.self, forKey: .libraryData) {
            self.libraryData = libraryData
        } else {
            libraryData = SignedData([])
            libraryData.set("Name", "Material", .TextField, .MaterialLibrary)
        }
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(libraryData, forKey: .libraryData)
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

