//
//  SignedProject.swift
//  Signed
//
//  Created by Markus Moenig on 27/6/21.
//

import Foundation

class SignedProject: Codable {

    private enum CodingKeys: String, CodingKey {
        case objects
    }
    
    /// The objects in the project
    var objects                             : [SignedObject] = []
        
     init() {
        let cameraObject = SignedObject("Camera", role: .Camera, graphPosition: CGPoint(x: 100, y: -100))
        let rendererObject = SignedObject("Renderer", role: .Renderer, graphPosition: CGPoint(x: 100, y: 100))
        let cubeObject = SignedObject("Cube", role: .Object, graphPosition: CGPoint(x: 0, y: 0))

        let cameraComponent = SignedComponent("Camera", role: .Camera, code: "")
        let cubePrimitive = SignedComponent("Cube", role: .Primitive, code: "")
        let rendererComponent = SignedComponent("Renderer", role: .Renderer, code: "")

        cameraObject.components.append(cameraComponent)
        cubeObject.components.append(cubePrimitive)
        rendererObject.components.append(rendererComponent)
        
        objects.append(cameraObject)
        objects.append(cubeObject)
        objects.append(rendererObject)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objects = try container.decode([SignedObject].self, forKey: .objects)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(objects, forKey: .objects)
    }
}
