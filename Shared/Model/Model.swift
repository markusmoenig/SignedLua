//
//  Model.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation
import Combine
import AVFoundation

class Model: NSObject, ObservableObject {
    
    enum CodeEditorMode {
        case project
        case object
        case material
        case module
    }
    
    var codeEditorMode                      : CodeEditorMode = .project
    
    // The entity the code editor is editing at the moment
    var codeEditorObjectEntity              : ObjectEntity? = nil
    var codeEditorMaterialEntity            : MaterialEntity? = nil
    var codeEditorModuleEntity              : ModuleEntity? = nil

    /// The project itself
    var project                             : SignedProject
    
    // The builder class
    var builder                             : SignedBuilder!
    
    var selectedObject                      : SignedObject? = nil
    var selectedCommand                     : SignedCommand? = nil

    /// The selection has changed
    let selectionChanged                    = PassthroughSubject<Void, Never>()
    
    /// Currently selected shape in the browser
    var selectedShape                       : SignedCommand? = nil

    /// Currently selected shape in the browser
    var selectedMaterial                    : SignedCommand? = nil
    
    /// Send when an object has been selected
    let objectSelected                      = PassthroughSubject<SignedObject, Never>()

    /// Send when an command has been selected
    let commandSelected                     = PassthroughSubject<SignedCommand, Never>()
    
    /// Send when a shape  has been selected
    let shapeSelected                       = PassthroughSubject<SignedCommand, Never>()
    
    /// Send when a material  has been selected
    let materialSelected                    = PassthroughSubject<SignedCommand, Never>()
    
    /// Send when an icon for  an entity has been rendered
    let iconFinished                        = PassthroughSubject<UUID, Never>()
    
    /// Editing cmd changed, update the UI
    let modelChanged                        = PassthroughSubject<Void, Never>()
    
    /// UIs of the DataViews needs to be updated
    let updateDataViews                     = PassthroughSubject<Void, Never>()
    
    /// Update UIs
    let updateUI                            = PassthroughSubject<Void, Never>()
    
    /// Send when the info changed and the UI has to be updated
    let infoChanged                        = PassthroughSubject<Void, Never>()
    
    /// Send when the modules were downloaded successfully
    let modulesArrived                      = PassthroughSubject<Void, Never>()
    
    /// Send when showing modeling progress
    let modelingProgressChanged             = PassthroughSubject<String, Never>()
    
    /// Reference to the underlying code editor
    var codeEditor                          : CodeEditor? = nil

    /// Reference to the renderer
    var renderer                            : RenderPipeline? = nil
    var modeler                             : ModelerPipeline? = nil

    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    
    /// The currently supported shapes
    var shapes                              : [SignedCommand] = []
    
    /// Icon cmd to render the shape previews
    var iconCmd                             = SignedCommand()
    
    /// Info text
    var infoText                            : String = ""
    
    /// True if the public modules were downloaded and are available
    var modulesAreAvailable                 : Bool = false

    /// The modeling progress
    var infoProgressValue                   : Double = 0
    
    var infoProgressProcessedCmds           : Int32 = 0
    var infoProgressTotalCmds               : Int32 = 0
    
    override init() {
        project = SignedProject()
        super.init()
        
        builder = SignedBuilder(self)

        iconCmd.action = .None
        
        createShapes()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shapeSelected.send(self.selectedShape!)
            self.modelingProgressChanged.send("Waiting for modules...")
        }
        
        checkForMaterials()
        checkForModules()
    }
    
    func setProject(_ project: SignedProject) {
        self.project = project
    }
    
    /// Sets the renderer
    func setRenderer(_ renderer: RenderPipeline?)
    {
        self.renderer = renderer
        self.renderer?.iconQueue += shapes
        self.renderer?.installNextShapeIconCmd(shapes.first)
    }
    
    /// Initialises the currently available shapes
    func createShapes() {
        shapes = [
            SignedCommand("Heightfield", role: .GeometryAndMaterial, action: .Add, primitive: .Heightfield,  data: ["Geometry": SignedData([SignedDataEntity("frequency", Float(2), float2(0, 20)), SignedDataEntity("octaves", Float(5), float2(0, 20)), SignedDataEntity("scale", Float(0.2), float2(0, 20))])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5))),
            SignedCommand("Sphere", role: .GeometryAndMaterial, action: .Add, primitive: .Sphere, data: ["Geometry": SignedData([SignedDataEntity("radius", Float(0.22), float2(0, 5))])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5))),
            SignedCommand("Box", role: .GeometryAndMaterial, action: .Add, primitive: .Box, data: ["Geometry": SignedData([SignedDataEntity("size", float3(0.3,0.3,0.3), float2(0,10), .Slider), SignedDataEntity("rounding", Float(0.0), float2(0,1))])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5)))
        ]
        selectedShape = shapes.first
    }
        
    /// Initialises the inbuilt materials
    func checkForMaterials() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let request = MaterialEntity.fetchRequest()
            
            let managedObjectContext = PersistenceController.shared.container.viewContext
            let materials = try! managedObjectContext.fetch(request)
            
            if materials.count == 0 {
                self.checkForMaterials()
                return
            }
        }
    }
    
    /// Wait to receive the public modules and enable building after that
    func checkForModules() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let request = ModuleEntity.fetchRequest()
            
            let managedObjectContext = PersistenceController.shared.container.viewContext
            let objects = try! managedObjectContext.fetch(request)
            
            if objects.count == 0 {
                self.checkForModules()
                return
            }
            
            self.modulesAreAvailable = true
            self.modulesArrived.send()
            self.modelingProgressChanged.send("Ready")
            //self.infoChanged.send()
        }
    }
    
    /// Returns the shape of the given name
    func getShape(_ name: String) -> SignedCommand?
    {
        for s in shapes {
            if s.name == name {
                return s
            }
        }
        return nil
    }
    
    /// A SignedData entity of the given group name has been changed. Reset the pathtracer.
    func updateSelectedGroup(groupName: String) {
        renderer?.restart()
    }
    
    /// Get the object of the given name
    func getObject(name: String = "main") -> SignedObject? {
        for o in project.objects {
            if o.name == name {
                return o
            }
        }
        return nil
    }
    
    /// Get the code string  of the given object
    func getObjectCode(name: String = "main") -> String {
        for o in project.objects {
            if o.name == name {
                if let code = o.code {
                    if let value = String(data: code, encoding: .utf8) {
                        return value
                    }
                }
            }
        }
        return ""
    }
    
    ///  Get an object entity of the given name
    func getObjectEntity(name: String) -> ObjectEntity? {
        
        let request = ObjectEntity.fetchRequest()
        
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let objects = try! managedObjectContext.fetch(request)

        for object in objects {
            if object.name == name {
                return object
            }
        }

        return nil
    }
    
    ///  Gets the material entity of the given name
    func getMaterialEntity(name: String) -> MaterialEntity? {
        
        let request = MaterialEntity.fetchRequest()
        
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let materials = try! managedObjectContext.fetch(request)

        for material in materials {
            if material.name == name {
                return material
            }
        }

        return nil
    }
}
