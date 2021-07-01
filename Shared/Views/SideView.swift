//
//  SideView.swift
//  Signed
//
//  Created by Markus Moenig on 29/6/21.
//

import SwiftUI

struct SideView: View {
    
    enum Mode {
        case shape, camera, settings
    }
    
    let model                               : Model
    
    @State var mode                         : Mode? = .camera

    @State var selection                    : SignedObject? = nil
    
    
    var body: some View {
                
        VStack(alignment: .leading) {
            HStack {
                
                Button(action: {
                    mode = .shape
                })
                {
                    Image(systemName: mode == .shape ? "square.fill" : "square")
                }
                .buttonStyle(.borderless)

                Button(action: {
                    mode = .camera
                })
                {
                    Image(systemName: mode == .camera ? "camera.fill" : "camera")
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    mode = .settings
                })
                {
                    Image(systemName: mode == .settings ? "gearshape.fill" : "gearshape")
                }
                .buttonStyle(.borderless)
                
            }
            .padding(.top, 4)
            
            Divider()            
            
            if mode == .shape {
                DataView(model: model, data: model.selectedShape!.data)
            } else
            if mode == .settings {
                SettingsView(model: model)
            }
            
            Spacer()
            
            Divider()
            
            StackView(model: model)
                .frame(maxHeight: 100)
        }
        
        
        .onReceive(model.shapeSelected) { shape in
            mode = .camera
            mode = .shape
        }
    }
}
