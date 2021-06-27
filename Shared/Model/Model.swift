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
    @Published var selectedComponent        : SignedComponent? = nil

    /// Send when an object has been selected
    let objectSelected                      = PassthroughSubject<SignedObject, Never>()

    /// Send when an object has been selected
    let componentPreviewNeedsUpdate         = PassthroughSubject<Void, Never>()
    
    /// Reference to the underlying script editor
    var scriptEditor                        : ScriptEditor? = nil

    /// Reference to the renderer
    var renderer                            : RenderPipeline? = nil

    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    
    /// The current preview model
    var previewModel                        : Model? = nil

    override init() {
        project = SignedProject()
        super.init()
    }
    
    func createPreviewCopy(_ objectPreview: SignedObject) -> Model? {
        
        if let data = try? JSONEncoder().encode(project) {
            if let copiedProject = try? JSONDecoder().decode(SignedProject.self, from: data) {
                
                let model = Model()
                model.project = copiedProject
                model.project.previewId = objectPreview.id
                
                return model
            }
        }
        return nil
    }
}
