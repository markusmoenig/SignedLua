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
    
    @State var selected                     : MaterialEntity? = nil
    
    init(model: Model) {
        self.model = model
        //_selected = State(initialValue: model.selectedMaterial)
    }

    var body: some View {
    
        let rows: [GridItem] = Array(repeating: .init(.fixed(80)), count: 2)
            
        ScrollView(.horizontal) {
            LazyVGrid(columns: rows, alignment: .center) {
                //ForEach(model.materials, id: \.id) { material in
                ForEach(materials, id: \.self) { material in

                    ZStack(alignment: .center) {
                                                    
                        if let image = getMaterialIcon(material: material) {
                            Image(image, scale: 1.0, label: Text(material.name!))
                                .onTapGesture(perform: {
                                    
                                    selected = material
                                    model.selectedDBMaterial = material
                                    model.dbMaterialSelected.send(material)

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
                        } else {
                            Rectangle()
                                .fill(Color.secondary)
                                .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                .onTapGesture(perform: {
                                    
                                    selected = material
                                    model.selectedDBMaterial = material
                                    model.dbMaterialSelected.send(material)
                                    
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
                        
                        if material === selected {
                            Rectangle()
                                .stroke(Color.accentColor, lineWidth: 2)
                                .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                .allowsHitTesting(false)
                        }
                        
                        /*
                        Rectangle()
                            .fill(.black)
                            .opacity(0.2)
                            .frame(width: CGFloat(ModelerPipeline.IconSize - (material === selected ? 2 : 0)), height: CGFloat(18 - (material === selected ? 1 : 0)))
                            .padding(.top, CGFloat(ModelerPipeline.IconSize - (18 + (material === selected ? 1 : 0))))
                        
                        Text(material.name!)
                            .padding(.top, CGFloat(ModelerPipeline.IconSize - 18))
                            .allowsHitTesting(false)
                            .foregroundColor(.white)
                         */
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
    
        .onReceive(model.deselectSideViewIcon) { _ in
            selected = nil
        }
        
        .onAppear {
            selected = model.selectedDBMaterial
            if selected == nil {
                let request = MaterialEntity.fetchRequest()
                
                let managedMaterialContext = PersistenceController.shared.container.viewContext
                let materials = try! managedMaterialContext.fetch(request)
                
                if materials.count > 0 {
                    selected = materials.first
                }
            }
            
            model.selectedDBMaterial = selected
            
            if selected != nil {
                model.dbMaterialSelected.send(selected!)
            }
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
