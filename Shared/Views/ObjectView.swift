//
//  ObjectView.swift
//  Signed
//
//  Created by Markus Moenig on 27/6/21.
//

import SwiftUI

struct ObjectView: View {
    
    let model                               : Model
    
    @State var selection                    : SignedObject? = nil
    
    var body: some View {
                
        VStack {
            HStack {

                if let selected = selection {
                    if selected.role == .Random {
                        if let previewModel = createPreviewCopy(selected) {
                            RenderView(model: previewModel)
                            //EditorView(model)
                        }
                    }
                }
                EditorView(model)
            }
        }
        
        .onReceive(model.componentPreviewNeedsUpdate) { _ in
            if let previewModel = model.previewModel {
                print("needs update")
                previewModel.renderer?.compilePreview()
                previewModel.renderer?.updateOnce()
            }
        }
        
        .onReceive(model.objectSelected) { object in
            selection = object
            model.selectedObject = object
            model.selectedComponent = object.components.first
            if let component = model.selectedComponent {
                model.scriptEditor?.setComponentSession(component)
            }
        }
    }
    
    func createPreviewCopy(_ object: SignedObject) -> Model? {
        model.previewModel = model.createPreviewCopy(object)
        return model.previewModel
    }
}
