//
//  MaterialView.swift
//  Signed
//
//  Created by Markus Moenig on 4/7/21.
//

import SwiftUI

struct MaterialView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext

    @FetchRequest(
      entity: MaterialEntity.entity(),
      sortDescriptors: [
        NSSortDescriptor(keyPath: \MaterialEntity.name, ascending: true)
      ]
    ) var objects: FetchedResults<MaterialEntity>
    
    let model                               : Model
    
    @State var selected                     : MaterialEntity? = nil
    
    init(model: Model) {
        self.model = model
        //_selected = State(initialValue: model.selectedMaterial)
    }

    var body: some View {
    
        let rows: [GridItem] = Array(repeating: .init(.fixed(70)), count: 1)
        
        HStack {
        
            VStack(alignment: .center) {
                Button(action: {
                    let object = MaterialEntity(context: managedObjectContext)
                    
                    object.id = UUID()
                    object.name = "New Material"
                    
                    let material = SignedMaterial()
                    object.data = material.toData()
                    
                    model.materialCmds[object.id!] = material
                    selected = object

                    do {
                        try managedObjectContext.save()
                    } catch {}
                })
                {
                    //Label("Add", systemImage: "+")
                    //Image(systemName: "+")
                    Text("New")
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 10)
                
                Spacer()
            }
            
            ScrollView(.horizontal) {
                LazyHGrid(rows: rows, alignment: .center) {
                    //ForEach(model.materials, id: \.id) { material in
                    ForEach(objects, id: \.self) { object in

                        ZStack(alignment: .center) {
                            
                            if let image = model.materialCmds[object.id!]?.icon {
                                Image(image, scale: 1.0, label: Text(object.name!))
                                    .onTapGesture(perform: {
                                        
                                        selected = object
                                        /*
                                        model.selectedMaterial = object
                                        model.editingCmd.copyMaterial(from: material)
                                        model.materialSelected.send(material)
                                        model.editingCmdChanged.send(model.editingCmd)
                                        model.renderer?.restart()*/
                                    })
                            } else {
                                Rectangle()
                                    .fill(Color.secondary)
                                    .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                    .onTapGesture(perform: {
                                        
                                        selected = object
                                        
                                        if let material = model.materialCmds[object.id!] {
                                            
                                            model.selectedMaterial = material
                                            model.editingCmd.copyMaterial(from: material)
                                            model.materialSelected.send(material)
                                            model.editingCmdChanged.send(model.editingCmd)
                                            model.renderer?.restart()
                                        }
                                    })
                                    .contextMenu {
                                        Button("Delete") {
                                            managedObjectContext.delete(object)
                                            do {
                                                try managedObjectContext.save()
                                            } catch {}
                                        }
                                    }
                            }
                            
                            if object === selected {
                                Rectangle()
                                    .stroke(Color.accentColor, lineWidth: 2)
                                    .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                    .allowsHitTesting(false)
                            }
                            
                            Rectangle()
                                .fill(.black)
                                .opacity(0.4)
                                .frame(width: CGFloat(ModelerPipeline.IconSize - (object === selected ? 2 : 0)), height: CGFloat(20 - (object === selected ? 1 : 0)))
                                .padding(.top, CGFloat(ModelerPipeline.IconSize - (20 + (object === selected ? 1 : 0))))
                            
                            Text(object.name!)
                                .padding(.top, CGFloat(ModelerPipeline.IconSize - 20))
                                .allowsHitTesting(false)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
            }
        }

        .onReceive(model.iconFinished) { cmd in
            let buffer = selected
            selected = nil
            selected = buffer
            print("finished", cmd.name)
        }
    }
}
