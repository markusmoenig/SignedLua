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
    ) var materials: FetchedResults<MaterialEntity>
    
    let model                               : Model
    
    @State var selected                     : UUID? = nil
    
    init(model: Model) {
        self.model = model
        //_selected = State(initialValue: model.selectedMaterial)
    }

    var body: some View {
    
        let rows: [GridItem] = Array(repeating: .init(.fixed(70)), count: 1)
            
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, alignment: .center) {
                //ForEach(model.materials, id: \.id) { material in
                ForEach(materials, id: \.self) { material in

                    ZStack(alignment: .center) {
                                                    
                        if let image = getMaterialIcon(material: material) {
                            Image(image, scale: 1.0, label: Text(material.name!))
                                .onTapGesture(perform: {
                                    
                                    selected = material.id
                                    
                                    if let data = material.code {
                                        if let value = String(data: data, encoding: .utf8) {
                                            model.codeEditor?.setSession(value: value, session: "__material_" + material.name!)
                                            
                                            model.codeEditorMode = .material
                                            model.codeEditorMaterialEntity = material
                                            model.selectionChanged.send()
                                        }
                                    }
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
                                        managedObjectContext.delete(material)
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
                                    
                                    selected = material.id
                                    
                                    if let data = material.code {
                                        if let value = String(data: data, encoding: .utf8) {
                                            model.codeEditor?.setSession(value: value, session: "__material_" + material.name!)
                                            
                                            model.codeEditorMode = .material
                                            model.codeEditorMaterialEntity = material
                                            model.selectionChanged.send()
                                        }
                                    }
                                })
                                .contextMenu {
                                    Button("Delete") {
                                        managedObjectContext.delete(material)
                                        do {
                                            try managedObjectContext.save()
                                        } catch {}
                                    }
                                }
                        }
                        
                        if material.id == selected {
                            Rectangle()
                                .stroke(Color.accentColor, lineWidth: 2)
                                .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                .allowsHitTesting(false)
                        }
                        
                        Rectangle()
                            .fill(.black)
                            .opacity(0.2)
                            .frame(width: CGFloat(ModelerPipeline.IconSize - (material.id == selected ? 2 : 0)), height: CGFloat(18 - (material.id == selected ? 1 : 0)))
                            .padding(.top, CGFloat(ModelerPipeline.IconSize - (18 + (material.id == selected ? 1 : 0))))
                        
                        Text(material.name!)
                            .padding(.top, CGFloat(ModelerPipeline.IconSize - 18))
                            .allowsHitTesting(false)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        
        .onReceive(model.selectionChanged) { _ in
            if model.codeEditorMode != .material {
                selected = nil
            }
        }
    
        .onReceive(model.iconFinished) { id in
            let buffer = selected
            //selected = cmd
            selected = id
            selected = buffer
            //print("finished", cmd.name)
        }
    }
    
    func getMaterialIcon(material: MaterialEntity) -> CGImage? {
        #if os(OSX)
        if let data = material.icon {
            if let image = NSImage(data: data) {
                return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
        }
        #else
        if let data = material.icon {
            if let image = UIImage(data: data) {
                return image.cgImage
            }
        }
        #endif
        return nil
    }
}
