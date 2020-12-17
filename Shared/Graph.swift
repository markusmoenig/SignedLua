//
//  Graph.swift
//  Signed
//
//  Created by Markus Moenig on 13/12/20.
//

import Foundation

class GraphOption {
    
    var type    = ""
    var name    : String
    var help    : String
    
    init(_ type: String,_ name: String,_ help: String)
    {
        self.type = type
        self.name = name
        self.help = help
    }
}

class GraphNode : Equatable, Identifiable {
    
    enum Result {
        case Success, Failure, Running, Unused
    }
    
    enum NodeRole {
        case Camera, Sky, Utility
    }
    
    enum NodeContext {
        case None, Analytical, SDF
    }
    
    var id                  = UUID()
    
    var role                : NodeRole = .Camera
    var context             : NodeContext = .None

    // Only applicable for branch nodes like a sequence
    var leaves              : [GraphNode]! = nil
    
    var name                : String = ""
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
    
    static func ==(lhs:GraphNode, rhs:GraphNode) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}

class GraphVariable
{
    var name        : String
    var value       : Any
    
    init(_ name: String,_ value:Any)
    {
        self.name = name
        self.value = value
    }
}

final class GraphContext
{
    var buffer              : Array<SIMD4<UInt8>>!
    
    var cameraNode          : GraphNode? = nil
    var skyNode             : GraphNode? = nil
    
    // Nodes
    var nodes               : [GraphNode] = []
    var analyticalNodes     : [GraphNode] = []
    var sdfNodes            : [GraphNode] = []

    var variables           : [GraphVariable] = []
    var failedAt            : [Int32] = []
    
    var lines               : [Int32:GraphNode] = [:]
        
    let core                : Core
    
    var uv                  = float2(0,0)                       // UV coordinate (0..1)
    var viewSize            = float2(0,0)                       // Size of the view

    var position            = float3(0,0,0)                     // Current 3D position for raymarching
    
    var camOffset           = float2(0,0)                       // Camera AA uv offset
    var camOrigin           = float3(0,0,-5)                    // Camera Origin, set by camera node
    
    var rayDir              = float3(0,0,0)                     // Ray direction, computed and set by camera node
    
    var result              = float4(0,0,0,1)                   // Temporary result of a node (Sky etc)
    
    var analyticalDist      : Float = .greatestFiniteMagnitude
    var analyticalNormal    = float3(0,0,0)                     // Analytical Normal

    // SDF Raymarching
    
    var rayPos              : float3 = float3(0,0,0)
    var rayDist             : [Float] = []
    var rayIndex            : Int = 0
    
    init(_ core: Core)
    {
        self.core = core
        
        rayDist.append(.greatestFiniteMagnitude)
        rayDist.append(.greatestFiniteMagnitude)
    }
    
    func clear()
    {
        nodes = []
        sdfNodes = []
        analyticalNodes = []
        variables = []
        lines = [:]
        cameraNode = nil
    }
    
    /// Create a copy of this context and return it
    func copy() -> GraphContext {
        let copy = GraphContext(core)
        copy.nodes = nodes
        copy.variables = variables
        return copy
    }
    
    @inlinable public func toggleRayIndex()
    {
        if rayIndex == 0 {
            rayIndex = 1
        } else {
            rayIndex = 0
        }
    }
    
    func addVariable(_ name: String,_ value: Any)
    {
        variables.append(GraphVariable(name, value))
    }
    
    func getVariableValue(_ name: String) -> Any?
    {
        // Globals
        if name == "Time" {
            return core._Time
        } else
        if name == "Aspect" {
            return core._Aspect
        }
        
        // Check the context variables
        for v in variables {
            if v.name == name {
                return v.value
            }
        }
        return nil
    }
    
    func getNode(_ name: String) -> GraphNode?
    {
        // Check the context variables
        for t in nodes {
            if t.name == name {
                return t
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
        failedAt = []
        for node in analyticalNodes {
            node.execute(context: self)
        }
        return .Success
    }
    
    @discardableResult @inlinable public func executeSDF(_ rayPos: float3 = float3(0,0,0)) -> GraphNode.Result
    {
        self.rayPos = rayPos
        rayDist[0] = .greatestFiniteMagnitude
        rayDist[1] = .greatestFiniteMagnitude
        rayIndex = 0
        position = float3(0,0,0)
        failedAt = []
        
        for node in sdfNodes {
            node.execute(context: self)
        }
        toggleRayIndex()
        
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
