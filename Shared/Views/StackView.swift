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
        
        ScrollView(.vertical) {
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
            }
        }
        
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
