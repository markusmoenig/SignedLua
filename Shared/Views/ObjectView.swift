//
//  ObjectView.swift
//  ObjectView
//
//  Created by Markus Moenig on 17/8/21.
//

import SwiftUI

struct ObjectView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext

    @FetchRequest(
      entity: ObjectEntity.entity(),
      sortDescriptors: [
        NSSortDescriptor(keyPath: \ObjectEntity.name, ascending: true)
      ]
    ) var objects: FetchedResults<ObjectEntity>
    
    let model                               : Model
    
    @State var selected                     : UUID? = nil
    @State private var IconSize             : CGFloat = 70

    init(model: Model) {
        self.model = model
        //_selected = State(initialValue: model.selectedMaterial)
    }

    var body: some View {
    
        let rows: [GridItem] = Array(repeating: .init(.fixed(70)), count: 1)
            
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, alignment: .center) {
                //ForEach(model.materials, id: \.id) { material in
                ForEach(objects, id: \.self) { object in

                    ZStack(alignment: .center) {
                        
                        Image(systemName: "cylinder")
                            .resizable()
                            .scaledToFit()
                            .frame(width: IconSize * 0.8, height: IconSize * 0.8)
                            .padding(.bottom, 15)
                            .onTapGesture(perform: {
                                
                                selected = object.id!
                                /*
                                model.selectedMaterial = material
                                model.editingCmd.copyMaterial(from: material.material)
                                model.materialSelected.send(material)
                                
                                model.editingCmd.code = material.code
                                //model.codeEditor?.setValue(model.editingCmd)
                                
                                model.editingCmdChanged.send(model.editingCmd)
                                model.renderer?.restart()
                                */
                            })
                            .contextMenu {
                                Button("Delete") {
                                    managedObjectContext.delete(object)
                                    do {
                                        try managedObjectContext.save()
                                    } catch {}
                                }
                            }
                            
                            if object.id == selected {
                                Rectangle()
                                    .stroke(Color.accentColor, lineWidth: 2)
                                    .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                    .allowsHitTesting(false)
                            }
                            
                            Rectangle()
                                .fill(.black)
                                .opacity(0.4)
                                .frame(width: CGFloat(ModelerPipeline.IconSize - (object.id == selected ? 2 : 0)), height: CGFloat(20 - (object.id == selected ? 1 : 0)))
                                .padding(.top, CGFloat(ModelerPipeline.IconSize - (20 + (object.id == selected ? 1 : 0))))
                            
                            Text(object.name!)
                                .padding(.top, CGFloat(ModelerPipeline.IconSize - 20))
                                .allowsHitTesting(false)
                                .foregroundColor(.white)
                             
                        }
                    //}
                }
            }
            .padding()
        }
    
        /*
        .onReceive(model.iconFinished) { cmd in
            let buffer = selected
            selected = cmd
            selected = buffer
            //print("finished", cmd.name)
        }*/
    }
}
