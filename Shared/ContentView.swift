//
//  ContentView.swift
//  Signed
//
//  Created by Markus Moenig on 12/12/20.
//

import SwiftUI

#if os(iOS)
import MobileCoreServices
#endif

struct ContentView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @Binding var document                               : SignedDocument
    @StateObject var storeManager                       : StoreManager

    @State var selection                                : SignedObject? = nil

    @Environment(\.colorScheme) var deviceColorScheme   : ColorScheme
    
    @State private var rightSideParamsAreVisible        : Bool = true
    
    @State var updateView                               : Bool = false
    
    @State private var showCustomResPopover             : Bool = false
    @State private var customResWidth                   : String = ""
    @State private var customResHeight                  : String = ""

    @State private var exportingImage                   : Bool = false
    
    @State private var toolsAreOn                       : Bool = false
    
    @State private var searchText = ""
    
    @State private var isOrbiting                       : Bool = false
    @State private var isMoving                         : Bool = false
    @State private var isZooming                        : Bool = false

    @State private var modulesArrived                   : Bool = false

    #if os(macOS)
    let leftPanelWidth                      : CGFloat = 180
    #else
    let leftPanelWidth                      : CGFloat = 230
    #endif
    
    #if os(macOS)
    let rightPanelWidth                     : CGFloat = 180
    #else
    let rightPanelWidth                     : CGFloat = 230
    #endif
    
    var body: some View {
        
        GeometryReader { geometry in

            
            NavigationView {
                
                ProjectView(document.model)
                
                VStack(spacing: 0) {
                    
                    HStack(spacing: 2) {
                        EditorView(document.model)

                        VStack(spacing: 2) {
                            ZStack(alignment: .bottomLeading) {
                                // Show tools
                                
                                RenderView(model: document.model)
                                    .zIndex(0)
                                    .animation(.default)
                                    .allowsHitTesting(true)
                                //ToolsView(document.core)
                                //    .zIndex(1)
                                 
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
                                            
                                            document.model.project.camera.rotateDelta(delta * 0.01)
                                            document.model.renderer?.restart()
                                            document.model.updateDataViews.send()
                                        })
                                        .onEnded({ info in
                                            isOrbiting = false
                                            document.model.project.camera.lastDelta = float2(0,0)
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
                                            
                                            document.model.project.camera.moveDelta(delta * 0.003, aspect: getAspectRatio())
                                            document.model.renderer?.restart()
                                            document.model.updateDataViews.send()
                                        })
                                        .onEnded({ info in
                                            isMoving = false
                                            document.model.project.camera.lastDelta = float2(0,0)
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
                                            
                                            document.model.project.camera.zoomDelta(delta.x * 0.04)
                                            document.model.renderer?.restart()
                                            document.model.updateDataViews.send()
                                        })
                                        .onEnded({ info in
                                            isZooming = false
                                            document.model.project.camera.lastZoomDelta = 0
                                        })
                                )
                            }
                            
                            //DetailView(model: document.model)
                        }
                    }
                    
                    BrowserView(model: document.model)
                        .frame(minHeight: 80, maxHeight: 100)
                }

                //Divider()
                    
                //SideView(model: document.model)
                //    .frame(width: geometry.size.width / 2.5)
            }
        }
        
        .onReceive(document.model.objectSelected) { object in
            selection = object
        }
        
        /*
        
        VStack(spacing: 0) {
        //VSplitView {
                        
            HStack {
                NavigationView {
                        
                    
                    ProjectView(document.core)
                        .frame(minWidth: leftPanelWidth, idealWidth: leftPanelWidth, maxWidth: leftPanelWidth)
                        .layoutPriority(0)
                        .animation(.easeInOut)
                     
                    
                    ZStack(alignment: .bottomLeading) {
                        // Show tools
                        
                        MetalView(document.core, .Main)
                            .zIndex(0)
                            .animation(.default)
                            .allowsHitTesting(true)
                        ToolsView(document.core)
                            .zIndex(1)
                         
                    }
                    //.layoutPriority(2)
                    //.frame(idealWidth: .infinity, maxWidth: .infinity)
                }
                
                if rightSideParamsAreVisible == true {
                    SettingsView(document.core)
                        .frame(minWidth: rightPanelWidth, idealWidth: rightPanelWidth, maxWidth: rightPanelWidth)
                        .layoutPriority(0)
                        .animation(.easeInOut)
                }
            }

            if screenState == .Mixed {
                Divider()
                EditorView(document.core)
            }
        }
        
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                          
                toolPreviewMenu
                
                Divider()
                    .padding(.horizontal, 20)
                    .opacity(0)
                
                // Controls for Start Render / Stop Render
                Button(action: {
                    document.core.renderPipeline.isStopped = false
                    document.core.renderPipeline.restart()
                })
                {
                    Label("Render", systemImage: "play.fill")
                }
                .keyboardShortcut("r")
                
                // Controls for Start Render / Stop Render
                Button(action: {
                    document.core.renderPipeline.isStopped = true
                    document.core.renderPipeline.stop()
                })
                {
                    Label("Stop", systemImage: "stop.fill")
                }
                .keyboardShortcut("t")

                Divider()
                    .padding(.horizontal, 20)
                    .opacity(0)
                
                toolGiftMenu
                
                // Toggle the Right sidebar
                Button(action: { rightSideParamsAreVisible.toggle() }, label: {
                    Image(systemName: "sidebar.right")
                })
            }
        }
        
        // Search
        .searchable(text: $searchText) {
            ForEach(searchResults, id: \.self) { result in
                Text("\(result)").searchCompletion(result)
            }
        }
        
        // If the searchtext matches a specific object name, select it
        .onChange(of: searchText) { newValue in
            if let graph = document.core.assetFolder.getGraph() {
                for n in graph.nodes {
                    if n.givenName == newValue {
                        document.core.graphBuilder.gotoNode(n)
                        break
                    }
                }
            }
        }

        .onAppear(perform: {
            if storeManager.myProducts.isEmpty {
                DispatchQueue.main.async {
                    storeManager.getProducts()
                }
            }
        })*/
        
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                          
                Button(action: {
                    
                    if document.model.codeEditorMode == .material {
                        if let material = document.model.codeEditorMaterialEntity {
                            if let data = material.code {
                                if let value = String(data: data, encoding: .utf8) {
                                    if let renderer = document.model.renderer {
                                        document.model.builder.build(code: value, kit: document.model.modeler!.mainKit, content: .material, renderKits: [renderer.mainRenderKit, renderer.iconRenderKit], materialEntity: material)
                                    }
                                }
                            }
                        }
                    } else {
                        if let renderer = document.model.renderer, let object = document.model.selectedObject {
                            switch document.model.project.getObjectType(from: object.id) {
                                case .object:
                                    document.model.builder.build(code: object.getCode(), kit: document.model.modeler!.mainKit, content: .object, renderKits: [renderer.mainRenderKit])
                                case .material:
                                    document.model.builder.build(code: object.getCode(), kit: document.model.modeler!.mainKit, content: .material, renderKits: [renderer.mainRenderKit])
                                default:
                                    document.model.builder.build(code: document.model.project.main.getCode(), kit: document.model.modeler!.mainKit, renderKits: [renderer.mainRenderKit])
                            }
                        }
                    }
                }) {
                    Text("Build")
                }
                .keyboardShortcut("b")
                .disabled(modulesArrived == false)
                
                toolPreviewMenu
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
                
                //let core = document.core
                /*
                if let texture = core.renderPipeline.getTexture() {
                    if let cgiTexture = core.makeCGIImage(texture) {
                        if let image = makeCGIImage(texture: cgiTexture, forImage: true) {
                            if let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) {
                                CGImageDestinationAddImage(imageDestination, image, nil)
                                CGImageDestinationFinalize(imageDestination)
                            }
                        }
                    }
                }*/
            } catch {
                // Handle failure.
            }
        }

    }
    
    /// Preview Menu
    var toolPreviewMenu: some View {
        Menu {
            Section(header: Text("Preview")) {

                Button("Set Custom", action: {
                    
        
                    //customResWidth = String(document.model.renderSize.x)
                    //customResHeight = String(document.model.renderSize.y)
                    
                    showCustomResPopover = true
                    updateView.toggle()
                })
                
                Button("Clear Custom", action: {
                    document.model.renderer?.restart()
                    updateView.toggle()
                })
            }
            Section(header: Text("Export")) {
                Button("Export Image...", action: {
                    exportingImage = true
                })
            }
        }
        label: {
            Text(computeResolutionText())
        }
        
        .onReceive(self.document.model.updateUI) { _ in
            updateView.toggle()
        }
        
        .onReceive(self.document.model.modulesArrived) { _ in
            modulesArrived = true
        }
        
        // Custom Resolution Popover
        .popover(isPresented: self.$showCustomResPopover,
                 arrowEdge: .top
        ) {
            VStack(alignment: .leading) {
                Text("Resolution:")
                TextField("Width", text: $customResWidth, onEditingChanged: { (changed) in
                })
                TextField("Height", text: $customResHeight, onEditingChanged: { (changed) in
                    /*
                    if let width = Int(customResWidth), width > 0 {
                        if let height = Int(customResHeight), height > 0 {
                            document.core.customRenderSize = SIMD2<Int>(width, height)
                        }
                    }*/
                })
                Button(action: {
                    if let width = Int(customResWidth), width > 0 {
                        if let height = Int(customResHeight), height > 0 {
                            //document.core.customRenderSize = SIMD2<Int>(width, height)
                            //document.core.renderPipeline.restart()
                        }
                    }
                })
                {
                    Text("Apply")
                    //Label("Run", systemImage: "viewfinder")
                }
                .foregroundColor(Color.accentColor)
                .padding(4)
                .padding(.leading, 10)
                .frame(minWidth: 200)
            }.padding()
        }
    }
    
    var toolGiftMenu : some View {
        Menu {
            HStack {
                VStack(alignment: .leading) {
                    Text("Small Tip")
                        .font(.headline)
                    Text("Tip of $2 for the author")
                        .font(.caption2)
                }
                Button(action: {
                    storeManager.purchaseId("com.moenig.ShaderMania.IAP.Tip2")
                }) {
                    Text("Buy for $2")
                }
                .foregroundColor(.blue)
                Divider()
                VStack(alignment: .leading) {
                    Text("Medium Tip")
                        .font(.headline)
                    Text("Tip of $5 for the author")
                        .font(.caption2)
                }
                Button(action: {
                    storeManager.purchaseId("com.moenig.ShaderMania.IAP.Tip5")
                }) {
                    Text("Buy for $5")
                }
                .foregroundColor(.blue)
                Divider()
                VStack(alignment: .leading) {
                    Text("Large Tip")
                        .font(.headline)
                    Text("Tip of $10 for the author")
                        .font(.caption2)
                }
                Button(action: {
                    storeManager.purchaseId("com.moenig.ShaderMania.IAP.Tip10")
                }) {
                    Text("Buy for $10")
                }
                .foregroundColor(.blue)
                Divider()
                Text("You are awesome! ❤️❤️")
            }
        }
        label: {
            Label("Dollar", systemImage: "gift")//dollarsign.circle")
        }
    }
    
    /// Returns the resolution of the current preview
    func computeResolutionText() -> String {
        let string = ""
        if let mainRenderKit = document.model.renderer?.mainRenderKit {
            let width = mainRenderKit.sampleTexture!.width
            let height = mainRenderKit.sampleTexture!.height
            return "\(width) x \(height)"
        }
        return string
    }
    
    /// Returns the resolution of the current preview
    func getAspectRatio() -> Float {
        if let mainRenderKit = document.model.renderer?.mainRenderKit {
            let width = mainRenderKit.sampleTexture!.width
            let height = mainRenderKit.sampleTexture!.height
            return Float(width) / Float(height)
        }
        return 1
    }
}
