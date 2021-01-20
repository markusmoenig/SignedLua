//
//  SignedPBSDF.swift
//  Signed
//
//  Created by Markus Moenig on 15/1/21.
//

import Foundation
import simd

/// GraphPrincipledPathNode
final class GraphPrincipledBSDFNode : GraphNode
{
    // Disney BSDF Implementation based on https://github.com/knightcrawler25/GLSL-PathTracer
    
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
    
    enum RayType {
        case Reflection, Refraction
    }
    
    struct Ray
    {
        var origin          = float3(0,0,0)
        var direction       = float3(0,0,0)
    }
    
    struct Material
    {
        var albedo          = float3(0,0,0)
        var specular        : Float = 0
        var emission        = float3(0,0,0)
        var anisotropic     : Float = 0
        var metallic        : Float = 0
        var roughness       : Float = 0.5
        var subsurface      : Float = 0
        var specularTint    : Float = 0
        var sheen           : Float = 0
        var sheenTint       : Float = 0
        var clearcoat       : Float = 0
        var clearcoatGloss  : Float = 0
        var transmission    : Float = 0
        var ior             : Float = 1.45
        var extinction      = float3(1,1,1)
    }
    
    struct State
    {
        var depth           : Int = 0
        var eta             : Float = 0
        var hitDist         : Float = 0
        var fhp             = float3(0,0,0)
        var normal          = float3(0,0,0)
        var ffnormal        = float3(0,0,0)
        var tangent         = float3(0,0,0)
        var bitangent       = float3(0,0,0)
        
        var isEmitter       = false
        var specularBounce  = false

        var texCoord        = float2(0,0)
        var bary            = float3(0,0,0)
        
        var rayType         : RayType = .Reflection
        //ivec3 triID;
        //int matID;
        var mat             = Material()
    }
    
    struct Light
    {
        var position            = float3(0,0,0)
        var emission            = float3(0,0,0)
        var u                   = float3(0,0,0)
        var v                   = float3(0,0,0)
        var radiusAreaType      = float3(0,0,0)
    }
    
    struct BsdfSampleRec
    {
        var bsdfDir             = float3(0,0,0)
        var pdf                 : Float = 0
    }

    struct LightSampleRec
    {
        var surfacePos          = float3(0,0,0)
        var normal              = float3(0,0,0)
        var emission            = float3(0,0,0)
        var pdf                 : Float = 0
    }
    
    let EPS                     : Float = 0.001
    var ctx                     : GraphContext!
    
    var maxDepth                : Int = 2
        
    init(_ options: [String:Any] = [:])
    {
        super.init(.Render, .None, options)
        name = "renderPrincipledBSDF"
        givenName = "Principled BSDF"
        renderType = .PathTracer
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractInt1Value(options, container: context, error: &error, name: "maxdepth", isOptional: true) {
            maxDepth = value.toSIMD()
        }
    }
    
    override func setupMaterialVariables(context: GraphContext)
    {
        context.albedo = Float3("albedo", 0.5, 0.5, 0.5)
        context.variables["albedo"] = context.albedo
        context.specular = Float1("specular", 0.5)
        context.variables["specular"] = context.specular
        
        context.emission = Float3("emission", 0, 0, 0)
        context.variables["emission"] = context.emission
        context.anisotropic = Float1("anisotropic", 0)
        context.variables["anisotropic"] = context.anisotropic
        
        context.metallic = Float1("metallic", 0)
        context.variables["metallic"] = context.metallic
        context.roughness = Float1("roughness", 0.5)
        context.variables["roughness"] = context.roughness
        context.subsurface = Float1("subsurface", 0)
        context.variables["subsurface"] = context.subsurface
        context.specularTint = Float1("specularTint", 0)
        context.variables["specularTint"] = context.specularTint
        
        context.sheen = Float1("sheen", 0)
        context.variables["sheen"] = context.sheen
        context.sheenTint = Float1("sheenTint", 0)
        context.variables["sheenTint"] = context.sheenTint
        context.clearcoat = Float1("clearcoat", 0)
        context.variables["clearcoat"] = context.clearcoat
        context.clearcoatGloss = Float1("clearcoatGloss", 0)
        context.variables["clearcoatGloss"] = context.clearcoatGloss
        
        context.transmission = Float1("transmission", 0)
        context.variables["transmission"] = context.transmission
        context.ior = Float1("ior", 1.45)
        context.variables["ior"] = context.ior
        context.extinction = Float3("extinction", 1, 1, 1)
        context.variables["extinction"] = context.extinction
    }
    
    override func resetMaterialVariables(context: GraphContext)
    {
        context.albedo.fromSIMD(float3(0.5, 0.5, 0.5))
        context.specular.fromSIMD(0.5)
        
        context.emission.fromSIMD(float3(0, 0, 0))
        context.anisotropic.fromSIMD(0)
        
        context.metallic.fromSIMD(0)
        context.roughness.fromSIMD(0.5)
        context.subsurface.fromSIMD(0)
        context.specularTint.fromSIMD(0)
        
        context.sheen.fromSIMD(0)
        context.sheenTint.fromSIMD(0)
        context.clearcoat.fromSIMD(0)
        context.clearcoatGloss.fromSIMD(0)
        
        context.transmission.fromSIMD(0)
        context.ior.fromSIMD(1.45)
        context.extinction.fromSIMD(float3(1, 1, 1))
    }
    
    var lastLightPdf : Float = 0
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        ctx = context
        lastLightPdf = 0
        
        var r = Ray(origin: context.rayOrigin.toSIMD(), direction: context.rayDirection.toSIMD())
        
        var radiance = float3(0, 0, 0)
        var throughput = float3(1, 1, 1)
        
        var state = State()
        //var lightSampleRec = LightSampleRec()
        var bsdfSampleRec = BsdfSampleRec()
                
        for depth in 0..<maxDepth
        {
            //var lightPdf : Float = 1.0
            state.depth = depth
            
            context.rayOrigin.fromSIMD(r.origin)
            context.rayDirection.fromSIMD(r.direction)
            
            let hit = context.hit()
            if hit.0 == Float.greatestFiniteMagnitude {
                
                // Sky
                if let skyNode = context.skyNode {
                    skyNode.execute(context: context)
                    radiance += context.outColor.toSIMD3() * throughput
                }
                
                context.outColor!.x = pow(radiance.x, 1.0 / 2.2)
                context.outColor!.y = pow(radiance.y, 1.0 / 2.2)
                context.outColor!.z = pow(radiance.z, 1.0 / 2.2)
                
                return .Success
            }
            
            context.normal.fromSIMD(hit.2)
            
            if let material = hit.1 {
                context.executeMaterial(material)
            }
            
            // Fill in state
            
            let normal = context.normal.toSIMD()
            state.fhp = r.origin + r.direction * hit.0
            state.normal = normal
            state.ffnormal = dot(normal, r.direction) <= 0.0 ? normal : normal * -1.0
            state.isEmitter = false
            
            state.texCoord = context.uv
            
            let UpVector = abs(state.ffnormal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0)
            state.tangent = normalize(cross(UpVector, state.ffnormal))
            state.bitangent = cross(state.ffnormal, state.tangent)

            // Fill in materials
            let albedo = context.outColor.toSIMD3()
            state.mat.albedo.x = pow(albedo.x, 2.2)
            state.mat.albedo.y = pow(albedo.y, 2.2)
            state.mat.albedo.z = pow(albedo.z, 2.2)
            state.mat.specular = context.variables["specular"]![0]
            
            state.mat.emission = (context.variables["emission"]! as! Float3).toSIMD()
            state.mat.anisotropic = context.variables["anisotropic"]![0]
            
            state.mat.metallic = context.variables["metallic"]![0]
            state.mat.roughness = context.variables["roughness"]![0]
            state.mat.subsurface = context.variables["subsurface"]![0]
            state.mat.specularTint = context.variables["specularTint"]![0]
            
            state.mat.sheen = context.variables["sheen"]![0]
            state.mat.sheenTint = context.variables["sheenTint"]![0]
            state.mat.clearcoat = context.variables["clearcoat"]![0]
            state.mat.clearcoatGloss = context.variables["clearcoatGloss"]![0]

            state.mat.transmission = context.variables["transmission"]![0]
            state.mat.ior = context.variables["ior"]![0]
            state.mat.extinction = (context.variables["extinction"]! as! Float3).toSIMD()

            state.eta = dot(state.normal, state.ffnormal) > 0.0 ? (1.0 / state.mat.ior) : state.mat.ior

            radiance += state.mat.emission * throughput

            // Light
            if state.mat.emission.x > 0 || state.mat.emission.y > 0 || state.mat.emission.z > 0 {
                
                context.outColor!.w = 1

                // EmitterSample
                var Le : float3
                if depth == 0 || state.specularBounce {
                    Le = state.mat.emission
                } else {
                    Le = powerHeuristic(bsdfSampleRec.pdf, lastLightPdf) * state.mat.emission
                }
                
                radiance += Le * throughput
                break
            }
            
            //
            if context.renderQuality == .Normal {
                radiance += DirectLight(r, &state) * throughput
                
                bsdfSampleRec.bsdfDir = DisneySample(r, &state)// simd_reflect(r.direction, state.ffnormal)

                bsdfSampleRec.pdf = DisneyPdf(r, &state, bsdfSampleRec.bsdfDir)
                
                if (bsdfSampleRec.pdf > 0.0) {
                    throughput *= DisneyEval(r, &state, bsdfSampleRec.bsdfDir) * abs(dot(state.ffnormal, bsdfSampleRec.bsdfDir)) / bsdfSampleRec.pdf
                } else {
                    break
                }
                
                // Russian roulette
                /*
                let RR_DEPTH = 2
                if depth >= RR_DEPTH {
                    let q = min(max(throughput.x, max(throughput.y, throughput.z)) * state.eta * state.eta + 0.001, 0.95)
                    if rand() > q {
                        break;
                    }
                    throughput /= q
                }*/
                
                r.direction = bsdfSampleRec.bsdfDir
                r.origin = state.fhp + r.direction * EPS
            } else {
                radiance += DirectLightPreview(r, &state) * throughput
                break
            }
        }
    
        context.outColor!.x = pow(radiance.x, 1.0 / 2.2)
        context.outColor!.y = pow(radiance.y, 1.0 / 2.2)
        context.outColor!.z = pow(radiance.z, 1.0 / 2.2)

        return .Success
    }
    
    /// DirectLight for Preview
    func DirectLightPreview(_ r: Ray,_ state: inout State) -> float3
    {
        var L = float3(0, 0, 0)
        
        let surfacePos = state.fhp + state.ffnormal * EPS
                
        for lightNode in ctx.lightNodes {
            
            guard let lightInfo = lightNode.sampleLight(context: ctx) else {
                print("failed to sample light")
                continue
            }
            
            var lightDir : float3
            var lightDistSq : Float = 0

            if lightInfo.lightType == .Sun {
                lightDir = lightInfo.direction
                
                if dot(lightDir, state.ffnormal) <= 0.0 {
                    continue
                }
            } else {
                
                lightDir = lightInfo.position - surfacePos
                let lightDist = length(lightDir)
                lightDistSq = lightDist * lightDist
                lightDir /= sqrt(lightDistSq)
                
                if dot(lightDir, state.ffnormal) <= 0.0 {//}|| dot(lightDir, lightInfo.normal) >= 0.0 {
                    continue
                }
                
                let LL = lightDir
                let V = -normalize(ctx.rayDirection.toSIMD())
                let rr = simd_reflect(V, ctx.normal.toSIMD())
                let centerToRay = dot( LL, rr ) * rr - LL
                let closestPoint = LL + centerToRay * simd_clamp( lightInfo.radius / length( centerToRay ), 0.0, 1.0 )
                let wi = normalize(closestPoint)
                
                lightDir = normalize(lightDir)
                //let bsdfPdf = DisneyPdf(r, &state, lightDir)
                let f = DisneyEval(r, &state, lightDir)// * abs(dot(wi, ctx.normal.toSIMD()))
                var weight : Float = 1
                
                let visibility = ctx.shadowRay(surfacePos, lightDir)
                
                var lightPdf : Float

                if lightInfo.lightType == .Sun {
                    lightPdf = 1.0 / 6.87E-2
                    weight = 1.0
                } else {
                    lightPdf = lightDistSq / (lightInfo.area * abs(dot(wi, ctx.normal.toSIMD()))) //abs(dot(lightInfo.normal, lightDir)))
                    weight = 1//powerHeuristic(lightPdf, bsdfPdf)
                }
                
                L += (weight * f * abs(dot(state.ffnormal, lightDir)) * lightInfo.emission / lightPdf) * visibility
            }
        }
        
        return L
    }
    
    func DirectLight(_ r: Ray,_ state: inout State) -> float3
    {
        var L = float3(0, 0, 0)
        
        let surfacePos = state.fhp + state.ffnormal * EPS
        
        // Analytic Lights
        
        if ctx.lightNodes.count == 0 { return L }
        
        let lightNode = ctx.lightNodes[Int.random(in: 0..<ctx.lightNodes.count)]

        guard let lightInfo = lightNode.sampleLight(context: ctx) else {
            print("failed to sample light")
            return L
        }
                
        var lightDir : float3
        var lightDistSq : Float = 0

        if lightInfo.lightType == .Sun {
            lightDir = lightInfo.direction
            
            if dot(lightDir, state.ffnormal) <= 0.0 {
                return L
            }
        } else {
            lightDir = lightInfo.surfacePos - surfacePos
            let lightDist = length(lightDir)
            lightDistSq = lightDist * lightDist
            lightDir /= sqrt(lightDistSq)
            
            if dot(lightDir, state.ffnormal) <= 0.0 || dot(lightDir, lightInfo.normal) >= 0.0 {
                return L
            }
        }
        
        lightDir = normalize(lightDir)
        ctx.rayOrigin.fromSIMD(surfacePos + lightDir * EPS)
        ctx.rayDirection.fromSIMD(lightDir)

        let hit = ctx.hit(shadowRay: true)
        var inShadow : Bool = false
            
        if lightInfo.lightType == .Sun {
            inShadow = hit.0 != Float.greatestFiniteMagnitude
        } else {
            if let material = hit.1 as? GraphMaterialNode {
                inShadow = material.isEmitter == false
            }
        }
        
        if inShadow == false {
            let bsdfPdf = DisneyPdf(r, &state, lightDir)
            let f = DisneyEval(r, &state, lightDir)
            var weight : Float = 1
            
            var lightPdf : Float

            if lightInfo.lightType == .Sun {
                lightPdf = 1.0 / 6.87E-2
                weight = 1.0
            } else {
                lightPdf = lightDistSq / (lightInfo.area * abs(dot(lightInfo.normal, lightDir)))
                weight = powerHeuristic(lightPdf, bsdfPdf)
            }
            lastLightPdf = lightPdf
            
            L += weight * f * abs(dot(state.ffnormal, lightDir)) * lightInfo.emission / lightPdf
        }
        
        return L
    }
    
    //-----------------------------------------------------------------------
    func DisneyPdf(_ ray: Ray,_ state: inout State,_ bsdfDir: float3) -> Float
    //-----------------------------------------------------------------------
    {
        let N = state.ffnormal
        let V = -ray.direction
        let L = bsdfDir
        var H = float3(0,0,0)
        
        if state.rayType == .Refraction {
            H = normalize(L + V * state.eta)
        } else {
            H = normalize(L + V)
        }

        let NDotH = abs(dot(N, H))
        let VDotH = abs(dot(V, H))
        let LDotH = abs(dot(L, H))
        let NDotL = abs(dot(N, L))
        //let NDotV = abs(dot(N, V))
        
        let specularAlpha = max(0.001, state.mat.roughness)

        // Handle transmission separately
        if (state.rayType == .Refraction)
        {
            let pdfGTR2 = GTR2(NDotH, specularAlpha) * NDotH
            let F = DielectricFresnel(VDotH, state.eta)
            let denomSqrt = LDotH + VDotH * state.eta
            return pdfGTR2 * (1.0 - F) * LDotH / (denomSqrt * denomSqrt) * state.mat.transmission
        }

        // Reflection
        var brdfPdf : Float = 0.0
        var bsdfPdf : Float = 0.0

        let clearcoatAlpha = simd_mix(0.1, 0.001, state.mat.clearcoatGloss)

        let diffuseRatio = 0.5 * (1.0 - state.mat.metallic)
        let specularRatio = 1.0 - diffuseRatio

        let aspect = sqrt(1.0 - state.mat.anisotropic * 0.9)
        let ax = max(0.001, state.mat.roughness / aspect)
        let ay = max(0.001, state.mat.roughness * aspect)

        // PDFs for brdf
        let pdfGTR2_aniso = GTR2_aniso(NDotH, dot(H, state.tangent), dot(H, state.bitangent), ax, ay) * NDotH
        let pdfGTR1 = GTR1(NDotH, clearcoatAlpha) * NDotH
        let ratio = 1.0 / (1.0 + state.mat.clearcoat)
        let pdfSpec = simd_mix(pdfGTR1, pdfGTR2_aniso, ratio) / (4.0 * VDotH)
        let pdfDiff = NDotL * (1.0 / Float.pi)
        brdfPdf = diffuseRatio * pdfDiff + specularRatio * pdfSpec

        // PDFs for bsdf
        let pdfGTR2 = GTR2(NDotH, specularAlpha) * NDotH
        let F = DielectricFresnel(VDotH, state.eta)
        bsdfPdf = pdfGTR2 * F / (4.0 * VDotH)

        return simd_mix(brdfPdf, bsdfPdf, state.mat.transmission)
    }
    
    //-----------------------------------------------------------------------
    func DisneySample(_ ray: Ray,_ state: inout State) -> float3
    //-----------------------------------------------------------------------
    {
        let N : float3 = state.ffnormal
        let V = -ray.direction
        state.specularBounce = false
        state.rayType = .Reflection

        var dir = float3(0,0,0)

        let r2D = ctx.rand2()

        // BSDF
        if (ctx.rand() < state.mat.transmission)
        {
            var H : float3 = ImportanceSampleGGX(state.mat.roughness, r2D.x, r2D.y)
            H = state.tangent * H.x
            H += state.bitangent * H.y
            H += N * H.z

            let R = simd_reflect(-V, H)
            let F = DielectricFresnel(dot(R, H), state.eta)
            
            // Reflection/Total internal reflection
            if ctx.rand() < F {
                dir = normalize(R)
            } else {
                // Transmission
                dir = normalize(simd_refract(-V, H, state.eta))
                state.specularBounce = true
                state.rayType = .Refraction
            }
        }
        // BRDF
        else
        {
            let diffuseRatio = 0.5 * (1.0 - state.mat.metallic)

            if ctx.rand() < diffuseRatio {
                var H = CosineSampleHemisphere(r2D.x, r2D.y)
                H = state.tangent * H.x
                H += state.bitangent * H.y
                H += N * H.z
                dir = H
            } else {
                var H = ImportanceSampleGGX(state.mat.roughness, r2D.x, r2D.y)
                H = state.tangent * H.x
                H += state.bitangent * H.y
                H += N * H.z
                dir = simd_reflect(-V, H)
            }
        }
        return dir
    }
    
    //-----------------------------------------------------------------------
    func DisneyEval(_ ray: Ray,_ state: inout State,_ bsdfDir: float3) -> float3
    //-----------------------------------------------------------------------
    {
        let N = state.ffnormal
        let V = -ray.direction
        let L = bsdfDir
        var H = normalize(L + V)

        if state.rayType == .Refraction {
            H = normalize(L + V * state.eta)
        } else {
            H = normalize(L + V)
        }

        let NDotL = dot(N, L)
        let NDotV = dot(N, V)
        let NDotH = dot(N, H)
        let VDotH = dot(V, H)
        let LDotH = dot(L, H)
        
        var brdf = float3(0, 0, 0)
        var bsdf = float3(0, 0, 0)

        if (state.mat.transmission > 0.0)
        {
            var transmittance = float3(1, 1, 1)
            let extinction = float3(log(state.mat.extinction.x), log(state.mat.extinction.y), log(state.mat.extinction.z))

            if (dot(state.normal, state.ffnormal) < 0.0) {
                transmittance.x = exp(extinction.x * state.hitDist)
                transmittance.y = exp(extinction.y * state.hitDist)
                transmittance.z = exp(extinction.z * state.hitDist)
            }

            let a = max(0.001, state.mat.roughness)
            let F = DielectricFresnel(VDotH, state.eta)
            let D = GTR2(NDotH, a)
            let G = SmithG_GGX(NDotL, a) * SmithG_GGX(NDotV, a)
            
            // TODO: Include subsurface scattering
            if state.rayType == .Refraction {
                let denomSqrt = LDotH + VDotH * state.eta
                bsdf = state.mat.albedo * transmittance * (1.0 - F) * D * G
                bsdf *= VDotH * LDotH * 4.0 * state.eta * state.eta / (denomSqrt * denomSqrt)
            } else {
                bsdf = state.mat.albedo * transmittance * F * D * G;
            }
        }

        if (state.mat.transmission < 1.0 && dot(N, L) > 0.0 && dot(N, V) > 0.0)
        {
            let Cdlin = state.mat.albedo
            let Cdlum = 0.3 * Cdlin.x + 0.6 * Cdlin.y + 0.1 * Cdlin.z // luminance approx.

            let Ctint = Cdlum > 0.0 ? Cdlin / Cdlum : float3(1,1,1) // normalize lum. to isolate hue+sat
            let Cspec0 = simd_mix(state.mat.specular * 0.08 * simd_mix(float3(1,1,1), Ctint, float3(state.mat.specularTint, state.mat.specularTint, state.mat.specularTint)), Cdlin, float3(state.mat.metallic, state.mat.metallic, state.mat.metallic))
            let Csheen = simd_mix(float3(1,1,1), Ctint, float3(state.mat.sheenTint, state.mat.sheenTint, state.mat.sheenTint))

            // Diffuse fresnel - go from 1 at normal incidence to .5 at grazing
            // and mix in diffuse retro-reflection based on roughness
            let FL = SchlickFresnel(NDotL)
            let FV = SchlickFresnel(NDotV)
            let Fd90 = 0.5 + 2.0 * LDotH * LDotH * state.mat.roughness
            let Fd = simd_mix(1.0, Fd90, FL) * simd_mix(1.0, Fd90, FV)

            // Based on Hanrahan-Krueger brdf approximation of isotropic bssrdf
            // 1.25 scale is used to (roughly) preserve albedo
            // Fss90 used to "flatten" retroreflection based on roughness
            let Fss90 = LDotH * LDotH * state.mat.roughness
            let Fss = simd_mix(1.0, Fss90, FL) * simd_mix(1.0, Fss90, FV)
            let ss = 1.25 * (Fss * (1.0 / (NDotL + NDotV) - 0.5) + 0.5)

            // TODO: Add anisotropic rotation
            // specular
            let aspect = sqrt(1.0 - state.mat.anisotropic * 0.9)
            let ax = max(0.001, state.mat.roughness / aspect)
            let ay = max(0.001, state.mat.roughness * aspect)
            let Ds = GTR2_aniso(NDotH, dot(H, state.tangent), dot(H, state.bitangent), ax, ay)
            let FH = SchlickFresnel(LDotH)
            let Fs = simd_mix(Cspec0, float3(1,1,1), float3(FH, FH, FH))
            var Gs = SmithG_GGX_aniso(NDotL, dot(L, state.tangent), dot(L, state.bitangent), ax, ay)
            Gs *= SmithG_GGX_aniso(NDotV, dot(V, state.tangent), dot(V, state.bitangent), ax, ay)

            // sheen
            let Fsheen = FH * state.mat.sheen * Csheen

            // clearcoat (ior = 1.5 -> F0 = 0.04)
            let Dr = GTR1(NDotH, simd_mix(0.1, 0.001, state.mat.clearcoatGloss))
            let Fr = simd_mix(0.04, 1.0, FH)
            let Gr = SmithG_GGX(NDotL, 0.25) * SmithG_GGX(NDotV, 0.25)

            brdf = ((1.0 / Float.pi) * simd_mix(Fd, ss, state.mat.subsurface) * Cdlin + Fsheen) * (1.0 - state.mat.metallic)
            brdf += Gs * Fs * Ds + 0.25 * state.mat.clearcoat * Gr * Fr * Dr
        }

        return simd_mix(brdf, bsdf, float3(state.mat.transmission, state.mat.transmission, state.mat.transmission))
    }
    
    //-----------------------------------------------------------------------
    func ImportanceSampleGGX(_ rgh: Float,_ r1: Float,_ r2: Float) -> float3
    //-----------------------------------------------------------------------
    {
        let a = max(0.001, rgh)

        let phi = r1 * 2.0 * Float.pi

        let cosTheta = sqrt((1.0 - r2) / (1.0 + (a * a - 1.0) * r2))
        let sinTheta = simd_clamp(sqrt(1.0 - (cosTheta * cosTheta)), 0.0, 1.0)
        let sinPhi = sin(phi)
        let cosPhi = cos(phi)

        return float3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta)
    }
    
    //-----------------------------------------------------------------------
    func SchlickFresnel(_ u: Float) -> Float
    //-----------------------------------------------------------------------
    {
        let m = simd_clamp(1.0 - u, 0.0, 1.0)
        let m2 = m * m
        return m2 * m2*m // pow(m,5)
    }
    
    //-----------------------------------------------------------------------
    func DielectricFresnel(_ cos_theta_i: Float,_ eta: Float) -> Float
    //-----------------------------------------------------------------------
    {
        let sinThetaTSq = eta * eta * (1.0 - cos_theta_i * cos_theta_i)

        // Total internal reflection
        if sinThetaTSq > 1.0 {
            return 1.0
        }

        let cos_theta_t = sqrt(max(1.0 - sinThetaTSq, 0.0))

        let rs = (eta * cos_theta_t - cos_theta_i) / (eta * cos_theta_t + cos_theta_i)
        let rp = (eta * cos_theta_i - cos_theta_t) / (eta * cos_theta_i + cos_theta_t)

        return 0.5 * (rs * rs + rp * rp)
    }
    
    //-----------------------------------------------------------------------
    func GTR1(_ NDotH: Float,_ a: Float) -> Float
    //-----------------------------------------------------------------------
    {
        if a >= 1.0 { return (1.0 / Float.pi) }
        let a2 = a * a
        let t = 1.0 + (a2 - 1.0) * NDotH * NDotH
        return (a2 - 1.0) / (Float.pi * log(a2) * t)
    }

    //-----------------------------------------------------------------------
    func GTR2(_ NDotH: Float,_ a: Float) -> Float
    //-----------------------------------------------------------------------
    {
        let a2 = a * a
        let t = 1.0 + (a2 - 1.0)*NDotH*NDotH
        return a2 / (Float.pi * t*t)
    }

    //-----------------------------------------------------------------------
    func GTR2_aniso(_ NDotH: Float,_ HDotX: Float,_ HDotY: Float,_ ax: Float,_ ay: Float) -> Float
    //-----------------------------------------------------------------------
    {
        let a = HDotX / ax
        let b = HDotY / ay
        let c = a * a + b * b + NDotH * NDotH
        return 1.0 / (Float.pi * ax * ay * c * c)
    }
    
    //-----------------------------------------------------------------------
    func SmithG_GGX(_ NDotV: Float,_ alphaG: Float) -> Float
    //-----------------------------------------------------------------------
    {
        let a = alphaG * alphaG
        let b = NDotV * NDotV
        return 1.0 / (NDotV + sqrt(a + b - a * b))
    }

    //-----------------------------------------------------------------------
    func SmithG_GGX_aniso(_ NDotV: Float,_ VDotX: Float,_ VDotY: Float,_ ax: Float,_ ay: Float) -> Float
    //-----------------------------------------------------------------------
    {
        let a = VDotX * ax
        let b = VDotY * ay
        let c = NDotV
        return 1.0 / (NDotV + sqrt(a*a + b*b + c*c))
    }

    //-----------------------------------------------------------------------
    func CosineSampleHemisphere(_ u1: Float,_ u2: Float) -> float3
    //-----------------------------------------------------------------------
    {
        var dir = float3(0,0,0)
        let r = sqrt(u1)
        let phi = 2.0 * Float.pi * u2
        dir.x = r * cos(phi)
        dir.y = r * sin(phi)
        dir.z = sqrt(max(0.0, 1.0 - dir.x*dir.x - dir.y*dir.y))

        return dir
    }
    
    //-----------------------------------------------------------------------
    func UniformSampleSphere(_ u1: Float,_ u2: Float) -> float3
    //-----------------------------------------------------------------------
    {
        let z = 1.0 - 2.0 * u1
        let r = sqrt(max(0.0, 1.0 - z * z))
        let phi = 2.0 * Float.pi * u2
        let x = r * cos(phi)
        let y = r * sin(phi)

        return float3(x, y, z)
    }
    
    //-----------------------------------------------------------------------
    func powerHeuristic(_ a: Float,_ b: Float) -> Float
    //-----------------------------------------------------------------------
    {
        let t = a * a
        return t / (b*b + t)
    }
    
    override func getHelp() -> String
    {
        return "A CPU based path tracer for Disney's Principled BSDF."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Int1(10), "Iterations", "The numer of iterations for the path tracer. The higher, the better quality."),
            GraphOption(Int1(2), "MaxDepth", "The maximum number of ray bounces.")
        ]
        return options
    }
}
