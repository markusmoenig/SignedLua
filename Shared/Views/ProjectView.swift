//
//  ProjectView.swift
//  Signed
//
//  Created by Markus Moenig on 20/6/2564 BE.
//

import SwiftUI

struct ProjectView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext

    enum DatabaseType {
        case object, material, module
    }
    
    let model                               : Model

    @State private var databaseType         : DatabaseType = .object
    @State private var showDatabasePopover  : Bool = false
    @State private var databaseName         : String = ""

    @State private var selected             : UUID? = nil

    @State var updateView                   : Bool = false
    
    @FetchRequest(
      entity: ModuleEntity.entity(),
      sortDescriptors: [
        NSSortDescriptor(keyPath: \ModuleEntity.name, ascending: true)
      ]
    ) var modules: FetchedResults<ModuleEntity>
    
    #if os(macOS)
    let TopRowPadding                       : CGFloat = 2
    #else
    let TopRowPadding                       : CGFloat = 5
    #endif

    init(_ model: Model)
    {
        self.model = model
        if let object = model.getObject() {
            _selected = State(initialValue: object.id)
        }
    }
    
    var body: some View {
        
        ZStack(alignment: .bottomLeading) {

            List {
                Section(header: Text("Project")) {
                //DisclosureGroup("Primitives", isExpanded: $showMaterials) {
                    ForEach(model.project.objects, id: \.id) { object in
                        Button(action: {
                            if let code = object.code {
                                if let value = String(data: code, encoding: .utf8) {
                                    selected = object.id
                                    //model.codeEditorMode = .project
                                    model.codeEditor?.setSession(value: value)
                                    if model.codeEditorMode != .project {
                                        model.codeEditorMode = .project
                                        model.selectionChanged.send()
                                    }
                                }
                            }
                        })
                        {
                            Label("main", systemImage: "s.square")
                                .foregroundColor(selected == object.id ? .accentColor : .primary)
                        }
                        .contextMenu {
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Section(header: Text("Public Modules")) {
                    ForEach(modules, id: \.self) { module in
                        Button(action: {
                            selected = module.id!
                            model.codeEditorMode = .module
                            model.codeEditorModuleEntity = module
                            if let data = module.code {
                                if let value = String(data: data, encoding: .utf8) {
                                    model.codeEditor?.setSession(value: value, session: "__" + module.name!)
                                    model.selectionChanged.send()
                                }
                            }
                        })
                        {
                            Label(module.name!, systemImage: "cloud")
                                .foregroundColor(selected == module.id ? .accentColor : .primary)
                        }
                        .contextMenu {
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            HStack {
                Menu {
                    
                    Button("Public Material", action: {
                        databaseType = .material
                        databaseName = "New Material"
                        showDatabasePopover = true
                    })
                    
                    Button("Public Module", action: {
                        databaseType = .module
                        databaseName = "New Module"
                        showDatabasePopover = true
                    })
                }
                label: {
                    Label("Add", systemImage: "plus")
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .padding(.leading, 10)
                .padding(.bottom, 6)
                Spacer()
            }
            
            // Create DB Object
            .popover(isPresented: $showDatabasePopover,
                     arrowEdge: .top
            ) {
                VStack(alignment: .leading) {
                    Text("Database Name")
                        .foregroundColor(Color.secondary)
                    TextField("Name", text: $databaseName, onEditingChanged: { (changed) in
                    })
                    .frame(minWidth: 300)
                    Button("Create") {
                        if databaseName.isEmpty == false {
                            
                            if databaseType == .material {
                                let material = MaterialEntity(context: managedObjectContext)
                                
                                material.id = UUID()
                                material.name = databaseName
                                material.code = "-- New Material".data(using: .utf8)
                                
                                do {
                                    try managedObjectContext.save()
                                } catch {}
                            } else
                            if databaseType == .module {
                                let module = ModuleEntity(context: managedObjectContext)
                                
                                module.id = UUID()
                                module.name = databaseName
                                module.code = "-- New Module".data(using: .utf8)
                                
                                do {
                                    try managedObjectContext.save()
                                } catch {}
                            }
                        }
                    }
                    
                }.padding()
            }
            
            .onReceive(model.selectionChanged) { _ in
                if model.codeEditorMode != .project && model.codeEditorMode != .module {
                    selected = nil
                }
            }
            
            /*
            List(topLevelNodes, children: \.children) { node in
                
                
                Button(action: {
                    
                    selectedNode = node
                    //document.model.objectSelected.send(object)
                    model.parser?.gotoNode(node: node)
                })
                {
                    Label(node.name, systemImage: getNodeIconName(node))
                        //.frame(maxWidth: .infinity, alignment: .leading)
                        //.contentShape(Rectangle())
                        .foregroundColor(selectedNode === node || selectedTopLevel === node ? .accentColor : .primary)
                }
                .buttonStyle(PlainButtonStyle())
            }*/
        }
        /*
        .onReceive(model.modelChanged) { _ in
            if let parser = model.parser {
                topLevelNodes = parser.topLevelNodes
                updateView.toggle()
            }
        }*/
        /*
        ZStack(alignment: .center) {
            
            ForEach(model.project.objects, id: \.self) { object in
                
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
        }*/
        
        //.onReceive(model.objectSelected) { object in
        //    selection = object
        //}
        
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
    /*
    func addDefinitionToLibrary(_ node: GraphNode, type: String) {
        let object = Component(context: managedObjectContext)
        object.name = node.givenName
        object.data = node.code
        object.type = type
        
        try! managedObjectContext.save()
    }*/
}
