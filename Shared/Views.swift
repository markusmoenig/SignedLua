//
//  Parma.swift
//  Denrim
//
//  Created by Markus Moenig on 29/10/20.
//

import SwiftUI
import Parma

struct LibraryItem: Identifiable {
    var id          : String { name }

    let name        : String
    var children    : [LibraryItem]?
    var image       : String? = nil
    var md          : String = ""
}

struct FloatView: View {
    
    let core                                : Core
    let option                              : GraphOption
    
    @State var valueText                    : String = ""

    init(_ core: Core, _ option: GraphOption)
    {
        self.core = core
        self.option = option
        
        if let f1 = option.variable as? Float1 {
            _valueText = State(initialValue: String(format: "%.03f", f1.x))
        }
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            TextField(option.name, text: $valueText)
                //.keyboardType(.numberPad)
        }
        
        /*
        .onReceive(self.core.modelChanged) { core in
            mode = .Project
            updateView.toggle()
        }*/
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            //options = core.graphBuilder.getOptions()
            //updateView.toggle()
        }
    }
}

struct RightPanelView: View {
    
    let core                                : Core
    
    @State var radius                       : String = "1"
    
    @State var updateView                   : Bool = false
    
    @State var options                      : [GraphOption] = []

    init(_ core: Core)
    {
        self.core = core
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            ForEach(options, id: \.id) { option in
                if option.variable.getType() == .Float {
                    FloatView(core, option)
                }
            }
        
            
            Spacer()
        }
        
        /*
        .onReceive(self.core.modelChanged) { core in
            mode = .Project
            updateView.toggle()
        }*/
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            options = core.graphBuilder.getOptions()
            updateView.toggle()
        }
    }
}

struct LeftPanelView: View {
    
    enum Mode {
        case Project, Library
    }
    
    let core                                : Core
    var libraryItems                        : [LibraryItem] = []
    
    @State var mode                         : Mode = .Library
    @State var current                      : LibraryItem? = nil
    
    @State var updateView                   : Bool = false
    @State var expanded                     : Bool = false
    
    @State private var selection            : UUID? = nil
    
    #if os(macOS)
    let TopRowPadding                       : CGFloat = 2
    #else
    let TopRowPadding                       : CGFloat = 5
    #endif

    init(_ core: Core)
    {
        self.core = core

        var cameraItem = LibraryItem(name: "Cameras")
        cameraItem.children = []
        
        for b in core.graphBuilder.branches {
            let node = b.createNode([:])
            if node.role == .Camera {
                var item = LibraryItem(name: b.name)
                item.md = node.getHelp()
                cameraItem.children!.append(item)
                current = item
            }
        }
        
        libraryItems.append(cameraItem)
    }
    
    var body: some View {
        
        VStack(spacing: 2) {
            
            HStack(spacing: 3) {
                Button(action: {
                    mode = .Project
                })
                {
                    Label("", systemImage: "list.bullet.below.rectangle")
                        .font(.system(size: 16))
                        .foregroundColor(mode == .Project ? Color.accentColor : Color.white)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 10)
                
                Button(action: {
                    mode = .Library
                })
                {
                    Label("", systemImage: "building.columns.fill")
                        .font(.system(size: 16))
                        .foregroundColor(mode == .Library ? Color.accentColor : Color.white)
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
            }
            .padding(.top, TopRowPadding)
            .padding(.bottom, 2)
            .frame(alignment: .topLeading)

            Divider()
            
            if mode == .Project {

                if let asset = core.assetFolder.getAsset("main", .Source) {
                    if let context = asset.graph {
                        List(context.nodes, id: \.id, children: \.leaves, selection: $selection) { item in
                            Button(action: {
                                core.graphBuilder.gotoNode(item)
                            })
                            {                         
                                Text(item.name)
                                    //.font(.system(.title3, design: .rounded))
                                    //.bold()
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            } else
            if mode == .Library {
                
                List(libraryItems, children: \.children) { item in                    
                    Button(action: {
                        current = item
                    })
                    {
                        if let image = item.image {
                            Image(image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                        }
                 
                        Text(item.name)
                            //.font(.system(.title3, design: .rounded))
                            //.bold()
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if let current = current {
                    Divider()
                    Parma(current.md)
                        .font(.system(size: 11))
                }
            }
        }
        .onReceive(self.core.modelChanged) { core in
            mode = .Project
            updateView.toggle()
        }
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            selection = id
        }
    }
}

struct ParmaView: View {
    @Binding var text: String
    var body: some View {
        Parma(text)
    }
}
