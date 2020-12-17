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
    
    var body: some View {
        //NavigationView {
            
        VStack(spacing: 2) {//VSplitView {
        
            if screenState == .Mixed || screenState == .RenderOnly {
                
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
                        .allowsHitTesting(false)
                }
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
                                        .frame(minWidth: 160, idealWidth: 160, maxWidth: 160)
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
                    document.core.renderer.render(core: document.core)
                })
                {
                    Label("Run", systemImage: "play.fill")
                }
                .keyboardShortcut("r")
                
                // Toggle the Right sidebar
                Button(action: { rightSideBarIsVisible.toggle() }, label: {
                    Image(systemName: "sidebar.right")
                })
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(SignedDocument()))
    }
}
