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
        case Camera, Sky, Utility, Variable, Render, Light, Boolean, SDF
    }
    
    enum NodeContext {
        case None, Analytical, SDF, SDF2D, Material
    }
    
    enum NodeRenderType {
        case Normal, PathTracer
    }
    
    var id                  = UUID()
    
    var role                : NodeRole = .Camera
    var context             : NodeContext = .None

    // Only applicable for branch nodes like a sequence
    var leaves              : [GraphNode]! = nil
    
    var name                : String = ""
    var givenName           : String = ""
    
    var lineNr              : Int32 = 0
    
    var renderType          : NodeRenderType = .Normal
    
    // Options
    var options             : [String:Any]
    
    // Hierarchy
    var rootNode            : GraphNode? = nil
    var parentNode          : GraphNode? = nil
    
    // The material for the node, if any
    var materialNode        : GraphNode? = nil
    
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
    
    /// Implemented by renderers to init / reset the material variables
    func sampleLight(context: GraphContext) -> GraphLightInfo?
    {
        return nil
    }
    
    /// Implemented by renderers to init / reset the material variables
    func resetMaterialVariables(context: GraphContext)
    {
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
    var renderNode          : GraphNode? = nil

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

    // Special Global Variables
    
    var rayPosition         : Float3!
    var rayOrigin           : Float3!
    var rayDirection        : Float3!

    var displacement        : Float1!
    var bump                : Float1!

    var outColor            : Float4!
    var normal              : Float3!

    // Graph Values used for rendering
    
    var seed                = float2(0,0)                       // random seed
    var randomVector        = float3()
    var uv                  = float2(0,0)                       // UV coordinate (0..1)
    var viewSize            = float2(0,0)                       // Size of the view

    var adjustedUV          = float2(0,0)                       // The adjusted UV between 0..100 with 0,0 at the upper left corner

    var position            = float3(0,0,0)                     // Current object position
    var position2D          = float2(0,0)                       // Current object position for 2D objects

    var camOffset           = float2(0,0)                       // Camera AA uv offset

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
    
    // Distance 2D
    
    var distance2D          : [Float] = []                      // The distance to a 2D SDF
    var distance2DIndex     : Int = 0
        
    override init()
    {
        distance2D.append(.greatestFiniteMagnitude)
        distance2D.append(.greatestFiniteMagnitude)
        
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
        sdf2DNodes = []
        analyticalNodes = []
        materialNodes = []
        objectNodes = []
        lightNodes = []
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
    
    @inlinable public func toggleRayIndex()
    {
        rayIndex = rayIndex == 0 ? 1 : 0
    }
    
    @inlinable public func toggleDistance2DIndex()
    {
        distance2DIndex = distance2DIndex == 0 ? 1 : 0
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
    
    @discardableResult @inlinable public func executeSDF2D() -> GraphNode.Result
    {
        distance2D[0] = .greatestFiniteMagnitude
        distance2D[1] = .greatestFiniteMagnitude
        hitMaterial[0] = nil
        hitMaterial[1] = nil
        distance2DIndex = 0
        failedAt = []
        
        for node in sdf2DNodes {
            node.execute(context: self)
        }
        toggleDistance2DIndex()
        
        return .Success
    }
    
    @discardableResult @inlinable public func executeRender() -> GraphNode.Result
    {
        failedAt = []
        if let renderNode = renderNode {
            renderNode.execute(context: self)
        }
        return .Success
    }
    
    /// Execute the material and optional bump mapping
    @discardableResult @inlinable public func executeMaterial(_ material: GraphNode) -> GraphNode.Result
    {
        failedAt = []

        bump.x = 0
        if let renderNode = renderNode {
            renderNode.resetMaterialVariables(context: self)
        }
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
    
    ///
    func hit(shadowRay: Bool = false) -> (Float, GraphNode?, float3)
    {
        var rc : (Float, GraphNode?, float3) = (Float.greatestFiniteMagnitude, nil, float3(0,0,0))
        
        let camOrigin = rayOrigin.toSIMD()
        let camDir = rayDirection.toSIMD()
        
        // Analytical Objects
        executeAnalytical()
        
        let maxDist : Float = analyticalDist//12.0//simd_min(12.0, analyticalDist)
        var material : GraphNode? = nil

        // Raymarch
        var hit = false
        var t : Float = 0.001;
        for _ in 0..<70
        {
            executeSDF(camOrigin + t * camDir)

            if abs(rayDist[rayIndex]) < (0.0001*t) {
                hit = true
                material = hitMaterial[rayIndex]
                break
            } else
            if t > maxDist {
                break
            }
            
            t += rayDist[rayIndex]
        }
        
        if hit && t < analyticalDist {
            rc.0 = t
            let p = camOrigin + t * camDir
            if shadowRay == false {
                rc.2 = calcNormal(position: p)
            }

            if let material = material {
                rc.1 = material
            }
        } else
        if analyticalDist != .greatestFiniteMagnitude {
            
            rc.0 = analyticalDist
            rc.2 = analyticalNormal

            if let material = analyticalMaterial {
                rc.1 = material
            }
        }
        return rc
    }

    /// Cast a ray
    func castRay(_ rO: float3,_ rD: float3) -> float3
    {
        let hasHitSomethingBuffer = hasHitSomething
        
        let backup = createVariableBackup()
        
        rayOrigin.fromSIMD(rO + rD * 0.0001)
        rayDirection.fromSIMD(rD)
        
        let camOrigin = rO + rD * 0.0001
        let rayDir = rD
        
        let hit = self.hit()
        if hit.0 == Float.greatestFiniteMagnitude {
            if let skyNode = skyNode {
                skyNode.execute(context: self)
            }
        } else {
            hasHitSomething = true

            normal.fromSIMD(hit.2)
            
            let p = camOrigin + hit.0 * rayDir
            rayPosition.fromSIMD(p)
            
            if let material = hit.1 {
                executeMaterial(material)
            }
            executeRender()
        }
        
        let outColor = self.outColor!.toSIMD()
        var result = float3(0,0,0)
        
        result.x = simd_clamp(outColor.x, 0.0, 1.0)
        result.y = simd_clamp(outColor.y, 0.0, 1.0)
        result.z = simd_clamp(outColor.z, 0.0, 1.0)

        hasHitSomething = hasHitSomethingBuffer
        restoreVariableBackup(backup)
        
        return result
    }
    
    /// Cast an SDF specific soft shadow ray
    func shadowRay(_ rO: float3,_ rD: float3) -> Float
    {
        if hasHitSomething == true {
                                
            let backup = createVariableBackup()
            
            rayOrigin.fromSIMD(rO + rD)
            rayDirection.fromSIMD(rD)
            
            let camOrigin = rO + rD
            let rayDir = rD

            // Analytical Objects
            executeAnalytical()
            let h = analyticalDist
            
            let tmin : Float = 0.02
            let tmax : Float = min(2.5, analyticalDist)
            var t : Float = tmin
            let k : Float = 4
            var ph : Float = 1e20

            var result : Float = 1
                                    
            if( h < 0.001 ) {
                result = 0
            }

            while t < tmax && result > 0.0 {
                executeSDF(camOrigin + t * rayDir)
                let h = rayDist[rayIndex]
                if( h < 0.001 ) {
                    result = 0
                    break
                }
                let y : Float = h*h/(2.0*ph)
                let d : Float = sqrt(h*h-y*y)
                result = min( result, k*d/max(0.0,t-y) )
                ph = h
                t += h
            }
                                    
            restoreVariableBackup(backup)
            
            return result
        }
        return 1
    }
    
    /// Calculates the normal for the given hit position
    func calcNormal(position: float3) -> float3
    {
        /*
        vec3 epsilon = vec3(0.001, 0., 0.);
        
        vec3 n = vec3(map(p + epsilon.xyy).x - map(p - epsilon.xyy).x,
                      map(p + epsilon.yxy).x - map(p - epsilon.yxy).x,
                      map(p + epsilon.yyx).x - map(p - epsilon.yyx).x);
        
        return normalize(n);*/

        let e = float3(0.001, 0.0, 0.0)

        var eOff : float3 = position + float3(e.x, e.y, e.y)
        executeSDF(eOff)
        var n1 = rayDist[rayIndex]
        
        eOff = position - float3(e.x, e.y, e.y)
        executeSDF(eOff)
        n1 = n1 - rayDist[rayIndex]
        
        eOff = position + float3(e.y, e.x, e.y)
        executeSDF(eOff)
        var n2 = rayDist[rayIndex]
        
        eOff = position - float3(e.y, e.x, e.y)
        executeSDF(eOff)
        n2 = n2 - rayDist[rayIndex]
        
        eOff = position + float3(e.y, e.y, e.x)
        executeSDF(eOff)
        var n3 = rayDist[rayIndex]
        
        eOff = position - float3(e.y, e.y, e.x)
        executeSDF(eOff)
        n3 = n3 - rayDist[rayIndex]
        
        return simd_normalize(float3(n1, n2, n3))
    }
    
    func rand() -> Float
    {
        //return 0.5

        //return Float.random(in: 0...1)
        seed.x -= randomVector.x
        seed.y -= randomVector.y
        let x = sin(dot(seed, float2(12.9898, 78.233)))
        return simd_fract(x * Float(43758.5453))
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
