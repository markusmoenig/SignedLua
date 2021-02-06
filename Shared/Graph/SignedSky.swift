//
//  SignedSky.swift
//  Signed
//
//  Created by Markus Moenig on 24/1/21.
//

import Foundation

/// DefaultSkyNode
final class GraphDefaultSkyNode : GraphNode
{
    var sunDirection       : Float3 = Float3(0.243, 0.075, 0.512)
    var sunColor           : Float3 = Float3(0.966, 0.966, 0.966)
    var worldHorizonColor  : Float3 = Float3(0.852, 0.591, 0.367)
    var sunStrength        : Float1 = Float1(5)

    init(_ options: [String:Any] = [:])
    {
        super.init(.Sky, .None, options)
        name = "DefaultSky"
        givenName = "Default Sky"
    }
    
    override func verifyOptions(context: GraphContext, error: inout CompileError) {
        //if let value = extractFloat1Value(options, context: context, error: &error, name: "radius", isOptional: true) {
        //    radius = value
        //}
    }
    
    @discardableResult @inlinable public override func execute(context: GraphContext) -> Result
    {
        if let index = sunDirection.dataIndex, index < context.data.count {
            context.data[index] = sunDirection.toSIMD4()
        }
        
        if let index = sunColor.dataIndex, index < context.data.count {
            context.data[index] = sunColor.toSIMD4()
        }
        
        if let index = worldHorizonColor.dataIndex, index < context.data.count {
            context.data[index] = worldHorizonColor.toSIMD4()
        }

        return .Success
    }
    
    /// Returns the metal code for this node
    override func generateMetalCode(context: GraphContext) -> String
    {        
        context.addDataVariable(sunDirection)
        context.addDataVariable(sunColor)
        context.addDataVariable(worldHorizonColor)
        //context.addDataVariable(sunStrength)

        let code =
        """
        
        // rayDir
        // outColor

        float3 sunDir = dataIn.data[\(sunDirection.dataIndex!)].xyz;
        float3 skyColor = float3(0.38, 0.6, 1.0);
        float3 sunColor = dataIn.data[\(sunColor.dataIndex!)].xyz;
        float3 horizonColor = dataIn.data[\(worldHorizonColor.dataIndex!)].xyz;

        //skyColor = pow(skyColor, 1 / 2.2);
        //sunColor = pow(sunColor, 1 / 2.2);
        //horizonColor = pow(horizonColor, 1 / 2.2);

        float sun = max(dot(rayDir, normalize(sunDir)), 0.0);
        float hor = pow(1.0 - max(rayDir.y, 0.0), 3.0);
        float3 col = mix(skyColor, sunColor, sun * float3(0.5, 0.5, 0.5));
        col = mix(col, horizonColor, float3(hor, hor, hor));
        
        col += 0.25 * float3(1.0, 0.7, 0.4) * pow(sun, 5.0);
        col += 0.25 * float3(1.0, 0.8, 0.6) * pow(sun, 5.0);
        col += 0.15 * float3(1.0, 0.9, 0.7) * max(pow(sun, 512.0), 0.25);

        outColor = float4(col, 1);//float4(pow(col, 2.2),1);

        """
                
        return code
    }
    
    override func getHelp() -> String
    {
        return "Creates a sphere of a given radius."
    }
    
    override func getOptions() -> [GraphOption]
    {
        let options = [
            GraphOption(Float1(1), "Radius", "The radius of the sphere.")
        ]
        return options
    }
}
