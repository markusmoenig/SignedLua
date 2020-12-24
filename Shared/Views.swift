//
//  Parma.swift
//  Denrim
//
//  Created by Markus Moenig on 29/10/20.
//

import SwiftUI
import Parma

// https://stackoverflow.com/questions/61386877/in-swiftui-is-it-possible-to-use-a-modifier-only-for-a-certain-os-target
enum OperatingSystem {
    case macOS
    case iOS
    case tvOS
    case watchOS

    #if os(macOS)
    static let current = macOS
    #elseif os(iOS)
    static let current = iOS
    #elseif os(tvOS)
    static let current = tvOS
    #elseif os(watchOS)
    static let current = watchOS
    #else
    #error("Unsupported platform")
    #endif
}

extension View {
    @ViewBuilder
    func ifOS<Content: View>(
        _ operatingSystems: OperatingSystem...,
        modifier: @escaping (Self) -> Content
    ) -> some View {
        if operatingSystems.contains(OperatingSystem.current) {
            modifier(self)
        } else {
            self
        }
    }
}

struct LibraryItem: Identifiable {
    var id          = UUID()

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
            TextField(option.name, text: $valueText, onEditingChanged: { (changed) in
                if let floatValue = Float(valueText) {
                    print(floatValue)
                }
            })
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
        
        
        .onReceive(self.core.modelChanged) { void in
            options = core.graphBuilder.getOptions()
            updateView.toggle()
        }
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            options = core.graphBuilder.getOptions()
            updateView.toggle()
        }
    }
}

struct LeftPanelView: View {
    
    let core                                : Core
    var libraryItems                        : [LibraryItem] = []
    
    @State var asset                        : Asset? = nil

    @State var current                      : LibraryItem? = nil
    
    @State var updateView                   : Bool = false
    @State var expanded                     : Bool = false
    
    @State private var selection            : UUID? = nil
    @State private var librarySelection     : UUID? = nil

    @State private var tabIndex             : Int = 0
    
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
        
        TabView/*(selection: $tabIndex)*/ {

            VStack {
                if let context = asset?.graph {
                    List(context.hierarchicalNodes, id: \.id, children: \.leaves, selection: $selection) { item in
                        Text(item.name)
                            .ifOS(.iOS) {
                                $0.foregroundColor(item === core.graphBuilder.currentNode ? Color.accentColor : Color.white)
                            }
                    }
                    // Selection handling
                    .onChange(of: selection) { newState in
                        if let id = newState {
                            if let node = context.getNode(id) {
                                core.graphBuilder.gotoNode(node)
                            }
                        }
                    }
                    .onTapGesture {
                        //if let node = context.getNode(id) {
                        //    core.graphBuilder.gotoNode(node)
                        //}
                    }
                }
            }
            .tabItem {
                Image(systemName: "list.dash")
                Text("Project")
            }
            
            VStack {
            
                List(libraryItems, children: \.children, selection: $librarySelection) { item in
                    Text(item.name)

                    /*
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
                    }
                    .buttonStyle(PlainButtonStyle())
                    */
                }
                
                if let current = current {
                    Divider()
                    Parma(current.md)
                        .font(.system(size: 11))
                }
            }
            .tabItem {
                Image(systemName: "building.columns.fill")
                Text("Library")
            }
            // Selection handling
            .onChange(of: librarySelection) { newState in
                if let id = newState {
                    for item in libraryItems {
                        if item.id == id {
                            current = item
                            break
                        }
                        if let childs = item.children {
                            for c in childs {
                                if c.id == id {
                                    current = c
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        
        /*
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
        }*/
        .onReceive(self.core.modelChanged) { core in
            asset = self.core.assetFolder.getAsset("main", .Source)
            updateView.toggle()
        }
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            selection = id
            updateView.toggle()
        }
    }
}

struct ParmaView: View {
    @Binding var text: String
    var body: some View {
        Parma(text)
    }
}
