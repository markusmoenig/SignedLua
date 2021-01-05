//
//  Game.swift
//  Signed
//
//  Created by Markus Moenig on 25/8/20.
//

import MetalKit
import Combine
import AVFoundation

public class Core       : ObservableObject
{
    enum State {
        case Idle, Running, Paused
    }
    
    var state           : State = .Idle
    
    var view            : DMTKView!
    var device          : MTLDevice!

    var metalStates     : MetalStates!
    
    var file            : File? = nil

    var viewportSize    : vector_uint2
    var scaleFactor     : Float
    
    var assetFolder     : AssetFolder!
    
    var screenWidth     : Float = 0
    var screenHeight    : Float = 0

    var gameCmdQueue    : MTLCommandQueue? = nil
    var gameCmdBuffer   : MTLCommandBuffer? = nil
    var gameScissorRect : MTLScissorRect? = nil
    
    var scriptEditor    : ScriptEditor!
    var scriptProcessor : ScriptProcessor!

    var textureLoader   : MTKTextureLoader!
        
    var resources       : [AnyObject] = []
    var availableFonts  : [String] = ["OpenSans", "Square", "SourceCodePro"]
    var fonts           : [Font] = []
    
    var _Time           = Float1(0)
    var _Aspect         = Float2(1,1)
    var _Frame          = UInt32(0)
    var targetFPS       : Float = 60
    
    var gameAsset       : Asset? = nil

    // Preview Size, UI only
    var previewFactor   : CGFloat = 4
    var previewOpacity  : Double = 0.5
    
    let updateUI        = PassthroughSubject<Void, Never>()
    var didSend         = false
    
    let timeChanged     = PassthroughSubject<Float, Never>()

    let createPreview   = PassthroughSubject<Void, Never>()

    var helpText        : String = ""
    let helpTextChanged = PassthroughSubject<Void, Never>()
    
    var contextText     : String = ""
    var contextKey      : String = ""
    let contextTextChanged = PassthroughSubject<String, Never>()

    var assetError      = CompileError()
    let gameError       = PassthroughSubject<Void, Never>()
    
    let modelChanged    = PassthroughSubject<Void, Never>()
    
    var localAudioPlayers: [String:AVAudioPlayer] = [:]
    var globalAudioPlayers: [String:AVAudioPlayer] = [:]
    
    var showingHelp     : Bool = false
    
    var frameworkId     : String? = nil
    
    var renderer        : Renderer!
    var graphBuilder    : GraphBuilder!

    public init(_ frameworkId: String? = nil)
    {        
        self.frameworkId = frameworkId
        
        viewportSize = vector_uint2( 0, 0 )
        
        #if os(OSX)
        scaleFactor = Float(NSScreen.main!.backingScaleFactor)
        #else
        scaleFactor = Float(UIScreen.main.scale)
        #endif
                
        file = File()

        assetFolder = AssetFolder()
        assetFolder.setup(self)
        
        graphBuilder = GraphBuilder(self)
        scriptProcessor = ScriptProcessor(self)

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            print(error.localizedDescription)
        }
        #endif
        
        renderer = Renderer()
    }
    
    public func setupView(_ view: DMTKView)
    {
        self.view = view
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            device = metalDevice
            if frameworkId != nil {
                view.device = device
            }
        } else {
            print("Cannot initialize Metal!")
        }
        view.core = self
        
        metalStates = MetalStates(self)
        textureLoader = MTKTextureLoader(device: device)
        view.enableSetNeedsDisplay = true
        view.isPaused = true

        /*
        for fontName in availableFonts {
            let font = Font(name: fontName, game: self)
            fonts.append(font)
        }*/
        
        view.platformInit()
    }
    
    public func load(_ data: Data)
    {
        if let folder = try? JSONDecoder().decode(AssetFolder.self, from: data) {
            assetFolder = folder
        }
    }
    
    public func draw()
    {
        guard let drawable = view.currentDrawable else {
            return
        }
                        
        if renderer.checkIfTextureIsValid(self) == false {
            return
        }
        
        if let texture = renderer.texture {            
            startDrawing()
            let renderPassDescriptor = view.currentRenderPassDescriptor
            renderPassDescriptor?.colorAttachments[0].loadAction = .load
            let renderEncoder = gameCmdBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
            
            drawTexture(texture, renderEncoder: renderEncoder!)
            renderEncoder?.endEncoding()
            
            gameCmdBuffer!.present(drawable)
            stopDrawing()
        }
        
        if state == .Running {
            _Time.x += 1.0 / targetFPS
            _Frame += 1
        }
    }
    
    func startDrawing()
    {
        if gameCmdQueue == nil {
            gameCmdQueue = view.device!.makeCommandQueue()
        }
        gameCmdBuffer = gameCmdQueue!.makeCommandBuffer()
    }
    
    func stopDrawing(deleteQueue: Bool = false)
    {
        gameCmdBuffer?.commit()

        if deleteQueue {
            self.gameCmdQueue = nil
        }
        self.gameCmdBuffer = nil
    }
    
    /// Clears all local audio
    func clearLocalAudio()
    {
        for (_, a) in localAudioPlayers {
            a.stop()
        }
        localAudioPlayers = [:]
    }
    
    /// Clears all global audio
    func clearGlobalAudio()
    {
        for (_, a) in globalAudioPlayers {
            a.stop()
        }
        globalAudioPlayers = [:]
    }
    
    /// Updates the display once
    var isUpdating : Bool = false
    func updateOnce()
    {
        if isUpdating == false {
            isUpdating = true
            #if os(OSX)
            let nsrect : NSRect = NSRect(x:0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
            self.view.setNeedsDisplay(nsrect)
            #else
            self.view.setNeedsDisplay()
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) {
                self.isUpdating = false
            }
        }
    }
    
    func drawTexture(_ texture: MTLTexture, renderEncoder: MTLRenderCommandEncoder)
    {
        let width : Float = Float(texture.width)
        let height: Float = Float(texture.height)

        var settings = TextureUniform()
        settings.screenSize.x = Float(texture.width)//screenWidth
        settings.screenSize.y = Float(texture.height)//screenHeight
        settings.pos.x = 0
        settings.pos.y = 0
        settings.size.x = width * scaleFactor
        settings.size.y = height * scaleFactor
        settings.globalAlpha = 1
                
        let rect = MMRect( 0, 0, width, height, scale: scaleFactor )
        let vertexData = createVertexData(texture: texture, rect: rect)
        
        var viewportSize = vector_uint2( UInt32(texture.width), UInt32(texture.height))

        renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        renderEncoder.setFragmentBytes(&settings, length: MemoryLayout<TextureUniform>.stride, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 1)

        renderEncoder.setRenderPipelineState(metalStates.getState(state: .CopyTexture))
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Creates vertex data for the given rectangle
    func createVertexData(texture: MTLTexture, rect: MMRect) -> [Float]
    {
        let left: Float  = -Float(texture.width) / 2.0 + rect.x
        let right: Float = left + rect.width//self.width / 2 - x
        
        let top: Float = Float(texture.height) / 2.0 - rect.y
        let bottom: Float = top - rect.height

        let quadVertices: [Float] = [
            right, bottom, 1.0, 0.0,
            left, bottom, 0.0, 0.0,
            left, top, 0.0, 1.0,
            
            right, bottom, 1.0, 0.0,
            left, top, 0.0, 1.0,
            right, top, 1.0, 1.0,
        ]
        
        return quadVertices
    }
}
