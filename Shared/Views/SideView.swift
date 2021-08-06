//
//  SideView.swift
//  Signed
//
//  Created by Markus Moenig on 29/6/21.
//

import SwiftUI

struct SideView: View {
    
    @Environment(\.colorScheme) var deviceColorScheme   : ColorScheme

    enum Mode {
        case shape, material, camera, javascript, settings
    }
    
    let model                               : Model
    
    @State var mode                         : Mode? = .shape
    @State var selection                    : SignedObject? = nil
        
    var body: some View {
                
        VStack(alignment: .leading) {
            HStack {
                
                Button(action: {
                    mode = .shape
                })
                {
                    Image(systemName: mode == .shape ? "cube.fill" : "cube")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)

                Button(action: {
                    mode = .material
                })
                {
                    Image(systemName: mode == .material ? "paintpalette.fill" : "paintpalette")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)

                Button(action: {
                    mode = .javascript
                })
                {
                    Image(systemName: mode == .javascript ? "j.square.fill" : "j.square")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    mode = .camera
                })
                {
                    Image(systemName: mode == .camera ? "camera.fill" : "camera")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    mode = .settings
                })
                {
                    Image(systemName: mode == .settings ? "gearshape.fill" : "gearshape")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                
            }
            .padding(.top, 6)
            .padding(.leading, 6)
            
            Divider()            
            
            if mode == .shape {
                DataViews(model: model, data: getShapeGroups())
            } else
            if mode == .material {
                DataView(model: model, data: model.editingCmd.material.data)
            } else
            if mode == .javascript {
                WebView(model, deviceColorScheme)
                    .onChange(of: deviceColorScheme) { newValue in
                        model.scriptEditor?.setTheme(newValue)
                    }            }
            if mode == .camera {
                DataView(model: model, data: model.project.camera.data)
            } else
            if mode == .settings {
                DataViews(model: model, data: getProjectSettingGroups())
            }
            
            Spacer()
            
            Divider()
            
            StackView(model: model)
                .frame(maxHeight: 100)
                .padding(0)
        }
        
        .onReceive(model.shapeSelected) { shape in
            mode = .camera
            mode = .shape
        }
        
        .onReceive(model.materialSelected) { shape in
            mode = .camera
            mode = .material
        }
    }
    
    /// Returns the data groups for this shape
    func getShapeGroups() -> [SignedData] {
        var views : [SignedData] = []

        if let transformData = model.editingCmd.dataGroups.getGroup("Transform") {
            views.append(transformData)
        }
        if let geometryData = model.editingCmd.dataGroups.getGroup("Geometry") {
            views.append(geometryData)
        }
        if let modifierData = model.editingCmd.dataGroups.getGroup("Modifier") {
            views.append(modifierData)
        }
        if let booleanData = model.editingCmd.dataGroups.getGroup("Boolean") {
            views.append(booleanData)
        }
        return views
    }
    
    /// Returns the project settings groups
    func getProjectSettingGroups() -> [SignedData] {
        var views : [SignedData] = []

        if let worldData = model.project.dataGroups.getGroup("World") {
            views.append(worldData)
        }
        if let rendererdData = model.project.dataGroups.getGroup("Renderer") {
            views.append(rendererdData)
        }
        return views
    }
}
