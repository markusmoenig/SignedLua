//
//  SignedParser.swift
//  SignedParser
//
//  Created by Markus Moenig on 12/8/21.
//

import Foundation

struct CodeError
{
    var line            : Int32 = 0
    var column          : Int32 = 0
    var error           : String? = nil
    var type            : String = "error"
}

class SignedBuilder {
    
    let model                   : Model
    
    var vm                      : VirtualMachine!
    
    init(_ model: Model) {
        self.model = model
    }
    
    /// Sets a named Float in the given data groups
    func setFloat(name: String, value: Number, groups: [SignedData]) {
        
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float3 {
                    entity.value.x = Float(value.toDouble())
                }
            }
        }
    }
    
    /// Sets a named Vec3 in the given data groups
    func setVec3(name: String, value: Table, groups: [SignedData]) {
        
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float3 {
                    if let x = value["x"] as? Number {
                        entity.value.x = Float(x.toDouble())
                    }
                    if let y = value["y"] as? Number {
                        entity.value.y = Float(y.toDouble())
                    }
                    if let z = value["z"] as? Number {
                        entity.value.z = Float(z.toDouble())
                    }
                    print(name, entity.value)
                }
            }
        }
    }
    
    /// Sets up the LuaShape ecosystem
    func setupLuaShape() {
        class LuaShape : CustomTypeInstance {
            
            var name        = ""
            var cmd         : SignedCommand? = nil
            
            static func luaTypeName() -> String {
                return "Shape"
            }
        }
            
        let shapeLib:CustomType<LuaShape> = vm.createCustomType { type in
            type["setFloat"] = type.createMethod([String.arg, Number.arg]) { shape, args in
                if args.values.count == 2 {
                    let (paramName, value) = (args.string, args.number)
                    if let cmd = shape.cmd {
                        self.setFloat(name: paramName, value: value, groups: cmd.dataGroups.flat())
                    }
                }
                return .nothing
            }
            type["setVec3"] = type.createMethod([String.arg, Table.arg]) { shape, args in
                if args.values.count == 2 {
                    let (paramName, table) = (args.string, args.table)
                    if let cmd = shape.cmd {
                        self.setVec3(name: paramName, value: table, groups: cmd.dataGroups.flat())
                    }
                }
                return .nothing
            }
            type["getName"] = type.createMethod([]) {
                note, args in
                return .value(note.name)
            }
        }
        
        shapeLib["new"] = vm.createFunction([String.arg]) { args in
            if args.values.isEmpty == false {
                let shape = LuaShape()
                shape.name = args.string
                shape.cmd = self.model.getShape(shape.name)
                
                let data = self.vm.createUserdata(shape)
                return .value(data)
            } else {
                return .nothing
            }
        }
        
        vm.globals["Shape"] = shapeLib
    }
    
    /// Load and execute the given module
    func require(_ input: String) {
        guard let path = Bundle.main.path(forResource: input, ofType: "lua", inDirectory: "Files/lua") else {
            return
        }
            
        if let value = try? String(contentsOfFile: path, encoding: String.Encoding.utf8) {
            switch vm.eval(value, args: []) {
            case let .values(values):
                //print(values, values.count)
                if values.isEmpty == false {
                    vm.globals[input] = values[0]
                }
            case let .error(e):
                print(e)
            }
        }
    }
    
    /// build 3D texture
    func build() {
        
        guard let modeler = model.modeler else {
            return
        }
        
        modeler.clear()
        model.renderer?.restart()
                
        vm = VirtualMachine()

        // print
        vm.globals["print"] = vm.createFunction([String.arg]) { args in
            if args.values.isEmpty == false {
                print(args.string)
            }
            return .nothing
        }
        
        require("vec3")
        setupLuaShape()

        switch vm.eval(model.project.code, args: []) {
        case let .values(values):
            if values.isEmpty == false {
                print(values.first!)
            }
        case let .error(e):
            print(e)
        }

        /*
        let cmd = SignedCommand("Ground", role: .GeometryAndMaterial, action: .Add, primitive: .Box,
                                       data: ["Transform" : SignedData([SignedDataEntity("Position", float3(0,-0.9,0)) ]),
                                              "Geometry": SignedData([SignedDataEntity("Size", float3(0.6,0.4,0.6) * Float(Modeler_Global_Scale))])
                                             ], material: SignedMaterial(albedo: float3(0.5,0.5,0.5), metallic: 1, roughness: 0.3))
        */
        
        /*
        let context = SignedContext(model: model)
        
        for node in topLevelNodes {
            node.execute(context: context)
        }*/
    }
}

