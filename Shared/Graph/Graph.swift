//
//  Graph.swift
//  Signed
//
//  Created by Markus Moenig on 13/12/20.
//

import MetalKit

class GraphOption : Equatable, Identifiable {
    
    enum Rules {
        case None, SameTypeAsPrevious
    }
    
    var id          = UUID()
    
    var variable    : BaseVariable
    var name        : String
    var help        : String
    var group       : String? = nil
    var optionals   : [BaseVariable]
    var rules       : Rules
    
    var raw         : String = ""
    
    init(_ variable: BaseVariable,_ name: String,_ help: String, group: String? = nil, optionals: [BaseVariable] = [], rules: Rules = .None)
    {
        self.variable = variable
        self.name = name
        self.help = help
        self.group = group
        self.optionals = optionals
        self.rules = rules
    }
    
    static func ==(lhs:GraphOption, rhs:GraphOption) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

class GraphLightInfo {

    enum LightType {
        case Sun, Spherical, Rect
    }
    
    var lightType       : LightType
    
    var surfacePos      = float3(0,0,0)
    var normal          = float3(0,0,0)
    var emission        = float3(0,0,0)
    
    var area            : Float = 1
    
    // For directional lights
    var direction       = float3(0,0,0)
    
    // For preview
    var position        = float3(0,0,0)
    var radius          = Float(1)

    init(_ lightType: LightType)
    {
        self.lightType = lightType
    }
}

class GraphNode : Equatable, Identifiable {
    
    enum Result {
        case Success, Failure, Running, Unused
    }
    
    enum NodeRole {
        case Camera, Sky, Utility, Variable, Render, Light, Boolean, SDF, Sun
    }
    
    enum NodeContext {
        case None, Analytical, SDF, SDF2D, Material
    }
    
    var id                  = UUID()
    var index               : Int? = nil
    
    var role                : NodeRole = .Camera
    var context             : NodeContext = .None

    // Only applicable for branch nodes like a sequence
    var leaves              : [GraphNode]! = nil
    
    var name                : String = ""
    var givenName           : String = ""
    
    var lineNr              : Int32 = -1
    
    var hasToolUI           : Bool = false

    // Options
    var options             : [String:Any]
    
    // Hierarchy
    var rootNode            : GraphNode? = nil
    var parentNode          : GraphNode? = nil
    
    // The material for the node, if any
    var materialNode        : GraphNode? = nil
    
    // Shader implementation
    var gpuShader           : AnyObject? = nil
        
    init(_ role: NodeRole,_ context: NodeContext,_ options: [String:Any] = [:])
    {
        self.role = role
        self.context = context
        self.options = options
    }
    
    /// Verify options
    func verifyOptions(context: GraphContext, error: inout CompileError) {
    }
    
    /// Executes a node inside a behaviour tree
    @discardableResult @inlinable public func execute(context: GraphContext) -> Result
    {
        return .Success
    }
    
    /// Returns the metal code for this node
    func generateMetalCode(context: GraphContext) -> String
    {
        let code = ""
        
        return code
    }
    
    /// Get help text
    func getHelp() -> String
    {
        return ""
    }
    
    /// Get options
    func getOptions() -> [GraphOption]
    {
        return []
    }
    
    /// toolActivated, draw the initial UI state
    func toolActivated(_ toolContext: GraphToolContext)
    {
    }
    
    /// toolTouchDown
    func toolTouchDown(_ pos: float2,_ toolContext: GraphToolContext)
    {
    }
    
    /// toolTouchMove
    func toolTouchMove(_ pos: float2,_ toolContext: GraphToolContext)
    {
    }
    
    /// toolTouchUp
    func toolTouchUp(_ pos: float2,_ toolContext: GraphToolContext)
    {
    }
    
    /// toolScrollWheel (macOSOnly)
    func toolScrollWheel(_ delta: float3,_ toolContext: GraphToolContext)
    {
    }
    
    /// toolPinchGesture (macOSOnly)
    func toolPinchGesture(_ scale: Float,_ firstTouch: Bool,_ toolContext: GraphToolContext)
    {
    }
    
    /// The state of a tool view button has changed
    func toolViewButtonAction(_ button: ToolViewButton, state: ToolViewButton.State, delta: float2, toolContext: GraphToolContext)
    {
    }

    /// The buttons visible as overlay in the tool window
    func getToolViewButtons() -> [ToolViewButton]
    {
        return []
    }
    
    static func ==(lhs:GraphNode, rhs:GraphNode) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

final class GraphContext    : VariableContainer
{
    enum RenderQuality {
        case Normal, Fast, Fastest
    }
    
    var renderQuality       : RenderQuality = .Normal
    
    //var buffer              : Array<SIMD4<UInt8>>!
    
    var cameraNode          : GraphNode? = nil
    var sunNode             : GraphNode? = nil
    var skyNode             : GraphNode? = nil

    // Nodes
    var nodes               : [GraphNode] = []
    
    var materialNodes       : [GraphNode] = []
    var objectNodes         : [GraphNode] = []

    var analyticalNodes     : [GraphNode] = []
    var sdfNodes            : [GraphNode] = []
    var sdf2DNodes          : [GraphNode] = []
    
    var lightNodes          : [GraphNode] = []

    var failedAt            : [Int32] = []
    
    var lines               : [Int32: GraphNode] = [:]
    
    var objectVariables     : [String: BaseVariable] = [:]

    // Special Global Variables
    
    var rayPosition         : Float3!
    var rayOrigin           : Float3!
    var rayDirection        : Float3!

    var displacement        : Float1!
    var bump                : Float1!

    var outColor            : Float4!
    var normal              : Float3!
    
    // Default Material Variables (Disney BSDF)

    var albedo              : Float3!
    var specular            : Float1!
    
    var emission            : Float3!
    var anisotropic         : Float1!
    
    var metallic            : Float1!
    var roughness           : Float1!
    var subsurface          : Float1!
    var specularTint        : Float1!
    
    var sheen               : Float1!
    var sheenTint           : Float1!
    var clearcoat           : Float1!
    var clearcoatGloss      : Float1!

    var transmission        : Float1!
    var ior                 : Float1!
    var extinction          : Float3!

    // Graph Values used for rendering
    
    var uv                  = float2(0,0)                       // UV coordinate (0..1)
    var viewSize            = float2(0,0)                       // Size of the view

    var adjustedUV          = float2(0,0)                       // The adjusted UV between 0..100 with 0,0 at the upper left corner

    var position            = float3(0,0,0)                     // Current object position
    var rotation            = float3(0,0,0)                     // Current object rotation
    var scale               = Float(1)                          // Current object scale
        
    var position2D          = float2(0,0)                       // Current 2D object position

    var activeMaterial      : GraphNode? = nil                  // The currently active Material in the hierarchy
    
    var data                : [float4] = []
    var lightsData          : [float4] = []

    override init()
    {
        super.init()
    }
    
    func setupBeforeCompiling()
    {
        data = [float4(0,0,0,0)]
        lightsData = [float4(0,0,0,0)]
    }
    
    func clear()
    {
        nodes = []
        sdfNodes = []
        sdf2DNodes = []
        analyticalNodes = []
        materialNodes = []
        objectNodes = []
        lightNodes = []
        variables = [:]
        lines = [:]
        
        cameraNode = nil
        skyNode = nil
        sunNode = nil
        
        data = []
    }
    
    func checkForPossibleLight(atPositionIndex: Int, material: GraphNode? = nil, radius: Float? = nil, rect: float3? = nil) {
        if let materialNode = material as? GraphMaterialNode {
            if materialNode.isEmitter && materialNode.index != nil {
                print("light at data index", atPositionIndex, materialNode.index!)
                
                var data1 = float4()
                let data2 = float4()
                
                data1.y = Float(atPositionIndex)
                data1.z = Float(materialNode.index!)
                
                if let radius = radius {
                    data1.x = 1
                    data1.w = radius
                }
                
                lightsData[0].x += 1
                lightsData.append(data1)
                lightsData.append(data2)
            }
        }
    }
    
    /// Add a variable to the data stack
    func addDataVariable(_ variable: BaseVariable)
    {
        variable.dataIndex = data.count
        data.append(float4())
    }
    
    /// Update the variable data value in the stack
    func updateDataVariable(_ variable: BaseVariable)
    {
        if let index = variable.dataIndex, index < data.count {
            data[index] = variable.toSIMD4()
        }
    }
    
    /// Returns the index of the currently active material
    func getMaterialIndex() -> String
    {
        var materialId = "-1"
        if let material = activeMaterial {
            if let index = material.index {
                materialId = String(index)
            }
        }
        return materialId
    }

    /// Creates the default variables for the graph
    func createDefaultVariables()
    {
        // Insert default variables
        
        parameters = []
        let uv = Float2("uv", 0, 0)
        uv.role = .System
        parameters!.append(uv)
        
        let viewSize = Float2("viewSize", 0, 0)
        viewSize.role = .System
        parameters!.append(viewSize)
        
        let rP = Float3("rayPosition", 0, 0, 0)
        rP.role = .System
        parameters!.append(rP)
        
        outColor = Float4("outColor", 0.0, 0.0, 0.0, 0.0)
        outColor.role = .System
        variables["outColor"] = outColor
        
        rayPosition = Float3("rayPosition", 0, 0, 0)
        rayPosition.role = .System
        variables["rayPosition"] = rayPosition
        
        rayOrigin = Float3("rayOrigin", 0, 0, 0)
        rayOrigin.role = .System
        variables["rayOrigin"] = rayOrigin
        
        rayDirection = Float3("rayDirection", 0, 0, 0)
        rayDirection.role = .System
        variables["rayDirection"] = rayDirection
        
        normal = Float3("normal", 0, 0, 0)
        normal.role = .System
        variables["normal"] = normal
        
        displacement = Float1("displacement", 0)
        displacement.role = .System
        variables["displacement"] = displacement
        
        bump = Float1("bump", 0)
        bump.role = .System
        variables["bump"] = bump
    }
    
    func createVariableBackup() -> ([String:float4],[String:float3], [String:float2], [String:Float])
    {
        var bf4 : [String:float4] = [:]
        var bf3 : [String:float3] = [:]
        var bf2 : [String:float2] = [:]
        var bf1 : [String:Float] = [:]
        
        for (key, v) in variables {
            if let f4 = v as? Float4 {
                bf4[key] = f4.toSIMD()
            } else
            if let f3 = v as? Float3 {
                bf3[key] = f3.toSIMD()
            } else
            if let f2 = v as? Float2 {
                bf2[key] = f2.toSIMD()
            } else
            if let f1 = v as? Float1 {
                bf1[key] = f1.toSIMD()
            }
        }

        return (bf4, bf3, bf2, bf1)
    }

    func restoreVariableBackup(_ backup: ([String:float4],[String:float3], [String:float2], [String:Float]))
    {
        for (key, v) in variables {
            if let f4 = v as? Float4 {
                f4.fromSIMD(backup.0[key]!)
            } else
            if let f3 = v as? Float3 {
                f3.fromSIMD(backup.1[key]!)
            } else
            if let f2 = v as? Float2 {
                f2.fromSIMD(backup.2[key]!)
            } else
            if let f1 = v as? Float1 {
                f1.fromSIMD(backup.3[key]!)
            }
        }
    }
    
    /// Adds a variable to the context
    func addVariable(_ variable: BaseVariable)
    {
        variables[variable.name] = variable
    }
    
    /// Recursively search for the node of the given id
    func getNode(_ id: UUID?) -> GraphNode?
    {
        if id == nil { return nil }
        
        func checkNode(_ node: GraphNode) -> GraphNode?
        {
            if node.id == id {
                return node
            }
            if let childs = node.leaves {
                for c in childs {
                    if let found = checkNode(c) {
                        return found
                    }
                }
            }
            return nil
        }
                
        for t in nodes {
            if let found = checkNode(t) {
                return found
            }
        }
        
        if let cameraNode = cameraNode {
            if cameraNode.id == id {
                return cameraNode
            }
        }
        
        return nil
    }
    
    /// Get the given variable and process globals
    override func getVariableValue(_ name: String) -> BaseVariable?
    {
        return super.getVariableValue(name)
    }
    
    /// Get the material by the given name
    func getMaterial(_ name: String) -> GraphNode?
    {
        for m in materialNodes {
            if m.givenName == name {
                return m
            }
        }
        return nil
    }
        
    func addFailure(lineNr: Int32)
    {
        failedAt.append(lineNr)
    }
    
    @discardableResult @inlinable public func execute() -> GraphNode.Result
    {
        failedAt = []
        for node in nodes {
            node.execute(context: self)
        }
        return .Success
    }
    
    /// Execute the material and optional bump mapping
    @discardableResult @inlinable public func executeMaterial(_ material: GraphNode) -> GraphNode.Result
    {
        failedAt = []

        bump.x = 0
        material.execute(context: self)
        
        if bump.x != 0.0 {
            let backup = createVariableBackup()
            let e = float2(0.001, 0)
            
            let pO = rayPosition.toSIMD()
            let bRef = bump.toSIMD()
            
            rayPosition.fromSIMD(pO - float3(e.x, e.y, e.y))
            material.execute(context: self)
            let b1 = bump.toSIMD()
            
            rayPosition.fromSIMD(pO - float3(e.y, e.x, e.y))
            material.execute(context: self)
            let b2 = bump.toSIMD()
            
            rayPosition.fromSIMD(pO - float3(e.y, e.y, e.x))
            material.execute(context: self)
            let b3 = bump.toSIMD()
            
            restoreVariableBackup(backup)
            
            let n = normal.toSIMD()
            var grad = (float3(b1, b2, b3) - bRef) / e.x
            grad -= n * simd_dot(n, grad)
            
            let bumpFactor : Float = 0.2
            normal.fromSIMD(simd_normalize(n + grad * bumpFactor))
        }
        
        return .Success
    }
    
    func debug()
    {
        for node in nodes {
            print(node.name, node.leaves.count )
            for l in node.leaves {
                print("  \(l.name)", l.leaves.count)
                for l in l.leaves {
                    print("    \(l.name)", l.leaves.count)
                }
            }
        }
    }
}
