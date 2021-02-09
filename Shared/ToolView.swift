//
//  ToolView.swift
//  Signed
//
//  Created by Markus Moenig on 1/2/21.
//

import SwiftUI

struct EditingView: View {
    
    enum EditingState {
        case Meta, Nodes
    }

    let core                                            : Core

    @State private var editingState                     : EditingState = .Meta

    @State private var rightSideHelpIsVisible           : Bool = true

    @Environment(\.colorScheme) var deviceColorScheme   : ColorScheme

    @State private var contextText                      : String = ""

    #if os(macOS)
    let rightPanelWidth                                 : CGFloat = 180
    #else
    let rightPanelWidth                                 : CGFloat = 230
    #endif
    
    init(_ core: Core)
    {
        self.core = core
    }
    
    var body: some View {
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
        
        HStack(spacing: 1) {
            
            if editingState == .Meta {
                GeometryReader { geometry in
                    ScrollView {

                        WebView(core, deviceColorScheme).tabItem {
                        }
                            .frame(height: geometry.size.height)
                            .tag(1)
                            .onChange(of: deviceColorScheme) { newValue in
                                core.scriptEditor?.setTheme(newValue)
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(2)
                }
            } else
            if editingState == .Nodes {
                MetalView(core, .Nodes)
                    .animation(.default)
                    .allowsHitTesting(true)
            }
            
            if rightSideHelpIsVisible == true {
                if let asset = core.assetFolder.current {
                    ScrollView {
                        if asset.type == .Source {
                            ParmaView(text: $contextText)
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
        }
    }
}

struct ToolsView: View {
    
    let core                                : Core
    
    @State var currentNode                  : GraphNode? = nil
    @State var arrayOfButtons               : [ToolViewButton] = []
    
    @State var currentButton                : ToolViewButton? = nil

    init(_ core: Core)
    {
        self.core = core
    }
    
    var body: some View {
        HStack()
        {
            Spacer()
            ForEach(arrayOfButtons, id: \.id) { result in
                Button(action: {
                })
                {
                    Text(result.name)
                }
                .frame(minWidth: 0, maxWidth: 70, maxHeight: 20)
                .font(.system(size: 16))
                .background(currentButton != nil && currentButton!.id == result.id ? Color.accentColor.opacity(1) : Color.accentColor.opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 0)
                )
                .padding(.leading, 10)
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged({ info in
                            currentButton = result
                            if let node = currentNode {
                                let delta = float2(Float(info.location.x) - core.toolContext.lastLocation.x, Float(info.location.y) - core.toolContext.lastLocation.y)
                                node.toolViewButtonAction(result, state: core.toolContext.lastLocation == float2(0,0) ? .Down : .Move, delta: delta, toolContext: core.toolContext)
                                core.toolContext.lastLocation = float2(Float(info.location.x), Float(info.location.y))
                            }
                        })
                        .onEnded({ info in
                            if let node = currentNode {
                                let delta = float2(Float(info.location.x - info.startLocation.x), Float(info.location.y - info.startLocation.y))
                                node.toolViewButtonAction(result, state: .Up, delta: delta, toolContext: core.toolContext)
                                core.toolContext.lastLocation = float2(0,0)
                            }
                            currentButton = nil
                        })
                )
                .padding()
            }
            Spacer()
        }
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            arrayOfButtons = []
            currentNode = nil
            if let node = core.graphBuilder.currentNode {
                currentNode = node
                arrayOfButtons = node.getToolViewButtons()
            }
        }
    }
}
