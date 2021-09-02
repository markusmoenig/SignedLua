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
        case renderCamera, settings
    }
    
    let document                                        : SignedDocument
    let model                                           : Model
    
    @State var mode                                     : Mode? = .renderCamera
    @State var selection                                : SignedObject? = nil
    
    @State var updateView                               : Bool = false

    @State private var showCustomResPopover             : Bool = false
    @State private var customResWidth                   : String = ""
    @State private var customResHeight                  : String = ""

    @State private var resolutionText                   : String = ""

    @State private var exportingImage                   : Bool = false
        
    @State private var isOrbiting                       : Bool = false
    @State private var isMoving                         : Bool = false
    @State private var isZooming                        : Bool = false
        
    var body: some View {
                
        GeometryReader { geometry in

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    
                    Button(action: {
                        mode = .renderCamera
                    })
                    {
                        Image(systemName: mode == .renderCamera ? "camera.fill" : "camera")
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
                                        
                    Menu {
                        
                        Button("Set Custom", action: {
                            
                            if let mainRenderKit = model.renderer?.mainRenderKit {
                                let width = mainRenderKit.sampleTexture!.width
                                let height = mainRenderKit.sampleTexture!.height
                                
                                model.renderSize = SIMD2<Int>(width, height)
                                customResWidth = String(width)
                                customResHeight = String(height)
                            }
                            
                            showCustomResPopover = true
                        })
                        
                        Button("Clear Custom", action: {
                            model.renderSize = nil
                            model.renderer?.restart()
                        })
                        
                        Divider()
                        
                        Button("Export Image...", action: {
                            exportingImage = true
                        })
                    }
                    label: {
                        Text(resolutionText)
                    }
                    .padding(.trailing, 6)
                    .frame(width: 100)
                    
                    .menuStyle(BorderlessButtonMenuStyle())
                    
                    // Custom Resolution Popover
                    .popover(isPresented: self.$showCustomResPopover,
                             arrowEdge: .top
                    ) {
                        VStack(alignment: .leading) {
                            Text("Resolution:")
                            TextField("Width", text: $customResWidth, onEditingChanged: { (changed) in
                            })
                            TextField("Height", text: $customResHeight, onEditingChanged: { (changed) in
                            })
                            
                            Button(action: {
                                if let width = Int(customResWidth), width > 0 {
                                    if let height = Int(customResHeight), height > 0 {
                                        model.renderSize = SIMD2<Int>(width, height)
                                        model.renderer?.restart()
                                    }
                                }
                            })
                            {
                                Text("Apply")
                            }
                            .foregroundColor(Color.accentColor)
                            .padding(4)
                            .padding(.leading, 10)
                            .frame(minWidth: 200)
                        }.padding()
                    }
                    
                }
                .padding(.top, 6)
                .padding(.leading, 6)
                
                //Divider()
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
                
                
                if mode == .renderCamera {

                    ZStack(alignment: .bottomLeading) {
                        // Show tools
                        
                        RenderView(model: model)
                            .animation(.default)
                            .allowsHitTesting(true)
                         
                        Button(action: {
                            
                        })
                        {
                            ZStack(alignment: .center) {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 0)
                                Text("Orbit")
                            }
                        }
                        .frame(minWidth: 70, maxWidth: 70, maxHeight: 20)
                        .font(.system(size: 16))
                        .background(isOrbiting ? Color.accentColor : Color.clear)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .padding(.leading, 10)
                        .padding(.bottom, 70)
                        .buttonStyle(.plain)
                        
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 4)
                            
                                .onChanged({ info in

                                    isOrbiting = true
                                    let delta = float2(Float(info.location.x - info.startLocation.x), 0)//Float(info.location.y - info.startLocation.y))
                                    
                                    model.project.camera.rotateDelta(delta * 0.01)
                                    model.renderer?.restart()
                                    model.updateDataViews.send()
                                })
                                .onEnded({ info in
                                    isOrbiting = false
                                    model.project.camera.lastDelta = float2(0,0)
                                })
                        )
                        
                        Button(action: {
                            
                        })
                        {
                            ZStack(alignment: .center) {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 0)
                                Text("Move")
                            }
                        }
                        .frame(minWidth: 70, maxWidth: 70, maxHeight: 20)
                        .font(.system(size: 16))
                        .background(isMoving ? Color.accentColor : Color.clear)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .padding(.leading, 10)
                        .padding(.bottom, 40)
                        .buttonStyle(.plain)
                        
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 4)
                            
                                .onChanged({ info in

                                    isMoving = true
                                    let delta = float2(/*Float(info.location.x - info.startLocation.x)*/0, Float(info.location.y - info.startLocation.y))
                                    
                                    model.project.camera.moveDelta(delta * 0.003, aspect: getAspectRatio())
                                    model.renderer?.restart()
                                    model.updateDataViews.send()
                                })
                                .onEnded({ info in
                                    isMoving = false
                                    model.project.camera.lastDelta = float2(0,0)
                                })
                        )
                        
                        Button(action: {
                            
                        })
                        {
                            ZStack(alignment: .center) {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 0)
                                Text("Zoom")
                            }
                        }
                        .frame(minWidth: 70, maxWidth: 70, maxHeight: 20)
                        .font(.system(size: 16))
                        .background(isZooming ? Color.accentColor : Color.clear)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .padding(.leading, 10)
                        .padding(.bottom, 10)
                        .buttonStyle(.plain)
                        
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 4)
                            
                                .onChanged({ info in

                                    isZooming = true
                                    let delta = float2(Float(info.location.x - info.startLocation.x), Float(info.location.y - info.startLocation.y))
                                    
                                    model.project.camera.zoomDelta(delta.x * 0.04)
                                    model.renderer?.restart()
                                    model.updateDataViews.send()
                                })
                                .onEnded({ info in
                                    isZooming = false
                                    model.project.camera.lastZoomDelta = 0
                                })
                        )
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 0)
                } else
                if mode == .settings {
                    DataViews(model: model, data: getSettingsGroups(), bottomPadding: 12)
                        .padding(.top, 4)
                    Spacer()
                }
            }
        }
        
        // Export Image
        .fileExporter(
            isPresented: $exportingImage,
            document: document,
            contentType: .png,
            defaultFilename: "Image"
        ) { result in
            do {
                let url = try result.get()
                
                if let image = document.model.modeler?.kitToImage(renderKit: document.model.renderer!.mainRenderKit) {
                    if let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) {
                        CGImageDestinationAddImage(imageDestination, image, nil)
                        CGImageDestinationFinalize(imageDestination)
                    }
                }
            } catch {
                // Handle failure.
            }
        }
        
        .onReceive(self.document.model.updateUI) { _ in
            resolutionText = computeResolutionText()
            updateView.toggle()
        }
        
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
    
    /// Returns the resolution of the current preview
    func computeResolutionText() -> String {
        let string = ""
        if let mainRenderKit = model.renderer?.mainRenderKit {
            let width = mainRenderKit.sampleTexture!.width
            let height = mainRenderKit.sampleTexture!.height
            return "\(width) x \(height)"
        }
        return string
    }
    
    /// Returns the resolution of the current preview
    func getAspectRatio() -> Float {
        if let mainRenderKit = model.renderer?.mainRenderKit {
            let width = mainRenderKit.sampleTexture!.width
            let height = mainRenderKit.sampleTexture!.height
            return Float(width) / Float(height)
        }
        return 1
    }
    
    /// Get the settings groups
    func getSettingsGroups() -> [SignedData]
    {
        return [model.project.dataGroups.getGroup("Renderer")!]
    }
}
