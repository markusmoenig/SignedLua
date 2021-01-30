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

struct IntView: View {
    
    let core                                : Core
    let option                              : GraphOption
    
    @State var valueText                    : String = ""

    init(_ core: Core, _ option: GraphOption)
    {
        self.core = core
        self.option = option
        
        if let i1 = option.variable as? Int1 {
            _valueText = State(initialValue: String(i1.x))
        }
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            TextField(option.name, text: $valueText, onEditingChanged: { (changed) in
                if let intValue = Int(valueText) {
                    option.variable = Int1(intValue)
                }
            },
            onCommit: {
                core.scriptProcessor.replaceOptionInLine(option)
            } )
        }
    }
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
            _valueText = State(initialValue: String(format: "%.03g", f1.x))
        }
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            TextField(option.name, text: $valueText, onEditingChanged: { (changed) in
                if let floatValue = Float(valueText) {
                    option.variable = Float1(floatValue)
                }
            },
            onCommit: {
                core.scriptProcessor.replaceOptionInLine(option)
            } )
        }
    }
}

struct Float2View: View {
    
    let core                                : Core
    let option                              : GraphOption
    
    @State var valueText1                   : String = ""
    @State var valueText2                   : String = ""

    init(_ core: Core, _ option: GraphOption)
    {
        self.core = core
        self.option = option
        
        if let f2 = option.variable as? Float2 {
            let simd = f2.toSIMD()
            _valueText1 = State(initialValue: String(format: "%.03g", simd.x))
            _valueText2 = State(initialValue: String(format: "%.03g", simd.y))
        }
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            TextField(option.name, text: $valueText1, onEditingChanged: { (changed) in
                if Float(valueText1) != nil {
                    option.variable = Float3(Float(valueText1)!, Float(valueText2)!)
                }
            },
            onCommit: {
                core.scriptProcessor.replaceOptionInLine(option)
            } )
            TextField(option.name, text: $valueText2, onEditingChanged: { (changed) in
                if Float(valueText2) != nil {
                    option.variable = Float3(Float(valueText1)!, Float(valueText2)!)
                }
            },
            onCommit: {
                core.scriptProcessor.replaceOptionInLine(option)
            } )
        }
    }
}

struct Float3View: View {
    
    let core                                : Core
    let option                              : GraphOption
    
    @State var valueText1                   : String = ""
    @State var valueText2                   : String = ""
    @State var valueText3                   : String = ""
    
    @State private var selectedColor        = Color.white
    var isColor                             = false

    init(_ core: Core, _ option: GraphOption)
    {
        self.core = core
        self.option = option
        
        if let f3 = option.variable as? Float3 {
            let simd = f3.toSIMD()
            _valueText1 = State(initialValue: String(format: "%.03g", simd.x))
            _valueText2 = State(initialValue: String(format: "%.03g", simd.y))
            _valueText3 = State(initialValue: String(format: "%.03g", simd.z))
            isColor = f3.isColor
        }
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            if isColor == false {
                TextField(option.name, text: $valueText1, onEditingChanged: { (changed) in
                    if Float(valueText1) != nil {
                        option.variable = Float3(Float(valueText1)!, Float(valueText2)!, Float(valueText3)!)
                    }
                },
                onCommit: {
                    core.scriptProcessor.replaceOptionInLine(option)
                } )
                TextField(option.name, text: $valueText2, onEditingChanged: { (changed) in
                    if Float(valueText2) != nil {
                        option.variable = Float3(Float(valueText1)!, Float(valueText2)!, Float(valueText3)!)
                    }
                },
                onCommit: {
                    core.scriptProcessor.replaceOptionInLine(option)
                } )
                TextField(option.name, text: $valueText3, onEditingChanged: { (changed) in
                    if Float(valueText3) != nil {
                        option.variable = Float3(Float(valueText1)!, Float(valueText2)!, Float(valueText3)!)
                    }
                },
                onCommit: {
                    core.scriptProcessor.replaceOptionInLine(option)
                } )
            } else {
                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                    .onChange(of: selectedColor) { color in
                        print(color)
                        let f3 = Float3()
                        f3.x = Float(color.cgColor!.components![0])
                        f3.y = Float(color.cgColor!.components![1])
                        f3.z = Float(color.cgColor!.components![2])
                        
                        print(f3.toHexString())
                    }
            }
        }
    }
}

struct Float4View: View {
    
    let core                                : Core
    let option                              : GraphOption
    
    @State var valueText1                   : String = ""
    @State var valueText2                   : String = ""
    @State var valueText3                   : String = ""
    @State var valueText4                   : String = ""

    init(_ core: Core, _ option: GraphOption)
    {
        self.core = core
        self.option = option
        
        if let f4 = option.variable as? Float4 {
            let simd = f4.toSIMD()
            _valueText1 = State(initialValue: String(format: "%.03f", simd.x))
            _valueText2 = State(initialValue: String(format: "%.03f", simd.y))
            _valueText3 = State(initialValue: String(format: "%.03f", simd.z))
            _valueText4 = State(initialValue: String(format: "%.03f", simd.w))
        }
    }
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(option.name)
            TextField(option.name, text: $valueText1, onEditingChanged: { (changed) in
                if Float(valueText1) != nil {
                    option.variable = Float4(Float(valueText1)!, Float(valueText2)!, Float(valueText3)!, Float(valueText4)!)
                }
            },
            onCommit: {
                core.scriptProcessor.replaceOptionInLine(option)
            } )
            TextField(option.name, text: $valueText2, onEditingChanged: { (changed) in
                if Float(valueText2) != nil {
                    option.variable = Float4(Float(valueText1)!, Float(valueText2)!, Float(valueText3)!, Float(valueText4)!)
                }
            },
            onCommit: {
                core.scriptProcessor.replaceOptionInLine(option)
            } )
            TextField(option.name, text: $valueText3, onEditingChanged: { (changed) in
                if Float(valueText3) != nil {
                    option.variable = Float4(Float(valueText1)!, Float(valueText2)!, Float(valueText3)!, Float(valueText4)!)
                }
            },
            onCommit: {
                core.scriptProcessor.replaceOptionInLine(option)
            } )
            TextField(option.name, text: $valueText3, onEditingChanged: { (changed) in
                if Float(valueText4) != nil {
                    option.variable = Float4(Float(valueText1)!, Float(valueText2)!, Float(valueText3)!, Float(valueText4)!)
                }
            },
            onCommit: {
                core.scriptProcessor.replaceOptionInLine(option)
            } )
        }
    }
}

struct ParameterView: View {
    
    let core                                : Core
    
    @State var radius                       : String = "1"
    
    @State var updateView                   : Bool = false
    
    @State var options                      : [GraphOption] = []

    init(_ core: Core)
    {
        self.core = core
    }
    
    var body: some View {
        
        ScrollView {
            VStack(alignment: .leading) {
                
                ForEach(options, id: \.id) { option in
                    if option.variable.getType() == .Int {
                        IntView(core, option)
                            .padding(4)
                    } else
                    if option.variable.getType() == .Float {
                        FloatView(core, option)
                            .padding(4)
                    } else
                    if option.variable.getType() == .Float2 {
                        Float2View(core, option)
                            .padding(4)
                    } else
                    if option.variable.getType() == .Float3 {
                        Float3View(core, option)
                            .padding(4)
                    } else
                    if option.variable.getType() == .Float4 {
                        Float4View(core, option)
                            .padding(4)
                    }
                }
                
                Spacer()
            }
            
            .onReceive(self.core.modelChanged) { void in
                options = core.scriptProcessor.getOptions()
                updateView.toggle()
            }
            .onReceive(self.core.graphBuilder.selectionChanged) { id in
                options = core.scriptProcessor.getOptions()
                updateView.toggle()
            }
            .onReceive(self.core.graphBuilder.contextColorChanged) { colorText in
                let v = Float3(0,0,0)
                v.isColor = true
                options = [GraphOption(v,"Color","")]
                updateView.toggle()
            }
            .onAppear(perform: {
                options = core.scriptProcessor.getOptions()
            })
        }
    }
}

struct RightPanelView: View {
    
    enum Status {
        case ParameterList, Renderer
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
                                core.renderPipeline.maxDepth = intValue
                                core.renderPipeline.restart()
                            }
                        } )
                            .padding(4)
                        Text("Maximum Samples")
                        TextField("Maximum Samples", text: $rendererMaxSamples, onEditingChanged: { (changed) in
                        },
                        onCommit: {
                            if let intValue = Int(rendererMaxSamples) {
                                core.renderPipeline.maxSamples = intValue
                                core.renderPipeline.restart()
                            }
                        } )
                            .padding(4)
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
        }
    }
}

struct LeftPanelView: View {
    
    let core                                : Core
    var libraryItems                        : [LibraryItem] = []
    
    @State var asset                        : Asset? = nil

    //@State var current                      : LibraryItem? = nil
    
    @State var updateView                   : Bool = false
    //@State var expanded                     : Bool = false
    
    @State private var selection            : UUID? = nil
    //@State private var librarySelection     : UUID? = nil

    //@State private var tabIndex             : Int = 0
        
    @State private var showMaterials        : Bool = false
    @State private var showObjects          : Bool = false

    #if os(macOS)
    let TopRowPadding                       : CGFloat = 2
    #else
    let TopRowPadding                       : CGFloat = 5
    #endif

    init(_ core: Core)
    {
        self.core = core
        
        /*
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
        */
    }
    
    var body: some View {
        
        //TabView/*(selection: $tabIndex)*/ {

            VStack {
                if let context = asset?.graph {
                    
                    List() {
                        if let cameraNode = context.cameraNode {
                            Button(action: {
                                core.graphBuilder.gotoNode(cameraNode)
                            })
                            {
                                Label(cameraNode.givenName, systemImage: "camera")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                if selection == cameraNode.id {
                                    Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                } else { Color.clear }
                            })
                        }
                        if let sunNode = context.sunNode {
                            Button(action: {
                                core.graphBuilder.gotoNode(sunNode)
                            })
                            {
                                Label(sunNode.name, systemImage: "sun.max")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                if selection == sunNode.id {
                                    Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                } else { Color.clear }
                            })
                        }
                        if let skyNode = context.skyNode {
                            Button(action: {
                                core.graphBuilder.gotoNode(skyNode)
                            })
                            {
                                Label(skyNode.givenName, systemImage: "sun.haze")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                if selection == skyNode.id {
                                    Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                } else { Color.clear }
                            })
                        }
                        if let renderNode = context.renderNode {
                            Button(action: {
                                core.graphBuilder.gotoNode(renderNode)
                            })
                            {
                                Label(renderNode.givenName, systemImage: "atom")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Group {
                                if selection == renderNode.id {
                                    Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                } else { Color.clear }
                            })
                        }
                        DisclosureGroup("Materials", isExpanded: $showMaterials) {
                            ForEach(context.materialNodes, id: \.id) { node in
                                Button(action: {
                                    core.graphBuilder.gotoNode(node)
                                })
                                {
                                    Label(node.givenName, systemImage: "light.max")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowBackground(Group {
                                    if selection == node.id {
                                        Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                    } else { Color.clear }
                                })
                            }
                        }
                        DisclosureGroup("Objects", isExpanded: $showObjects) {
                            ForEach(context.objectNodes, id: \.id) { node in
                                Button(action: {
                                    core.graphBuilder.gotoNode(node)
                                })
                                {
                                    Label(node.givenName, systemImage: "cube")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowBackground(Group {
                                    if selection == node.id {
                                        Color.gray.mask(RoundedRectangle(cornerRadius: 4))
                                    } else { Color.clear }
                                })
                            }
                        }
                    }
                    
                    /*
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
                    */
                }
            }
            .tabItem {
                Image(systemName: "list.dash")
                Text("Project")
            }
            
            /*
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
            }*/
        
        //}
        
        .onReceive(self.core.modelChanged) { core in
            asset = self.core.assetFolder.getAsset("main", .Source)
            updateView.toggle()
        }
        .onReceive(self.core.graphBuilder.selectionChanged) { id in
            selection = id
            //DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            //    selection = id
            //}
        }
    }
}

struct ParmaView: View {
    @Binding var text: String
    var body: some View {
        Parma(text)
    }
}
