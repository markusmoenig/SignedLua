//
//  ObjectView.swift
//  Signed
//
//  Created by Markus Moenig on 27/6/21.
//

import SwiftUI

struct BrowserView: View {
        
    enum BrushMode {
        case Geometry
        case Paint
    }
    
    enum NavigationItem {
        case shapes
        case materials
        case scripts
    }
    
    let model                               : Model
    
    @State private var selection            : NavigationItem? = .shapes
    
    @State private var editingMode          : Model.EditingMode? = .single
    @State private var editingBooleanMode   : Model.EditingBooleanMode? = .plus

    @State private var editingBrushMode     : Model.EditingBrushMode? = .Geometry
    
    @State private var brushSize            : Float = 0.05
    @State private var brushRange           = float2(0, 0.5)

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
                                
                Button(action: {
                    editingBrushMode = .Geometry
                    model.editingBrushMode = .Geometry
                    model.renderer?.restart()
                })
                {
                    Image(systemName: editingBrushMode == .Geometry ? "cube.fill" : "cube")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 10)
                .padding(.bottom, 4)
                          
                //Divider()

                Button(action: {
                    editingBrushMode = .Brush
                    model.editingBrushMode = .Brush
                    
                    model.editingCmd.action = .None
                    model.renderer?.restart()
                })
                {
                    Image(systemName: editingBrushMode == .Brush ? "paintbrush.pointed.fill" : "paintbrush.pointed")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
                
                Divider()
                    .frame(maxHeight: 16)
                
                if editingBrushMode == .Geometry {
                    
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
                    
                    Button(action: {
                        if let object = model.selectedObject {
                            if let cmd = model.editingCmd.copy() {
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
                }
                else
                if editingBrushMode == .Brush {
                    Image(systemName: "scribble.variable")
                        .foregroundColor(.gray)
                        .imageScale(.large)
                    DataFloatSliderView(model, $brushSize, $brushRange, .accentColor, 2)
                        .frame(maxHeight: 19)
                }
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
                        selection =  .materials
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
                        selection =  .scripts
                    })
                    {
                        Label("Scripts", systemImage: "j.square")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.leading, 6)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Group {
                        if selection == .scripts {
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
                }
                Spacer()
            }
            .padding(.top, 0)
        }
        
        //.onReceive(model.componentPreviewNeedsUpdate) { _ in
        //}
        
        .onReceive(model.objectSelected) { object in

        }
        
        .onChange(of: brushSize) { value in
            model.brushSize = value
        }
    }
}
