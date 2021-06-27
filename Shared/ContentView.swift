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
        case Mixed, RenderOnly
    }
    
    @Binding var document                               : SignedDocument
    @StateObject var storeManager                       : StoreManager

    @State var selection                                : SignedObject? = nil

    @State var asset                                    : Asset? = nil

    @Environment(\.colorScheme) var deviceColorScheme   : ColorScheme
    
    @State private var screenState                      : ScreenState = .Mixed

    @State private var rightSideParamsAreVisible        : Bool = true
    
    @State var updateView                               : Bool = false
    
    @State private var showCustomResPopover             : Bool = false
    @State private var customResWidth                   : String = ""
    @State private var customResHeight                  : String = ""

    @State private var exportingImage                   : Bool = false
    
    @State private var toolsAreOn                       : Bool = false
    
    @State private var searchText = ""

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
        
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                
                ZStack(alignment: .bottomLeading) {
                    // Show tools
                    
                    RenderView(model: document.model)
                        .zIndex(0)
                        .animation(.default)
                        .allowsHitTesting(true)
                    ToolsView(document.core)
                        .zIndex(1)
                     
                }
                
                Divider()
                
                ProjectView(document.model)
                    .frame(width: 400)
            }
         
            if let object =  selection {
                ObjectView(model: document.model)//, object: object)
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
        })
        
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
        */
    }
    
    /// Preview Menu
    var toolPreviewMenu: some View {
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
    
    /// Supplies the search results for the given searchText
    var searchResults: [String] {
        var names : [String] = []
        
        if let graph = document.core.assetFolder.getGraph() {
            for n in graph.nodes {
                names.append(n.givenName)
            }
        }
                        
        if searchText.isEmpty {
            return names
        } else {
            return names.filter { $0.contains(searchText) }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(SignedDocument()), storeManager: StoreManager())
    }
}
