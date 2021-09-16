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
    
    var parentMaterial          : SignedCommand? = nil
    
    init(_ model: Model) {
        self.model = model
    }
    
    /// Converts the float3 to a vec3 string
    func float3ToVec3(_ value: float3) -> String {
        return "vec3(\(value.x), \(value.y), \(value.z))"
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
    
    /// Get a named float3 and convert it to a vec3 string
    func getFloat3AsVec3(name: String, groups: [SignedData]) -> String {
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float3 {
                    return "vec3(\(entity.value.x), \(entity.value.y), \(entity.value.z))"
                }
            }
        }
        return "vec3()"
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
    
    /// extracts a float3 from a table
    func extractFloat2(table: Table) -> float2 {
        var v = float2()
        if let x = table["x"] as? Number {
            v.x = x.toFloat()
        }
        if let y = table["y"] as? Number {
            v.y = y.toFloat()
        }
        return v
    }
    
    /// extracts a float3 from a table
    func extractFloat3(table: Table) -> float3 {
        var v = float3()
        if let x = table["x"] as? Number {
            v.x = x.toFloat()
        }
        if let y = table["y"] as? Number {
            v.y = y.toFloat()
        }
        if let z = table["z"] as? Number {
            v.z = z.toFloat()
        }
        return v
    }
    
    /// Sets a named Vec3 in the given data groups
    func setVec3(name: String, value: Table, groups: [SignedData]) {
        
        for data in groups {
            for entity in data.data {
                if entity.key == name && entity.type == .Float3 {
                    /*if name == "Color" {
                        if let x = value["x"] as? Number {
                            entity.value.x = pow(x.toFloat(), 2.2)
                        }
                        if let y = value["y"] as? Number {
                            entity.value.y = pow(y.toFloat(), 2.2)
                        }
                        if let z = value["z"] as? Number {
                            entity.value.z = pow(z.toFloat(), 2.2)
                        }
                    } else {*/
                        if let x = value["x"] as? Number {
                            entity.value.x = x.toFloat()
                        }
                        if let y = value["y"] as? Number {
                            entity.value.y = y.toFloat()
                        }
                        if let z = value["z"] as? Number {
                            entity.value.z = z.toFloat()
                        }
                    //}
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
    
    /// Sets up the config class
    func setupLuaConfig(_ kit: ModelerKit) {

        let table = vm.createTable()
        
        if let texture = kit.modelTexture {
            switch self.vm.eval("return vec3(\(texture.width), \(texture.height), \(texture.depth))") {
            case let .values(values):
                if values.isEmpty == false {
                    table["dimensions"] = values.first!
                }
            case let .error(e):
                print(e)
            }
        }
        
        table["pixelsPerMeter"] = model.project.pixelsPerMeter
                
        vm.globals["config"] = table
    }
    
    /// Sets up the command class
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
            
            // Set Mode
            type["setMode"] = type.createMethod([String.arg]) { cmd, args in
                if args.values.count == 1 {
                    let modeName = args.string.lowercased()
                    if let cmd = cmd.cmd {
                        if modeName == "add" {
                            cmd.action = .Add
                        } else
                        if modeName == "subtract" {
                            cmd.action = .Subtract
                        }
                    }
                }
                return .nothing
            }
            
            // Set Mode
            type["setBlendMode"] = type.createMethod([String.arg, Table.arg]) { cmd, args in
                if args.values.count == 2 {
                    if let cmd = cmd.cmd {
                        
                        let modeName = args.string.lowercased()
                        let table = args.table
                                         
                        if let value = table["depth"] as? Table {
                            if let modifierData = cmd.dataGroups.getGroup("Modifier") {
                                modifierData.set("depth", self.extractFloat2(table: value))
                            }
                        }
                        
                        if modeName == "valuenoise" {
                            cmd.blendMode = .ValueNoise
                            
                            if let offset = table["offset"] as? Table {
                                cmd.blendOptions.set("offset", self.extractFloat3(table: offset))
                            }
                            if let value = table["frequency"] as? Number {
                                cmd.blendOptions.set("frequency", value.toFloat())
                            }
                            if let value = table["smoothing"] as? Number {
                                cmd.blendOptions.set("smoothing", value.toFloat())
                            }                            
                        } else {
                            cmd.blendMode = .Linear
                            if let value = table["value"] as? Number {
                                cmd.blendOptions.set("value", value.toFloat())
                            }
                        }
                    }
                }
                return .nothing
            }
            
            // Get name of cmd
            type["getName"] = type.createMethod([]) { cmd, args in
                return .value(cmd.name)
            }
            
            // Execute the command
            type["execute"] = type.createMethod([Number.arg]) { cmd, args in
                
                var materialId : Int = 0
                if args.values.isEmpty == false {
                    let value = args.number
                    materialId = Int(value.toInteger())
                }
                                
                if let cmd = cmd.cmd {
                    cmd.materialId = materialId

                    if cmd.role == .GeometryAndMaterial {
                        // Geometry
                        if cmd.code.isEmpty == true {
                            self.context.addToPipeline(cmd: cmd)
                        } else {
                            _ = self.vm.eval(cmd.code)
                            let position = self.getFloat3(name: "position", groups: cmd.allDataGroups())!
                            let size = self.getFloat3(name: "size", groups: cmd.allDataGroups())!
                            let rotation = self.getFloat3(name: "rotation", groups: cmd.allDataGroups())!

                            let v1 = position - size / 2
                            let v2 = position + size / 2

                            let bboxString = "bbox:new( \(self.float3ToVec3(v1)), \(self.float3ToVec3(v2)), \(self.float3ToVec3(rotation)))"
                            let cmdString = "buildObject(\(materialId), \(bboxString), config.___opts)\n"
                            _ = self.vm.eval(cmdString)
                        }
                    } else
                    if cmd.role == .MaterialOnly {
                        // Material
                        if cmd.code.isEmpty == true {
                            // Merging the depth values of the calling material and the currently executing material
                            if let parentMaterial = self.parentMaterial {
                                if let modifierData = parentMaterial.dataGroups.getGroup("Modifier") {
                                    let depthValue = modifierData.getFloat2("depth", float2(-5,5))
                                    if let modifierData = cmd.dataGroups.getGroup("Modifier") {
                                        let depthValue1 = modifierData.getFloat2("depth", float2(-5,5))
                                        modifierData.set("depth", float2(max(depthValue.x, depthValue1.x), min(depthValue.y, depthValue1.y)))
                                    }
                                }
                            }
                            self.context.addToPipeline(cmd: cmd)
                        } else {
                            self.parentMaterial = cmd
                            _ = self.vm.eval(cmd.code)
                            _ = self.vm.eval("buildMaterial(\(materialId))\n")
                            self.parentMaterial = nil
                        }
                    }
                }
                return .nothing
            }
        }
        
        // Create a cmd from a shape
        commandLib["newShape"] = vm.createFunction([String.arg]) { args in
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
        
        // Create a cmd from an object, try project objects and then DB objects
        commandLib["newObject"] = vm.createFunction([String.arg]) { args in
            if args.values.isEmpty == false {
                let cmd = LuaCommand()
                cmd.name = args.string
                
                cmd.cmd = SignedCommand()

                if cmd.name.isEmpty == false {
                    
                    var found = false
                    /// First search the project materials
                    ///
                    for object in self.model.project.objects {
                        if object.name == cmd.name {
                            cmd.cmd?.code = object.getCode()
                            found = true
                        }
                    }
                    
                    /// Than search the object cloud database
                    if found == false {
                        if let entity = self.model.getObjectEntity(name: cmd.name) {
                            if let data = entity.code {
                                if let value = String(data: data, encoding: .utf8) {
                                    cmd.cmd?.code = value
                                }
                            }
                        }
                    }
                }
                
                if let cmd = cmd.cmd {
                    let geometryData = SignedData([SignedDataEntity("size", float3(0.3,0.3,0.3), float2(0,10), .Slider)])
                    
                    cmd.dataGroups.addGroup("Geometry", geometryData)
                    cmd.role = .GeometryAndMaterial
                    cmd.action = .None
                }
                
                let data = self.vm.createUserdata(cmd)
                return .value(data)
            } else {
                return .nothing
            }
        }
        
        // Create a cmd from a material, try project materials and then DB materials
        commandLib["newMaterial"] = vm.createFunction([String.arg]) { args in
            if args.values.isEmpty == false {
                let cmd = LuaCommand()
                cmd.name = args.string
                
                cmd.cmd = SignedCommand()

                if cmd.name.isEmpty == false {
                    
                    var found = false
                    /// First search the project materials
                    /// 
                    for material in self.model.project.materials {
                        if material.name == cmd.name {
                            cmd.cmd?.code = material.getCode()
                            found = true
                        }
                    }
                    
                    /// Than search the material cloud database
                    if found == false {
                        if let entity = self.model.getMaterialEntity(name: cmd.name) {
                            if let data = entity.code {
                                if let value = String(data: data, encoding: .utf8) {
                                    cmd.cmd?.code = value
                                }
                            }
                        }
                    }
                }
                
                cmd.cmd?.role = .MaterialOnly
                cmd.cmd?.action = .None
                
                let data = self.vm.createUserdata(cmd)
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
    func build(code: String, kit: ModelerKit, content: ModelerKit.Content = .project, renderKits: [RenderKit], objectEntity: ObjectEntity? = nil, materialEntity: MaterialEntity? = nil) {
        
        //guard let modeler = model.modeler else {
        //    return
        //}
        
        inProgress = true
        
        workItem = DispatchWorkItem {
            
            let model = self.model
            
            kit.status = .running
            kit.content = content
            kit.renderKits = renderKits
            kit.installNextRenderKit()
            kit.objectEntity = objectEntity
            kit.materialEntity = materialEntity
            
            if model.cameraMode != content {
                model.cameraMode = content
                DispatchQueue.main.async {
                    model.cameraModeChanged.send(content)
                }
            }
            
            if content == .project {
                kit.scale = Float(model.project.resolution) / Float(model.project.pixelsPerMeter)
                model.currentRenderName = "renderPBR"
            } else {
                kit.scale = 1
            }
                        
            if kit.role == .main {
                model.renderer?.restart()
                model.infoText = ""
                DispatchQueue.main.async {
                    model.infoChanged.send()
                }
            
                model.infoProgressProcessedCmds = 0
                model.infoProgressTotalCmds = 0
            }
                    
            self.vm = VirtualMachine()
            self.context = SignedContext(model: model, kit: kit)
            self.context.addToPipeline(cmd: SignedCommand("Clear", role: .GeometryAndMaterial, action: .Clear))
            
            // print
            self.vm.globals["_print"] = self.vm.createFunction([String.arg]) { args in
                if args.values.isEmpty == false {
                    if kit.role == .main {
                        self.model.infoText += args.string + "\n"
                        DispatchQueue.main.async {
                            self.model.infoChanged.send()
                        }
                    } else {
                        print(args.string)
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
            
            self.alreadyRequired = []
            
            // Auto require the basic public modules
            self.requireModules(["vec3", "vec2", "command"])
            
            // If we build a project require the project modules first, these have priority over public modules
            if kit.content == .project && kit.role == .main {
                for module in model.project.modules {
                    switch self.vm.eval(module.getCode(), args: []) {
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
                    self.alreadyRequired.append(module.name)
                }
            }
            
            // Set up the native classes
            self.setupLuaConfig(kit)
            self.setupLuaCommand()
            
            switch self.vm.eval(code, args: []) {
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
            
            if kit.content == .object {
                
                let position = float3(0,0,0)
                let size = float3(1,1,1)
                let rotation = float3(0,0,0)

                let v1 = position - size / 2
                let v2 = position + size / 2

                let bboxString = "bbox:new( \(self.float3ToVec3(v1)), \(self.float3ToVec3(v2)), \(self.float3ToVec3(rotation)))"
                let objectCode = """

                buildObject(0, \(bboxString), {})

                """
                                
                switch self.vm.eval(objectCode, args: []) {
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
            }
            
            if kit.content == .material {
                
                let materialCode = """

                sphereCmd = command:newShape("Sphere")
                sphereCmd:setVec3("position", vec3(0,0.5,0))
                sphereCmd:setNumber("radius", 0.5)
                sphereCmd:execute(0)

                sphereCmd = command:newShape("Sphere")
                sphereCmd:setVec3("position", vec3(0,0.5,0))
                sphereCmd:setNumber("radius", 0.47)
                sphereCmd:setMode("subtract")
                sphereCmd:execute(1)

                boxCmd = command:newShape("Box")
                boxCmd:setVec3("position", vec3(0,0.5,0))
                boxCmd:setVec3("rotation", vec3(0,0,0))
                boxCmd:setVec3("size", vec3(2, 0.07, 2))
                boxCmd:setMode("subtract")
                boxCmd:execute(1)

                boxCmd = command:newShape("Box")
                boxCmd:setVec3("position", vec3(0,0.5,0))
                boxCmd:setVec3("rotation", vec3(0,0,0))
                boxCmd:setVec3("size", vec3(0.07, 2, 2))
                boxCmd:setMode("subtract")
                boxCmd:execute(1)

                sphereCmd = command:newShape("Sphere")
                sphereCmd:setVec3("position", vec3(0,0.5,0))
                sphereCmd:setVec3("color", vec3(0.5,0.5,0.5))
                sphereCmd:setNumber("roughness", 0)
                sphereCmd:setNumber("radius", 0.44)
                sphereCmd:setVec3("emission", vec3(0.4,0.4,0.4))
                sphereCmd:execute(1)
                
                buildMaterial(0)

                """
                
                switch self.vm.eval(materialCode, args: []) {
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
            }
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

