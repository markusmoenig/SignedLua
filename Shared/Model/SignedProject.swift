//
//  SignedProject.swift
//  Signed
//
//  Created by Markus Moenig on 27/6/21.
//

import Foundation
import CoreGraphics

class SignedProject: Codable {

    private enum CodingKeys: String, CodingKey {
        case objects
        case camera
    }
    
    /// The objects in the project
    var objects                             : [SignedObject] = []
    
    var camera                              : SignedPinholeCamera
    
    init() {
        let cubeObject = SignedObject("Cube", graphPosition: CGPoint(x: -100, y: 100))
        let cubePrimitive = SignedCommand("Cube", code: "")

        cubeObject.commands.append(cubePrimitive)
        
        objects.append(cubeObject)
        
        camera = SignedPinholeCamera()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objects = try container.decode([SignedObject].self, forKey: .objects)
        camera = try container.decode(SignedPinholeCamera.self, forKey: .camera)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(objects, forKey: .objects)
        try container.encode(camera, forKey: .camera)
    }
}
