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
    
    let model                                   : Model

    @State private var databaseType             : DatabaseType = .object
    @State private var showDatabasePopover      : Bool = false
    @State private var databaseObject           : SignedObject? = nil
    @State private var databaseTypeName         : String = ""

    @State private var showProjectNamePopover   : Bool = false
    @State private var projectName              : String = ""
    
    @State private var selected                 : UUID? = nil

    @State var updateView                       : Bool = false
    
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
        _selected = State(initialValue: model.project.main.id)
        if model.selectedObject == nil {
            model.selectedObject = model.project.main
        }
    }
    
    var body: some View {
        
        ZStack(alignment: .bottomLeading) {

            List {
                Section(header: Text("Project")) {
                    
                    Button(action: {
                        let object = model.project.main
                        selected = object.id
                        model.selectedObject = object
                        model.codeEditor?.setSession(value: object.getCode(), session: object.session)
                        if model.codeEditorMode != .project {
                            model.codeEditorMode = .project
                            model.selectionChanged.send()
                        }
                    })
                    {
                        Label("main", systemImage: selected == model.project.main.id ? "s.square.fill" :  "s.square")
                            .foregroundColor(selected == model.project.main.id ? .accentColor : .primary)
                    }
                    .contextMenu {
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Objects
                    ForEach(model.project.objects, id: \.id) { object in
                        HStack{
                        Button(action: {
                            selected = object.id
                            model.selectedObject = object
                            model.codeEditor?.setSession(value: object.getCode(), session: object.session)
                            if model.codeEditorMode != .project {
                                model.codeEditorMode = .project
                                model.selectionChanged.send()
                            }
                        })
                        {
                            Label(object.name, systemImage: selected == object.id ? "cube.fill" : "cube")
                                .foregroundColor(selected == object.id ? .accentColor : .primary)
                        }
                        .contextMenu {
                            Button("Upload to Database...") {
                                selected = object.id
                                databaseObject = object
                                databaseType = .object
                                databaseTypeName = " object "
                                showDatabasePopover = true
                            }
                            
                            Button("Rename...") {
                                selected = object.id
                                projectName = object.name
                                showProjectNamePopover = true
                            }
                            
                            Divider()
                            
                            Button("Delete") {
                                if let index = model.project.objects.firstIndex(of: object) {
                                    model.project.objects.remove(at: index)
                                }
                                selected = model.project.main.id
                                model.selectedObject = model.project.main
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        Image(systemName: "eye")
                            .foregroundColor(selected == object.id ? .accentColor : .primary)
                            .onTapGesture(perform: {
                                if let renderer = model.renderer {
                                    model.builder.build(code: object.getCode(), kit: model.modeler!.mainKit, content: .object, renderKits: [renderer.mainRenderKit])
                                }
                            })
                        }
                    }
                    
                    // Materials
                    ForEach(model.project.materials, id: \.id) { material in
                        Button(action: {
                            selected = material.id
                            model.selectedObject = material
                            model.codeEditor?.setSession(value: material.getCode(), session: material.session)
                            if model.codeEditorMode != .project {
                                model.codeEditorMode = .project
                                model.selectionChanged.send()
                            }
                        })
                        {
                            Label(material.name, systemImage: selected == material.id ? "paintpalette.fill" : "paintpalette")
                                .foregroundColor(selected == material.id ? .accentColor : .primary)
                        }
                        .contextMenu {
                            Button("Upload to Database...") {
                                selected = material.id
                                databaseObject = material
                                databaseType = .material
                                databaseTypeName = " material "
                                showDatabasePopover = true
                            }
                            
                            Button("Rename...") {
                                selected = material.id
                                projectName = material.name
                                showProjectNamePopover = true
                            }
                            
                            Divider()
                            
                            Button("Delete") {
                                if let index = model.project.materials.firstIndex(of: material) {
                                    model.project.materials.remove(at: index)
                                }
                                selected = model.project.main.id
                                model.selectedObject = model.project.main
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        Image(systemName: "eye")
                            .foregroundColor(selected == material.id ? .accentColor : .primary)
                            .onTapGesture(perform: {
                                if let renderer = model.renderer {
                                    model.builder.build(code: material.getCode(), kit: model.modeler!.mainKit, content: .material, renderKits: [renderer.mainRenderKit])
                                }
                            })
                    }
                    
                    // Modules
                    ForEach(model.project.modules, id: \.id) { module in
                        Button(action: {
                            selected = module.id
                            model.selectedObject = model.project.main
                            model.codeEditor?.setSession(value: module.getCode(), session: module.session)
                            if model.codeEditorMode != .project {
                                model.codeEditorMode = .project
                                model.selectionChanged.send()
                            }
                        })
                        {
                            Label(module.name, systemImage: selected == module.id ? "cylinder.fill" : "cylinder")
                                .foregroundColor(selected == module.id ? .accentColor : .primary)
                        }
                        .contextMenu {
                            Button("Upload to Database...") {
                                selected = module.id
                                databaseObject = module
                                databaseType = .module
                                databaseTypeName = " module "
                                showDatabasePopover = true
                            }
                            
                            Button("Rename...") {
                                selected = module.id
                                projectName = module.name
                                showProjectNamePopover = true
                            }
                            
                            Divider()
                            
                            Button("Delete") {
                                if let index = model.project.modules.firstIndex(of: module) {
                                    model.project.modules.remove(at: index)
                                }
                                selected = model.project.main.id
                                model.selectedObject = model.project.main
                            }
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
            
            // Edit object name
            .popover(isPresented: self.$showProjectNamePopover,
                     arrowEdge: .top
            ) {
                VStack(alignment: .leading) {
                    Text("Name:")
                    TextField("Name", text: $projectName, onEditingChanged: { (changed) in
                        if let selected = selected {
                            if let o = self.model.project.getObject(from: selected) {
                                o.name = projectName
                                self.selected = nil
                                self.selected = o.id
                            }
                        }
                    })
                    .frame(minWidth: 200)
                }.padding()
            }
            
            HStack {
                Menu {
                    
                    Button("Object", action: {
                        let object = SignedObject("New Object")
                        object.code = "-- Object\n\nfunction buildObject(index, bbox, options)\n\nend\n\n-- Used for preview\nfunction defaultSize()\n    return vec3(1, 1, 1)\nend\n".data(using: .utf8)
                        model.project.objects.append(object)
                        selected = object.id
                        model.codeEditor?.setSession(value: object.getCode(), session: object.session)
                        projectName = object.name
                        showProjectNamePopover = true
                    })
                    
                    Button("Material", action: {
                        let material = SignedObject("New Material")
                        material.code = "-- Material\n\nfunction buildMaterial(index)\n\nend\n".data(using: .utf8)
                        model.project.materials.append(material)
                        selected = material.id
                        model.codeEditor?.setSession(value: material.getCode(), session: material.session)
                        projectName = material.name
                        showProjectNamePopover = true
                    })
                    
                    Button("Module", action: {
                        let module = SignedObject("newmodule")
                        module.code = "-- module\n".data(using: .utf8)
                        model.project.modules.append(module)
                        selected = module.id
                        model.codeEditor?.setSession(value: module.getCode(), session: module.session)
                        projectName = module.name
                        showProjectNamePopover = true
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
            
            // Upload an object, material or module to the public database
            .popover(isPresented: $showDatabasePopover,
                     arrowEdge: .top
            ) {
                VStack(alignment: .leading) {
                    Text("Database upload")
                        .font(.title)
                    Text("By uploading your \(databaseTypeName) code to the public database")
                        .font(.body)
                        .foregroundColor(Color.secondary)
                        .padding(.top, 4)
                    Text("you make it available for public consumption and waive any")
                        .font(.body)
                        .foregroundColor(Color.secondary)
                    Text("proprietory copyright.")
                        .font(.body)
                        .foregroundColor(Color.secondary)
                    Text("Please test it first and choose a unique name.")
                        .font(.body)
                        .foregroundColor(Color.secondary)
                        .padding(.top, 2)
                    Text("Thanks for sharing!")
                        .font(.body)
                        .foregroundColor(Color.secondary)
                        //.frame(minWidth: 400, maxWidth: 400)
                        .padding(.top, 2)

                    Button("Upload") {
                        if let databaseObject = databaseObject {
                            
                            if databaseType == .object {
                                let object = ObjectEntity(context: managedObjectContext)
                                
                                object.id = UUID()
                                object.name = databaseObject.name
                                object.code = databaseObject.code
                                object.icon = "  ".data(using: .utf8)
                                object.render = "  ".data(using: .utf8)
                                object.about = ""
                                object.tags = ""

                                do {
                                    try managedObjectContext.save()
                                } catch {}
                            } else
                            if databaseType == .material {
                                let material = MaterialEntity(context: managedObjectContext)
                                
                                material.id = UUID()
                                material.name = databaseObject.name
                                material.code = databaseObject.code
                                //material.icon = "  ".data(using: .utf8)
                                //material.render = "  ".data(using: .utf8)
                                material.about = ""
                                material.tags = ""

                                do {
                                    try managedObjectContext.save()
                                } catch {}
                            } else
                            if databaseType == .module {
                                let module = ModuleEntity(context: managedObjectContext)
                                
                                module.id = UUID()
                                module.name = databaseObject.name
                                module.code = databaseObject.code
                                module.about = ""
                                
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
        }
    }
}
