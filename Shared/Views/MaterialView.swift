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
    
    @State var selected                     : SignedCommand? = nil
    
    init(model: Model) {
        self.model = model
        _selected = State(initialValue: model.selectedMaterial)
    }

    var body: some View {
    
        let rows: [GridItem] = Array(repeating: .init(.fixed(70)), count: 1)
            
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, alignment: .center) {
                //ForEach(model.materials, id: \.id) { material in
                ForEach(objects, id: \.self) { object in

                    ZStack(alignment: .center) {
                        
                        if let material = model.materials[object.id!] {
                            
                            if let image = material.icon {
                                Image(image, scale: 1.0, label: Text(object.name!))
                                    .onTapGesture(perform: {
                                        
                                        selected = material
                                                                                    
                                        model.selectedMaterial = material
                                        model.editingCmd.copyMaterial(from: material.material)
                                        model.materialSelected.send(material)
                                        
                                        model.editingCmd.code = material.code
                                        //model.codeEditor?.setValue(model.editingCmd)
                                        
                                        model.editingCmdChanged.send(model.editingCmd)
                                        model.renderer?.restart()
                                    })
                                    .contextMenu {
                                        Button("Delete") {
                                            managedObjectContext.delete(object)
                                            do {
                                                try managedObjectContext.save()
                                            } catch {}
                                        }
                                    }
                            } else {
                                Rectangle()
                                    .fill(Color.secondary)
                                    .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                    .onTapGesture(perform: {
                                        
                                        selected = material
                                                                                    
                                        model.selectedMaterial = material
                                        model.editingCmd.copyMaterial(from: material.material)
                                        model.materialSelected.send(material)
                                        
                                        model.editingCmd.code = material.code
                                        //model.codeEditor?.setValue(model.editingCmd)
                                        
                                        model.editingCmdChanged.send(model.editingCmd)
                                        model.renderer?.restart()
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
                            
                            if material === selected {
                                Rectangle()
                                    .stroke(Color.accentColor, lineWidth: 2)
                                    .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                    .allowsHitTesting(false)
                            }
                            
                            Rectangle()
                                .fill(.black)
                                .opacity(0.4)
                                .frame(width: CGFloat(ModelerPipeline.IconSize - (material === selected ? 2 : 0)), height: CGFloat(20 - (material === selected ? 1 : 0)))
                                .padding(.top, CGFloat(ModelerPipeline.IconSize - (20 + (material === selected ? 1 : 0))))
                            
                            Text(object.name!)
                                .padding(.top, CGFloat(ModelerPipeline.IconSize - 20))
                                .allowsHitTesting(false)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding()
        }
    
        .onReceive(model.iconFinished) { cmd in
            let buffer = selected
            selected = cmd
            selected = buffer
            //print("finished", cmd.name)
        }
    }
}
