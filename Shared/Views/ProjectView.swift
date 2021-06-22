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
    
    @State var updateView                   : Bool = false
    
    @State private var selection            : UUID? = nil
        
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
    }
    
    var body: some View {
        

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
                    Section(header: Text("Definitions")) {
                    //DisclosureGroup("Primitives", isExpanded: $showMaterials) {
                        ForEach(context.defPrimitiveNodes, id: \.id) { node in
                            Button(action: {
                                core.graphBuilder.gotoNode(node)
                            })
                            {
                                Label(node.givenName, systemImage: "circle")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .padding(.leading, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                if selection == node.id {
                                    Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                                } else { Color.clear }
                            })
                        }
                        ForEach(context.defBooleanNodes, id: \.id) { node in
                            Button(action: {
                                core.graphBuilder.gotoNode(node)
                            })
                            {
                                Label(node.givenName, systemImage: "square.on.circle")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .padding(.leading, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                if selection == node.id {
                                    Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                                } else { Color.clear }
                            })
                        }
                    }
                    Section(header: Text("Materials")) {
                    //DisclosureGroup("Materials", isExpanded: $showMaterials) {
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
                    Section(header: Text("Objects")) {
                    //DisclosureGroup("Objects", isExpanded: $showObjects) {
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
            }
        }
        
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
