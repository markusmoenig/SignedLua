//
//  SignedPBSDF.swift
//  Signed
//
//  Created by Markus Moenig on 15/1/21.
//

import Foundation
import simd

/// GraphPrincipledPathNode
final class GraphPrincipledPathNode : GraphNode
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
        var subsurface      : Float = 0
        var specularTint    : Float = 0
        var sheen           : Float = 0
        var sheenTint       : Float = 0
        var clearcoatGloss  : Float = 0
        var transmission    : Float = 0
        var ior             : Float = 0
        var extinction      = float3(0,0,0)
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
    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Render, .None, options)
        name = "renderPrincipledBSDF"
        givenName = "Principled BSDF Pathtracer"
        renderType = .PathTracer
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        /*
        let v = -context.rayDirection.toSIMD()
        let n = context.normal.toSIMD()
        //let l = normalize(float3(0.6, 0.7, -0.7))
        let l = normalize(float3(5, 10, -10))
        let h = normalize(v + l)
        let r = normalize(simd_reflect(context.rayDirection.toSIMD(), n))*/
        
        var r = Ray(origin: context.rayOrigin.toSIMD(), direction: context.rayDirection.toSIMD())
        
        var radiance = float3(0, 0, 0)
        var throughput = float3(1, 1, 1)
        
        var state = State()
        var lightSampleRec = LightSampleRec()
        var bsdfSampleRec = BsdfSampleRec()
        
        var maxDepth: Int = 1
        
        for depth in 0..<maxDepth
        {
            var lightPdf : Float = 1.0
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
            
            if let material = hit.1 {
                context.executeMaterial(material)
            }
            
            radiance += state.mat.emission * throughput;

            //GetNormalsAndTexCoord(state, r);
            //GetMaterialsAndTextures(state, r);
            
            /*
    #ifdef LIGHTS
            if (state.isEmitter)
            {
                radiance += EmitterSample(r, state, lightSampleRec, bsdfSampleRec) * throughput;
                break;
            }
    #endif
    */
            
            radiance += DirectLight(r, state) * throughput
        }
    
        context.outColor!.x = pow(radiance.x, 1.0 / 2.2)
        context.outColor!.y = pow(radiance.y, 1.0 / 2.2)
        context.outColor!.z = pow(radiance.z, 1.0 / 2.2)

        return .Success
    }
    
    func DirectLight(_ r: Ray,_ state: State) -> float3
    {
        var L = float3(0, 0, 0)

        return L
    }

    
    override func getHelp() -> String
    {
        return "A CPU based path tracer for Disney's Principled BSDF."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Int1(1), "Anti-Aliasing", "The anti-aliasing performed by the renderer. Higher values produce more samples and better quality.")
        ]
        return options
    }
        
    
    
    
}
