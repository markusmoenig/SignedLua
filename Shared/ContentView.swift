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
    
    enum ScreenState {
        case Mixed, RenderOnly, SourceOnly
    }
    
    @Binding var document                               : SignedDocument
    @StateObject var storeManager                       : StoreManager

    @State var asset                                    : Asset? = nil

    @Environment(\.colorScheme) var deviceColorScheme   : ColorScheme
    
    @State private var screenState                      : ScreenState = .Mixed

    @State private var rightSideBarIsVisible            : Bool = true
    @State private var contextText                      : String = ""
    
    @State var updateView                               : Bool = false
    
    @State private var showCustomResPopover             : Bool = false
    @State private var customResWidth                   : String = ""
    @State private var customResHeight                  : String = ""

    @State private var exportingImage                   : Bool = false

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
        VStack(spacing: 0) {
        //VSplitView {
        
            if screenState == .Mixed || screenState == .RenderOnly {
                
                HStack {

                    NavigationView {
                            
                        LeftPanelView(document.core)
                            .frame(minWidth: leftPanelWidth, idealWidth: leftPanelWidth, maxWidth: leftPanelWidth)
                            .layoutPriority(0)
                            .animation(.easeInOut)
                        
                        MetalView(document.core)
                            //.zIndex(2)
                            /*
                            .frame(minWidth: 0,
                                   maxWidth: geometry.size.width / document.game.previewFactor,
                                   minHeight: 0,
                                   maxHeight: geometry.size.height / document.game.previewFactor,
                                   alignment: .topTrailing)
                            */
                            //.opacity(helpIsVisible ? 0 : (document.game.state == .Running ? 1 : document.game.previewOpacity))
                            .animation(.default)
                            .allowsHitTesting(true)
                        
                    }

                    if rightSideBarIsVisible == true {
                        RightPanelView(document.core)
                            .frame(minWidth: rightPanelWidth, idealWidth: rightPanelWidth, maxWidth: rightPanelWidth)
                            .layoutPriority(0)
                            .animation(.easeInOut)
                    }
                }
            }
            
            Divider()
                
            HStack(spacing: 1) {

                Button(action: {
                })
                {
                    Text("Meta View")
                    //Label("Run", systemImage: "viewfinder")
                }
                .foregroundColor(Color.accentColor)
                .padding(4)
                .padding(.leading, 10)
                
                Button(action: {
                })
                {
                    Text("Node View")
                    //Label("Run", systemImage: "viewfinder")
                }
                .padding(4)

                Spacer()
            }
            
            if screenState == .Mixed || screenState == .SourceOnly {

                HStack(spacing: 1) {
                    GeometryReader { geometry in
                        ZStack(alignment: .topTrailing) {

                            GeometryReader { geometry in
                                ScrollView {

                                    WebView(document.core, deviceColorScheme).tabItem {
                                    }
                                        .frame(height: geometry.size.height)
                                        .tag(1)
                                        .onChange(of: deviceColorScheme) { newValue in
                                            document.core.scriptEditor?.setTheme(newValue)
                                        }
                                }
                                .zIndex(0)
                                .frame(maxWidth: .infinity)
                                .layoutPriority(2)
                            }
                        }
                    }
                    
                    if rightSideBarIsVisible == true {
                        if let asset = document.core.assetFolder.current {
                            ScrollView {
                                if asset.type == .Source {
                                    ParmaView(text: $contextText)
                                        .frame(minWidth: 0,
                                               maxWidth: .infinity,
                                               minHeight: 0,
                                               maxHeight: .infinity,
                                               alignment: .bottomLeading)
                                        .padding(4)
                                        .onReceive(self.document.core.contextTextChanged) { text in
                                            contextText = text
                                        }
                                        .foregroundColor(Color.gray)
                                        .font(.system(size: 12))
                                        .frame(minWidth: rightPanelWidth + 6, idealWidth: rightPanelWidth + 6, maxWidth: rightPanelWidth + 6)
                                        .layoutPriority(0)
                                        .animation(.easeInOut)
                                }
                            }
                            .animation(.easeInOut)
                        }
                    }
                }
            }
        }
        
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                          
                Menu {
                    Section(header: Text("Preview")) {
                        Button("Small", action: {
                            screenState = .Mixed
                            updateView.toggle()
                        })
                        Button("Large", action: {
                            screenState = .RenderOnly
                            updateView.toggle()
                        })
                        .keyboardShortcut("3")
                        Button("Set Custom", action: {
                            
                
                            customResWidth = String(document.core.renderPipeline.renderSize.x)
                            customResHeight = String(document.core.renderPipeline.renderSize.y)
                            
                            showCustomResPopover = true
                            updateView.toggle()
                        })
                        
                        Button("Clear Custom", action: {
                            document.core.customRenderSize = nil
                            document.core.renderPipeline.restart()
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
                    Text("\(document.core.renderPipeline == nil ? "" : String(document.core.renderPipeline.renderSize.x) + " x " + String(document.core.renderPipeline.renderSize.y))")
                    //Label("View", systemImage: "viewfinder")
                }
                .onReceive(self.document.core.updateUI) { state in
                    updateView.toggle()
                }

                /*
                // Toggle preview size
                Button(action: {
                    if screenState == .Mixed {
                        screenState = .RenderOnly
                    } else
                    if screenState == .RenderOnly {
                        screenState = .SourceOnly
                    } else {
                        screenState = .Mixed
                    }
                })
                {
                    Label("Run", systemImage: "viewfinder")
                }
                .keyboardShortcut("e")
                */
                
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
                
                Menu {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Small Tip")
                                .font(.headline)
                            Text("Tip of $2 for the author")
                                .font(.caption2)
                        }
                        Button(action: {
                            storeManager.purchaseId("com.moenig.Signed.IAP.Tip2")
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
                            storeManager.purchaseId("com.moenig.Signed.IAP.Tip5")
                        }) {
                            Text("Buy for $5")
                        }
                        .foregroundColor(.blue)
                        Divider()
                        Text("You are awesome! ❤️❤️")
                    }
                }
                label: {
                    Label("Dollar", systemImage: "gift")
                }
                
                // Toggle the Right sidebar
                Button(action: { rightSideBarIsVisible.toggle() }, label: {
                    Image(systemName: "sidebar.right")
                })
            }
        }
        .onAppear(perform: {
            if storeManager.myProducts.isEmpty {
                DispatchQueue.main.async {
                    storeManager.getProducts()
                }
            }
        })
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
                            document.core.customRenderSize = SIMD2<Int>(width, height)
                            document.core.renderPipeline.restart()
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
        
        // Export Image
        .fileExporter(
            isPresented: $exportingImage,
            document: document,
            contentType: .png,
            defaultFilename: "Image"
        ) { result in
            do {
                let url = try result.get()
                let core = document.core
                if let texture = core.renderPipeline.getTexture() {
                    if let cgiTexture = core.makeCGIImage(texture) {
                        if let image = makeCGIImage(texture: cgiTexture, forImage: true) {
                            if let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) {
                                CGImageDestinationAddImage(imageDestination, image, nil)
                                CGImageDestinationFinalize(imageDestination)
                            }
                        }
                    }
                }
            } catch {
                // Handle failure.
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(SignedDocument()), storeManager: StoreManager())
    }
}
