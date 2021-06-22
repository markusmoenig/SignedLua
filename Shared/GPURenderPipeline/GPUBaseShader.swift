//
//  GPUBaseShader.swift
//  Signed
//
//  Created by Markus Moenig on 20/1/21.
//

import MetalKit

class GPUShader
{
    enum ShaderState {
        case Undefined, Compiling, Compiled, Invalid
    }
    
    var id                  : String
    var vertexName          : String
    var fragmentName        : String
    
    //var textureOffset       : Int
    var pixelFormat         : MTLPixelFormat

    var addition            : Bool
    var blending            : Bool
        
    var shaderState         : ShaderState = .Undefined
    
    var pipelineStateDesc   : MTLRenderPipelineDescriptor!
    var pipelineState       : MTLRenderPipelineState!

    var commandQueue        : MTLCommandQueue!
    
    var executionTime       : Double = 0
    
    init(id: String, vertexName: String = "procVertex", fragmentName: String = "procFragment",/* textureOffset: Int, */ pixelFormat: MTLPixelFormat = .rgba16Float, blending: Bool = true, addition: Bool = false)
    {
        self.id = id
        self.vertexName = vertexName
        self.fragmentName = fragmentName
        
        //self.textureOffset = textureOffset
        self.pixelFormat = pixelFormat
        self.blending = blending
        self.addition = addition
    }
}

class GPUBaseShader
{
    var pipelineStateDesc   : MTLRenderPipelineDescriptor!
    var pipelineState       : MTLRenderPipelineState!
    
    var compileTime         : Double = 0
    var executionTime       : Double = 0
    
    var library             : MTLLibrary!

    // Instance Data
    
    var data                : [SIMD4<Float>] = []
    var buffer              : MTLBuffer!
    
    var shaders             : [String:GPUShader] = [:]
    var allShaders          : [GPUShader] = []
    
    var pipeline            : GPURenderPipeline
    var context             : GraphContext

    init(pipeline: GPURenderPipeline)
    {
        self.pipeline = pipeline
        self.context = pipeline.context
        
        data.append(SIMD4<Float>(0, 0,0, 0))
    }
    
    deinit
    {
        shaders = [:]
        allShaders = []
    }
    
    func compile(code: String, shaders: [GPUShader], sync: Bool = false, drawWhenFinished: Bool = false)
    {
        self.shaders = [:]
        allShaders = shaders
        let source = GPUBaseShader.getHeaderCode() + code
        
        let compiledCB : MTLNewLibraryCompletionHandler = { (library, error) in
            if let error = error, library == nil {
                print(error)
            } else
            if let library = library {
                
                self.library = library
                for shader in shaders {
                
                    shader.shaderState = .Compiling
                    
                    //print(shader.id, shader.vertexName, shader.fragmentName, self as? BackgroundShader != nil)
                    
                    shader.pipelineStateDesc = MTLRenderPipelineDescriptor()
                    shader.pipelineStateDesc.vertexFunction = library.makeFunction(name: shader.vertexName)
                    shader.pipelineStateDesc.fragmentFunction = library.makeFunction(name: shader.fragmentName)
                    shader.pipelineStateDesc.colorAttachments[0].pixelFormat = shader.pixelFormat
                    
                    if shader.addition {
                        shader.pipelineStateDesc.colorAttachments[0].isBlendingEnabled = true
                        shader.pipelineStateDesc.colorAttachments[0].rgbBlendOperation = .add
                        shader.pipelineStateDesc.colorAttachments[0].alphaBlendOperation = .add
                        shader.pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = .one
                        shader.pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
                        shader.pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = .one
                        shader.pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = .one
                    } else
                    if shader.blending {
                        shader.pipelineStateDesc.colorAttachments[0].isBlendingEnabled = true
                        shader.pipelineStateDesc.colorAttachments[0].rgbBlendOperation = .add
                        shader.pipelineStateDesc.colorAttachments[0].alphaBlendOperation = .add
                        shader.pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                        shader.pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
                        shader.pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                        shader.pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                    }

                    do {
                        shader.pipelineState = try self.pipeline.device.makeRenderPipelineState(descriptor: shader.pipelineStateDesc)
                    } catch {
                        shader.shaderState = .Undefined
                        self.shaders[shader.id] = nil
                        return
                    }
                    
                    //shader.commandQueue = self.device.makeCommandQueue()
                    shader.shaderState = .Compiled
                    
                    self.shaders[shader.id] = shader
                }
            }
            
            self.pipeline.toCompile -= 1
            
            if self.pipeline.toCompile == 0 {
                self.pipeline.compilationFinished()
            }
        }
        
        pipeline.toCompile += 1
        
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
    
    func createComputeState(name: String) -> MTLComputePipelineState?
    {
        if let library = library {
            let function = library.makeFunction(name: name)
            do {
                let computePipelineState = try pipeline.device.makeComputePipelineState( function: function! )
                return computePipelineState
            } catch {
                print( "computePipelineState failed" )
                return nil
            }
        }
        return nil
    }
    
    func calculateThreadGroups(_ state: MTLComputePipelineState, _ encoder: MTLComputeCommandEncoder,_ width: Int,_ height: Int, store: Bool = false, limitThreads: Bool = false)
    {
        let w = limitThreads ? 1 : state.threadExecutionWidth
        let h = limitThreads ? 1 : state.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        
        //let threadsPerGrid = MTLSize(width: width, height: height, depth: 1)
        //encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

        let threadgroupsPerGrid = MTLSize(width: (width + w - 1) / w, height: (height + h - 1) / h, depth: 1)
                
        print(width, height, threadgroupsPerGrid, threadsPerThreadgroup)
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        /*
        if store {
            self.threadsPerThreadgroup = threadsPerThreadgroup
            self.threadsPerGrid = threadsPerGrid
            self.threadgroupsPerGrid = threadgroupsPerGrid
            
            tWidth = Float(texture.width)
            tHeight = Float(texture.height)
        }*/
    }
    
    
    /// The main render operation of the shader
    func render()
    {
    }
    
    /// Creates vertex shader source code for a quad shader
    static func getQuadVertexSource(name: String = "procVertex") -> String
    {
        let code =
        """

        typedef struct
        {
            float4 clipSpacePosition [[position]];
            float2 textureCoordinate;
            float2 viewportSize;
        } RasterizerData;

        typedef struct
        {
            vector_float2 position;
            vector_float2 textureCoordinate;
        } VertexData;

        // Quad Vertex Function
        vertex RasterizerData
        __NAME__(uint vertexID [[ vertex_id ]],
                     constant VertexData *vertexArray [[ buffer(0) ]],
                     constant vector_uint2 *viewportSizePointer  [[ buffer(1) ]])

        {
            RasterizerData out;
            
            float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
            float2 viewportSize = float2(*viewportSizePointer);
            
            out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize / 2.0);
            out.clipSpacePosition.z = 0.0;
            out.clipSpacePosition.w = 1.0;
            
            out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
            out.viewportSize = viewportSize;

            return out;
        }

        """

        return code.replacingOccurrences(of: "__NAME__", with: name)
    }
    
    /// Creates a vertex buffer for a quad shader
    func getQuadVertexBuffer(_ rect: MMRect ) -> MTLBuffer?
    {
        let left = -rect.width / 2 + rect.x
        let right = left + rect.width//self.width / 2 - x
        
        let top = rect.height / 2 - rect.y
        let bottom = top - rect.height
        
        let quadVertices: [Float] = [
            right, bottom, 1.0, 0.0,
            left, bottom, 0.0, 0.0,
            left, top, 0.0, 1.0,
            
            right, bottom, 1.0, 0.0,
            left, top, 0.0, 1.0,
            right, top, 1.0, 1.0,
            ]
        
        return pipeline.device.makeBuffer(bytes: quadVertices, length: quadVertices.count * MemoryLayout<Float>.stride, options: [])!
    }
    
    /// Creates a vertex buffer for a quad shader
    func getQuadVertexData(_ rect: MMRect ) -> [Float]
    {
        let left = -rect.width / 2 + rect.x
        let right = left + rect.width//self.width / 2 - x
        
        let top = rect.height / 2 - rect.y
        let bottom = top - rect.height
        
        let quadVertices: [Float] = [
            right, bottom, 1.0, 0.0,
            left, bottom, 0.0, 0.0,
            left, top, 0.0, 1.0,
            
            right, bottom, 1.0, 0.0,
            left, top, 0.0, 1.0,
            right, top, 1.0, 1.0,
            ]
        
        return quadVertices
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
