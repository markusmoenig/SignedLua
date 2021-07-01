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

    /// Send when an object has been selected
    let objectSelected                      = PassthroughSubject<SignedObject, Never>()

    /// Send when an command has been selected
    let commandSelected                     = PassthroughSubject<SignedCommand, Never>()
    
    /// Reference to the underlying script editor
    var scriptEditor                        : ScriptEditor? = nil

    /// Reference to the renderer
    var renderer                            : RenderPipeline? = nil
    var modeler                             : ModelerPipeline? = nil

    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    
    /// The currently supported shapes
    var shapes                              : [SignedShape] = []
    
    override init() {
        project = SignedProject()
        super.init()
        
        selectedObject = project.objects.first
        
        createShapes()
    }
    
    func createShapes() {
        shapes = [SignedShape("Sphere"), SignedShape("Box")]

    }
}
