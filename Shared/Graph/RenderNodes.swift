//
//  RenderNodes.swift
//  Signed
//
//  Created by Markus Moenig on 12/1/21.
//

import Foundation
import simd

/// PBRRenderer
final class GraphPBRNode : GraphNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Render, .None, options)
        name = "renderPBR"
        givenName = "PBR Render"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        let v = -context.rayDirection.toSIMD()
        let n = context.normal.toSIMD()
        //let l = normalize(float3(0.6, 0.7, -0.7))
        let l = normalize(float3(5, 10, -10))
        let h = normalize(v + l)
        let r = normalize(simd_reflect(context.rayDirection.toSIMD(), n))
        
        let NoV = abs(dot(n, v)) + 1e-5
        let NoL = saturate(dot(n, l))
        let NoH = saturate(dot(n, h))
        let LoH = saturate(dot(l, h))
        
        let baseColor = float3(context.outColor.x, context.outColor.y, context.outColor.z)
        let roughness : Float = 0.4
        let metallic : Float = 0.8

        let intensity : Float = 2.0
        let indirectIntensity : Float = 0.64
        
        let linearRoughness = roughness * roughness
        let diffuseColor = (1.0 - metallic) * baseColor
        let f0 = float3(repeating: 0.04 * (1.0 - metallic) * metallic)

        let attenuation : Float = context.shadowRay(context.rayPosition!.toSIMD(), l)
        
        // specular BRDF
        let D = D_GGX(linearRoughness, NoH, h)
        let V = V_SmithGGXCorrelated(linearRoughness, NoV, NoL)
        let F = F_Schlick(f0, LoH)
        let Fr = (D * V) * F

        // diffuse BRDF
        let Fd = diffuseColor * Fd_Burley(linearRoughness, NoV, NoL, LoH)

        var color = Fd + Fr
        color *= (intensity * attenuation * NoL) * float3(0.98, 0.92, 0.89)
        
        // diffuse indirect
        let indirectDiffuse = Irradiance_SphericalHarmonics(n) * Fd_Lambert()
        
        //vec2 indirectHit = traceRay(position, r);
        let indirectSpecular = context.castRay(context.rayPosition!.toSIMD(), r)
        
        // indirect contribution
        let dfg = PrefilteredDFG_Karis(roughness, NoV)
        let specularColor = f0 * dfg.x + dfg.y
        let ibl = diffuseColor * indirectDiffuse + indirectSpecular * specularColor

        color += ibl * indirectIntensity

        context.outColor!.x = pow(color.x, 1.0 / 2.2)
        context.outColor!.y = pow(color.y, 1.0 / 2.2)
        context.outColor!.z = pow(color.z, 1.0 / 2.2)

        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates a texture of a static color."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0.5, 0.5, 0.5), "Color", "The static color of the texture.")
        ]
        return options
    }
    
    // Based on https://www.shadertoy.com/view/XlKSDR
    
    func saturate(_ x: Float) -> Float
    {
        return simd_clamp(x, 0, 1)
    }
    
    func pow5(_ x: Float) -> Float
    {
        let x2 = x * x
        return x2 * x2 * x
    }
    
    func D_GGX(_ linearRoughness: Float,_ NoH: Float,_ h: float3) -> Float
    {
        // Walter et al. 2007, "Microfacet Models for Refraction through Rough Surfaces"
        let oneMinusNoHSquared = 1.0 - NoH * NoH
        let a = NoH * linearRoughness
        let k = linearRoughness / (oneMinusNoHSquared + a * a)
        let d = k * k * (1.0 / Float.pi)
        return d
    }
    
    func V_SmithGGXCorrelated(_ linearRoughness: Float,_ NoV: Float,_ NoL: Float) -> Float
    {
        // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
        let a2 = linearRoughness * linearRoughness
        let GGXV = NoL * sqrt((NoV - a2 * NoV) * NoV + a2)
        let GGXL = NoV * sqrt((NoL - a2 * NoL) * NoL + a2)
        return 0.5 / (GGXV + GGXL)
    }
    
    func F_Schlick(_ f0: float3,_ VoH: Float) -> float3
    {
        // Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
        return f0 + (float3(1,1,1) - f0) * pow5(1.0 - VoH)
    }

    func F_Schlick(_ f0: Float,_ f90: Float,_ VoH: Float) -> Float
    {
        return f0 + (f90 - f0) * pow5(1.0 - VoH)
    }

    func Fd_Burley(_ linearRoughness: Float,_ NoV: Float,_ NoL: Float,_ LoH: Float) -> Float
    {
        // Burley 2012, "Physically-Based Shading at Disney"
        let f90 = 0.5 + 2.0 * linearRoughness * LoH * LoH
        let lightScatter = F_Schlick(1.0, f90, NoL)
        let viewScatter  = F_Schlick(1.0, f90, NoV)
        return lightScatter * viewScatter * (1.0 / Float.pi)
    }
    
    func Fd_Lambert() -> Float
    {
        return 1.0 / Float.pi
    }

    func Irradiance_SphericalHarmonics(_ n: float3) -> float3 {
        // Irradiance from "Ditch River" IBL (http://www.hdrlabs.com/sibl/archive.html)
        return max(
            float3( 0.754554516862612,  0.748542953903366,  0.790921515418539)
            + float3(-0.083856548007422,  0.092533500963210,  0.322764661032516) * (n.y)
            + float3( 0.308152705331738,  0.366796330467391,  0.466698181299906) * (n.z)
            + float3(-0.188884931542396, -0.277402551592231, -0.377844212327557) * (n.x)
            , 0.0)
    }
    
    func PrefilteredDFG_Karis(_ roughness: Float,_ NoV: Float) -> float2 {
        // Karis 2014, "Physically Based Material on Mobile"
        let c0 = float4(-1.0, -0.0275, -0.572,  0.022)
        let c1 = float4( 1.0,  0.0425,  1.040, -0.040)

        let r = roughness * c0 + c1
        let a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y

        return float2(-1.04, 1.04) * a004 + float2(r.z, r.w)
    }
}

/// CustomRenderer
final class GraphCustomRenderNode : GraphNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Render, .None, options)
        name = "renderCustom"
        givenName = "Custom Render"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        for n in leaves {
            n.execute(context: context)
        }        
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Creates a texture of a static color."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0.5, 0.5, 0.5), "Color", "The static color of the texture.")
        ]
        return options
    }
}
