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
                        RenderView(model: model, component: selected.components[0])
                        //EditorView(model)
                    }
                }
                EditorView(model)
            }
        }
        
        .onReceive(model.componentPreviewNeedsUpdate) { _ in
            if let renderer = model.previewRenderer {
                renderer.compileComponent()
                renderer.render()
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
}
