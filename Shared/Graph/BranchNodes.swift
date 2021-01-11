//
//  GraphBranchNodes.swift
//  Signed
//
//  Created by Markus Moenig on 13/12/20.
//

import Foundation

/// Distance Base Node
class DistanceNode         : GraphNode
{
    var position      : Float3 = Float3(0,0,0)
    var rotation      : Float3 = Float3(0,0,0)
    var scale         : Float1 = Float1(0)
    
    func verifyTranslationOptions(context: GraphContext, error: inout CompileError) {
        if let value = extractFloat3Value(options, container: context, error: &error, name: "position", isOptional: true) {
            position = value
        }
        if let value = extractFloat3Value(options, container: context, error: &error, name: "rotation", isOptional: true) {
            rotation = value
        }
        if let value = extractFloat1Value(options, container: context, error: &error, name: "scale", isOptional: true) {
            scale = value
        }
    }
    
    static func getObjectOptions() -> [GraphOption]
    {
        return [
            GraphOption(Float3(0,0,0), "Position", "The position of the object. If this is a child object the position is relative to it's parent.")
        ]
    }
    
    static func getSDFOptions() -> [GraphOption]
    {
        return [
            GraphOption(Float3(0,0,0), "Position", "The position of the SDF relative to it's parent object.")
        ]
    }
}

/// SDFObject
final class SDFObject : DistanceNode
{
    var maxBox        : Float3? = nil
    
    var maxBufferRo   = float3(0,0,0)
    var maxBufferRd   = float3(0,0,0)
    var maxBuffer     = false

    var positionStore : Float3!
    
    var materialName  : String? = nil

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .SDF, options)
        name = "sdfObject"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let name = options["name"] as? String {
            self.givenName = name.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        } else {
            self.givenName = "SDF Object"
        }
        if let materialName = options["materialname"] as? String {
            self.materialName = materialName.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        }
        if let value = extractFloat3Value(options, container: context, error: &error, name: "maxbox", isOptional: true) {
            maxBox = value
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position += position.toSIMD()
        
        var processIt = true
        
        if maxBox != nil {
            if maxBufferRo == context.camOrigin && maxBufferRd == context.rayDir {
                processIt = maxBuffer
            } else
            if intersect(context, maxDimensions: maxBox!.toSIMD3()) == false {
                processIt = false
            }
        }
            
        if processIt {
            if let materialName = materialName {
                context.activeMaterial = context.getMaterial(materialName)
                if let material = context.activeMaterial as? MaterialNode {
                    if material.hasDisplacement {
                        material.onlyDisplacement = true
                        material.execute(context: context)
                        material.onlyDisplacement = false
                    }
                }
            } else {
                context.activeMaterial = nil
                context.displacement.fromSIMD(0)
            }
            
            for leave in leaves {
                leave.execute(context: context)
            }
        }
        context.position -= position.toSIMD()
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Defines an SDF Object. SDF objects contain lists of SDF primitives and booleans and can also contain child objects."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Text1("Object"), "Name", "The name of the object.")
        ]
        return options + DistanceNode.getObjectOptions()
    }
    
    func intersect(_ context: GraphContext, maxDimensions: float3) -> Bool
    {
        let ro = context.camOrigin
        let rd = context.rayDir
        
        maxBufferRo = ro
        maxBufferRd = rd

        let bounds = [position.toSIMD() - maxDimensions / 2, position.toSIMD() + maxDimensions / 2]
        
        var tmin : Float = 0
        var tmax : Float = 0
        
        var tymin : Float = 0
        var tymax : Float = 0
        var tzmin : Float = 0
        var tzmax : Float = 0

        if (rd.x >= 0.0) {
            tmin = (bounds[0].x - ro.x) / rd.x;
            tmax = (bounds[1].x - ro.x) / rd.x;
        }
        else {
            tmin = (bounds[1].x - ro.x) / rd.x;
            tmax = (bounds[0].x - ro.x) / rd.x;
        }

        if (rd.y >= 0.0) {
            tymin = (bounds[0].y - ro.y) / rd.y;
            tymax = (bounds[1].y - ro.y) / rd.y;
        }
        else {
            tymin = (bounds[1].y - ro.y) / rd.y;
            tymax = (bounds[0].y - ro.y) / rd.y;
        }

        if ( (tmin > tymax) || (tymin > tmax) ) {
            maxBuffer = false
            return false
        }

        if (tymin > tmin) {
            tmin = tymin
        }
        if (tymax < tmax) {
            tmax = tymax
        }

        if (rd.z >= 0.0 ) {
            tzmin = (bounds[0].z - ro.z) / rd.z;
            tzmax = (bounds[1].z - ro.z) / rd.z;
        }
        else {
            tzmin = (bounds[1].z - ro.z) / rd.z;
            tzmax = (bounds[0].z - ro.z) / rd.z;
        }

        if ( (tmin > tzmax) || (tzmin > tmax) ) {
            maxBuffer = false
            return false
        }

        /*
        if (tzmin > tmin)
            tmin = tzmin;
        if (tzmax < tmax)
            tmax = tzmax;
        */

        //return tmin < tmax;
        maxBuffer = true
        return true
    }
}

/// AnalyticalObject
final class AnalyticalObject : DistanceNode
{
    var positionStore : Float3!

    var materialName  : String? = nil

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Analytical, options)
        name = "analyticalObject"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        verifyTranslationOptions(context: context, error: &error)
        if let name = options["name"] as? String {
            self.givenName = name.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        } else {
            self.givenName = "Analytical Object"
        }
        if let materialName = options["materialname"] as? String {
            self.materialName = materialName.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        context.position += position.toSIMD()
        
        if let materialName = materialName {
            context.activeMaterial = context.getMaterial(materialName)
        } else {
            context.activeMaterial = nil
        }
        
        for leave in leaves {
            leave.execute(context: context)
        }
        context.position -= position.toSIMD()
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Defines an analytical object. Analytical objects contain lists of analytical primitives can also contain child objects."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Text1("Object"), "Name", "The name of the object.")
        ]
        return options + DistanceNode.getObjectOptions()
    }
}

/// MaterialNode
final class MaterialNode : GraphNode
{
    /// Material has displacement
    var hasDisplacement  : Bool = false

    /// Material should only output displacement
    var onlyDisplacement : Bool = false

    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Material, options)
        name = "Material"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let name = options["name"] as? String {
            self.givenName = name.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        } else {
            error.error = "Material needs a 'Name' parameter"
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        let buffer = context.variables["outColor"]
        if onlyDisplacement {
            context.variables["outColor"] = Float4()
        }
        for leave in leaves {
            leave.execute(context: context)
        }
        context.variables["outColor"] = buffer
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Defines an Material."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Text1("Material"), "Name", "The name of the material.")
        ]
        return options
    }
}

/// RenderNode
final class RenderNode : GraphNode
{
    init(_ options: [String:Any] = [:])
    {
        super.init(.Utility, .Render, options)
        name = "Render"
        leaves = []
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        if let name = options["name"] as? String {
            self.givenName = name.replacingOccurrences(of: "\"", with: "", options: NSString.CompareOptions.literal, range: nil)
        } else {
            error.error = "Render node needs a 'Name' parameter"
        }
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        for leave in leaves {
            leave.execute(context: context)
        }
        return .Success
    }
    
    override func getHelp() -> String
    {
        return "Renders the scene."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Text1("Render"), "Name", "The name of the render node.")
        ]
        return options
    }
}
