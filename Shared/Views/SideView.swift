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
        case shapes, objects, materials, camera, settings, help
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
                        model.showHelpTopic.send(.none)
                    })
                    {
                        Image(systemName: mode == .shapes ? "pyramid.fill" : "pyramid")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        mode = .objects
                        model.showHelpTopic.send(.none)
                    })
                    {
                        Image(systemName: mode == .objects ? "cube.fill" : "cube")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        mode = .materials
                        model.showHelpTopic.send(.none)
                    })
                    {
                        Image(systemName: mode == .materials ? "paintpalette.fill" : "paintpalette")
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
                        model.showHelpTopic.send(.none)
                    })
                    {
                        Image(systemName: mode == .settings ? "gearshape.fill" : "gearshape")
                            .imageScale(.large)
                        Spacer()
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        mode = .help
                        if model.currentHelpTopic == .none {
                            model.currentHelpTopic = .introduction
                        }
                        model.showHelpTopic.send(model.currentHelpTopic)
                    })
                    {
                        Image(systemName: mode == .help ? "questionmark.circle.fill" : "questionmark.circle")
                            .imageScale(.large)
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
                    if mode == .camera {
                        DataView(model: model, data: model.project.camera.data)
                    } else
                    if mode == .settings {
                        
                        TextureSizeView(model)
                        Divider()
                        
                        DataViews(model: model, data: getSettingsGroups(), bottomPadding: 12)
                            .padding(.top, 4)
                    } else
                    if mode == .help {
                        HelpContentView(model: model)
                    }
                    
                    if mode != .settings && mode != .camera && mode != .help{
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
        return [model.project.dataGroups.getGroup("Renderer")!, model.project.dataGroups.getGroup("Sun")!]
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
                    model.modeler?.freeKit(model.modeler!.mainKit);
                    model.modeler!.mainKit = model.modeler!.allocateKit(width: res, height: res, depth: res)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(4)
    }
}
