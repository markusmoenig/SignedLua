//
//  GraphAnalyticalNodes.swift
//  Signed
//
//  Created by Markus Moenig on 16/12/20.
//

import Foundation
import simd

/// Analytical  Ground Plane
final class GraphAnalyticalGroundPlaneNode : GraphTransformationNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Analytical, options)
        name = "analyticalGroundPlane"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {

        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {        
        let code =
        """

        float groundT = (0.0 - rayOrigin.y) / rayDir.y;
        if (groundT > 0.0) {
            analyticalMap = float4(groundT, 0, -1, \(context.getMaterialIndex()));
            analyticalNormal = float3(0,1,0);
        }

        """
                
        return code
    }
    
    override func getHelp() -> String
    {
        return "Creates a ground plane."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0,1,0), "Normal", "The normal defines the orientation of the plane.")
        ]
        return options + GraphTransformationNode.getTransformationOptions()
    }
}

/// Analytical Dome
final class GraphAnalyticalDomeNode : GraphTransformationNode
{
    var radius                  : Float1 = Float1(20)
    var ceilingMaterialName     : String? = nil

    
    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Analytical, options)
        name = "analyticalDome"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let value = extractFloat1Value(options, container: context, error: &error, name: "radius", isOptional: true) {
            radius = value
        }
        if let ceilingMaterial = options["ceilingmaterial"] as? String {
            ceilingMaterialName = ceilingMaterial.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position = position.toSIMD()
        
        if let index = position.dataIndex, index < context.data.count {
            context.data[index] = float4(context.position.x, context.position.y, context.position.z, 0)
        }
        
        if let index = radius.dataIndex, index < context.data.count {
            context.data[index] = radius.toSIMD4()
        }
        
        context.position -= position.toSIMD()
        
        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {
        context.addDataVariable(position)
        context.addDataVariable(radius)
        
        let materialIndex = context.getMaterialIndex()
        var ceilingMaterialIndex = materialIndex
        if let ceilingMaterialName = ceilingMaterialName {
            if let ceilingMateral = context.getMaterial(ceilingMaterialName) {
                ceilingMaterialIndex = String(ceilingMateral.index!)
            }
        }
        
        let code =
        """
        
        float3 center = dataIn.data[\(position.dataIndex!)].xyz;
        float radius = dataIn.data[\(radius.dataIndex!)].x;
        
        float3 L = rayOrigin - center;
        float B = dot(rayDir, L);
        float C = dot(L,L) - radius * radius;
        float det = B * B - C;
        float I = sqrt(det) - B;
        float3 hitP = rayOrigin + rayDir * I;
        
        if (I > 0) {
            analyticalMap = float4(I, 0, -1, \(ceilingMaterialIndex));
            analyticalNormal = -normalize(hitP - center);
        }

        float groundT = (0.0 - rayOrigin.y) / rayDir.y;
        if (groundT > 0.0 && groundT < I) {
            analyticalMap = float4(groundT, 0, -1, \(materialIndex));
            analyticalNormal = float3(0,1,0);
        }

        """
                
        return code
    }
    
    override func getHelp() -> String
    {
        return "Creates a ground plane."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float3(0,1,0), "Normal", "The normal defines the orientation of the plane.")
        ]
        return options + GraphTransformationNode.getTransformationOptions()
    }
}

