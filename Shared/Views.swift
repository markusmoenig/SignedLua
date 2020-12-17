//
//  Parma.swift
//  Denrim
//
//  Created by Markus Moenig on 29/10/20.
//

import SwiftUI
import Parma

struct LibraryItem: Identifiable {
    var id          : String { name }

    let name        : String
    var children    : [LibraryItem]?
    var image       : String? = nil
    var md          : String = ""
}

struct LeftPanelView: View {
    
    enum Mode {
        case Project, Library
    }
    
    let core                                : Core
    var libraryItems                        : [LibraryItem] = []
    
    @State var mode                         : Mode = .Project
    @State var current                      : LibraryItem? = nil
    
    @State var updateView                   : Bool = false
    @State var expanded                     : Bool = false
    
    @State private var selection            : UUID? = nil

    init(_ core: Core)
    {
        self.core = core

        var cameraItem = LibraryItem(name: "Cameras")
        cameraItem.children = []
        
        for b in core.graphBuilder.branches {
            let node = b.createNode([:])
            if node.role == .Camera {
                var item = LibraryItem(name: b.name)
                item.md = node.getHelp()
                cameraItem.children!.append(item)
                current = item
            }
        }
        
        libraryItems.append(cameraItem)
    }
    
    var body: some View {
        
        VStack(spacing: 2) {
            
            HStack(spacing: 3) {
                Button(action: {
                    mode = .Project
                })
                {
                    Label("", systemImage: "list.bullet.below.rectangle")
                        .font(.system(size: 14))
                        .foregroundColor(mode == .Project ? Color.accentColor : Color.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    mode = .Library
                })
                {
                    Label("", systemImage: "building.columns.fill")
                        .font(.system(size: 14))
                        .foregroundColor(mode == .Library ? Color.accentColor : Color.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 1)
            .padding(.bottom, 2)
            .frame(alignment: .topLeading)

            #if os(macOS)
            Divider()
            #endif
            
            if mode == .Project {

                if let asset = core.assetFolder.getAsset("main", .Source) {
                    if let context = asset.graph {
                        List(context.nodes, id: \.id, children: \.leaves, selection: $selection) { item in
                            Button(action: {
                                core.graphBuilder.gotoNode(item)
                            })
                            {                         
                                Text(item.name)
                                    //.font(.system(.title3, design: .rounded))
                                    //.bold()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            } else
            if mode == .Library {
                
                List(libraryItems, children: \.children) { item in
                    
                    Button(action: {
                        //core.helpText = item.md
                        //core.helpTextChanged.send()
                        current = item
                    })
                    {
                        if let image = item.image {
                            Image(image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                        }
                 
                        Text(item.name)
                            //.font(.system(.title3, design: .rounded))
                            //.bold()
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    /*
                    HStack {
                        
                        if let image = item.image {
                            Image(image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                        }
                 
                        Text(item.name)
                            .font(.system(.title3, design: .rounded))
                            .bold()
                    }*/
                }
                
                if let current = current {
                    Divider()
                    Parma(current.md)
                        .font(.system(size: 11))
                }
            }
        }
        .onReceive(self.core.modelChanged) { core in
            mode = .Project
            updateView.toggle()
        }
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            selection = id
        }
        .font(.system(size: 11))
    }
}

struct ParmaView: View {
    @Binding var text: String
    var body: some View {
        Parma(text)
    }
}
