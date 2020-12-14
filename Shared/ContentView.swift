//
//  ContentView.swift
//  Signed
//
//  Created by Markus Moenig on 12/12/20.
//

import SwiftUI

struct ContentView: View {

    @Binding var document                               : SignedDocument
    @Environment(\.colorScheme) var deviceColorScheme   : ColorScheme

    var body: some View {
        //NavigationView {
            
            VSplitView {
                
                MetalView(document.game)
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
                
                GeometryReader { geometry in
                    ZStack(alignment: .topTrailing) {

                        GeometryReader { geometry in
                            ScrollView {

                                WebView(document.game, deviceColorScheme).tabItem {
                                }
                                    .frame(height: geometry.size.height)
                                    .tag(1)
                                    .onChange(of: deviceColorScheme) { newValue in
                                        document.game.scriptEditor?.setTheme(newValue)
                                    }
                            }
                            .zIndex(0)
                            .frame(maxWidth: .infinity)
                            .layoutPriority(2)
                        }
                    }
                }
                
            }
        //}
        
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                
                // Game Controls
                Button(action: {
                    document.game.project!.render(game: document.game)
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
