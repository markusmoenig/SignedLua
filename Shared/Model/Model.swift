//
//  Model.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation
import Combine
import AVFoundation
import MetalKit

class Model: NSObject, ObservableObject {
    
    enum SignedProgress {
        case none, modelling, rendering
    }
    
    enum RenderType {
        case pbr, bsdf
    }
    
    enum CodeEditorMode {
        case project
        case object
        case material
        case module
    }
    
    var codeEditorMode                      : CodeEditorMode = .project
    var cameraMode                          : ModelerKit.Content = .project

    // The entity the code editor is editing at the moment
    var codeEditorObjectEntity              : ObjectEntity? = nil
    var codeEditorMaterialEntity            : MaterialEntity? = nil
    var codeEditorModuleEntity              : ModuleEntity? = nil

    /// The project itself
    var project                             : SignedProject
    
    // The builder class
    var builder                             : SignedBuilder!
    
    /// Currently selected project object
    var selectedObject                      : SignedObject? = nil
    
    /// Currently selected project material
    var selectedMaterial                    : SignedCommand? = nil
    
    /// The selection has changed
    let selectionChanged                    = PassthroughSubject<Void, Never>()
    
    /// Currently selected shape in the browser
    var selectedShape                       : SignedCommand? = nil

    /// Currently selected object in the db
    var selectedDBObject                    : ObjectEntity? = nil
    
    /// Currently selected material in the db
    var selectedDBMaterial                  : MaterialEntity? = nil
    
    /// Send when the camera mode changed
    let cameraModeChanged                   = PassthroughSubject<ModelerKit.Content, Never>()

    /// Send when an command has been selected
    let commandSelected                     = PassthroughSubject<SignedCommand, Never>()
    
    /// Send when a shape  has been selected
    let shapeSelected                       = PassthroughSubject<SignedCommand, Never>()
    
    /// Send when a material  has been selected
    let materialSelected                    = PassthroughSubject<SignedCommand, Never>()
    
    /// Send when a db object has been selected
    let dbObjectSelected                    = PassthroughSubject<ObjectEntity, Never>()
    
    /// Send when a db material has been selected
    let dbMaterialSelected                  = PassthroughSubject<MaterialEntity, Never>()
    
    /// Send when an icon for  an entity has been rendered
    let iconFinished                        = PassthroughSubject<UUID, Never>()
    
    /// Send when the icon in the side view should be deselected
    let deselectSideViewIcon                = PassthroughSubject<Void, Never>()
    
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
    
    /// Send when the current  progress changed
    let progressChanged                     = PassthroughSubject<Void, Never>()
    
    /// Send when modelling is starting
    let modellingStarted                    = PassthroughSubject<Void, Never>()
    /// Send when modelling is finished
    let modellingEnded                      = PassthroughSubject<Void, Never>()
    
    /// Send when help is showh (or not)
    let showHelpTopic                       = PassthroughSubject<HelpContentView.HelpTopic, Never>()
    
    /// Reference to the underlying code editor
    var codeEditor                          : CodeEditor? = nil

    /// Reference to the current renderView
    var renderView                          : STKView!
    
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
    ///
    var progress                            : SignedProgress = .none

    var progressValue                       : Double = 0    
    var progressCurrent                     : Int32 = 0
    var progressTotal                       : Int32 = 0
    
    /// Shows the bounding box
    var showBBox                            : Int32 = 0
    
    /// renderName (User setting)
    var renderName                          = "renderPBR"
    var renderType                          : RenderType = .pbr
    
    /// Current renderer
    var currentRenderName                   = "renderPBR"
    
    /// Polygonization
    var polygoniser                         : ModelerPolygonise? = nil
    var objData                             : Data!
    var mtlData                             : Data!

    let polygonisationEnded                 = PassthroughSubject<Void, Never>()

    /// Current help topic
    var currentHelpTopic                    : HelpContentView.HelpTopic = .none
    
    override init() {
        project = SignedProject()
        super.init()
        
        builder = SignedBuilder(self)

        iconCmd.action = .None
        
        createShapes()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shapeSelected.send(self.selectedShape!)
            self.progressChanged.send()
        }
        
        checkForMaterials()
        checkForModules()
    }
    
    func setProject(_ project: SignedProject) {
        self.project = project
    }
    
    /// Sets the renderer
    func setRenderView(_ renderView: STKView)
    {
        self.renderView = renderView
        if renderer == nil {
            renderer = RenderPipeline(self)
            
            self.renderer?.iconQueue += shapes
            self.renderer?.installNextShapeIconCmd(shapes.first)
        }
        renderView.renderer = renderer
    }
    
    /// Initialises the currently available shapes
    func createShapes() {
        shapes = [
            //SignedCommand("Heightfield", role: .GeometryAndMaterial, action: .Add, primitive: .Heightfield,  data: ["Geometry": SignedData([SignedDataEntity("frequency", Float(2), float2(0, 20)), SignedDataEntity("octaves", Float(5), float2(0, 20)), SignedDataEntity("scale", Float(0.2), float2(0, 20))])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5))),
            SignedCommand("Sphere", role: .GeometryAndMaterial, action: .Add, primitive: .Sphere, data: ["Geometry": SignedData([SignedDataEntity("radius", Float(0.35), float2(0, 5), .Slider, .None, "Radius of the sphere.")])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5))),
            SignedCommand("Box", role: .GeometryAndMaterial, action: .Add, primitive: .Box, data: ["Geometry": SignedData([SignedDataEntity("size", float3(0.065,0.065,0.065) * 7, float2(0,10), .Slider, .None, "Size of the box."), SignedDataEntity("rounding", Float(0.0), float2(0,1), .Slider, .None, "Rounding of the box.")])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5))),
            SignedCommand("Cylinder", role: .GeometryAndMaterial, action: .Add, primitive: .Cylinder, data: ["Geometry": SignedData([SignedDataEntity("height", Float(0.2), float2(0, 5), .Slider, .None, "Height of the cylinder."), SignedDataEntity("radius", Float(0.14), float2(0, 5), .Slider, .None, "Radius of the cylinder."), SignedDataEntity("rounding", Float(0), float2(0, 1), .Slider, .None, "Height of the cylinder.")])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5))),
        ]
        selectedShape = shapes.first
        
        shapeSelected.send(selectedShape!)
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
            self.progressChanged.send()
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
    
    /// Gets the renderType for the given ModelerKit
    func getRenderType(kit: ModelerKit) -> RenderType {
        var type : RenderType = .pbr
        
        type = renderType
        
        return type
    }
    
    /// Get the renderer name for the given ModelerKit
    func getRenderName(kit: ModelerKit) -> String {        
        switch getRenderType(kit: kit) {
        case .bsdf:
            return "renderBSDF"
        default:
            return "renderPBR"
        }
    }
}
