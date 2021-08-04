//
//  StackView.swift
//  Signed
//
//  Created by Markus Moenig on 1/7/21.
//

import SwiftUI

struct StackView: View {
    
    let model                               : Model

    @State var selectedObject               : SignedObject? = nil
    @State var updateView                   = false

    var body: some View {
        
        List {
            
            /*
            List(model.project.objects, children: \.children) { object in
                Text(object.name)
                    .foregroundColor(selectedObject == object ? .accentColor : .gray)
                
                ForEach(object.commands, id: \.id) { cmd in
                    Text(cmd.name)
                        .border(model.selectedCommand === cmd ? .white : .clear)
                }
            }*/
            /*
            
            OutlineGroup(model.project.objects, children: \.children) { object in
                Text(object.name)
                    .foregroundColor(selectedObject == object ? .accentColor : .gray)
                VStack {

                    ForEach(object.commands, id: \.id) { cmd in
                        Text(cmd.name)
                            .border(model.selectedCommand === cmd ? .white : .clear)
                    }
                }
            }*/
            
            if let selected = selectedObject {
                //Section(header: Text("Command Stack")) {
                    //ForEach(selected.commands, id: \.id) { cmd in
                      
                ForEach(Array(selected.commands.enumerated()), id:\.element.id) { (index, cmd) in

                    //ForEach(Array(zip(1..., selected.commands)), id: \.1.id) { number, cmd in
                        //Text("\(number). \(person.name)")
                        Button(action: {
                            model.selectedCommand = cmd
                            model.commandSelected.send(cmd)
                            
                            // Copy geometry and material
                            
                            if cmd.role == .GeometryAndMaterial {
                                model.editingCmd.copyGeometry(from: cmd)
                                model.shapeSelected.send(cmd)
                            }
                            model.editingCmd.copyMaterial(from: cmd.material)
                            if cmd.role == .MaterialOnly {
                                model.materialSelected.send(cmd)
                            }

                            model.editingCmdChanged.send(model.editingCmd)
                            
                            // Render to cmd ? Disabled for now
                            //model.modeler?.buildIndex = nil
                            //model.modeler?.buildTo = cmd
                        })
                        {
                            if cmd.role == .GeometryAndMaterial {
                                Image(systemName: "cube")
                                    .foregroundColor(model.selectedCommand === cmd ? .accentColor : .gray)
                            }
                            Image(systemName: "paintpalette")
                                .foregroundColor(model.selectedCommand === cmd ? .accentColor : .gray)
                            Text(String(index) + ". " + cmd.name)
                                .foregroundColor(model.selectedCommand === cmd ? .accentColor : .gray)

                            //Label(cmd.name, systemImage: "circle")
                                //.frame(maxWidth: .infinity, alignment: .leading)
                                //.contentShape(Rectangle())
                                //.padding(.leading, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        /*
                        .listRowBackground(Group {
                            if model.selectedCommand === cmd  {
                                Color.accentColor.mask(RoundedRectangle(cornerRadius: 4))
                            } else { Color.gray.mask(RoundedRectangle(cornerRadius: 4).opacity(0.1)) }
                        })*/
                    }

                //}
            }

            /*
            if let selected = selectedObject {
                ForEach(selected.commands, id: \.self) { cmd in
                    
                    Canvas { context, size in
                        
                        context.fill(
                            Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 0),
                            with: .color(.gray))
                        /*
                        context.stroke(
                            Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10),
                            with: .color(model.selectedCommand === cmd ? .white : .clear),
                            lineWidth: 2)
                         */
                        
                        let text = cmd.name
                        
                        context.draw(Text(text), at: CGPoint(x: 4, y: 2), anchor: .topLeading)
                        
                    }
                    .frame(width: 100, height: 20)
                    .border(model.selectedCommand === cmd ? .white : .clear)
                    //.scaleEffect(scale)
                    .onTapGesture {
                        model.selectedCommand = cmd
                        model.commandSelected.send(cmd)
                        //model.modeler?.executeObject(selected, until: cmd)
                        model.modeler?.buildIndex = nil
                        model.modeler?.buildTo = cmd
                        //model.renderer?.restart()
                    }
                    .contextMenu {
                        Text("hallo")
                    }
                }
            }*/
        }
        .listStyle(InsetListStyle(alternatesRowBackgrounds: true))

        .onAppear(perform: {
            selectedObject = nil
            updateView.toggle()
            selectedObject = model.selectedObject
        })
        
        .onReceive(model.commandSelected) { cmd in
            selectedObject = nil
            updateView.toggle()
            selectedObject = model.selectedObject
        }
    
    }
}
