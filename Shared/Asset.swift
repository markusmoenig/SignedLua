//
//  Asset.swift
//  Signed
//
//  Created by Markus Moenig on 26/8/20.
//

import MetalKit
import CloudKit

/// Base64 extension for string
extension String {

func fromBase64() -> String? {
    guard let data = Data(base64Encoded: self, options: Data.Base64DecodingOptions(rawValue: 0)) else {
        return nil
    }

    return String(data: data as Data, encoding: String.Encoding.utf8)
}

func toBase64() -> String? {
    guard let data = self.data(using: String.Encoding.utf8) else {
        return nil
    }

    return data.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
    }
}

class AssetFolder       : Codable
{
    var assets          : [Asset] = []
    var core            : Core!
    var current         : Asset? = nil
        
    private enum CodingKeys: String, CodingKey {
        case assets
        case groups
    }
    
    init()
    {
        /*
        CKContainer.default().requestApplicationPermission(.userDiscoverability) { (status, error) in
                    CKContainer.default().fetchUserRecordID { (record, error) in
                        CKContainer.default().discoverUserIdentity(withUserRecordID: record!, completionHandler: { (userID, error) in
                            print(userID?.hasiCloudAccount)
                            print(userID?.lookupInfo?.phoneNumber)
                            print(userID?.lookupInfo?.emailAddress)
                            print((userID?.nameComponents?.givenName)! + " " + (userID?.nameComponents?.familyName)!)
                        })
                    }
                }
        */
    }
    
    func setup(_ core: Core)
    {
        self.core = core
        
        guard let commonPath = Bundle.main.path(forResource: "main", ofType: "", inDirectory: "Files/default") else {
            return
        }
        
        if let value = try? String(contentsOfFile: commonPath, encoding: String.Encoding.utf8) {
            assets.append(Asset(type: .Source, name: "main", value: value))
        }
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assets = try container.decode([Asset].self, forKey: .assets)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(assets, forKey: .assets)
    }
    
    func addImages(_ name: String, _ urls: [URL], existingAsset: Asset? = nil)
    {
        let asset: Asset
            
        if existingAsset != nil {
            asset = existingAsset!
        } else {
            asset = Asset(type: .Image, name: name)
            assets.append(asset)
        }

        for url in urls {
            if let imageData: Data = try? Data(contentsOf: url) {
                asset.data.append(imageData)
            }
        }
        
        core.scriptEditor?.createSession(asset)
        select(asset.id)
    }
    
    func attachImage(_ asset: Asset, _ url: URL)
    {
        asset.data = []
        if let imageData: Data = try? Data(contentsOf: url) {
            asset.data.append(imageData)
        }
        
        select(asset.id)
    }
    
    func addAudio(_ name: String, _ urls: [URL], existingAsset: Asset? = nil)
    {
        let asset: Asset
            
        if existingAsset != nil {
            asset = existingAsset!
        } else {
            asset = Asset(type: .Audio, name: name)
            assets.append(asset)
        }

        for url in urls {
            if let audioData: Data = try? Data(contentsOf: url) {
                asset.data.append(audioData)
            }
        }
        
        core.scriptEditor?.createSession(asset)
        select(asset.id)
    }
    
    func select(_ id: UUID)
    {
        if let current = current {
            if current.type == .Source {
                if core.graphBuilder.cursorTimer != nil {
                    core.graphBuilder.stopTimer()
                }
                current.graph = nil
            }
        }

        for asset in assets {
            if asset.id == id {
                if asset.scriptName.isEmpty {
                    core.scriptEditor?.createSession(asset)
                }
                core.scriptEditor?.setAssetSession(asset)
                
                if core.state == .Idle {
                    assetCompile(asset)
                    if asset.type == .Source {
                        if core.graphBuilder.cursorTimer == nil {
                            core.graphBuilder.startTimer(asset)
                        }
                    }
                }
                
                current = asset
                break
            }
        }
    }
    
    /// Returns the graph of the "Main" function
    func getGraph() -> GraphContext?
    {
        if let asset = getAsset("main", .Source) {
            return asset.graph
        }
        return nil
    }
    
    func getAsset(_ name: String,_ type: Asset.AssetType = .Source) -> Asset?
    {
        for asset in assets {
            if asset.type == type && asset.name == name {
                return asset
            }
        }
        return nil
    }
    
    func getAssetById(_ id: UUID,_ type: Asset.AssetType = .Source) -> Asset?
    {
        for asset in assets {
            if asset.type == type && asset.id == id {
                return asset
            }
        }
        return nil
    }
    
    func getAssetById(_ id: UUID) -> Asset?
    {
        for asset in assets {
            if asset.id == id {
                return asset
            }
        }
        return nil
    }
    
    func getAssetTexture(_ name: String,_ index: Int = 0) -> MTLTexture?
    {
        if let asset = getAsset(name, .Image) {
            if index >= 0 && index < asset.data.count {
                let data = asset.data[index]
                
                let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps : false, .SRGB : false]                
                return try? core.textureLoader.newTexture(data: data, options: options)
            }
        }
        return nil
    }
    
    func assetUpdated(id: UUID, value: String)//, deltaStart: Int32, deltaEnd: Int32)
    {
        for asset in assets {
            if asset.id == id {
                asset.value = value
                assetCompile(asset)
            }
        }
    }
    
    /// Compiles the Buffer or Shader asset
    func assetCompile(_ asset: Asset)
    {
        if asset.type == .Source {
            core.graphBuilder.compile(asset)
        }
    }
    
    /// Compiles all assets, used after loading the project
    func assetCompileAll()
    {
        for asset in assets {
            assetCompile(asset)
        }
    }
    
    /// Safely removes an asset from the project
    func removeAsset(_ asset: Asset)
    {
        if asset.type == .Source {
            core.graphBuilder.stopTimer()
        } else
        if let index = assets.firstIndex(of: asset) {
            assets.remove(at: index)
            select(assets[0].id)
        }
    }
}

class Asset         : Codable, Equatable
{
    enum AssetType  : Int, Codable {
        case Source, Image, Audio
    }
    
    var type        : AssetType = .Source
    var id          = UUID()
    
    var name        = ""
    var value       = ""
    
    var data        : [Data] = []
    var dataIndex   : Int = 0
    var dataScale   : Double = 1
    
    var size        : SIMD2<Int>? = nil

    // For the script based assets
    var scriptName  = ""
    
    // Compiled Graph
    var graph       : GraphContext? = nil

    // If the asset has an error
    var hasError    : Bool = false

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
        case value
        case uuid
        case data
    }
    
    init(type: AssetType, name: String, value: String = "", data: [Data] = [])
    {
        self.type = type
        self.name = name
        self.value = value
        self.data = data
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(AssetType.self, forKey: .type)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(String.self, forKey: .value)
        if let base64 = value.fromBase64() {
            value = base64
        }
        data = try container.decode([Data].self, forKey: .data)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(value.toBase64(), forKey: .value)
        try container.encode(data, forKey: .data)
    }
    
    static func ==(lhs:Asset, rhs:Asset) -> Bool { // Implement Equatable
        return lhs.id == rhs.id
    }
}
