//
//  Model.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation
import Combine

class Model: NSObject, ObservableObject {

    private enum CodingKeys: String, CodingKey {
        case objects
    }
    
    /// The project itself
    var project                             : SignedProject
    
    @Published var selectedObject           : SignedObject? = nil
    @Published var selectedComponent        : SignedComponent? = nil

    /// Send when an object has been selected
    let objectSelected                      = PassthroughSubject<SignedObject, Never>()

    /// Reference to the underlying script editor
    var scriptEditor                        : ScriptEditor? = nil

    /// Reference to the renderer
    var renderer                            : RenderPipeline? = nil

    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    
    override init() {
        project = SignedProject()
        super.init()
    }
}
