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
    var alreadyRequired         : [String] = []
    
    var inProgress              : Bool = false
    
    var workItem                : DispatchWorkItem? = nil
    
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
                }
            }
        }
    }
    
    /*
    /// extract variables from VM
    func extractVariables(variables: String)
    {
        if let vm = vm {
            if let v = vm.globals[variables] as? Table {
                //print("test", v["id"])
            }
        }
    }*/
    
    /// Sets up the LuaShape ecosystem
    func setupLuaCommand() {
            
        class LuaCommand : CustomTypeInstance {
            
            var name        = ""
            var cmd         : SignedCommand? = nil
            
            static func luaTypeName() -> String {
                return "__command"
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
                
                shape.cmd?.role = .GeometryAndMaterial
                shape.cmd?.action = .Add
                
                let data = self.vm.createUserdata(shape)
                return .value(data)
            } else {
                return .nothing
            }
        }
        
        vm.globals["__command"] = commandLib
    }
    
    /// Load and execute the givenessential  modules
    func requireModules(_ inputs: [String]) {
        
        let request = ModuleEntity.fetchRequest()

        let managedObjectContext = PersistenceController.shared.container.viewContext
        let modules = try! managedObjectContext.fetch(request)

        modules.forEach { module in
            
            if let name = module.name {
                if inputs.contains(name) {
                    if alreadyRequired.contains(name) == false {
                        if let data = module.code {
                            if let code = String(data: data, encoding: .utf8) {
                                switch vm.eval(code, args: []) {
                                case let .values(values):
                                    if values.isEmpty == false {
                                        vm.globals[name] = values[0]
                                    }
                                case let .error(e):
                                    print("error in module \(name)", e)
                                }
                            }
                        }
                        alreadyRequired.append(name)
                    }
                }
            }
        }
    }
    
    /// build 3D texture
    func build() {
        
        guard let modeler = model.modeler else {
            return
        }
        
        inProgress = true
        
        workItem = DispatchWorkItem {
            
            let model = self.model
            
            modeler.clear()
            model.renderer?.restart()
            model.infoText = ""
            DispatchQueue.main.async {
                model.infoChanged.send()
            }
            
            model.infoProgressProcessedCmds = 0
            model.infoProgressTotalCmds = 0
                    
            self.vm = VirtualMachine()
            self.context = SignedContext(model: model)
            
            // print
            self.vm.globals["_print"] = self.vm.createFunction([String.arg]) { args in
                if args.values.isEmpty == false {
                    self.model.infoText += args.string + "\n"
                    DispatchQueue.main.async {
                        self.model.infoChanged.send()
                    }
                }
                return .nothing
            }
            
            _ = self.vm.eval("""
            
            print = function(...)
                local args = {...}
                local printResult = ""
                for i,v in ipairs(args) do
                    if i > 1 then
                        printResult = printResult .. ", "
                    end
                    printResult = printResult .. tostring(v)
                end
                _print(printResult)
            end
            
            """, args: [])
            // require
            self.vm.globals["require"] = self.vm.createFunction([String.arg]) { args in
                if args.values.isEmpty == false {
                    let string = args.string
                    self.requireModules([string])
                }
                return .nothing
            }
            
            // Auto require the basic modules
            self.alreadyRequired = []
            self.requireModules(["vec3", "vec2", "command"])
            
            self.setupLuaCommand()

            switch self.vm.eval(model.getObjectCode(), args: []) {
            case let .values(values):
                if values.isEmpty == false {
                    print(values.first!)
                }
            case let .error(e):
                self.model.infoText += e + "\n"
                DispatchQueue.main.async {
                    self.model.infoChanged.send()
                }
            }

            /*
            let cmd = SignedCommand("Ground", role: .GeometryAndMaterial, action: .Add, primitive: .Box,
                                           data: ["Transform" : SignedData([SignedDataEntity("Position", float3(0,-0.9,0)) ]),
                                                  "Geometry": SignedData([SignedDataEntity("Size", float3(0.6,0.4,0.6) * Float(Modeler_Global_Scale))])
                                                 ], material: SignedMaterial(albedo: float3(0.5,0.5,0.5), metallic: 1, roughness: 0.3))
            
            context.addToPipeline(cmd: cmd)
             */
            
            /*
            let context = SignedContext(model: model)
            
            for node in topLevelNodes {
                node.execute(context: context)
            }*/
        }
        
        if let workItem = workItem {
            DispatchQueue.global().async(execute: workItem)
        }
    }
    
    func exitLua() {
        //if let vm = vm {
            //_ = vm.eval("yield()", args: [])
        //}
    }
}

