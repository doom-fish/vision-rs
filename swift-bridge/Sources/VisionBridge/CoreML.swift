import CoreGraphics
import CoreML
import CoreVideo
import Foundation
import ImageIO
import Vision

// MARK: - CoreML request (v0.12)

@frozen
public struct VNCoreMLFeatureValueRaw {
    public var feature_name: UnsafeMutablePointer<CChar>?
    public var type_name: UnsafeMutablePointer<CChar>?
    public var kind: Int32
    public var int64_value: Int64
    public var double_value: Double
    public var string_value: UnsafeMutablePointer<CChar>?
    public var multi_array_shape: UnsafeMutablePointer<Int>?
    public var multi_array_shape_count: Int
    public var multi_array_values: UnsafeMutablePointer<Double>?
    public var multi_array_value_count: Int
}

private let coreMLCompileLock = NSLock()

final class VisionCoreMLModelBox {
    var model: VNCoreMLModel?
    private let ownedDirectory: URL?

    init(ownedDirectory: URL?) {
        self.ownedDirectory = ownedDirectory
    }

    deinit {
        model = nil
        if let ownedDirectory {
            try? FileManager.default.removeItem(at: ownedDirectory)
        }
    }
}

private func compileCoreMLModel(at modelURL: URL) throws -> (model: URL, directory: URL) {
    coreMLCompileLock.lock()
    defer { coreMLCompileLock.unlock() }
    let compiled = try MLModel.compileModel(at: modelURL)
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("apple-vision-coreml-\(UUID().uuidString)", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(compiled.lastPathComponent, isDirectory: true)
        try FileManager.default.moveItem(at: compiled, to: destination)
        return (destination, directory)
    } catch {
        try? FileManager.default.removeItem(at: compiled)
        try? FileManager.default.removeItem(at: directory)
        throw error
    }
}

@_cdecl("vn_coreml_model_load")
public func vn_coreml_model_load(
    _ modelPath: UnsafePointer<CChar>,
    _ inputImageFeatureName: UnsafePointer<CChar>?,
    _ outHandle: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    outHandle.pointee = nil
    let modelURL = URL(fileURLWithPath: String(cString: modelPath))
    let featureName = inputImageFeatureName.map { String(cString: $0) }
    do {
        let box: VisionCoreMLModelBox
        let compiledURL: URL
        if modelURL.pathExtension == "mlmodelc" {
            box = VisionCoreMLModelBox(ownedDirectory: nil)
            compiledURL = modelURL
        } else {
            let compiled = try compileCoreMLModel(at: modelURL)
            box = VisionCoreMLModelBox(ownedDirectory: compiled.directory)
            compiledURL = compiled.model
        }
        let vnModel = try VNCoreMLModel(for: MLModel(contentsOf: compiledURL))
        if let featureName, #available(macOS 10.15, *) {
            vnModel.inputImageFeatureName = featureName
        }
        box.model = vnModel
        outHandle.pointee = Unmanaged.passRetained(box).toOpaque()
        return VN_OK
    } catch {
        outErrorMessage?.pointee = ffiString("CoreML model load failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
}

@_cdecl("vn_coreml_model_release")
public func vn_coreml_model_release(_ handle: UnsafeMutableRawPointer?) {
    guard let handle else { return }
    Unmanaged<VisionCoreMLModelBox>.fromOpaque(handle).release()
}

internal func applyCoreMLRequestConfig(
    _ request: VNCoreMLRequest,
    imageCropAndScaleOption: Int32,
    roiX: Double,
    roiY: Double,
    roiW: Double,
    roiH: Double,
    hasRegionOfInterest: Bool,
    preferBackgroundProcessing: Bool,
    usesCPUOnly: Bool,
    revision: Int,
    hasRevision: Bool
) {
    if let option = VNImageCropAndScaleOption(rawValue: UInt(imageCropAndScaleOption)) {
        request.imageCropAndScaleOption = option
    }
    applyImageBasedRequestConfig(
        request,
        roiX: roiX,
        roiY: roiY,
        roiW: roiW,
        roiH: roiH,
        hasRegionOfInterest: hasRegionOfInterest,
        preferBackgroundProcessing: preferBackgroundProcessing,
        usesCPUOnly: usesCPUOnly,
        revision: revision,
        hasRevision: hasRevision
    )
}

internal func copyMultiArrayValues(_ multiArray: MLMultiArray) -> [Double] {
    let count = multiArray.count
    if #available(macOS 26.0, *), multiArray.dataType == .int8 {  // .int8 added macOS 26.0
        let ptr = multiArray.dataPointer.bindMemory(to: Int8.self, capacity: count)
        return (0..<count).map { Double(ptr[$0]) }
    }
    switch multiArray.dataType {
    case .double:
        let ptr = multiArray.dataPointer.bindMemory(to: Double.self, capacity: count)
        return Array(UnsafeBufferPointer(start: ptr, count: count))
    case .float32:
        let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        return (0..<count).map { Double(ptr[$0]) }
    case .int32:
        let ptr = multiArray.dataPointer.bindMemory(to: Int32.self, capacity: count)
        return (0..<count).map { Double(ptr[$0]) }
    case .float16:
        let ptr = multiArray.dataPointer.bindMemory(to: UInt16.self, capacity: count)
        return (0..<count).map { Double(Float16(bitPattern: ptr[$0])) }
    @unknown default:
        return []
    }
}

@_cdecl("vn_coreml_request_classify_in_path")
public func vn_coreml_request_classify_in_path(
    _ path: UnsafePointer<CChar>,
    _ modelHandle: UnsafeMutableRawPointer,
    _ imageCropAndScaleOption: Int32,
    _ roiX: Double,
    _ roiY: Double,
    _ roiW: Double,
    _ roiH: Double,
    _ hasRegionOfInterest: Bool,
    _ preferBackgroundProcessing: Bool,
    _ usesCPUOnly: Bool,
    _ revision: Int,
    _ hasRevision: Bool,
    _ outArray: UnsafeMutablePointer<UnsafeMutableRawPointer?>,
    _ outCount: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let pathStr = String(cString: path)
    let modelBox = Unmanaged<VisionCoreMLModelBox>.fromOpaque(modelHandle).takeUnretainedValue()
    outArray.pointee = nil
    outCount.pointee = 0
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        return VN_IMAGE_LOAD_FAILED
    }
    guard let vnModel = modelBox.model else {
        outErrorMessage?.pointee = ffiString("CoreML model is not loaded")
        return VN_INVALID_ARGUMENT
    }
    let request = VNCoreMLRequest(model: vnModel)
    applyCoreMLRequestConfig(
        request,
        imageCropAndScaleOption: imageCropAndScaleOption,
        roiX: roiX,
        roiY: roiY,
        roiW: roiW,
        roiH: roiH,
        hasRegionOfInterest: hasRegionOfInterest,
        preferBackgroundProcessing: preferBackgroundProcessing,
        usesCPUOnly: usesCPUOnly,
        revision: revision,
        hasRevision: hasRevision
    )
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: imageOrientation(path: pathStr), options: [:])
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("CoreML perform: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let results = request.results as? [VNClassificationObservation], !results.isEmpty else {
        return VN_OK
    }
    let count = results.count
    let buf = UnsafeMutablePointer<VNClassificationRaw>.allocate(capacity: count)
    for (i, obs) in results.enumerated() {
        buf.advanced(by: i).initialize(to: VNClassificationRaw(
            identifier: ffiString(obs.identifier),
            confidence: obs.confidence))
    }
    outArray.pointee = UnsafeMutableRawPointer(buf)
    outCount.pointee = count
    return VN_OK
}

@_cdecl("vn_coreml_feature_value_in_path")
public func vn_coreml_feature_value_in_path(
    _ path: UnsafePointer<CChar>,
    _ modelHandle: UnsafeMutableRawPointer,
    _ imageCropAndScaleOption: Int32,
    _ roiX: Double,
    _ roiY: Double,
    _ roiW: Double,
    _ roiH: Double,
    _ hasRegionOfInterest: Bool,
    _ preferBackgroundProcessing: Bool,
    _ usesCPUOnly: Bool,
    _ revision: Int,
    _ hasRevision: Bool,
    _ outFeatureRaw: UnsafeMutableRawPointer,
    _ outHasValue: UnsafeMutablePointer<Bool>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let outFeature = outFeatureRaw.assumingMemoryBound(to: VNCoreMLFeatureValueRaw.self)
    let pathStr = String(cString: path)
    let modelBox = Unmanaged<VisionCoreMLModelBox>.fromOpaque(modelHandle).takeUnretainedValue()
    outHasValue.pointee = false
    outFeature.pointee = VNCoreMLFeatureValueRaw(
        feature_name: nil,
        type_name: nil,
        kind: 0,
        int64_value: 0,
        double_value: 0,
        string_value: nil,
        multi_array_shape: nil,
        multi_array_shape_count: 0,
        multi_array_values: nil,
        multi_array_value_count: 0
    )
    guard let cgImage = loadCGImage(path: pathStr) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(pathStr)")
        return VN_IMAGE_LOAD_FAILED
    }
    guard let vnModel = modelBox.model else {
        outErrorMessage?.pointee = ffiString("CoreML model is not loaded")
        return VN_INVALID_ARGUMENT
    }
    let request = VNCoreMLRequest(model: vnModel)
    applyCoreMLRequestConfig(
        request,
        imageCropAndScaleOption: imageCropAndScaleOption,
        roiX: roiX,
        roiY: roiY,
        roiW: roiW,
        roiH: roiH,
        hasRegionOfInterest: hasRegionOfInterest,
        preferBackgroundProcessing: preferBackgroundProcessing,
        usesCPUOnly: usesCPUOnly,
        revision: revision,
        hasRevision: hasRevision
    )
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: imageOrientation(path: pathStr), options: [:])
    do { try handler.perform([request]) } catch {
        outErrorMessage?.pointee = ffiString("CoreML perform: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let observation = request.results?.first as? VNCoreMLFeatureValueObservation else {
        return VN_OK
    }
    let featureValue = observation.featureValue
    if #available(macOS 10.15, *) {
        outFeature.pointee.feature_name = ffiString(observation.featureName)
    }
    switch featureValue.type {
    case .int64:
        outFeature.pointee.kind = 1
        outFeature.pointee.type_name = ffiString("int64")
        outFeature.pointee.int64_value = featureValue.int64Value
    case .double:
        outFeature.pointee.kind = 2
        outFeature.pointee.type_name = ffiString("double")
        outFeature.pointee.double_value = featureValue.doubleValue
    case .string:
        outFeature.pointee.kind = 3
        outFeature.pointee.type_name = ffiString("string")
        outFeature.pointee.string_value = ffiString(featureValue.stringValue)
    case .multiArray:
        outFeature.pointee.kind = 4
        outFeature.pointee.type_name = ffiString("multiArray")
        if let multiArray = featureValue.multiArrayValue {
            var shape = multiArray.shape.map { $0.intValue }
            if !shape.isEmpty {
                let shapeBuffer = UnsafeMutablePointer<Int>.allocate(capacity: shape.count)
                shapeBuffer.initialize(from: &shape, count: shape.count)
                outFeature.pointee.multi_array_shape = shapeBuffer
                outFeature.pointee.multi_array_shape_count = shape.count
            }
            var values = copyMultiArrayValues(multiArray)
            if !values.isEmpty {
                let valueBuffer = UnsafeMutablePointer<Double>.allocate(capacity: values.count)
                valueBuffer.initialize(from: &values, count: values.count)
                outFeature.pointee.multi_array_values = valueBuffer
                outFeature.pointee.multi_array_value_count = values.count
            }
        }
    case .invalid, .image, .dictionary, .sequence, .state:
        outFeature.pointee.kind = 0
        outFeature.pointee.type_name = ffiString("unsupported")
    @unknown default:
        outFeature.pointee.kind = 0
        outFeature.pointee.type_name = ffiString("unknown")
    }
    outHasValue.pointee = true
    return VN_OK
}

@_cdecl("vn_coreml_feature_value_free")
public func vn_coreml_feature_value_free(_ featureRaw: UnsafeMutableRawPointer) {
    let feature = featureRaw.assumingMemoryBound(to: VNCoreMLFeatureValueRaw.self)
    if let featureName = feature.pointee.feature_name {
        free(featureName)
        feature.pointee.feature_name = nil
    }
    if let typeName = feature.pointee.type_name {
        free(typeName)
        feature.pointee.type_name = nil
    }
    if let stringValue = feature.pointee.string_value {
        free(stringValue)
        feature.pointee.string_value = nil
    }
    feature.pointee.multi_array_shape?.deallocate()
    feature.pointee.multi_array_shape = nil
    feature.pointee.multi_array_shape_count = 0
    feature.pointee.multi_array_values?.deallocate()
    feature.pointee.multi_array_values = nil
    feature.pointee.multi_array_value_count = 0
}
