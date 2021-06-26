//
//  ProjectView.swift
//  Signed
//
//  Created by Markus Moenig on 20/6/2564 BE.
//

import SwiftUI

struct ProjectView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext

    let model                               : Model
    
    @State var selection                    : SignedObject? = nil
    @State var scale                        : CGFloat = 1.0

    //var libraryItems                      : [LibraryItem] = []
    /*
    @State var asset                        : Asset? = nil
    
    @State var updateView                   : Bool = false
    
    @State private var selection            : UUID? = nil
        
    @State private var showMaterials        : Bool = false
    @State private var showObjects          : Bool = false
     */
    #if os(macOS)
    let TopRowPadding                       : CGFloat = 2
    #else
    let TopRowPadding                       : CGFloat = 5
    #endif

    init(_ model: Model)
    {
        self.model = model
    }
    
    var body: some View {
        
        ZStack(alignment: .center) {
            
            ForEach(model.objects, id: \.self) { object in
                
                Canvas { context, size in
                    
                    context.fill(
                        Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10),
                        with: .color(.gray))
                    
                    context.stroke(
                        Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10),
                        with: .color(selection === object ? .white : .clear),
                        lineWidth: 4)
                    
                    context.draw(Text(object.name), at: CGPoint(x: 10, y: 4), anchor: .topLeading)
                    
                }
                .offset(x: object.graphPosition.x, y: object.graphPosition.y)
                .frame(width: 100, height: 100)
                //.border(Color.blue)
                .scaleEffect(scale)
                .onTapGesture {
                    //print()
                    model.selectedObject = object
                    model.objectSelected.send(object)
                }
                .contextMenu {
                    Text("hallo")
                }
            }
        }
        
        .onReceive(model.objectSelected) { object in
            selection = object
        }

        
        /*

        VStack {
            if let context = asset?.graph {
                
                List() {
                    
                    // Camera
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
                    
                    // Sun
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
                    
                    // Environment
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
                    
                    // Definitions
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
                            
                            .contextMenu {
                                Button("Add To Library") {
                                    addDefinitionToLibrary(node, type: "SDF3D")
                                    print(node.givenName, node.code)
                                }
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
         
         */
    }
    
    // Adds a definition node to the library
    func addDefinitionToLibrary(_ node: GraphNode, type: String) {
        let object = Component(context: managedObjectContext)
        object.name = node.givenName
        object.data = node.code
        object.type = type
        
        try! managedObjectContext.save()
    }
}
