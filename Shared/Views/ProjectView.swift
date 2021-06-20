//
//  ProjectView.swift
//  Signed
//
//  Created by Markus Moenig on 20/6/2564 BE.
//

import SwiftUI

struct ProjectView: View {
    
    let core                                : Core
    var libraryItems                        : [LibraryItem] = []
    
    @State var asset                        : Asset? = nil

    //@State var current                      : LibraryItem? = nil
    
    @State var updateView                   : Bool = false
    //@State var expanded                     : Bool = false
    
    @State private var selection            : UUID? = nil
    //@State private var librarySelection     : UUID? = nil

    //@State private var tabIndex             : Int = 0
        
    @State private var showMaterials        : Bool = false
    @State private var showObjects          : Bool = false

    #if os(macOS)
    let TopRowPadding                       : CGFloat = 2
    #else
    let TopRowPadding                       : CGFloat = 5
    #endif

    init(_ core: Core)
    {
        self.core = core
        
        /*
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
        */
    }
    
    var body: some View {
        
        //TabView/*(selection: $tabIndex)*/ {

            VStack {
                if let context = asset?.graph {
                    
                    
                    List() {
                        if let cameraNode = context.cameraNode {
                            Button(action: {
                                core.graphBuilder.gotoNode(cameraNode)
                            })
                            {
                                Label(cameraNode.givenName, systemImage: "camera")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                if selection == cameraNode.id {
                                    Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                } else { Color.clear }
                            })
                        }
                        if let sunNode = context.sunNode {
                            Button(action: {
                                core.graphBuilder.gotoNode(sunNode)
                            })
                            {
                                Label(sunNode.name, systemImage: "sun.max")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                if selection == sunNode.id {
                                    Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                } else { Color.clear }
                            })
                        }
                        if let envNode = context.environmentNode {
                            Button(action: {
                                core.graphBuilder.gotoNode(envNode)
                            })
                            {
                                Label(envNode.defNode!.givenName, systemImage: "cloud.sun")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                if selection == envNode.id {
                                    Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                } else { Color.clear }
                            })
                        }
                        DisclosureGroup("Materials", isExpanded: $showMaterials) {
                            ForEach(context.materialNodes, id: \.id) { node in
                                Button(action: {
                                    core.graphBuilder.gotoNode(node)
                                })
                                {
                                    Label(node.givenName, systemImage: "light.max")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowBackground(Group {
                                    if selection == node.id {
                                        Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                    } else { Color.clear }
                                })
                            }
                        }
                        DisclosureGroup("Objects", isExpanded: $showObjects) {
                            ForEach(context.objectNodes, id: \.id) { node in
                                Button(action: {
                                    core.graphBuilder.gotoNode(node)
                                })
                                {
                                    Label(node.givenName, systemImage: "cube")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowBackground(Group {
                                    if selection == node.id {
                                        Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                    } else { Color.clear }
                                })
                            }
                        }
                    }
                     
                    
                    /*
                    List(context.hierarchicalNodes, id: \.id, children: \.leaves, selection: $selection) { item in
                        Text(item.name)
                            .ifOS(.iOS) {
                                $0.foregroundColor(item === core.graphBuilder.currentNode ? Color.accentColor : Color.white)
                            }
                    }
                    
                    // Selection handling
                    .onChange(of: selection) { newState in
                        if let id = newState {
                            if let node = context.getNode(id) {
                                core.graphBuilder.gotoNode(node)
                            }
                        }
                    }
                    .onTapGesture {
                        //if let node = context.getNode(id) {
                        //    core.graphBuilder.gotoNode(node)
                        //}
                    }
                    */
                }
            }
        /*
            .tabItem {
                Image(systemName: "list.dash")
                Text("Project")
            }
         */
            
            /*
            VStack {
            
                List(libraryItems, children: \.children, selection: $librarySelection) { item in
                    Text(item.name)

                    /*
                    Button(action: {
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
                    }
                    .buttonStyle(PlainButtonStyle())
                    */
                }
                
                if let current = current {
                    Divider()
                    Parma(current.md)
                        .font(.system(size: 11))
                }
            }
            .tabItem {
                Image(systemName: "building.columns.fill")
                Text("Library")
            }
            // Selection handling
            .onChange(of: librarySelection) { newState in
                if let id = newState {
                    for item in libraryItems {
                        if item.id == id {
                            current = item
                            break
                        }
                        if let childs = item.children {
                            for c in childs {
                                if c.id == id {
                                    current = c
                                    break
                                }
                            }
                        }
                    }
                }
            }*/
        
        //}
        
        .onReceive(self.core.modelChanged) { core in
            asset = self.core.assetFolder.getAsset("main", .Source)
            updateView.toggle()
        }
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            selection = id
            //DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //    selection = id
            //}
        }
    }
}
