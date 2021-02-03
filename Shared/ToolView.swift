//
//  ToolView.swift
//  Signed
//
//  Created by Markus Moenig on 1/2/21.
//

import SwiftUI

struct ToolsView: View {
    
    let core                                : Core
    
    @State var currentNode                  : GraphNode? = nil
    @State var arrayOfButtons               : [ToolViewButton] = []
    
    @State var currentButton                : ToolViewButton? = nil

    init(_ core: Core)
    {
        self.core = core
    }
    
    var body: some View {
        HStack()
        {
            Spacer()
            ForEach(arrayOfButtons, id: \.id) { result in
                Button(action: {
                })
                {
                    Text(result.name)
                }
                .frame(minWidth: 0, maxWidth: 70, maxHeight: 20)
                .font(.system(size: 16))
                .background(currentButton != nil && currentButton!.id == result.id ? Color.accentColor.opacity(1) : Color.accentColor.opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .padding(.leading, 10)
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged({ info in
                            currentButton = result
                            if let node = currentNode {
                                let delta = float2(Float(info.location.x) - core.toolContext.lastLocation.x, Float(info.location.y) - core.toolContext.lastLocation.y)
                                node.toolViewButtonAction(result, state: core.toolContext.lastLocation == float2(0,0) ? .Down : .Move, delta: delta, toolContext: core.toolContext)
                                core.toolContext.lastLocation = float2(Float(info.location.x), Float(info.location.y))
                            }
                        })
                        .onEnded({ info in
                            if let node = currentNode {
                                let delta = float2(Float(info.location.x - info.startLocation.x), Float(info.location.y - info.startLocation.y))
                                node.toolViewButtonAction(result, state: .Up, delta: delta, toolContext: core.toolContext)
                                core.toolContext.lastLocation = float2(0,0)
                            }
                            currentButton = nil
                        })
                )
                .padding()
            }
            Spacer()
        }
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            arrayOfButtons = []
            currentNode = nil
            if let node = core.graphBuilder.currentNode {
                currentNode = node
                arrayOfButtons = node.getToolViewButtons()
            }
        }
    }
}
