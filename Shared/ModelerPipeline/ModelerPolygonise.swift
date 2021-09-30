//
//  ModelerPolygonise.swift
//  Signed
//
//  Created by Markus Moenig on 26/9/2564 BE.
//

import MetalKit
import Accelerate
import ModelIO

class ModelerPolygonRegion {
    let region          : MTLRegion
    let position        : float3
    
    init(region: MTLRegion, position: float3) {
        self.region = region
        self.position = position
    }
}

/// Based on http://paulbourke.net/geometry/polygonise/
class ModelerPolygonise {
    
    public typealias _Float16 = UInt16

    struct GRIDCELL {
        var p               : [float3] = [float3(), float3(), float3(), float3(), float3(), float3(), float3(), float3()]
        var val             : [Float] = [0, 0, 0, 0, 0, 0, 0, 0]
    }
    
    let model           : Model
    let kit             : ModelerKit
        
    var chunkSize       : Int = 0
    
    var pixelByteCount  : Int = 0
    var bytesPerRow     : Int = 0
    var bytesPerChunk   : Int = 0
    
    var startTime       : Double = 0
    var totalTime       : Double = 0
    var coresActive     : Int = 0
    
    var regionJobs      : [ModelerPolygonRegion] = []
    
    var semaphore       : DispatchSemaphore!
    var dispatchGroup   : DispatchGroup!
    
    var totalJobs       : Int = 0
    
    var jobsHandedOut   : Int = 0
    
    var objVertices     = ""
    var objFaces        = ""
    var objFaceCount    : Int = 1

    init(model: Model, kit: ModelerKit) {
        self.model = model
        self.kit = kit
        
        semaphore = DispatchSemaphore(value: 1)
        dispatchGroup = DispatchGroup()
    }
    
    /// Returns the next job
    func getNextJob() -> ModelerPolygonRegion?
    {
        semaphore.wait()
        var regionJob : ModelerPolygonRegion? = nil
        if regionJobs.isEmpty == false {
            regionJob = regionJobs.removeFirst()
            
            jobsHandedOut += 1
            print("Jobs handed out", jobsHandedOut)
        }
        semaphore.signal()
        return regionJob
    }
        
    /// Multithreaded polygonization
    func processTexture() {
        
        chunkSize = 50
        
        pixelByteCount = MemoryLayout<_Float16>.size
        bytesPerRow = chunkSize * pixelByteCount
        bytesPerChunk = bytesPerRow * chunkSize
                
        if let texture = kit.modelTexture {
        
            let chunks = texture.width / chunkSize

            //var texArray = Array<UInt16>(repeating: 0, count: chunkSize * chunkSize * chunkSize)

            for z in 0..<chunks {
                for y in 0..<chunks {
                    for x in 0..<chunks {                        
                        let region = MTLRegionMake3D(x * chunkSize, y * chunkSize, z * chunkSize, chunkSize, chunkSize, chunkSize)
                        regionJobs.append(ModelerPolygonRegion(region: region, position: float3(Float(x), Float(y), Float(z))))
                    }
                }
            }
        }
                
        if regionJobs.isEmpty == false {
            
            let cores = ProcessInfo().activeProcessorCount

            startTime = Double(Date().timeIntervalSince1970)
            totalTime = 0
            coresActive = 0
            
            totalJobs = regionJobs.count
            
            func startThread() {
                coresActive += 1
                dispatchGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    self.processRegionJobs()
                }
            }

            for i in 0..<cores {
                if i < regionJobs.count {
                    startThread()
                }
            }
            print("Cores", cores, "Jobs", regionJobs.count, "Cores started:", coresActive)
        }
    }
    
    /// Thread interface
    func processRegionJobs()
    {
        var texArray = Array<UInt16>(repeating: 0, count: chunkSize * chunkSize * chunkSize)
        let chunkPolygoniser = ModelerPolygoniseChunk(chunkSize: chunkSize)
        
        while let job = getNextJob() {

            semaphore.wait()
            
            texArray.withUnsafeMutableBytes { texArrayPtr in
            
                if let texture = kit.modelTexture {

                    texture.getBytes(texArrayPtr.baseAddress!,
                                     bytesPerRow: bytesPerRow,
                                     bytesPerImage: bytesPerChunk,
                                     from: job.region,
                                     mipmapLevel: 0,
                                     slice: 0)
                }
            }
            
            semaphore.signal()

            // Polygonise
            let f = float16to32(&texArray, count: 50 * 50 * 50)
            chunkPolygoniser.processChunk(array: f, position: job.position)
            
            // Write the data to the obj buffers
            if chunkPolygoniser.triangles.isEmpty == false {
                
                // Create the string for the vertices in this thread
                
                func writeVertex(_ v: float3) -> String {
                    return String(format: "%.04f", v.x) + "    " +  String(format: "%.04f", v.y) + "    " +  String(format: "%.04f", -v.z) + "\n"
                }
                
                var obj = ""
                let triangles = chunkPolygoniser.triangles
                
                for o in 0..<(triangles.count / 3) {
                    
                    let index = o * 3
                    
                    let v1 = triangles[index]
                    let v2 = triangles[index+1]
                    let v3 = triangles[index+2]
                    
                    obj += "v " + writeVertex(v1)
                    obj += "v " + writeVertex(v2)
                    obj += "v " + writeVertex(v3)
                }
                
                self.objTriangleFeed(triangles.count, obj)
                chunkPolygoniser.triangles = []
            }
        }
        
        semaphore.wait()
        coresActive -= 1
        semaphore.signal()

        if coresActive == 0  {
            
            let myTime = Double(Date().timeIntervalSince1970) - startTime
            totalTime += myTime
                        
            self.model.objData = Data((objVertices + objFaces).utf8)
            
            print("Total polygonisation time", totalTime)

            DispatchQueue.main.async {
                self.model.polygonisationEnded.send()
            }
        }
    }
    
    /// Create the faces list for the triangles passed from the thread
    func objTriangleFeed(_ trianglesCount: Int,_ trianglesString: String)
    {
        semaphore.wait()
        
        self.objVertices += trianglesString
        
        var obj = ""

        var index : Int = self.objFaceCount
        for _ in 0..<(trianglesCount / 3) {
            obj += "f " + String(index) + "    " + String((index+1)) + "    "  + String(index+2) + "\n"
            index += 3
        }
        self.objFaceCount = index
        self.objFaces += obj

        semaphore.signal()
    }
    
    /*
    /// Convert the triangles to an MDLAsset
    func toMesh(device: MTLDevice) -> MDLAsset?
    {
        let allocator = MTKMeshBufferAllocator.init(device: device)
        let vertexBuffer = allocator.newBuffer(MemoryLayout<float3>.stride * triangles.count, type: .vertex)

        let vertexMap = vertexBuffer.map()
        vertexMap.bytes.assumingMemoryBound(to: float3.self).assign(from: triangles, count: triangles.count)

        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<float3>.stride)


        let mdlMesh = MDLMesh(vertexBuffer: vertexBuffer,
                              vertexCount: triangles.count,
                              descriptor: vertexDescriptor,
                              submeshes: [])
        
        let asset = MDLAsset()
        asset.add(mdlMesh)
        return asset
    }*/
    
    // https://developer.apple.com/forums/thread/93282
    
    func float16to32(_ input: UnsafeMutablePointer<_Float16>, count: Int) -> [Float] {
        var output = [Float](repeating: 0, count: count)
        float16to32(input: input, output: &output, count: count)
        return output
    }
    
    func float16to32(input: UnsafeMutablePointer<_Float16>, output: UnsafeMutableRawPointer, count: Int) {
        var bufferFloat16 = vImage_Buffer(data: input, height: 1, width: UInt(count), rowBytes: count * 2)
        var bufferFloat32 = vImage_Buffer(data: output, height: 1, width: UInt(count), rowBytes: count * 4)

        if vImageConvert_Planar16FtoPlanarF(&bufferFloat16, &bufferFloat32, 0) != kvImageNoError {
            print("Error converting float16 to float32")
        }
    }
    

}
