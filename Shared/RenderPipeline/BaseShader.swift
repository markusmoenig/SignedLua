//
//  BaseShader.swift
//  Signed
//
//  Created by Markus Moenig on 26/6/21.
//

import MetalKit

class Shader
{
    enum ShaderState {
        case Undefined, Compiling, Compiled, Invalid
    }
    
    var id                  : String
    var computeName         : String
    
    var pixelFormat         : MTLPixelFormat
        
    var shaderState         : ShaderState = .Undefined
    
    var state               : MTLComputePipelineState!

    var commandQueue        : MTLCommandQueue!
    
    var executionTime       : Double = 0
    
    init(id: String, computeName: String = "kernel", pixelFormat: MTLPixelFormat = .rgba16Float)
    {
        self.id = id
        self.computeName = computeName
        
        self.pixelFormat = pixelFormat
    }
}

class BaseShader
{
    var pipelineState       : MTLRenderPipelineState? = nil
    
    var compileTime         : Double = 0
    var executionTime       : Double = 0
    
    var library             : MTLLibrary!

    // Instance Data
    
    var data                : [SIMD4<Float>] = []
    var buffer              : MTLBuffer!
    
    var shaders             : [String: Shader] = [:]
    var allShaders          : [Shader] = []
    
    var pipeline            : RenderPipeline

    init(pipeline: RenderPipeline)
    {
        self.pipeline = pipeline
        data.append(SIMD4<Float>(0, 0, 0, 0))
    }
    
    deinit
    {
        shaders = [:]
        allShaders = []
    }
    
    func compile(code: String, shaders: [Shader], sync: Bool = false)
    {
        self.shaders = [:]
        allShaders = shaders
        let source = BaseShader.getHeaderCode() + code
        
        let compiledCB : MTLNewLibraryCompletionHandler = { (library, error) in
            if let error = error, library == nil {
                print(error)
            } else
            if let library = library {
                
                self.library = library
                for shader in shaders {
                
                    shader.shaderState = .Compiling

                    if let state = self.createComputeState(shader.computeName) {
                        shader.state = state
                        
                    } else {
                        shader.shaderState = .Undefined
                        self.shaders[shader.id] = nil
                        return
                    }
                    
                    shader.shaderState = .Compiled
                    
                    self.shaders[shader.id] = shader
                }
            }
            
            //self.pipeline.toCompile -= 1
            
            //if self.pipeline.toCompile == 0 {
            //    self.pipeline.compilationFinished()
            //}
        }
        
        //pipeline.toCompile += 1
        
        //print(source)
        if sync == false {
            pipeline.device.makeLibrary( source: source, options: nil, completionHandler: compiledCB)
        } else {
            do {
                let library = try pipeline.device.makeLibrary( source: source, options: nil)
                compiledCB(library, nil)
            } catch {
                //print(error)
            }
        }
    }
    
    /// Creates a compute state for the given function name
    func createComputeState(_ name: String) -> MTLComputePipelineState?
    {
        if let library = library {
            if let function = library.makeFunction(name: name) {
                do {
                    let computePipelineState = try pipeline.device.makeComputePipelineState(function: function)
                    return computePipelineState
                } catch {
                    print( "computePipelineState failed" )
                    return nil
                }
            }
        }
        return nil
    }
    
    /// Execute the given state
    func calculateThreadGroups(_ state: MTLComputePipelineState, _ encoder: MTLComputeCommandEncoder,_ width: Int,_ height: Int)
    {
        let w = state.threadExecutionWidth
        let h = state.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)

        let threadgroupsPerGrid = MTLSize(width: (width + w - 1) / w, height: (height + h - 1) / h, depth: 1)
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }
    
    /// The main render operation of the shader
    func render()
    {
    }
    
    /// Returns the code filling out the DataIn structure, needed by most shaders
    func getDataInCode() -> String
    {
        return """
        DataIn dataIn;
        dataIn.time = data[0].x;
        dataIn.uv = uv;
        dataIn.seed = uv;
        dataIn.viewSize = size;
        dataIn.randomVector = uniforms.randomVector;
        dataIn.data = data;
        """
    }

    /// Returns the header code required by every shader
    static func getHeaderCode() -> String
    {
        return """
        
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;

        typedef struct
        {
            float               time;

            float2              uv;
            float2              viewSize;
            
            float2              seed;
            float3              randomVector;
            constant float4    *data;

            float               hash;
            float               gradient;
        } DataIn;

        typedef struct {

            simd_float3         randomVector;

            int                 samples;
            int                 depth;
            int                 maxDepth;

            // bbox
            simd_float3         P;
            simd_float3         L;
            matrix_float3x3     F;

            float               maxDistance;
        } FragmentUniforms;

        #define REFL 0
        #define REFR 1
        #define SUBS 2

        typedef struct
        {
            float3 albedo;
            float specular;

            float3 emission;
            float anisotropic;

            float metallic;
            float roughness;
            float subsurface;
            float specularTint;

            float sheen;
            float sheenTint;
            float clearcoat;
            float clearcoatGloss;

            float transmission;

            float ior;
            float atDistance;
            float3 extinction;

            float ax;
            float ay;
        } Material;

        struct State
        {
            int depth;
            float eta;
            float hitDist;

            float3 fhp;
            float3 normal;
            float3 ffnormal;
            float3 tangent;
            float3 bitangent;

            bool isEmitter;
            bool specularBounce;

            float2 texCoord;
            Material mat;
        };

        struct Ray
        {
            float3 origin;
            float3 direction;
        };

        struct BsdfSampleRec
        {
            float3 L;
            float3 f;
            float pdf;
        };

        float mod(float x, float y) {
            return x - y * floor(x / y);
        }

        float2 mod(float2 x, float y) {
            return x - y * floor(x / y);
        }

        float3 mod(float3 x, float y) {
            return x - y * floor(x / y);
        }

        float4 mod(float4 x, float y) {
            return x - y * floor(x / y);
        }

        #define EPS       0.01

        bool isEqual(float a, float b, float epsilon = 0.00001)
        {
            return abs(a-b) < epsilon;
        }
        
        bool isNotEqual(float a, float b, float epsilon = 0.00001)
        {
            return abs(a-b) > epsilon;
        }
        
        float degrees(float radians)
        {
            return radians * 180.0 / M_PI_F;
        }
        
        float radians(float degrees)
        {
            return degrees * M_PI_F / 180.0;
        }
        
        float4 toGamma(float4 linearColor) {
           return float4(pow(linearColor.xyz, float3(1.0/2.2)), linearColor.w);
        }

        float4 toLinear(float4 gammaColor) {
           return float4(pow(gammaColor.xyz, float3(2.2)), gammaColor.w);
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
        
        float2 translate(float2 p, float2 t)
        {
            return p - t;
        }
        
        float3 translate(float3 p, float3 t)
        {
            return p - t;
        }

        float rand(DataIn dataIn)
        {
            dataIn.seed -= dataIn.randomVector.xy;
            return fract(sin(dot(dataIn.seed, float2(12.9898, 78.233))) * 43758.5453);
        }

        float3 FaceForward(float3 a, float3 b)
        {
            return dot(a, b) < 0.0 ? -b : b;
        }

        float hash13(float3 p3)
        {
            p3  = fract(p3 * .1031);
            p3 += dot(p3, p3.zyx + 31.32);
            return fract((p3.x + p3.y) * p3.z);
        }

        float3 hash31(float p)
        {
            float3 p3 = fract(float3(p) * float3(.1031, .1030, .0973));
            p3 += dot(p3, p3.yzx+33.33);
            return fract((p3.xxy+p3.yzz)*p3.zyx);
        }

        """
    }
}
