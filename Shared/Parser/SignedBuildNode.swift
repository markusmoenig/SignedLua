//
//  SignedObjectNode.swift
//  Signed
//
//  Created by Markus Moenig on 12/8/2564 BE.
//

import Foundation

class SignedBuildNode : SignedNode {
    
    init() {
        super.init(role: .Build)
    }
    
    override func verifyArguments(parser: SignedParser, str: String, error: inout CodeError) {
        name = "build"
    }
    
    override func execute(context: SignedContext) {
        super.execute(context: context)
                
        
        for i in 0...10 {
        
            let cmd = SignedCommand("Brick", role: .GeometryAndMaterial, action: .Add, primitive: .Box,
                                    data: ["Transform" : SignedData([SignedDataEntity("Position", float3(Float(i) * 0.042,0,0)) ]),
                                                  "Geometry": SignedData([SignedDataEntity("Size", float3(0.2,0.08,0.15)), SignedDataEntity("Rounding", 0)])
                                                 ], material: SignedMaterial(albedo: float3(0.5,0.5,0.5), metallic: 1, roughness: 0.3))
            
            context.addToPipeline(cmd: cmd)
        }
    }
}
