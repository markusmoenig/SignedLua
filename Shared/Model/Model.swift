//
//  Model.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation
import Combine

class Model: NSObject, ObservableObject {
    
    /// The project itself
    var project                             : SignedProject
    
    @Published var selectedObject           : SignedObject? = nil
    @Published var selectedCommand          : SignedCommand? = nil

    /// Currently selected shape in the browser
    @Published var selectedShape            : SignedCommand? = nil

    /// Send when an object has been selected
    let objectSelected                      = PassthroughSubject<SignedObject, Never>()

    /// Send when an command has been selected
    let commandSelected                     = PassthroughSubject<SignedCommand, Never>()
    
    /// Send when a shape  has been selected
    let shapeSelected                       = PassthroughSubject<SignedCommand, Never>()
    
    /// Send when an icon for  a cmd has been rendered
    let iconFinished                        = PassthroughSubject<SignedCommand, Never>()
    
    /// Reference to the underlying script editor
    var scriptEditor                        : ScriptEditor? = nil

    /// Reference to the renderer
    var renderer                            : RenderPipeline? = nil
    var modeler                             : ModelerPipeline? = nil

    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    
    /// The currently supported shapes
    var shapes                              : [SignedCommand] = []
    
    override init() {
        project = SignedProject()
        super.init()
        
        selectedObject = project.objects.first
        
        createShapes()
    }
    
    /// Sets the renderer
    func setRenderer(_ renderer: RenderPipeline?)
    {
        self.renderer = renderer
        self.renderer?.iconQueue += shapes
        self.modeler?.executeCommand(shapes.first!, self.modeler?.iconKit, clearFirst: true)
    }
    
    /// Initialises the currently available shapes
    func createShapes() {
        shapes = [
            SignedCommand("Sphere", role: .Geometry, action: .Add, primitive: .Sphere, data: SignedData([SignedDataEntity("Position", float3(0,0,0)), SignedDataEntity("Radius", Float(0.4))]), material: SignedMaterial(albedo: float3(0.5,0.5,0.5))),
            SignedCommand("Box", role: .Geometry, action: .Add, primitive: .Box, data: SignedData([SignedDataEntity("Position", float3(0,0,0)), SignedDataEntity("Size", float3(0.2,0.2,0.2))]))
        ]
        selectedShape = shapes.first
    }
}
