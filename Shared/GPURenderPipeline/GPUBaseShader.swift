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
        
        /*
        for shader in shaders {
            let funcDataCode =
            """

            float GlobalTime = __data[0].x;
            float GlobalSeed = __data[0].z;
            
            struct FuncData __funcData_;
            thread struct FuncData *__funcData = &__funcData_;
            __funcData_.GlobalTime = GlobalTime;
            __funcData_.GlobalSeed = GlobalSeed;
            __funcData_.inShape = float4(1000, 1000, -1, -1);
            __funcData_.hash = 1.0;

            {
                float2 uv = float2(uv.x, uv.y);
                //__funcData_.seed = fract(cos((uv.xy+uv.yx * float2(1000.0,1000.0) ) + float2(__data[0].z, __data[0].w)*10.0));
                __funcData_.GlobalSeed = float(baseHash(as_type<uint2>(uv - (float2(__data[0].z, __data[0].w) * 100.0) )))/float(0xffffffffU);
            }
            __funcData_.__data = __data;

            __\(shader.id)_TEXTURE_ASSIGNMENT_CODE__

            """

            //textureRep.append((shader.id, shader.textureOffset))
            //source = source.replacingOccurrences(of: "__\(shader.id)_INITIALIZE_FUNC_DATA__", with: funcDataCode)
        }*/
        //source = replaceTexturReferences(sourceCode: source)
        
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
                
                /*
                if self as? ObjectShader != nil || self as? GroundShader != nil || self as? TerrainShader != nil || self as? BackgroundShader != nil {
                    DispatchQueue.main.async {
                        globalApp!.currentEditor.render()
                        globalApp!.mmView.update()
                    }
                }
                
                if drawWhenFinished {
                    DispatchQueue.main.async {
                        globalApp!.mmView.update()
                    }
                }
                */
            }
        }
        
        //print(source)
        if sync == false {
            pipeline.device.makeLibrary( source: source, options: nil, completionHandler: compiledCB)
        } else {
            do {
                let library = try pipeline.device.makeLibrary( source: source, options: nil)
                compiledCB(library, nil)
            } catch {
                print(error)
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
    
    /*
    func shadowPass(texture: MTLTexture)
    {
    }
    
    func materialPass(texture: MTLTexture)
    {
    }
    
    func reflectionPass(texture: MTLTexture)
    {
    }
    
    func reflectionMaterialPass(texture: MTLTexture)
    {
    }
    
    func createFragmentUniform() -> ObjectFragmentUniforms
    {
        var fragmentUniforms = ObjectFragmentUniforms()

        fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
        fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
        fragmentUniforms.screenSize = prtInstance.screenSize
        if let ambient = getGlobalVariableValue(withName: "World.worldAmbient") {
            fragmentUniforms.ambientColor = ambient
        }
        
        return fragmentUniforms
    }
    
    /// Apply the textures used in CodeComponents to the MTLRenderEncoder
    func applyUserFragmentTextures(shader: Shader, encoder: MTLRenderCommandEncoder)
    {
        var offset : Int = shader.textureOffset
        for t in textures {
            for texture in globalApp!.images {
                if texture.0 == t.0 {
                    encoder.setFragmentTexture(texture.1, index: offset)
                    offset += 1
                    break
                }
            }
        }
    }
    
    func createLightCode(scene: Scene) -> String
    {
        let lightStage = scene.getStage(.LightStage)

        var headerCode = ""

        for (index,l) in lightStage.children3D.enumerated() {
            if let light = l.components[l.defaultName] {
                dryRunComponent(light, data.count)
                collectProperties(light)
                if let globalCode = light.globalCode {
                    headerCode += globalCode
                }

                var code =
                """

                float4 light\(index)(float3 lightPosition, float3 position, thread struct FuncData *__funcData )
                {
                    float4 outColor = float4(0);

                    constant float4 *__data = __funcData->__data;
                    float GlobalTime = __funcData->GlobalTime;
                    float GlobalSeed = __funcData->GlobalSeed;
                    __CREATE_TEXTURE_DEFINITIONS__

                """
                
                code += light.code!
                
                code +=
                """

                    return outColor;
                }
                
                """
                
                headerCode += code
            }
        }
        
        return headerCode
    }
    
    /// Update the instance data
    func updateData()
    {
        let timeline = globalApp!.artistEditor.timeline
        
        var time : Float

        // Timeline Playback
        time = (Float(timeline.currentFrame) * 1000/60) / 1000
        
        data[0].x = time
                
        //inst.data[0].z = 1
        //inst.data[0].w = 1

        for property in properties {
            
            let dataIndex = property.3
            let component = property.4

            if property.0 != nil
            {
                // Property, stored in the CodeFragments
                
                let isToolProperty : Bool = property.2 != nil && property.1 != nil
                
                let data = isToolProperty ? SIMD4<Float>(property.1!.values[property.2!]!,0,0,0) : extractValueFromFragment(property.1!)
                let components = isToolProperty ? 1 : property.1!.evaluateComponents()
                
                // Transform the properties inside the artist editor
                
                let name = isToolProperty ? property.2! : property.0!.name
                var properties : [String:Float] = [:]
                
                if components == 1 {
                    properties[name] = data.x
                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    
                    var value = transformed[name]!
                    if let velocity = velocity, elasticity > 0 {
                        
                        let direct = elasticity / 10
                        let indirect = direct / 2

                        if name == "height" {
                            value = value - Float(velocity.y) * direct
                            
                            value = value + Float(velocity.x) * indirect
                            value = value + Float(velocity.z) * indirect
                            
                            value = max(0.01, value)
                        }
                        
                        if name == "width" {
                            value = value - Float(velocity.x) * direct

                            value = value + Float(velocity.y) * indirect
                            value = value + Float(velocity.z) * indirect
                            
                            value = max(0.01, value)
                        }
                        
                        if name == "depth" {
                            value = value - Float(velocity.z) * direct

                            value = value + Float(velocity.x) * indirect
                            value = value + Float(velocity.y) * indirect
                            
                            value = max(0.01, value)
                        }
                    }
                    self.data[dataIndex].x = value
                } else
                if components == 2 {
                    properties[name + "_x"] = data.x
                    properties[name + "_y"] = data.y
                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    self.data[dataIndex].x = transformed[name + "_x"]!
                    self.data[dataIndex].y = transformed[name + "_y"]!
                } else
                if components == 3 {
                    properties[name + "_x"] = data.x
                    properties[name + "_y"] = data.y
                    properties[name + "_z"] = data.z
                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    self.data[dataIndex].x = transformed[name + "_x"]!
                    self.data[dataIndex].y = transformed[name + "_y"]!
                    self.data[dataIndex].z = transformed[name + "_z"]!
                } else
                if components == 4 {
                    properties[name + "_x"] = data.x
                    properties[name + "_y"] = data.y
                    properties[name + "_z"] = data.z
                    properties[name + "_w"] = data.w
                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    self.data[dataIndex].x = transformed[name + "_x"]!
                    self.data[dataIndex].y = transformed[name + "_y"]!
                    self.data[dataIndex].z = transformed[name + "_z"]!
                    self.data[dataIndex].w = transformed[name + "_w"]!
                }
                if globalApp!.currentEditor === globalApp!.artistEditor {
                    globalApp!.artistEditor.designProperties.updateTransformedProperty(component: property.4, name: name, data: self.data[dataIndex])
                }
                if components == 4 {
                    // For colors, convert them to sRGB for rendering
                    self.data[dataIndex].x = pow(self.data[dataIndex].x, 2.2)
                    self.data[dataIndex].y = pow(self.data[dataIndex].y, 2.2)
                    self.data[dataIndex].z = pow(self.data[dataIndex].z, 2.2)
                }
            } else
            if let name = property.2 {
                // Transform property, stored in the values of the component
                
                // Recursively add the parent values for this transform
                var parentValue : Float = 0
                
                for stageItem in property.5.reversed() {
                    if let transComponent = stageItem.components[stageItem.defaultName] {
                        // Transform
                        var properties : [String:Float] = [:]
                        
                        if let value = transComponent.values[name] {
                            properties[name] = value
                            
                            let transformed = timeline.transformProperties(sequence: transComponent.sequence, uuid: transComponent.uuid, properties: properties, frame: timeline.currentFrame)
                            
                            parentValue += transformed[name]!
                        }
                    }
                }
                
                var properties : [String:Float] = [:]
                if let value = component.values[name] {
                    properties[name] = value
                    
                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    
                    if component.componentType != .Transform2D && component.componentType != .Transform3D {
                        self.data[dataIndex].x = transformed[name]! + parentValue
                    } else {
                        // Transforms do not get their parent values, these are added by hand in the shader for the pivot
                        self.data[dataIndex].x = transformed[name]!
                    }
                }
            }
        }
        
        if buffer != nil {
            buffer!.setPurgeableState(.empty)
            buffer = nil
        }
        
        buffer = device.makeBuffer(bytes: self.data, length: self.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
    }
    
    func buildDepthStencilState() -> MTLDepthStencilState?
    {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState( descriptor: descriptor)
    }
    
    /// Adds a global variable to the instance data
    func addGlobalVariable(name: String) -> Int?
    {
        let globalVars = globalApp!.project.selected!.getStage(.VariablePool).getGlobalVariable()
        if let variableComp = globalVars[name] {
            
            for uuid in variableComp.properties {
                let rc = variableComp.getPropertyOfUUID(uuid)
                if rc.0!.values["variable"] == 1 {
                    let index = data.count
                    properties.append((rc.0, rc.1, nil, data.count, variableComp, []))
                    data.append(SIMD4<Float>(rc.1!.values["value"]!,0,0,0))
                    return index
                }
            }
        }
        
        return nil
    }
    
    /// Collects properties from the component to the instance data
    func collectProperties(_ component: CodeComponent,_ hierarchy: [StageItem] = [])
    {
        // Collect properties and globalVariables
        for (index,uuid) in component.inputDataList.enumerated() {
            let propComponent = component.inputComponentList[index]
            if propComponent.properties.contains(uuid) {
                // Normal property
                let rc = propComponent.getPropertyOfUUID(uuid)
                if rc.0 != nil && rc.1 != nil {
                    properties.append((rc.0, rc.1, nil, data.count, propComponent, hierarchy))
                    data.append(SIMD4<Float>(rc.1!.values["value"]!,0,0,0))
                }
            } else
            if let tool = propComponent.toolPropertyIndex[uuid] {
                // Tool property, tool.0 is the name of fragment value
                for t in tool {
                    properties.append((t.1, t.1, t.0, data.count, propComponent, hierarchy))
                    data.append(SIMD4<Float>(t.1.values[t.0]!,0,0,0))
                }
            } else
            if let variableComp = component.globalVariables[uuid] {
                // Global Variable, Extract the CodeFragment from the VariableComponent
                for uuid in variableComp.properties {
                    let rc = variableComp.getPropertyOfUUID(uuid)
                    if rc.0!.values["variable"] == 1 {
                        properties.append((rc.0, rc.1, nil, data.count, variableComp, []))
                        data.append(SIMD4<Float>(rc.1!.values["value"]!,0,0,0))
                    }
                }
            }
        }
        
        // Collect transforms, stored in the values map of the component
        if component.componentType == .SDF2D || component.componentType == .Transform2D {
            properties.append((nil, nil, "_posX", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_posY", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            
            if component.values["2DIn3D"] == 1 {
                properties.append((nil, nil, "_posZ", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_rotateX", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_rotateY", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_rotateZ", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_extrusion", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_revolution", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_rounding", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
            } else {
                properties.append((nil, nil, "_rotate", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
            }
        } else
        if component.componentType == .SDF3D || component.componentType == .Transform3D {
            properties.append((nil, nil, "_posX", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_posY", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_posZ", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_rotateX", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_rotateY", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_rotateZ", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            if component.values["_bb_x"] != nil {
                properties.append((nil, nil, "_bb_x", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_bb_y", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_bb_z", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
            }
        }
        
        // Scaling on the transforms
        if component.componentType == .Transform2D || component.componentType == .Transform3D {
            if component.values["_scale"] == nil { component.values["_scale"] = 1 }
            properties.append((nil, nil, "_scale", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
        }
        
        // Add the textures
        textures += component.textures
    }
    
    /// Gets the instance data index for the transform property name of the given component
    func getTransformPropertyIndex(_ component: CodeComponent,_ name: String) -> Int
    {
        for property in properties {
            if let propertyName = property.2 {
                if propertyName == name && property.4 === component {
                    return property.3
                }
            }
        }
        print("property", name, "not found")
        return 0
    }*/
    
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
    
    /*
    /// Inserts the texture code into the source code
    func insertTextureCode(sourceCode: String, startOffset: Int, id: String) -> String
    {
        // Replace
        var code = ""
        
        for (index, t) in textures.enumerated() {
            code += "texture2d<half, access::sample>     \(t.1) [[texture(\(index + startOffset))]], \n"
            //print(t.0, index + startOffset)
        }

        var changed = sourceCode.replacingOccurrences(of: "__\(id)_TEXTURE_HEADER_CODE__", with: code)

        changed = changed.replacingOccurrences(of: "__\(id)_AFTER_TEXTURE_OFFSET__", with: String(startOffset + textures.count))
        //print("__AFTER_TEXTURE_OFFSET__", startOffset + instance.textures.count)

        code = ""
        if textures.count > 0 {
            code = "constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);\n"
        }
        for t in textures{
            code += "__funcData->\(t.1) = \(t.1);\n"
        }
        
        changed = changed.replacingOccurrences(of: "__\(id)_TEXTURE_ASSIGNMENT_CODE__", with: code)
        return changed
    }
    
    /// Inserts the texture references into the source code
    func replaceTexturReferences(sourceCode: String) -> String
    {
        var replacedSource = sourceCode
        
        for tR in textureRep {
            replacedSource = insertTextureCode(sourceCode: replacedSource, startOffset: tR.1, id: tR.0)
        }
        
        var code = replacedSource
        
        // __FuncData structure and texture definitions
        var funcData = ""
        var textureDefs = ""//constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);\n"

        for t in textures {
            funcData += "texture2d<half, access::sample> " + t.1 + ";"
            textureDefs += "texture2d<half, access::sample> " + t.1 + " = __funcData->\(t.1);\n"
        }

        code = code.replacingOccurrences(of: "__FUNCDATA_TEXTURE_LIST__", with: funcData)
        code = code.replacingOccurrences(of: "__CREATE_TEXTURE_DEFINITIONS__", with: textureDefs)
        
        return code
    }
    
    /// Sphere contact code with this shader
    func sphereContacts(objectSpheres: [ObjectSpheres3D])
    {
        if sphereContactsState == nil {
            sphereContactsState = createComputeState(name: "sphereContacts")
        }
         
        if let state = sphereContactsState {
                         
            updateData()
             
            var sphereUniforms = SphereUniforms()
            
            var sphereData : [float4] = []
            
            for oS in objectSpheres {
                for s in oS.transSpheres {
                    sphereData.append(s)
                }
            }
            
            if sphereData.count == 0 {
                return
            }
            
            let commandQueue = device.makeCommandQueue()
            let commandBuffer = commandQueue!.makeCommandBuffer()!
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
             
            computeEncoder.setComputePipelineState( state )
            computeEncoder.setBuffer(buffer, offset: 0, index: 0)
            
            sphereUniforms.numberOfSpheres = Int32(sphereData.count)
            
            let inBuffer = device.makeBuffer(bytes: sphereData, length: sphereData.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            computeEncoder.setBuffer(inBuffer, offset: 0, index: 1)

            let outBuffer = device.makeBuffer(length: sphereData.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            computeEncoder.setBuffer(outBuffer, offset: 0, index: 2)
            
            computeEncoder.setBytes(&sphereUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 3)

            let numThreadgroups = MTLSize(width: 1, height: 1, depth: 1)
            let threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
            computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
             
            computeEncoder.endEncoding()
            commandBuffer.commit()
             
            commandBuffer.waitUntilCompleted()
             
            let result = outBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: 1)
            
            var index : Int = 0
            for oS in objectSpheres {
                for (ii,s) in oS.transSpheres.enumerated() {
                    
                    if result[index].w < 0 {
                        let penetration = -result[index].w
                        let hitNormal = float3(result[index].x, result[index].y, result[index].z)
                        let contactPoint = float3(s.x, s.y, s.z) + -hitNormal * (s.w - penetration)
                    
                        oS.sphereHits[ii] = true
                        
                        let contact = RigidBody3DContact(body: [oS.body3D, nil], contactPoint: _Vector3(contactPoint), normal: _Vector3(hitNormal), penetration: Double(penetration))
                        if let restitution = oS.object.components[oS.object.defaultName]!.values["restitution"] {
                            contact.restitution = Double(restitution)
                        }
                        if let friction = oS.object.components[oS.object.defaultName]!.values["friction"] {
                            contact.friction = Double(friction)
                        }
                        oS.world!.contacts.append(contact)
                    }
                    index += 1
                }
            }
        }
    }*/
    
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
            float3 extinction;
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
            int rayType;

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
            float3 bsdfDir;
            float  pdf;
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

        #define PI        3.14159265358979323
        #define TWO_PI    6.28318530717958648
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
            return radians * 180.0 / PI;
        }
        
        float radians(float degrees)
        {
            return degrees * PI / 180.0;
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

        """
    }
}
