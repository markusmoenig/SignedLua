//
//  Graph.swift
//  Signed
//
//  Created by Markus Moenig on 13/12/20.
//

import MetalKit

class GraphOption : Equatable, Identifiable {
    
    var id      = UUID()
    
    var variable: BaseVariable
    var name    : String
    var help    : String
    
    init(_ variable: BaseVariable,_ name: String,_ help: String)
    {
        self.variable = variable
        self.name = name
        self.help = help
    }
    
    static func ==(lhs:GraphOption, rhs:GraphOption) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

class GraphNode : Equatable, Identifiable {
    
    enum Result {
        case Success, Failure, Running, Unused
    }
    
    enum NodeRole {
        case Camera, Sky, Utility, Variable
    }
    
    enum NodeContext {
        case None, Analytical, SDF, Material, Render
    }
    
    var id                  = UUID()
    
    var role                : NodeRole = .Camera
    var context             : NodeContext = .None

    // Only applicable for branch nodes like a sequence
    var leaves              : [GraphNode]! = nil
    
    var name                : String = ""
    var givenName           : String = ""
    
    var lineNr              : Int32 = 0
    
    // Options
    var options             : [String:Any]
    
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
    
    static func ==(lhs:GraphNode, rhs:GraphNode) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

final class GraphContext    : VariableContainer
{
    var buffer              : Array<SIMD4<UInt8>>!
    
    var cameraNode          : GraphNode? = nil
    var skyNode             : GraphNode? = nil
    
    // Nodes
    var nodes               : [GraphNode] = []
    
    var materialNodes       : [GraphNode] = []

    var analyticalNodes     : [GraphNode] = []
    var sdfNodes            : [GraphNode] = []

    var renderNodes         : [GraphNode] = []

    var hierarchicalNodes   : [GraphNode] = []

    var failedAt            : [Int32] = []
    
    var lines               : [Int32: GraphNode] = [:]

    // Special Global Variables
    
    var rayPosition         : Float3!
    var rayOrigin           : Float3!
    var rayDirection        : Float3!

    var displacement        : Float1!

    var outColor            : Float4!
    var normal              : Float3!

    // Graph Values used for rendering
    
    var uv                  = float2(0,0)                       // UV coordinate (0..1)
    var viewSize            = float2(0,0)                       // Size of the view

    var position            = float3(0,0,0)                     // Current object position
    var position2D          = float2(0,0)                       // Current object position for 2D objects

    var camOffset           = float2(0,0)                       // Camera AA uv offset
    var camOrigin           = float3(0,0,-5)                    // Camera Origin, set by camera node
    
    var rayDir              = float3(0,0,0)                     // Ray direction, computed and set by camera node
        
    var analyticalDist      : Float = .greatestFiniteMagnitude
    var analyticalNormal    = float3(0,0,0)                     // Analytical Normal
    var analyticalMaterial  : GraphNode? = nil
    
    var activeMaterial      : GraphNode? = nil                  // The currently active Material in the hierarchy

    var hitMaterial         : [GraphNode?] = []                 // The material which was hit for the given index
    var blendMaterial       : GraphNode? = nil                  // The material to blend with (optional), set by the booleans
    var materialBlend       : Float? = nil                      // The blend factor

    var reflectionDepth     : Int = 0
    var insideShadowRay     : Bool = false
    
    var hasHitSomething     : Bool = false
    
    // SDF Raymarching
    
    var rayDist             : [Float] = []
    var rayIndex            : Int = 0
    
    override init()
    {
        rayDist.append(.greatestFiniteMagnitude)
        rayDist.append(.greatestFiniteMagnitude)
        
        hitMaterial.append(nil)
        hitMaterial.append(nil)
        
        super.init()
    }
    
    func clear()
    {
        nodes = []
        sdfNodes = []
        renderNodes = []
        analyticalNodes = []
        materialNodes = []
        hierarchicalNodes = []
        variables = [:]
        lines = [:]
        
        cameraNode = nil
        skyNode = nil
                
        analyticalMaterial = nil
        hitMaterial[0] = nil
        hitMaterial[1] = nil
        
        blendMaterial = nil
        materialBlend = 0
    }
    
    /// Creates the default variables for the graph
    func createDefaultVariables()
    {
        // Insert default variables
        
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
    
    
    @inlinable public func toggleRayIndex()
    {
        if rayIndex == 0 {
            rayIndex = 1
        } else {
            rayIndex = 0
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
    
    @discardableResult @inlinable public func executeAnalytical() -> GraphNode.Result
    {
        analyticalDist = .greatestFiniteMagnitude
        analyticalMaterial = nil
        failedAt = []
        for node in analyticalNodes {
            node.execute(context: self)
        }
        return .Success
    }
    
    @discardableResult @inlinable public func executeSDF(_ rayPosition: float3 = float3(0,0,0)) -> GraphNode.Result
    {
        self.rayPosition.fromSIMD(rayPosition)
        rayDist[0] = .greatestFiniteMagnitude
        rayDist[1] = .greatestFiniteMagnitude
        hitMaterial[0] = nil
        hitMaterial[1] = nil
        rayIndex = 0
        position = float3(0,0,0)
        failedAt = []
        
        for node in sdfNodes {
            node.execute(context: self)
        }
        toggleRayIndex()
        
        return .Success
    }
    
    @discardableResult @inlinable public func executeRender() -> GraphNode.Result
    {
        failedAt = []
        for node in renderNodes {
            node.execute(context: self)
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
