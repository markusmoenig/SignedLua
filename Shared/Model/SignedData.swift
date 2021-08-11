//
//  SignedData.swift
//  Signed
//
//  Created by Markus Moenig on 30/6/21.
//

import Foundation

/// A singlee data entity of a given type and optionally at a given time, for convenience and speed use float4 to store
class SignedDataEntity: Codable, Hashable {
    
    enum DataType: String, Codable {
        case Int, Float, Float2, Float3, Float4, Text
    }
    
    enum UsageType: String, Codable {
        case Numeric, Slider, Color, Menu, TextField
    }
    
    enum Feature: String, Codable {
        case None, Texture, ProceduralMixer, MaterialLibrary, GeometryLibrary
    }
    
    var id          = UUID()

    var key         : String
    
    var type        : DataType
    var usage       : UsageType
    var feature     : Feature

    var value       : float4
    var defaultValue: float4
    var time        : Double?
    var range       : float2
    
    var text        : String = ""
    
    var subData     : SignedData? = nil
        
    private enum CodingKeys: String, CodingKey {
        case key
        case type
        case usage
        case feature
        case value
        case range
        case time
        case defaultValue
        case text
        case subData
    }
    
    init(_ key: String,_ v: String,_ u: UsageType = .TextField,_ f: Feature = .None,_ t: Double? = nil) {
        self.key = key
        type = .Text
        usage = u
        feature = f
        text = v
        range = float2(0,0)
        time = t
                
        value = float4()
        defaultValue = float4()
    }
    
    init(_ key: String,_ v: Int,_ r: float2 = float2(0,1),_ u: UsageType = .Slider,_ f: Feature = .None,_ te: String = "",_ t: Double? = nil) {
        self.key = key
        type = .Int
        usage = u
        feature = f
        value = float4(Float(v), 0, 0, 0)
        range = r
        time = t
        text = te
        
        defaultValue = value
    }
    
    init(_ key: String,_ v: Float,_ r: float2 = float2(0,1),_ u: UsageType = .Slider,_ f: Feature = .None,_ t: Double? = nil) {
        self.key = key
        type = .Float
        usage = u
        feature = f
        value = float4(v, 0, 0, 0)
        range = r
        time = t
        
        defaultValue = value
    }
    
    init(_ key: String,_ v: float2,_ r: float2 = float2(0,1),_ u: UsageType = .Numeric,_ f: Feature = .None,_ t: Double? = nil) {
        self.key = key
        type = .Float2
        usage = u
        feature = f
        value = float4(v.x, v.y, 0, 0)
        range = r
        time = t
        
        defaultValue = value
    }
    
    init(_ key: String,_ v: float3,_ r: float2 = float2(0,1),_ u: UsageType = .Numeric,_ f: Feature = .None,_ t: Double? = nil) {
        self.key = key
        type = .Float3
        usage = u
        feature = f
        value = float4(v.x, v.y, v.z, 0)
        range = r
        time = t
        
        defaultValue = value
    }
    
    init(_ key: String,_ v: float4,_ r: float2 = float2(0,1),_ u: UsageType = .Numeric,_ f: Feature = .None,_ t: Double? = nil) {
        self.key = key
        type = .Float4
        usage = u
        feature = f
        value = v
        range = r
        time = t
        
        defaultValue = value
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        type = try container.decode(DataType.self, forKey: .type)
        usage = try container.decode(UsageType.self, forKey: .usage)
        feature = try container.decode(Feature.self, forKey: .feature)
        value = try container.decode(float4.self, forKey: .value)
        range = try container.decode(float2.self, forKey: .range)
        time = try container.decode(Double?.self, forKey: .time)
        defaultValue = try container.decode(float4.self, forKey: .defaultValue)
        text = try container.decode(String.self, forKey: .text)
        subData = try container.decode(SignedData?.self, forKey: .subData)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(type, forKey: .type)
        try container.encode(usage, forKey: .usage)
        try container.encode(feature, forKey: .feature)
        try container.encode(value, forKey: .value)
        try container.encode(range, forKey: .range)
        try container.encode(time, forKey: .time)
        try container.encode(defaultValue, forKey: .defaultValue)
        try container.encode(text, forKey: .text)
        try container.encode(subData, forKey: .subData)
    }
    
    static func ==(lhs: SignedDataEntity, rhs: SignedDataEntity) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A dictionary of SignedDataEntity's to create a data fault for values which can be keyed over time.
class SignedData: Codable, Hashable {
 
    var id          = UUID()
    var name        : String = ""
    
    var data: [SignedDataEntity]
    
    private enum CodingKeys: String, CodingKey {
        case name
        case data
    }
    
    init(_ data: [SignedDataEntity])
    {
        self.data = data
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        data = try container.decode([SignedDataEntity].self, forKey: .data)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(data, forKey: .data)
    }
    
    /// Get an Int key
    func getInt(_ key: String,_ defaultValue: Int = 0,_ time: Double? = nil) -> Int {
        for e in data {
            if e.key == key && e.type == .Int && e.time == time {
                return Int(e.value.x)
            }
        }
        // TODO: Interpolate between existing values
        return defaultValue
    }
    
    /// Get an Float key
    func getFloat(_ key: String,_ defaultValue: Float = 0,_ time: Double? = nil) -> Float {
        for e in data {
            if e.key == key && e.type == .Float && e.time == time {
                return e.value.x
            }
        }
        // TODO: Interpolate between existing values
        return defaultValue
    }
    
    /// Get an Float2 key
    func getFloat2(_ key: String,_ defaultValue: float2 = float2(0,0),_ time: Double? = nil) -> float2 {
        for e in data {
            if e.key == key && e.type == .Float2 && e.time == time {
                return float2(e.value.x, e.value.y)
            }
        }
        // TODO: Interpolate between existing values
        return defaultValue
    }
    
    /// Get an Float3 key
    func getFloat3(_ key: String,_ defaultValue: float3 = float3(0,0,0),_ time: Double? = nil) -> float3 {
        for e in data {
            if e.key == key && e.type == .Float3 && e.time == time {
                return float3(e.value.x, e.value.y, e.value.z)
            }
        }
        // TODO: Interpolate between existing values
        return defaultValue
    }
    
    /// Get an Float4 key
    func getFloat4(_ key: String,_ defaultValue: float4 = float4(0,0,0,0),_ time: Double? = nil) -> float4 {
        for e in data {
            if e.key == key && e.type == .Float4 && e.time == time {
                return e.value
            }
        }
        // TODO: Interpolate between existing values
        return defaultValue
    }
    
    /// Checks if a given key exists
    func exists(_ key : String) -> Bool {
        for e in data {
            if e.key == key {
                return true
            }
        }
        return false
    }
    
    /// Returns the text of an data entity
    func getText(_ key : String) -> String? {
        for e in data {
            if e.key == key {
                return e.text
            }
        }
        return nil
    }
    
    /// Returns the entity itself
    func getEntity(_ key : String) -> SignedDataEntity? {
        for e in data {
            if e.key == key {
                return e
            }
        }
        return nil
    }
    
    /// Set Text
    func set(_ key: String,_ value: String,_ usage: SignedDataEntity.UsageType = .TextField,_ feature: SignedDataEntity.Feature = .None,_ time: Double? = nil) {
        if let ex = getExisting(key, .Int, time) {
            ex.text = value
        } else {
            data.append(SignedDataEntity(key, value, usage, feature, time))
        }
    }
    
    /// Set Int
    func set(_ key: String,_ value: Int,_ range: float2 = float2(0,1),_ usage: SignedDataEntity.UsageType = .Slider,_ feature: SignedDataEntity.Feature = .None,_ text: String = "",_ time: Double? = nil) {
        if let ex = getExisting(key, .Int, time) {
            ex.value = float4(Float(value), 0, 0, 0)
        } else {
            data.append(SignedDataEntity(key, value, range, usage, feature, text, time))
        }
    }
    
    /// Set Float
    func set(_ key: String,_ value: Float,_ range: float2 = float2(0,1),_ usage: SignedDataEntity.UsageType = .Slider,_ feature: SignedDataEntity.Feature = .None,_ time: Double? = nil) {
        if let ex = getExisting(key, .Float, time) {
            ex.value = float4(value, 0, 0, 0)
        } else {
            data.append(SignedDataEntity(key, value, range, usage, feature, time))
        }
    }
    
    /// Set Float2
    func set(_ key: String,_ value: float2,_ range: float2 = float2(0,1),_ usage: SignedDataEntity.UsageType = .Numeric,_ feature: SignedDataEntity.Feature = .None,_ time: Double? = nil) {
        if let ex = getExisting(key, .Float2, time) {
            ex.value = float4(value.x, value.y, 0, 0)
        } else {
            data.append(SignedDataEntity(key, value, range, usage, feature, time))
        }
    }
    
    /// Set Float3
    func set(_ key: String,_ value: float3,_ range: float2 = float2(0,1),_ usage: SignedDataEntity.UsageType = .Numeric,_ feature: SignedDataEntity.Feature = .None,_ time: Double? = nil) {
        if let ex = getExisting(key, .Float3, time) {
            ex.value = float4(value.x, value.y, value.z, 0)
        } else {
            data.append(SignedDataEntity(key, value, range, usage, feature, time))
        }
    }
    
    /// Set Float4
    func set(_ key: String,_ value: float4,_ range: float2 = float2(0,1),_ usage: SignedDataEntity.UsageType = .Numeric,_ feature: SignedDataEntity.Feature = .None,_ time: Double? = nil) {
        if let ex = getExisting(key, .Float4, time) {
            ex.value = value
        } else {
            data.append(SignedDataEntity(key, value, range, usage, feature, time))
        }
    }
    
    /// Returns either an existing DataEntity for the given key, type and time or creates a new one.
    func getExisting(_ key: String,_ type: SignedDataEntity.DataType,_ time: Double?) -> SignedDataEntity? {
        for e in data {
            if e.key == key && e.type == type && e.time == time {
                return e
            }
        }
        return nil
    }
    
    static func ==(lhs: SignedData, rhs: SignedData) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    func debug() {
        print("start debug --- ", name)
        for e in data {
            print(e.key, e.value)
        }
    }
}

/// A group of data dictionaries
class SignedDataGroups: Codable {
 
    var groups: [String: SignedData]
    
    private enum CodingKeys: String, CodingKey {
        case groups
    }
    
    init(_ groups: [String: SignedData] = [:])
    {
        self.groups = groups
        for (name, d) in self.groups {
            d.name = name
        }
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groups = try container.decode([String: SignedData].self, forKey: .groups)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groups, forKey: .groups)
    }
    
    func flat() -> [SignedData] {
        var rc : [SignedData] = []
        for (_, v) in groups {
            rc.append(v)
        }
        return rc
    }
    
    /// Returns the group of the given name
    func getGroup(_ name: String) -> SignedData? {
        return groups[name]
    }
    
    /// Adds a named data class to the groups
    func addGroup(_ name: String,_ data: SignedData) {
        data.name = name
        groups[name] = data
    }
    
    /// Returns the name of the given data group
    func getName(of: SignedData) -> String {
        
        for (name, d) in groups {
            if d === of {
                return name
            }
        }
        
        return ""
    }
    
    func debug() {
        for (_, d) in groups {
            d.debug()
        }
    }
}
