//
//  EditorView.swift
//  Signed
//
//  Created by Markus Moenig on 20/6/2564 BE.
//

import SwiftUI

struct EditorView: View {

    let model                                           : Model

    @State private var rightSideHelpIsVisible           : Bool = true

    @Environment(\.colorScheme) var deviceColorScheme   : ColorScheme

    @State private var contextText                      : AttributedString = ""

    #if os(macOS)
    let rightPanelWidth                                 : CGFloat = 180
    #else
    let rightPanelWidth                                 : CGFloat = 230
    #endif
    
    init(_ model: Model)
    {
        self.model = model
    }
    
    var body: some View {
        /*
        HStack(spacing: 1) {

            Button(action: {
                editingState = .Meta
            })
            {
                Text("Meta View")
            }
            .frame(minWidth: 0, maxWidth: 80, maxHeight: 20)
            .font(.system(size: 13))
            .background(editingState == .Meta ? Color.accentColor.opacity(1) : Color.accentColor.opacity(0.5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 0)
            )
            .padding(.leading, 10)
            .buttonStyle(PlainButtonStyle())
            
            
            Button(action: {
                editingState = .Nodes
            })
            {
                Text("Node View")
            }
            .frame(minWidth: 0, maxWidth: 80, maxHeight: 20)
            .font(.system(size: 13))
            .background(editingState == .Nodes ? Color.accentColor.opacity(1) : Color.accentColor.opacity(0.5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 0)
            )
            .padding(.leading, 20)
            .buttonStyle(PlainButtonStyle())

            Spacer()
            
            // Toggle the Right sidebar
            Button(action: { rightSideHelpIsVisible.toggle() }, label: {
                Image(systemName: "sidebar.right")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 17.0, height: 17.0)
                    .foregroundColor(Color.gray)
            })
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 20)
        }
        .frame(minHeight: 30)
        */
        
        HStack(spacing: 1) {
            
            GeometryReader { geometry in
            //    ScrollView {

                    
                    WebView(model, deviceColorScheme).tabItem {
                    }
                        .frame(height: geometry.size.height)
                        .tag(1)
                        .onChange(of: deviceColorScheme) { newValue in
                            model.scriptEditor?.setTheme(newValue)
                        }
                     
                //}
                .frame(maxWidth: .infinity)
                .layoutPriority(2)
            }
            
            /*
            if rightSideHelpIsVisible == true {
                if let asset = core.assetFolder.current {
                    ScrollView {
                        if asset.type == .Source {
                            Text(contextText)
                                .frame(minWidth: 0,
                                       maxWidth: .infinity,
                                       minHeight: 0,
                                       maxHeight: .infinity,
                                       alignment: .bottomLeading)
                                .padding(4)
                                .onReceive(core.contextTextChanged) { text in
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
            */
        }
        
        /*
        .onReceive(model.objectSelected) { object in
            model.selectedComponent = object.components.first
            if let component = model.selectedComponent {
                model.scriptEditor?.setComponentSession(component)
            }
        }*/
    }
}
