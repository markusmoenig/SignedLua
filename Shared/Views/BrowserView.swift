//
//  ObjectView.swift
//  Signed
//
//  Created by Markus Moenig on 27/6/21.
//

import SwiftUI

struct BrowserView: View {
        
    @Environment(\.managedObjectContext) var managedObjectContext

    enum BrushMode {
        case Geometry
        case Paint
    }
    
    enum NavigationItem {
        case shapes
        case objects
        case materials
    }
    
    let model                               : Model
    
    @State private var selection            : NavigationItem? = .shapes

    @State private var showDatabasePopover  : Bool = false
    @State private var databaseName         : String = ""

    var body: some View {
        
        VStack(alignment: .leading, spacing: 1) {

            Divider()
            
            HStack(spacing: 1) {
                List {
                    Button(action: {
                        selection =  .shapes
                        if let selectedShape = model.selectedShape {
                            self.model.shapeSelected.send(selectedShape)
                        }
                    })
                    {
                        Label("Shapes", systemImage: "cube")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.leading, 6)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Group {
                        if selection == .shapes {
                            Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                        } else { Color.clear }
                    })
                    
                    Button(action: {
                        selection = .objects
                        //if let selectedMaterial = model.selectedMaterial {
                        //    self.model.materialSelected.send(selectedMaterial)
                        //}
                    })
                    {
                        Label("Objects", systemImage: "house")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.leading, 6)
                            .foregroundColor(.white)
                    }
                    .contextMenu {
                        Button("Add") {
                            let module = ObjectEntity(context: managedObjectContext)
                            
                            module.id = UUID()
                            module.name = "Object"
                            module.code = "test".data(using: .utf8)
                            
                            do {
                                try managedObjectContext.save()
                            } catch {}
                            
                            let project = ProjectEntity(context: managedObjectContext)
                            
                            project.id = UUID()
                            project.name = "Object"
                            project.code = "test".data(using: .utf8)
                            
                            do {
                                try managedObjectContext.save()
                            } catch {}
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Group {
                        if selection == .objects {
                            Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                        } else { Color.clear }
                    })
                    
                    Button(action: {
                        selection = .materials
                        if let selectedMaterial = model.selectedMaterial {
                            self.model.materialSelected.send(selectedMaterial)
                        }
                    })
                    {
                        Label("Materials", systemImage: "paintpalette")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.leading, 6)
                            .foregroundColor(.white)
                    }
                    .contextMenu {
                        Button("Add") {
                            let module = MaterialEntity(context: managedObjectContext)
                            
                            module.id = UUID()
                            module.name = "Object"
                            module.code = "test".data(using: .utf8)
                            
                            do {
                                try managedObjectContext.save()
                            } catch {}
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Group {
                        if selection == .materials {
                            Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                        } else { Color.clear }
                    })
                }

                #if os(OSX)
                .frame(maxWidth: 130)
                #elseif os(iOS)
                .frame(maxWidth: 230)
                .listStyle(.plain)
                #endif

                Divider()
                
                if selection == .shapes {
                    ShapeView(model: model)
                } else
                if selection == .objects {
                    ObjectView(model: model)
                } else
                if selection == .materials {
                    MaterialView(model: model)
                }
                
                Divider()

                InfoView(model: model)
                    .frame(maxWidth: 400)
                    .foregroundColor(.gray)
            }
            .padding(.top, 0)
        }
        
        //.onChange(of: materialOnlyMixer) { value in
        //    model.materialOnlyMixer = value
        //}
    }
}
