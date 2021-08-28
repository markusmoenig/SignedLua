//
//  SignedMaterial.swift
//  Signed
//
//  Created by Markus Moenig on 3/7/21.
//

import Foundation

class SignedMaterial: Codable {
    
    var data            : SignedData

    private enum CodingKeys: String, CodingKey {
        case data
    }
    
    init(albedo: float3 = float3(0.5, 0.5, 0.5), specular: Float = 0.0, anisotropic: Float = 0, metallic: Float = 0, roughness: Float = 0.5, subsurface: Float = 0, specularTint: Float = 0, sheen: Float = 0, sheenTint: Float = 0.0, clearcoat: Float = 0, clearcoatGloss: Float = 0, specTrans: Float = 0, ior: Float = 1.45, emission: float3 = float3(0,0,0)) {
        
        data = SignedData([])

        func setColor(_ key: String,_ value: float3) {
            data.set(key, value, float2(0,1), .Color)
        }
        
        func setFloat3(_ key: String,_ value: float3) {
            data.set(key, value, float2(0,1), .Numeric)
        }
        
        func setFloat(_ key: String,_ value: Float,_ r: float2 = float2(0,1)) {
            data.set(key, value, r, .Slider)
        }
        
        setColor("color", albedo)
        setFloat("metallic", metallic)
        setFloat("roughness", roughness)
        setFloat("subsurface", subsurface)
        setFloat("anisotropic", anisotropic)
        setFloat("specular", specular)
        setFloat("specularTint", specularTint)
        setFloat("sheen", sheen)
        setFloat("sheenTint", sheenTint)
        setFloat("clearcoat", clearcoat)
        setFloat("clearcoatGloss", clearcoatGloss)
        setFloat("transmission", specTrans)
        setFloat("ior", ior, float2(0, 2))
        setFloat3("emission", emission)
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
        
        material.albedo = data.getFloat3("color")
        material.specular = data.getFloat("specular")
        material.anisotropic = data.getFloat("anisotropic")
        material.metallic = data.getFloat("metallic")
        material.roughness = data.getFloat("roughness")
        material.subsurface = data.getFloat("subsurface")
        material.specularTint = data.getFloat("specularTint")
        material.sheen = data.getFloat("sheen")
        material.sheenTint = data.getFloat("sheenTint")
        material.clearcoat = data.getFloat("clearcoat")
        material.clearcoatGloss = data.getFloat("clearcoatGloss")
        material.specTrans = data.getFloat("transmission")
        material.ior = data.getFloat("ior")
        material.emission = data.getFloat3("emission")

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

