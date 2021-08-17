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
        case modules
    }
    
    let model                               : Model
    
    @State private var selection            : NavigationItem? = .shapes
    
    @State private var editingMode          : Model.EditingMode? = .single
    @State private var editingBooleanMode   : Model.EditingBooleanMode? = .plus

    @State private var editingBrushMode     : Model.EditingBrushMode? = .GeometryAndMaterial
    
    @State private var materialOnlyMixer    : Float = 0.5
    @State private var materialOnlyText     : String = "0.5"
    @State private var materialOnlyRange    = float2(0, 1)

    var body: some View {
                
        /*
        NavigationView {
         List {
             NavigationLink(tag: NavigationItem.shapes, selection: $selection) {
                 ShapeView(model: model)
             } label: {
                 Label("Shapes", systemImage: "square")
             }
             
             NavigationLink(tag: NavigationItem.materials, selection: $selection) {
             } label: {
                 Label("Materials", systemImage: "book.closed")
             }
             
             NavigationLink(tag: NavigationItem.scripts, selection: $selection) {
                 Text("Scripts")
             } label: {
                 Label("Scripts", systemImage: "heart")
             }
         
         }
        }*/
        
        VStack(alignment: .leading, spacing: 1) {

            HStack(alignment: .top) {
                               
                /*
                Button(action: {
                    editingBrushMode = .GeometryAndMaterial
                    model.editingBrushMode = .GeometryAndMaterial
                    model.renderer?.restart()
                })
                {
                    Image(systemName: editingBrushMode == .GeometryAndMaterial ? "cube.fill" : "cube")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 10)
                .padding(.bottom, 4)
                          
                //Divider()

                Button(action: {
                    editingBrushMode = .MaterialOnly
                    model.editingBrushMode = .MaterialOnly
                    
                    model.editingCmd.action = .None
                    model.renderer?.restart()
                })
                {
                    Image(systemName: editingBrushMode == .MaterialOnly ? "paintpalette.fill" : "paintpalette")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                
                Divider()
                    .frame(maxHeight: 16)
                                    
                Button(action: {
                    editingMode = .single
                    model.editingMode = .single
                })
                {
                    Image(systemName: editingMode == .single ? "circlebadge.fill" : "circlebadge")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                .padding(.bottom, 4)
                          
                //Divider()

                Button(action: {
                    editingMode = .multiple
                    model.editingMode = .multiple
                })
                {
                    Image(systemName: editingMode == .multiple ? "circlebadge.2.fill" : "circlebadge.2")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                
                Divider()
                    .frame(maxHeight: 16)
                
                if editingBrushMode == .GeometryAndMaterial {
                    
                    Button(action: {
                        editingBooleanMode = .plus
                        model.editingBooleanMode = .plus
                    })
                    {
                        Image(systemName: editingBooleanMode == .plus ? "plus.square.fill" : "plus.square")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    .padding(.bottom, 4)
                              
                    //Divider()

                    Button(action: {
                        editingBooleanMode = .minus
                        model.editingBooleanMode = .minus
                    })
                    {
                        Image(systemName: editingBooleanMode == .minus ? "minus.square.fill" : "minus.square")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                }
                else
                if editingBrushMode == .MaterialOnly {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.gray)
                        .imageScale(.large)
                    DataFloatSliderView(model, "Brush", $materialOnlyMixer, $materialOnlyText, $materialOnlyRange, .accentColor, 2)
                        .frame(maxHeight: 19)
                }
                
                Button(action: {
                    if let object = model.selectedObject {
                        if let cmd = model.editingCmd.copy() {
                            
                            if cmd.role == .GeometryAndMaterial {
                                if let selectedShape = model.selectedShape {
                                    cmd.name = selectedShape.name
                                }
                            } else
                            if cmd.role == .MaterialOnly {
                                if let name = cmd.material.data.getText("Name") {
                                    cmd.name = "\(name) applied on \(cmd.geometryId)"
                                }
                            }
                            
                            print(cmd.role)
                            
                            object.commands.append(cmd)
                            model.modeler?.executeCommand(cmd)
                            model.renderer?.restart()
                            
                            model.selectedCommand = cmd
                            model.commandSelected.send(cmd)
                            
                            model.editingCmd.action = .None
                        }
                    }
                })
                {
                    Text("Accept")
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 10)
                //.disabled(true)
                
                //Spacer()
                 */
            }
            Divider()
            
            HStack {
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
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Group {
                        if selection == .materials {
                            Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                        } else { Color.clear }
                    })
                    
                    Button(action: {
                        selection =  .modules
                    })
                    {
                        Label("Modules", systemImage: "l.square")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.leading, 6)
                            .foregroundColor(.white)
                    }
                    .contextMenu {
                        Button("Add") {
                            let module = ModuleEntity(context: managedObjectContext)
                            
                            module.id = UUID()
                            module.name = "vec3"
                            module.code = "dsd".data(using: .utf8)
                            
                            do {
                                try managedObjectContext.save()
                            } catch {}
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Group {
                        if selection == .modules {
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
                if selection == .materials {
                    MaterialView(model: model)
                } else
                if selection == .modules {
                    ModuleView(model: model)
                }
                Spacer()
            }
            .padding(.top, 0)
        }
        
        //.onReceive(model.componentPreviewNeedsUpdate) { _ in
        //}
        
        .onReceive(model.objectSelected) { object in

        }
        
        .onChange(of: materialOnlyMixer) { value in
            model.materialOnlyMixer = value
        }
    }
}
