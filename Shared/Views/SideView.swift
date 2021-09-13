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
                
                VStack {
                    if mode == .shapes {
                        ScrollView {
                            ShapeView(model: model)
                        }
                    } else
                    if mode == .objects {
                        ScrollView {
                            ObjectView(model: model)
                        }
                    } else
                    if mode == .materials {
                        ScrollView {
                            MaterialView(model: model)
                        }
                    } else
                    if mode == .settings {
                        
                        TextureSizeView(model)
                        Divider()
                        
                        DataViews(model: model, data: getSettingsGroups(), bottomPadding: 12)
                            .padding(.top, 4)
                    }
                    
                    if mode != .settings {
                        Divider()
                        InfoView(model: model)
                    }
                }
            }
        }
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
    @State private var resolutionText                   : String = ""
    @State private var yText                            : String = ""
    @State private var zText                            : String = ""
    @State private var pixelPerMeterText                : String = ""

    init(_ model: Model) {
        self.model = model
        _resolutionText = State(initialValue: String(model.project.resolution))
        _pixelPerMeterText = State(initialValue: String(model.project.pixelsPerMeter))
    }
    
    var body: some View {
                
        VStack(alignment: .leading) {
            Text("3D Texture Size")
                .padding(.leading, 4)
            TextField("", text: $resolutionText, onEditingChanged: { changed in
            })
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
                if let res = Int(resolutionText), let ppm = Int(pixelPerMeterText) {
                    if let kit = model.modeler?.mainKit {
                        model.modeler?.freeKit(kit)
                    }
                    model.project.resolution = res
                    model.project.pixelsPerMeter = ppm
                    model.modeler!.mainKit = model.modeler!.allocateKit(width: res, height: res, depth: res)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(4)
    }
}
