//
//  SignedMaterial.swift
//  Signed
//
//  Created by Markus Moenig on 3/7/21.
//

import Foundation

class SignedMaterial: Codable {
    
    var data:       SignedData
    
    private enum CodingKeys: String, CodingKey {
        case data
    }
    
    init(albedo: float3 = float3(0.5, 0.5, 0.5), specular: Float = 0, anisotropic: Float = 0, metallic: Float = 0, roughness: Float = 0.5, subsurface: Float = 0, specularTint: Float = 0, sheen: Float = 0, sheenTint: Float = 0, clearcoat: Float = 0, clearcoatGloss: Float = 0, specTrans: Float = 0, ior: Float = 1.45, emission: float3 = float3(0,0,0)) {
        
        data = SignedData([])
        
        data.set("Color", albedo)
        data.set("Specular", specular)
        data.set("Anisotropic", anisotropic)
        data.set("Metallic", metallic)
        data.set("Roughness", roughness)
        data.set("Subsurface", subsurface)
        data.set("SpecularTint", specularTint)
        data.set("Sheen", sheen)
        data.set("SheenTint", sheenTint)
        data.set("Clearcoat", clearcoat)
        data.set("ClearcoatGloss", clearcoatGloss)
        data.set("Transmission", specTrans)
        data.set("IOR", ior)
        data.set("Emission", emission)
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
        
        material.albedo = data.getFloat3("Color")!
        material.specular = data.getFloat("Specular")!
        material.anisotropic = data.getFloat("Anisotropic")!
        material.metallic = data.getFloat("Metallic")!
        material.roughness = data.getFloat("Roughness")!
        material.subsurface = data.getFloat("Subsurface")!
        material.specularTint = data.getFloat("SpecularTint")!
        material.sheen = data.getFloat("Sheen")!
        material.sheenTint = data.getFloat("SheenTint")!
        material.clearcoat = data.getFloat("Clearcoat")!
        material.clearcoatGloss = data.getFloat("ClearcoatGloss")!
        material.specTrans = data.getFloat("Transmission")!
        material.ior = data.getFloat("IOR")!
        material.emission = data.getFloat3("Emission")!

        material.atDistance = 1.0

        return material
    }
}

