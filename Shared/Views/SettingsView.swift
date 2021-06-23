//
//  SettingsView.swift
//  Signed
//
//  Created by Markus Moenig on 20/6/2564 BE.
//

import SwiftUI

struct SettingsView: View {
    
    enum Status {
        case ParameterList, Renderer, Library
    }
    
    let core                                : Core
    
    @State var status                       : Status = .ParameterList
    
    @State var updateView                   : Bool = false
    
    @State var rendererMaxReflections       = String(4)
    @State var rendererMaxSamples           = String(10000)

    @State var currentSamples               = String("Samples: 0")
    @State var currentTimePerSample         = String("Time per Sample: 0")

    #if os(macOS)
    let toolBarIconSize                     : CGFloat = 13
    let toolBarTopPadding                   : CGFloat = 4
    let toolBarSpacing                      : CGFloat = 4
    #else
    let toolBarIconSize                     : CGFloat = 16
    let toolBarTopPadding                   : CGFloat = 8
    let toolBarSpacing                      : CGFloat = 6
    #endif
    
    init(_ core: Core)
    {
        self.core = core
    }
    
    var body: some View {
        
        VStack {
            HStack(spacing: toolBarSpacing) {
                Button(action: {
                    status = .ParameterList
                    updateView.toggle()
                })
                {
                    Label("", systemImage: "list.bullet")
                        .font(.system(size: toolBarIconSize + 4))
                        .foregroundColor(status == .ParameterList ? Color.accentColor : Color.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    status = .Renderer
                    updateView.toggle()
                })
                {
                    Label("", systemImage: "atom")
                        .font(.system(size: toolBarIconSize))
                        .foregroundColor(status == .Renderer ? Color.accentColor : Color.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    status = .Library
                    updateView.toggle()
                })
                {
                    Label("", systemImage: "building.columns")
                        .font(.system(size: toolBarIconSize))
                        .foregroundColor(status == .Library ? Color.accentColor : Color.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.top, toolBarTopPadding)
            .padding(.bottom, 2)
            Divider()
        
            if status == .ParameterList {
                ParameterView(core)
            } else
            if status == .Renderer {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("Maximum Reflections")
                        TextField("Max Reflection Depth", text: $rendererMaxReflections, onEditingChanged: { (changed) in
                        },
                        onCommit: {
                            if let intValue = Int(rendererMaxReflections) {
                                if core.renderPipeline.maxDepth != intValue {
                                    core.renderPipeline.maxDepth = intValue
                                    core.renderPipeline.restart()
                                }
                            }
                        } )
                            .padding(4)
                        Text("Maximum Samples")
                        TextField("Maximum Samples", text: $rendererMaxSamples, onEditingChanged: { (changed) in
                        },
                        onCommit: {
                            if let intValue = Int(rendererMaxSamples) {
                                if core.renderPipeline.maxSamples != intValue {
                                    core.renderPipeline.maxSamples = intValue
                                    core.renderPipeline.restart()
                                }
                            }
                        } )
                            .padding(4)
                        Divider()
                        Text(currentSamples)
                            .onReceive(self.core.samplesChanged) { samples in
                                currentSamples = String("Samples: \(Int(samples.x))")
                                currentTimePerSample = String("Time per Sample: \(Int(samples.y + 0.5))ms")
                            }
                        Text(currentTimePerSample)
                        Spacer()
                    }
                }
            }
            else
            if status == .Library {
                LibraryView()
                Spacer()
            }
        }
    }
}


