//
//  SideView.swift
//  Signed
//
//  Created by Markus Moenig on 29/6/21.
//

import SwiftUI

struct SideView: View {
    
    enum Mode {
        case Camera, Settings
    }
    
    let model                               : Model
    
    @State var mode                         : Mode? = .Camera

    @State var selection                    : SignedObject? = nil
    
    
    var body: some View {
                
        VStack(alignment: .leading) {
            HStack {

                Button(action: {
                    mode = .Camera
                })
                {
                    Image(systemName: mode == .Camera ? "camera.fill" : "camera")
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    mode = .Settings
                })
                {
                    Image(systemName: mode == .Settings ? "gearshape.fill" : "gearshape")
                }
                .buttonStyle(.borderless)
                
            }
            .padding(.top, 4)
            
            Divider()            
            
            if mode == .Settings {
                SettingsView(model: model)
            }
            
            Spacer()
            
        }
        
        .onReceive(model.componentPreviewNeedsUpdate) { _ in
        }
        
        .onReceive(model.objectSelected) { object in
            selection = object
            model.selectedObject = object
            model.selectedCommand = object.commands.first
            if let component = model.selectedCommand {
                model.scriptEditor?.setComponentSession(component)
            }
        }
    }
}
