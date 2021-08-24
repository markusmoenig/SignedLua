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
        case camera
        case dataGroups
        case objects
    }
    
    /// The objects in the project
    var objects                             : [SignedObject] = []
    
    /// Camera
    var camera                              : SignedPinholeCamera
    
    /// Project settings data groups
    var dataGroups                          : SignedDataGroups
    
    init() {
        let object = SignedObject("main")
        objects.append(object)
        
        camera = SignedPinholeCamera()
        dataGroups = SignedDataGroups()
        
        initDataGroups()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objects = try container.decode([SignedObject].self, forKey: .objects)
        camera = try container.decode(SignedPinholeCamera.self, forKey: .camera)
        dataGroups = try container.decode(SignedDataGroups.self, forKey: .dataGroups)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(objects, forKey: .objects)
        try container.encode(camera, forKey: .camera)
        try container.encode(dataGroups, forKey: .dataGroups)
    }
    
    /// Initializes the data groups with default values, or, when already exists, make sure all options are present
    func initDataGroups(fromConstructor: Bool = false) {
            
        addDataGroup(name: "World", entities: [
            SignedDataEntity("Scale", Int(3), float2(1, 10), .Slider),
        ])
        
        addDataGroup(name: "Renderer", entities: [
            SignedDataEntity("Background", float4(0.55,0.55,0.85,1.0), float2(0, 1), .Color),
            SignedDataEntity("Reflections", Int(6), float2(1, 20), .Slider),
        ])
    }
    
    /// Creates or adds the given entities to the new or existing group. This way we can dynamically add new options to existing projects.
    func addDataGroup(name: String, entities: [SignedDataEntity]) {
        let group = dataGroups.getGroup(name)
        if let group = group {
            // If group exists, make sure all entities are present

            for e in entities {
                if group.exists(e.key) == false {
                    group.data.append(e)
                }
            }
        } else {
            // If group does not exist add it
            dataGroups.addGroup(name, SignedData(entities))
        }
    }
    
    /// Returns the world scale, i.e. the scale of the 3D texture
    func getWorldScale() -> Float {
        if let worldData = dataGroups.getGroup("World") {
            return Float(worldData.getInt("Scale", 3))
        }
        return 3
    }
}
