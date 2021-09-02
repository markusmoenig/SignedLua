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
        case shapes, objects, materials, settings
    }
    
    let model                                           : Model
    
    @State var mode                                     : Mode? = .shapes
    @State var updateView                               : Bool = false
        
    var body: some View {
                
        GeometryReader { geometry in

            VStack(alignment: .center, spacing: 0) {
                HStack {
                    
                    Spacer()
                    
                    Button(action: {
                        mode = .shapes
                    })
                    {
                        Image(systemName: mode == .shapes ? "cube.fill" : "cube")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        mode = .objects
                    })
                    {
                        Image(systemName: mode == .objects ? "house.fill" : "house")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        mode = .materials
                    })
                    {
                        Image(systemName: mode == .materials ? "paintpalette.fill" : "paintpalette")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        mode = .settings
                    })
                    {
                        Image(systemName: mode == .settings ? "gearshape.fill" : "gearshape")
                            .imageScale(.large)
                        Spacer()
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.leading, 6)
                .padding(.bottom, 6)
                .frame(alignment: .center)

                Divider()
                
                /*
                if mode == .shape {
                    //DataViews(model: model, data: getShapeGroups(), bottomPadding: 12)
                } else
                if mode == .material {
                    //DataViews(model: model, data: [model.editingCmd.material.libraryData, model.editingCmd.material.data], bottomPadding: 0)
                } else
                if mode == .javascript {
                    WebView(model, deviceColorScheme)
                        .onChange(of: deviceColorScheme) { newValue in
                            model.codeEditor?.setTheme(newValue)
                        }            }
                if mode == .camera {
                    DataView(model: model, data: model.project.camera.data)
                } else
                if mode == .settings {
                    DataViews(model: model, data: getProjectSettingGroups(), bottomPadding: 12)
                }*/
                
                VStack {
                    if mode == .shapes {
                        ShapeView(model: model)
                    } else
                    if mode == .objects {
                        ObjectView(model: model)
                    } else
                    if mode == .materials {
                        MaterialView(model: model)
                    } else
                    if mode == .settings {
                        DataViews(model: model, data: getSettingsGroups(), bottomPadding: 12)
                            .padding(.top, 4)
                    }
                    
                    InfoView(model: model)
                }
            }
        }
        
        //.onReceive(self.document.model.updateUI) { _ in
        //    updateView.toggle()
        //}
        
        /*/
        .onReceive(model.shapeSelected) { shape in
            mode = .camera
            mode = .shape
        }
        
        .onReceive(model.materialSelected) { shape in
            mode = .camera
            mode = .material
        }*/
    }
    
    /// Get the settings groups
    func getSettingsGroups() -> [SignedData]
    {
        return [model.project.dataGroups.getGroup("Renderer")!]
    }
}
