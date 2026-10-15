// aispeed-darwin-v1: AI Speed probe for Apple silicon.
// One JSON line: FP16 matmul TFLOPS (MPSMatrixMultiplication) and blit-copy
// memory bandwidth, with raw timings and a Freivalds correctness check.
// Exit 0 with a line; exit 2 (no line) when there is no Metal device.
import Foundation
import Metal
import MetalPerformanceShaders

var pci = "0000:00:00.0"
var args = CommandLine.arguments.dropFirst()
while let a = args.popFirst() {
    if a == "--pci", let v = args.popFirst() { pci = v }
}

guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    FileHandle.standardError.write("aispeed: no Metal device\n".data(using: .utf8)!)
    exit(2)
}

let n = 4096
let rowBytes = n * MemoryLayout<Float16>.stride
let matBytes = n * rowBytes

// Deterministic pseudo-random values in [-1, 1) (xorshift32).
var rng: UInt32 = 0x9E3779B9
func next() -> Float {
    rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5
    return Float(rng) / Float(UInt32.max) * 2 - 1
}
func matrix(fill: Bool) -> (MTLBuffer, MPSMatrix) {
    let buf = device.makeBuffer(length: matBytes, options: .storageModeShared)!
    if fill {
        let p = buf.contents().bindMemory(to: Float16.self, capacity: n * n)
        for i in 0..<(n * n) { p[i] = Float16(next()) }
    }
    let desc = MPSMatrixDescriptor(rows: n, columns: n, rowBytes: rowBytes, dataType: .float16)
    return (buf, MPSMatrix(buffer: buf, descriptor: desc))
}
let (bufA, matA) = matrix(fill: true)
let (bufB, matB) = matrix(fill: true)
let (bufC, matC) = matrix(fill: false)
let mm = MPSMatrixMultiplication(device: device, transposeLeft: false, transposeRight: false,
                                 resultRows: n, resultColumns: n, interiorColumns: n,
                                 alpha: 1, beta: 0)

func timed(_ encode: (MTLCommandBuffer) -> Void) -> Double {
    let cb = queue.makeCommandBuffer()!
    encode(cb)
    let t0 = DispatchTime.now().uptimeNanoseconds
    cb.commit()
    cb.waitUntilCompleted()
    return Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e9
}
func matmul(_ cb: MTLCommandBuffer) {
    mm.encode(commandBuffer: cb, leftMatrix: matA, rightMatrix: matB, resultMatrix: matC)
}
func median(_ xs: [Double]) -> Double {
    let s = xs.sorted(); let m = s.count / 2
    return s.count % 2 == 1 ? s[m] : (s[m - 1] + s[m]) / 2
}

// Correctness first: Freivalds, C·x vs A·(B·x), in Float32 on the CPU.
_ = timed(matmul)
func matvec(_ buf: MTLBuffer, _ x: [Float]) -> [Float] {
    let p = buf.contents().bindMemory(to: Float16.self, capacity: n * n)
    var y = [Float](repeating: 0, count: n)
    for i in 0..<n {
        var s: Float = 0
        let row = p + i * n
        for j in 0..<n { s += Float(row[j]) * x[j] }
        y[i] = s
    }
    return y
}
let x = (0..<n).map { _ in next() }
let cx = matvec(bufC, x)
let abx = matvec(bufA, matvec(bufB, x))
var num: Float = 0, den: Float = 0
for i in 0..<n { num += (cx[i] - abx[i]) * (cx[i] - abx[i]); den += abx[i] * abx[i] }
let rel = den > 0 ? (num / den).squareRoot() : Float.infinity
let check = rel.isFinite && rel < 1e-2 ? "pass" : "fail"

var matmulS: [Double] = []
var copyS: [Double] = []
var copyBytes = 1 << 30
if check == "pass" {
    for _ in 0..<20 { _ = timed(matmul) }
    for _ in 0..<100 { matmulS.append(timed(matmul)) }
    if device.recommendedMaxWorkingSetSize < (4 << 30) { copyBytes = 512 << 20 }
    let src = device.makeBuffer(length: copyBytes, options: .storageModePrivate)!
    let dst = device.makeBuffer(length: copyBytes, options: .storageModePrivate)!
    func copy(_ cb: MTLCommandBuffer) {
        let blit = cb.makeBlitCommandEncoder()!
        blit.copy(from: src, sourceOffset: 0, to: dst, destinationOffset: 0, size: copyBytes)
        blit.endEncoding()
    }
    for _ in 0..<3 { _ = timed(copy) }
    for _ in 0..<10 { copyS.append(timed(copy)) }
}

let ok = check == "pass" && !matmulS.isEmpty && !copyS.isEmpty
let flops = 2 * pow(Double(n), 3)
// Hand-formatted numbers: JSONSerialization would print binary-float noise
// (0.011017000000000001); timings keep 6 decimals, figures 2.
func f(_ x: Double, _ d: Int) -> String { String(format: "%.\(d)f", x) }
func arr(_ xs: [Double]) -> String { "[" + xs.map { f($0, 6) }.joined(separator: ",") + "]" }
let pciJSON = String(data: try! JSONSerialization.data(withJSONObject: [pci]), encoding: .utf8)!.dropFirst().dropLast()
let tflops = ok ? f(flops / median(matmulS) / 1e12, 2) : "null"
let gbps = ok ? f(2 * Double(copyBytes) / median(copyS) / 1e9, 2) : "null"
print("{\"pci_address\":\(pciJSON),\"tflops_bf16\":\(tflops),\"mem_bw_gbps\":\(gbps),"
    + "\"evidence\":{\"matmul_n\":\(n),\"matmul_s\":\(arr(matmulS)),\"copy_bytes\":\(copyBytes),"
    + "\"copy_s\":\(arr(copyS)),\"check\":\"\(check)\"}}")
_ = (bufA, bufB)   // keep the shared buffers alive through the check
exit(0)
