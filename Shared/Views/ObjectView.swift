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
    
    init(model: Model) {
        self.model = model
        //_selected = State(initialValue: model.selectedMaterial)
    }

    var body: some View {
    
        let rows: [GridItem] = Array(repeating: .init(.fixed(70)), count: 1)
            
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows, alignment: .center) {
                ForEach(objects, id: \.self) { object in

                    ZStack(alignment: .center) {
                                                    
                        if let image = getObjectIcon(object: object) {
                            Image(image, scale: 1.0, label: Text(object.name!))
                                .onTapGesture(perform: {
                                    
                                    selected = object.id
                                    
                                    if let data = object.code {
                                        if let value = String(data: data, encoding: .utf8) {
                                            model.codeEditor?.setSession(value: value, session: "__object_" + object.name!)
                                            
                                            model.codeEditorMode = .object
                                            model.codeEditorObjectEntity = object
                                            model.selectionChanged.send()
                                        }
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
                        } else {
                            Rectangle()
                                .fill(Color.secondary)
                                .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                .onTapGesture(perform: {
                                    
                                    selected = object.id
                                    
                                    if let data = object.code {
                                        if let value = String(data: data, encoding: .utf8) {
                                            model.codeEditor?.setSession(value: value, session: "__object_" + object.name!)
                                            
                                            model.codeEditorMode = .object
                                            model.codeEditorObjectEntity = object
                                            model.selectionChanged.send()
                                        }
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
                        
                        if object.id == selected {
                            Rectangle()
                                .stroke(Color.accentColor, lineWidth: 2)
                                .frame(width: CGFloat(ModelerPipeline.IconSize), height: CGFloat(ModelerPipeline.IconSize))
                                .allowsHitTesting(false)
                        }
                        
                        Rectangle()
                            .fill(.black)
                            .opacity(0.2)
                            .frame(width: CGFloat(ModelerPipeline.IconSize - (object.id == selected ? 2 : 0)), height: CGFloat(18 - (object.id == selected ? 1 : 0)))
                            .padding(.top, CGFloat(ModelerPipeline.IconSize - (18 + (object.id == selected ? 1 : 0))))
                        
                        Text(object.name!)
                            .padding(.top, CGFloat(ModelerPipeline.IconSize - 18))
                            .allowsHitTesting(false)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        
        .onReceive(model.selectionChanged) { _ in
            if model.codeEditorMode != .object {
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
    
    func getObjectIcon(object: ObjectEntity) -> CGImage? {
        if let data = object.icon {
            if let image = NSImage(data: data) {
                return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
        }
        return nil
    }
}
