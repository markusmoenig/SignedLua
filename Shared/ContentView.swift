//
//  ContentView.swift
//  Signed
//
//  Created by Markus Moenig on 12/12/20.
//

import SwiftUI

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
                .onReceive(self.document.core.updateUI) { state in
                    screenState = .Mixed
                    updateView.toggle()
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
                
                // Render Quality
                Button(action: {
                    document.core.renderQuality = document.core.renderQuality == .Normal ? .Fast : .Normal
                    updateView.toggle()
                })
                {
                    Text(document.core.renderQuality == .Normal ? "Path Tracer" : "Preview")
                    //Label("Run", systemImage: "viewfinder")
                }
                
                Divider()
                    .padding(.horizontal, 20)
                    .opacity(0)
                                
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
                
                // Controls for Start Render / Stop Render
                Button(action: {
                    document.core.renderer.restart()
                })
                {
                    Label("Render", systemImage: "play.fill")
                }
                .keyboardShortcut("r")
                
                // Controls for Start Render / Stop Render
                Button(action: {
                    document.core.renderer.stop()
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(SignedDocument()), storeManager: StoreManager())
    }
}
