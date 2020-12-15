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

    var body: some View {
        //NavigationView {
            
        VStack {//VSplitView {
        
            if screenState == .Mixed || screenState == .RenderOnly {
                
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
                
            if screenState == .Mixed || screenState == .SourceOnly {

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
                
            }
        }
        
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                
                // Game Controls
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
                
                // Game Controls
                Button(action: {
                    document.core.renderer.render(core: document.core)
                })
                {
                    Label("Run", systemImage: "play.fill")
                }
                .keyboardShortcut("r")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(SignedDocument()))
    }
}
