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
                        
                        TextureSizeView(model)
                        Divider()
                        
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

/// The 3D texture details
struct TextureSizeView: View {
    
    let model                                           : Model
    
    // For Numeric
    @State private var xText                            : String = ""
    @State private var yText                            : String = ""
    @State private var zText                            : String = ""
    @State private var pixelPerMeterText                : String = ""

    init(_ model: Model) {
        self.model = model
                    
        _xText = State(initialValue: String(model.project.resolution.x))
        _yText = State(initialValue: String(model.project.resolution.y))
        _zText = State(initialValue: String(model.project.resolution.z))
        _pixelPerMeterText = State(initialValue: String(model.project.pixelsPerMeter))
    }
    
    var body: some View {
                
        VStack(alignment: .leading) {
            Text("3D Texture Size")
                .padding(.leading, 4)
            HStack {
                TextField("", text: $xText, onEditingChanged: { changed in
                })
                    .border(.red)
                
                TextField("", text: $yText, onEditingChanged: { changed in
                })
                    .border(.green)
                
                TextField("", text: $zText, onEditingChanged: { changed in
                })
                    .border(.blue)
            }
            .padding(.top, 0)
            .padding(.horizontal, 8)
            
            Text("Pixel per Meter")
                .padding(.leading, 4)
            HStack {
                TextField("", text: $pixelPerMeterText, onEditingChanged: { changed in
                })
            }
            .padding(.top, 0)
            .padding(.horizontal, 8)
            
            Button("Apply") {                
                if let x = Int(xText), let y = Int(yText), let z = Int(zText), let ppm = Int(pixelPerMeterText) {
                    print(x,y,z)
                    if x * y * z < 512 * 512 * 512 {
                        if let kit = model.modeler?.mainKit {
                            model.modeler?.freeKit(kit)
                        }
                        model.project.resolution.x = x
                        model.project.resolution.y = y
                        model.project.resolution.z = z
                        model.project.pixelsPerMeter = ppm
                        model.modeler!.mainKit = model.modeler!.allocateKit(width: x, height: y, depth: z)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(4)
    }
}
