//
//  RenderStates.swift
//  Signed
//
//  Created by Markus Moenig on 28/6/21.
//

import MetalKit

class RenderStates {
    
    var defaultLibrary          : MTLLibrary!

    let pipelineStateDescriptor : MTLRenderPipelineDescriptor
    
    var states                  : [String: MTLRenderPipelineState] = [:]
    var computeStates           : [String: MTLComputePipelineState] = [:]

    let device                  : MTLDevice
    
    init(_ device: MTLDevice)
    {
        self.device = device
        
        defaultLibrary = device.makeDefaultLibrary()
        pipelineStateDescriptor = MTLRenderPipelineDescriptor()

        if let defaultLibrary = defaultLibrary {

            let vertexFunction = defaultLibrary.makeFunction( name: "renderQuadVertexShader" )

            pipelineStateDescriptor.vertexFunction = vertexFunction
            //        pipelineStateDescriptor.fragmentFunction = fragmentFunction
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.rgba16Float;
            
            pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            computeStates["renderBSDF"] = createComputeState(name: "renderBSDF")
            computeStates["renderPBR"] = createComputeState(name: "renderPBR")
            computeStates["renderAccum"] = createComputeState(name: "renderAccum")
            //states["render"] = createQuadState(name: "render")
        }
    }
    
    /// Creates a quad state from an optional library and the function name
    func createQuadState( library: MTLLibrary? = nil, name: String ) -> MTLRenderPipelineState?
    {
        let function : MTLFunction?
            
        if library != nil {
            function = library!.makeFunction( name: name )
        } else {
            function = defaultLibrary!.makeFunction( name: name )
        }
        
        var renderPipelineState : MTLRenderPipelineState?
        
        do {
            //renderPipelineState = try device.makeComputePipelineState( function: function! )
            pipelineStateDescriptor.fragmentFunction = function
            renderPipelineState = try device.makeRenderPipelineState( descriptor: pipelineStateDescriptor )
        } catch {
            print( "computePipelineState failed" )
            return nil
        }
        
        return renderPipelineState
    }
    
    /// Creates a compute state from an optional library and the function name
    func createComputeState( library: MTLLibrary? = nil, name: String ) -> MTLComputePipelineState?
    {
        let function : MTLFunction?
            
        if library != nil {
            function = library!.makeFunction( name: name )
        } else {
            function = defaultLibrary!.makeFunction( name: name )
        }
        
        var computePipelineState : MTLComputePipelineState?
        
        if function == nil {
            return nil
        }
        
        do {
            computePipelineState = try device.makeComputePipelineState( function: function! )
        } catch {
            print( "computePipelineState failed" )
            return nil
        }

        return computePipelineState
    }
    
    func getState(stateName: String) -> MTLRenderPipelineState?
    {
        return states[stateName]
    }
    
    func getComputeState(stateName: String) -> MTLComputePipelineState?
    {
        return computeStates[stateName]
    }
}
