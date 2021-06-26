//
//  Model.swift
//  Signed
//
//  Created by Markus Moenig on 25/6/21.
//

import Foundation
import Combine

class Model: NSObject, ObservableObject {

    /// The objects in the project
    var objects                             : [SignedObject] = []
    
    @Published var selectedObject           : SignedObject? = nil

    /// Send when an object has been selected
    let objectSelected                      = PassthroughSubject<SignedObject, Never>()

    /// Reference to the underlying script editor
    var scriptEditor                        : ScriptEditor? = nil

    /// Reference to the renderer
    var renderer                            : RenderPipeline? = nil

    /// Custom render size
    var renderSize                          : SIMD2<Int>? = nil
    
    override init() {
        super.init()
        let rendererObject = SignedObject("Renderer", role: .Renderer, graphPosition: CGPoint(x: 100, y: 100))
        let cubeObject = SignedObject("Cube", role: .Object, graphPosition: CGPoint(x: 0, y: 0))

        let cubePrimitive = SignedComponent("Cube", role: .Primitive, code: "")
        let rendererPrimitive = SignedComponent("Renderer", role: .Renderer, code: "")

        cubeObject.components.append(cubePrimitive)
        rendererObject.components.append(rendererPrimitive)
        
        objects.append(cubeObject)
        objects.append(rendererObject)
    }
}
