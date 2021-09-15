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
        case main
        case objects
        case materials
        case modules
        case camera
        case dataGroups
        case resolution
        case pixelsPerMeter
    }
    
    var main                                : SignedObject
    
    /// The objects in the project
    var objects                             : [SignedObject] = []
    
    /// The materials in the project
    var materials                           : [SignedObject] = []
    
    /// The modules in the project
    var modules                             : [SignedObject] = []
    
    /// Camera
    var camera                              : SignedPinholeCamera
    var objectCamera                        = SignedPinholeCamera("Object Camera", .object)
    var materialCamera                      = SignedPinholeCamera("Material Camera", .material)

    /// Resolution of the 3D texture
    var resolution                          = Int(512)
    
    /// How many pixels per meter
    var pixelsPerMeter                      = Int(100)
    
    /// Project settings data groups
    var dataGroups                          : SignedDataGroups
    
    init() {        
        camera = SignedPinholeCamera()
        dataGroups = SignedDataGroups()
        
        main = SignedObject("main")
        
        initDataGroups()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        main = try container.decode(SignedObject.self, forKey: .main)
        objects = try container.decode([SignedObject].self, forKey: .objects)
        materials = try container.decode([SignedObject].self, forKey: .materials)
        modules = try container.decode([SignedObject].self, forKey: .modules)
        camera = try container.decode(SignedPinholeCamera.self, forKey: .camera)
        dataGroups = try container.decode(SignedDataGroups.self, forKey: .dataGroups)
        resolution = try container.decode(Int.self, forKey: .resolution)
        pixelsPerMeter = try container.decode(Int.self, forKey: .pixelsPerMeter)
        //dataGroups.groups["Renderer"]!.set("Background", float4(0.25, 0.25, 0.25, 1.0))
        if let rendererData = dataGroups.groups["Renderer"] {
            rendererData.removeEntity("background")
            rendererData.removeEntity("reflections")
        }
        initDataGroups()
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(main, forKey: .main)
        try container.encode(objects, forKey: .objects)
        try container.encode(materials, forKey: .materials)
        try container.encode(modules, forKey: .modules)
        try container.encode(camera, forKey: .camera)
        try container.encode(dataGroups, forKey: .dataGroups)
        try container.encode(resolution, forKey: .resolution)
        try container.encode(pixelsPerMeter, forKey: .pixelsPerMeter)
    }
    
    /// Initializes the data groups with default values, or, when already exists, make sure all options are present
    func initDataGroups(fromConstructor: Bool = false) {
            
        //addDataGroup(name: "World", entities: [
        //    SignedDataEntity("scale", Int(3), float2(1, 10), .Slider),
        //])
        
        addDataGroup(name: "Renderer", entities: [
            SignedDataEntity("Background", float4(0.25,0.25,0.25,1.0), float2(0, 1), .Color),
            SignedDataEntity("Reflections", Int(6), float2(1, 20), .Slider),
            SignedDataEntity("Samples", Int(400), float2(1, 10000), .Slider),
        ])
        
        addDataGroup(name: "Sun", entities: [
            SignedDataEntity("Sun Position", float3(0, 100, -100), float2(0, 1000), .Numeric),
            SignedDataEntity("Sun Emission", float3(4, 4, 4), float2(0, 1000), .Numeric),
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
    
    /// Returns the object of the given uuid
    func getObject(from: UUID) -> SignedObject? {
        if main.id == from {
            return main
        }
        for o in objects {
            if o.id == from {
                return o
            }
        }
        for o in materials {
            if o.id == from {
                return o
            }
        }
        for o in modules {
            if o.id == from {
                return o
            }
        }
        return nil
    }
    
    /// Returns the type of the given object id
    func getObjectType(from: UUID) -> SignedObject.Role {
        if main.id == from {
            return .main
        }
        for o in objects {
            if o.id == from {
                return .object
            }
        }
        for o in materials {
            if o.id == from {
                return .material
            }
        }
        for o in modules {
            if o.id == from {
                return .module
            }
        }
        return .main
    }
    
    /// Get the maximum amount of samples
    func getMaxSamples() -> Int32 {
        if let renderData = dataGroups.getGroup("Renderer") {
            return Int32(renderData.getInt("Samples", 400))
        }
        return 400
    }
}
