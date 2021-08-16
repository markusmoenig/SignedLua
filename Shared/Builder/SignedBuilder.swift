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
    var context                 : SignedContext!
    
    init(_ model: Model) {
        self.model = model
    }
    
    /// Get a named Float in the given data groups
    func getFloat(name: String, groups: [SignedData]) -> Float? {
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float {
                    return entity.value.x
                }
            }
        }
        return nil
    }
    
    /// Get a named Float in the given data groups
    func getFloat3(name: String, groups: [SignedData]) -> float3? {
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float3 {
                    return float3(entity.value.x, entity.value.y, entity.value.z)
                }
            }
        }
        return nil
    }
    
    /// Sets a named Float in the given data groups
    func setFloat(name: String, value: Number, groups: [SignedData]) {
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float {
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
    func setupLuaCommand() {
            
        class LuaCommand : CustomTypeInstance {
            
            var name        = ""
            var cmd         : SignedCommand? = nil
            
            static func luaTypeName() -> String {
                return "Command"
            }
        }
        
        let commandLib:CustomType<LuaCommand> = vm.createCustomType { type in
            
            // Get named float for the cmd
            type["getNumber"] = type.createMethod([]) { cmd, args in
                if args.values.count == 2 {
                    let (paramName) = (args.string)
                    if let cmd = cmd.cmd {
                        if let v = self.getFloat(name: paramName, groups: cmd.allDataGroups()) {
                            return .value(Double(v))
                        }
                    }
                }
                return .nothing
            }
            
            // Get named float3 for the cmd
            type["getVec3"] = type.createMethod([]) { cmd, args in
                if args.values.count == 2 {
                    let (paramName) = (args.string)
                    if let cmd = cmd.cmd {
                        if let v = self.getFloat3(name: paramName, groups: cmd.allDataGroups()) {
                            switch self.vm.eval("return vec3(\(v.x), \(v.y), \(v.z))") {
                            case let .values(values):
                                if values.isEmpty == false {
                                    return .value(values.first)
                                }
                            case let .error(e):
                                print(e)
                            }
                        }
                    }
                }
                return .nothing
            }
            
            // Set named number data
            type["setNumber"] = type.createMethod([String.arg, Number.arg]) { cmd, args in
                if args.values.count == 2 {
                    let (paramName, value) = (args.string, args.number)
                    if let cmd = cmd.cmd {
                        self.setFloat(name: paramName, value: value, groups: cmd.allDataGroups())
                    }
                }
                return .nothing
            }
            
            // Set named vec3 data
            type["setVec3"] = type.createMethod([String.arg, Table.arg]) { cmd, args in
                if args.values.count == 2 {
                    let (paramName, table) = (args.string, args.table)
                    if let cmd = cmd.cmd {
                        self.setVec3(name: paramName, value: table, groups: cmd.allDataGroups())
                    }
                }
                return .nothing
            }
            
            // Get name of cmd
            type["getName"] = type.createMethod([]) { cmd, args in
                return .value(cmd.name)
            }
            
            // Create shape
            type["execute"] = type.createMethod([]) { cmd, args in
                if let cmd = cmd.cmd {
                    self.context.addToPipeline(cmd: cmd)
                }
                return .nothing
            }
        }
        
        commandLib["newFromShape"] = vm.createFunction([String.arg]) { args in
            if args.values.isEmpty == false {
                let shape = LuaCommand()
                shape.name = args.string
                
                // Get the shape and copy it
                if let cmd = self.model.getShape(shape.name) {
                    shape.cmd = cmd.copy()
                }
                
                let data = self.vm.createUserdata(shape)
                return .value(data)
            } else {
                return .nothing
            }
        }
        
        vm.globals["Command"] = commandLib
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
        context = SignedContext(model: model)

        // print
        vm.globals["print"] = vm.createFunction([String.arg]) { args in
            if args.values.isEmpty == false {
                print(args.string)
            }
            return .nothing
        }
        
        /*
        // Creates a shape
        vm.globals["create"] = vm.createFunction([]) { args in
            
            print(args.values[0])
            if let userData = args.values[0].customType {
                print(userData.custom)
            }

            //print(shape.values[0])
            //print(shape.toCustomType())// as? LuaShape)
            //print(shape.cmd)
            //let userData = shape.values[0] as! CustomType<LuaShape>
            //print(shape.customType())
            //print(userData.userdataPointer())//.toCustomType())
            //}
            return .nothing
        }*/
        
        require("vec3")
        setupLuaCommand()

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

