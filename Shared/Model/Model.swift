//
//  Model.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation
import Combine

class Model: NSObject, ObservableObject {
    
    enum EditingMode {
        case single
        case multiple
    }
    
    enum EditingBooleanMode {
        case plus
        case minus
    }
    
    enum EditingBrushMode {
        case GeometryAndMaterial
        case MaterialOnly
    }
    
    var editingMode                         : EditingMode? = .single
    var editingBrushMode                    : EditingBrushMode? = .GeometryAndMaterial
    var editingBooleanMode                  : EditingBooleanMode? = .plus

    /// The project itself
    var project                             : SignedProject
    
    var selectedObject                      : SignedObject? = nil
    var selectedCommand                     : SignedCommand? = nil

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
    
    /// Send when an icon for  a cmd has been rendered
    let iconFinished                        = PassthroughSubject<SignedCommand, Never>()
    
    /// Editing cmd changed, update the UI
    let editingCmdChanged                   = PassthroughSubject<SignedCommand, Never>()
    
    /// UIs of the DataViews needs to be updated
    let updateDataViews                     = PassthroughSubject<Void, Never>()
    
    /// Update UIs
    let updateUI                            = PassthroughSubject<Void, Never>()
    
    /// Reference to the underlying script editor
    var scriptEditor                        : ScriptEditor? = nil
    
    /// The script handler
    var scriptHandler                       : ScriptHandler!

    /// Reference to the renderer
    var renderer                            : RenderPipeline? = nil
    var modeler                             : ModelerPipeline? = nil

    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    
    /// The currently supported shapes
    var shapes                              : [SignedCommand] = []
    
    /// Material library
    var materials                           : [UUID: SignedCommand] = [:]
    
    /// The current editing command
    var editingCmd                          = SignedCommand()
    var iconCmd                             = SignedCommand()
    
    /// Set to the current hit position of the mouse cursor
    var editingHit                          = float3()
    
    /// The current modeling action is a write (currenrtly unused as no brush painting is allowed)
    var writeAction                         : Int32 = 0
    
    /// The current materialOnlyMixer
    var materialOnlyMixer                   : Float = 0.5

    override init() {
        project = SignedProject()
        super.init()
        
        scriptHandler = ScriptHandler(self)

        selectedObject = project.objects.first
        
        editingCmd.action = .None
        iconCmd.action = .None
        
        createShapes()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shapeSelected.send(self.selectedShape!)
        }
    }
    
    /// Sets the renderer
    func setRenderer(_ renderer: RenderPipeline?)
    {
        self.renderer = renderer
        self.renderer?.iconQueue += shapes
        createMaterials()
        //self.renderer?.iconQueue += materials
        self.renderer?.installNextIconCmd(shapes.first)
        
        editingCmd.copyGeometry(from: shapes.first!)
        editingCmd.action = .None
    }
    
    /// Initialises the currently available shapes
    func createShapes() {
        shapes = [
            SignedCommand("Sphere", role: .GeometryAndMaterial, action: .Add, primitive: .Sphere, data: ["Geometry": SignedData([SignedDataEntity("Radius", Float(0.4), float2(0, 5))])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5))),
            SignedCommand("Box", role: .GeometryAndMaterial, action: .Add, primitive: .Box, data: ["Geometry": SignedData([SignedDataEntity("Size", float3(0.3,0.3,0.3), float2(0,10), .Slider), SignedDataEntity("Rounding", Float(0.01), float2(0,1))])], material: SignedMaterial(albedo: float3(0.5,0.5,0.5)))
        ]
        selectedShape = shapes.first
    }
    
    /// Initialises the inbuilt materials
    func createMaterials() {        
        let request = MaterialEntity.fetchRequest()
        
        let managedObjectContext = PersistenceController.shared.container.viewContext
        let objects = try! managedObjectContext.fetch(request)

        objects.forEach { object in
            
            let material = try? JSONDecoder().decode(SignedMaterial.self, from: object.data!)

            let cmd = SignedCommand(object.name!, role: .GeometryAndMaterial, action: .Add, primitive: .Sphere, data: ["Geometry": SignedData([SignedDataEntity("Radius", Float(0.4))])], material: material!)
            
            materials[object.id!] = cmd
            self.renderer?.iconQueue += [cmd]
        }
    }
    
    // A SignedData entity of the given group name has been changed. Reset the pathtracer.
    func updateSelectedGroup(groupName: String) {
        renderer?.restart()
    }
    
    /// Returns the next available geometry id
    func getNextGeometryId() -> Int {
        var id : Int = 0
        if let object = selectedObject {
            for c in object.commands {
                if c.role == .GeometryAndMaterial {
                    id += 1
                }
            }
        }
        return id - 1
    }
}
