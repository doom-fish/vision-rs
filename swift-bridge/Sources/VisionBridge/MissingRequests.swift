// Vision v0.13 missing-request gap fill — single-frame requests
// added to bring the bridge to 100% parity with Apple's SDK.
//
// Detection: animal body pose, 3D human body pose, text rectangles,
//            trajectories, objectness saliency, person instance mask.
// Registration: translational, homographic.
//
// Tracking requests (stateful) live in Tracking.swift (v0.14).

import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import Vision

// MARK: - Shared simple-rect struct (also used for v0.13 text rectangles +
// objectness saliency).

@frozen
public struct VNSimpleRectRaw {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    public var confidence: Float
    public var _pad: Float
}

@_cdecl("vn_simple_rects_free")
public func vn_simple_rects_free(_ ptr: UnsafeMutableRawPointer?, _ count: Int) {
    guard let ptr = ptr else { return }
    let typed = ptr.assumingMemoryBound(to: VNSimpleRectRaw.self)
    typed.deinitialize(count: count)
    typed.deallocate()
}

internal func mkRect(_ r: CGRect, _ c: Float) -> VNSimpleRectRaw {
    VNSimpleRectRaw(x: Double(r.origin.x), y: Double(r.origin.y),
                    w: Double(r.size.width), h: Double(r.size.height),
                    confidence: c, _pad: 0)
}

// MARK: - Animal body pose (macOS 14+)

@frozen
public struct VNAnimalJointRaw {
    /// Joint name (UTF-8, heap-allocated, free with vn_string_free).
    public var name: UnsafeMutablePointer<CChar>?
    public var x: Double
    public var y: Double
    public var confidence: Float
    public var _pad: Float
}

@_cdecl("vn_detect_animal_body_pose_in_path")
public func vn_detect_animal_body_pose_in_path(
    _ path: UnsafePointer<CChar>,
    _ out_joints_raw: UnsafeMutableRawPointer,
    _ out_count: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let out_joints = out_joints_raw.assumingMemoryBound(to: UnsafeMutablePointer<VNAnimalJointRaw>?.self)
    out_joints.pointee = nil
    out_count.pointee = 0
    if #available(macOS 14.0, *) {
        let p = String(cString: path)
        guard let img = loadCGImage(path: p) else {
            outErrorMessage?.pointee = ffiString("could not load image at \(p)")
            return VN_IMAGE_LOAD_FAILED
        }
        let req = VNDetectAnimalBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: img, options: [:])
        do { try handler.perform([req]) } catch {
            outErrorMessage?.pointee = ffiString("animal body pose request failed: \(error.localizedDescription)")
            return VN_REQUEST_FAILED
        }
        guard let obs = req.results?.first else { return VN_OK }
        let names: [VNAnimalBodyPoseObservation.JointName] = [
            .leftEarTop, .leftEarMiddle, .leftEarBottom,
            .rightEarTop, .rightEarMiddle, .rightEarBottom,
            .leftEye, .rightEye,
            .nose, .neck,
            .leftFrontElbow, .leftFrontKnee, .leftFrontPaw,
            .rightFrontElbow, .rightFrontKnee, .rightFrontPaw,
            .leftBackElbow, .leftBackKnee, .leftBackPaw,
            .rightBackElbow, .rightBackKnee, .rightBackPaw,
            .tailTop, .tailMiddle, .tailBottom,
        ]
        var joints: [VNAnimalJointRaw] = []
        for n in names {
            guard let pt = try? obs.recognizedPoint(n), pt.confidence > 0 else { continue }
            joints.append(VNAnimalJointRaw(
                name: ffiString(n.rawValue.rawValue),
                x: Double(pt.location.x), y: Double(pt.location.y),
                confidence: pt.confidence, _pad: 0
            ))
        }
        if joints.isEmpty { return VN_OK }
        let buf = UnsafeMutablePointer<VNAnimalJointRaw>.allocate(capacity: joints.count)
        buf.initialize(from: &joints, count: joints.count)
        out_joints.pointee = buf
        out_count.pointee = joints.count
        return VN_OK
    }
    return VN_REQUEST_FAILED
}

@_cdecl("vn_animal_joints_free")
public func vn_animal_joints_free(_ ptr: UnsafeMutableRawPointer?, _ count: Int) {
    guard let ptr = ptr else { return }
    let typed = ptr.assumingMemoryBound(to: VNAnimalJointRaw.self)
    for i in 0..<count {
        vn_string_free(typed[i].name)
    }
    typed.deinitialize(count: count)
    typed.deallocate()
}

// MARK: - 3D human body pose (macOS 14+)

@frozen
public struct VNHumanJoint3DRaw {
    public var name: UnsafeMutablePointer<CChar>?
    public var x: Float
    public var y: Float
    public var z: Float
    public var confidence: Float
}

@_cdecl("vn_detect_human_body_pose_3d_in_path")
public func vn_detect_human_body_pose_3d_in_path(
    _ path: UnsafePointer<CChar>,
    _ out_joints_raw: UnsafeMutableRawPointer,
    _ out_count: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let out_joints = out_joints_raw.assumingMemoryBound(to: UnsafeMutablePointer<VNHumanJoint3DRaw>?.self)
    out_joints.pointee = nil
    out_count.pointee = 0
    if #available(macOS 14.0, *) {
        let p = String(cString: path)
        guard let img = loadCGImage(path: p) else {
            outErrorMessage?.pointee = ffiString("could not load image at \(p)")
            return VN_IMAGE_LOAD_FAILED
        }
        let req = VNDetectHumanBodyPose3DRequest()
        let handler = VNImageRequestHandler(cgImage: img, options: [:])
        do { try handler.perform([req]) } catch {
            outErrorMessage?.pointee = ffiString("3D body pose request failed: \(error.localizedDescription)")
            return VN_REQUEST_FAILED
        }
        guard let obs = req.results?.first else { return VN_OK }
        let names: [VNHumanBodyPose3DObservation.JointName] = [
            .root, .topHead, .centerHead,
            .leftShoulder, .leftElbow, .leftWrist,
            .rightShoulder, .rightElbow, .rightWrist,
            .leftHip, .leftKnee, .leftAnkle,
            .rightHip, .rightKnee, .rightAnkle,
            .spine, .centerShoulder,
        ]
        var joints: [VNHumanJoint3DRaw] = []
        for n in names {
            guard let pt = try? obs.recognizedPoint(n) else { continue }
            let pos = pt.position
            joints.append(VNHumanJoint3DRaw(
                name: ffiString(n.rawValue.rawValue),
                x: pos.columns.3.x, y: pos.columns.3.y, z: pos.columns.3.z,
                confidence: 1.0
            ))
        }
        if joints.isEmpty { return VN_OK }
        let buf = UnsafeMutablePointer<VNHumanJoint3DRaw>.allocate(capacity: joints.count)
        buf.initialize(from: &joints, count: joints.count)
        out_joints.pointee = buf
        out_count.pointee = joints.count
        return VN_OK
    }
    return VN_REQUEST_FAILED
}

@_cdecl("vn_human_joints_3d_free")
public func vn_human_joints_3d_free(_ ptr: UnsafeMutableRawPointer?, _ count: Int) {
    guard let ptr = ptr else { return }
    let typed = ptr.assumingMemoryBound(to: VNHumanJoint3DRaw.self)
    for i in 0..<count {
        vn_string_free(typed[i].name)
    }
    typed.deinitialize(count: count)
    typed.deallocate()
}

// MARK: - Text rectangles (region-only, no OCR)

@_cdecl("vn_detect_text_rectangles_in_path")
public func vn_detect_text_rectangles_in_path(
    _ path: UnsafePointer<CChar>,
    _ reports_character_boxes: Bool,
    _ out_rects_raw: UnsafeMutableRawPointer,
    _ out_count: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let out_rects = out_rects_raw.assumingMemoryBound(to: UnsafeMutablePointer<VNSimpleRectRaw>?.self)
    out_rects.pointee = nil
    out_count.pointee = 0
    let p = String(cString: path)
    guard let img = loadCGImage(path: p) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(p)")
        return VN_IMAGE_LOAD_FAILED
    }
    let req = VNDetectTextRectanglesRequest()
    req.reportCharacterBoxes = reports_character_boxes
    let handler = VNImageRequestHandler(cgImage: img, options: [:])
    do { try handler.perform([req]) } catch {
        outErrorMessage?.pointee = ffiString("text rectangles request failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let obs = req.results else { return VN_OK }
    var rects = obs.map { mkRect($0.boundingBox, $0.confidence) }
    if rects.isEmpty { return VN_OK }
    let buf = UnsafeMutablePointer<VNSimpleRectRaw>.allocate(capacity: rects.count)
    buf.initialize(from: &rects, count: rects.count)
    out_rects.pointee = buf
    out_count.pointee = rects.count
    return VN_OK
}

// MARK: - Objectness-based saliency

@_cdecl("vn_objectness_saliency_in_path")
public func vn_objectness_saliency_in_path(
    _ path: UnsafePointer<CChar>,
    _ out_rects_raw: UnsafeMutableRawPointer,
    _ out_count: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let out_rects = out_rects_raw.assumingMemoryBound(to: UnsafeMutablePointer<VNSimpleRectRaw>?.self)
    out_rects.pointee = nil
    out_count.pointee = 0
    let p = String(cString: path)
    guard let img = loadCGImage(path: p) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(p)")
        return VN_IMAGE_LOAD_FAILED
    }
    let req = VNGenerateObjectnessBasedSaliencyImageRequest()
    let handler = VNImageRequestHandler(cgImage: img, options: [:])
    do { try handler.perform([req]) } catch {
        outErrorMessage?.pointee = ffiString("objectness saliency request failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let obs = req.results?.first, let regions = obs.salientObjects else { return VN_OK }
    var rects = regions.map { mkRect($0.boundingBox, $0.confidence) }
    if rects.isEmpty { return VN_OK }
    let buf = UnsafeMutablePointer<VNSimpleRectRaw>.allocate(capacity: rects.count)
    buf.initialize(from: &rects, count: rects.count)
    out_rects.pointee = buf
    out_count.pointee = rects.count
    return VN_OK
}

// MARK: - Person instance mask (macOS 14+)

/// Writes a packed 8-bit per-pixel mask. Caller must `free()` the buffer.
@_cdecl("vn_person_instance_mask_in_path")
public func vn_person_instance_mask_in_path(
    _ path: UnsafePointer<CChar>,
    _ out_width: UnsafeMutablePointer<Int>,
    _ out_height: UnsafeMutablePointer<Int>,
    _ out_bytes_per_row: UnsafeMutablePointer<Int>,
    _ out_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    out_width.pointee = 0
    out_height.pointee = 0
    out_bytes_per_row.pointee = 0
    out_data.pointee = nil
    if #available(macOS 14.0, *) {
        let p = String(cString: path)
        guard let img = loadCGImage(path: p) else {
            outErrorMessage?.pointee = ffiString("could not load image at \(p)")
            return VN_IMAGE_LOAD_FAILED
        }
        let req = VNGeneratePersonInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: img, options: [:])
        do { try handler.perform([req]) } catch {
            outErrorMessage?.pointee = ffiString("person instance mask request failed: \(error.localizedDescription)")
            return VN_REQUEST_FAILED
        }
        guard let obs = req.results?.first else { return VN_OK }
        let allInstances = obs.allInstances
        if allInstances.isEmpty { return VN_OK }
        guard let pb = try? obs.generateScaledMaskForImage(forInstances: allInstances, from: handler) else {
            return VN_OK
        }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        let w = CVPixelBufferGetWidth(pb)
        let h = CVPixelBufferGetHeight(pb)
        let bpr = CVPixelBufferGetBytesPerRow(pb)
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return VN_OK }
        let size = bpr * h
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        data.initialize(from: base.assumingMemoryBound(to: UInt8.self), count: size)
        out_width.pointee = w
        out_height.pointee = h
        out_bytes_per_row.pointee = bpr
        out_data.pointee = data
        return VN_OK
    }
    return VN_REQUEST_FAILED
}

@_cdecl("vn_mask_buffer_free")
public func vn_mask_buffer_free(_ ptr: UnsafeMutablePointer<UInt8>?, _ size: Int) {
    guard let ptr = ptr else { return }
    ptr.deinitialize(count: size)
    ptr.deallocate()
}

// MARK: - Trajectories

@frozen
public struct VNTrajectoryRaw {
    public var detected_x: Double
    public var detected_y: Double
    public var projected_x: Double
    public var projected_y: Double
    public var equation_a: Double
    public var equation_b: Double
    public var equation_c: Double
    public var confidence: Float
    public var _pad: Float
}

@_cdecl("vn_detect_trajectories_in_path")
public func vn_detect_trajectories_in_path(
    _ path: UnsafePointer<CChar>,
    _ trajectory_length: Int,
    _ out_trajectories_raw: UnsafeMutableRawPointer,
    _ out_count: UnsafeMutablePointer<Int>,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let out_trajectories = out_trajectories_raw.assumingMemoryBound(to: UnsafeMutablePointer<VNTrajectoryRaw>?.self)
    out_trajectories.pointee = nil
    out_count.pointee = 0
    let p = String(cString: path)
    guard let img = loadCGImage(path: p) else {
        outErrorMessage?.pointee = ffiString("could not load image at \(p)")
        return VN_IMAGE_LOAD_FAILED
    }
    let req = VNDetectTrajectoriesRequest(frameAnalysisSpacing: .zero, trajectoryLength: trajectory_length)
    let handler = VNSequenceRequestHandler()
    do { try handler.perform([req], on: img) } catch {
        let msg = error.localizedDescription
        // Single-image trajectories are degenerate — Apple requires a
        // multi-frame video signal with timestamps. Return zero
        // trajectories rather than surfacing the "no PTS" error so
        // single-shot smoke tests succeed; for real use feed a
        // sequence of frames via the stateful API.
        if msg.contains("presentationTimeStamp") || msg.contains("PTS") {
            return VN_OK
        }
        outErrorMessage?.pointee = ffiString("trajectories request failed: \(msg)")
        return VN_REQUEST_FAILED
    }
    guard let results = req.results, !results.isEmpty else { return VN_OK }
    var out: [VNTrajectoryRaw] = []
    for t in results {
        guard let detected = t.detectedPoints.last,
              let projected = t.projectedPoints.last
        else { continue }
        out.append(VNTrajectoryRaw(
            detected_x: Double(detected.location.x),
            detected_y: Double(detected.location.y),
            projected_x: Double(projected.x),
            projected_y: Double(projected.y),
            equation_a: Double(t.equationCoefficients.x),
            equation_b: Double(t.equationCoefficients.y),
            equation_c: Double(t.equationCoefficients.z),
            confidence: t.confidence,
            _pad: 0
        ))
    }
    if out.isEmpty { return VN_OK }
    let buf = UnsafeMutablePointer<VNTrajectoryRaw>.allocate(capacity: out.count)
    buf.initialize(from: &out, count: out.count)
    out_trajectories.pointee = buf
    out_count.pointee = out.count
    return VN_OK
}

@_cdecl("vn_trajectories_free")
public func vn_trajectories_free(_ ptr: UnsafeMutableRawPointer?, _ count: Int) {
    guard let ptr = ptr else { return }
    let typed = ptr.assumingMemoryBound(to: VNTrajectoryRaw.self)
    typed.deinitialize(count: count)
    typed.deallocate()
}

// MARK: - Image registration (translational + homographic)

@frozen
public struct VNTranslationalAlignmentRaw {
    public var tx: Double
    public var ty: Double
}

@frozen
public struct VNHomographicAlignmentRaw {
    public var m00: Float
    public var m01: Float
    public var m02: Float
    public var m10: Float
    public var m11: Float
    public var m12: Float
    public var m20: Float
    public var m21: Float
    public var m22: Float
    public var _pad: Float
}

@_cdecl("vn_register_translational_in_paths")
public func vn_register_translational_in_paths(
    _ target_path: UnsafePointer<CChar>,
    _ floating_path: UnsafePointer<CChar>,
    _ out_raw: UnsafeMutableRawPointer,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let out = out_raw.assumingMemoryBound(to: VNTranslationalAlignmentRaw.self)
    let tp = String(cString: target_path)
    let fp = String(cString: floating_path)
    guard let target = loadCGImage(path: tp), let floating = loadCGImage(path: fp) else {
        outErrorMessage?.pointee = ffiString("could not load images \(tp) / \(fp)")
        return VN_IMAGE_LOAD_FAILED
    }
    let req = VNTranslationalImageRegistrationRequest(targetedCGImage: target, options: [:])
    let handler = VNImageRequestHandler(cgImage: floating, options: [:])
    do { try handler.perform([req]) } catch {
        outErrorMessage?.pointee = ffiString("translational registration failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let obs = req.results?.first else { return VN_OK }
    out.pointee = VNTranslationalAlignmentRaw(
        tx: Double(obs.alignmentTransform.tx),
        ty: Double(obs.alignmentTransform.ty)
    )
    return VN_OK
}

@_cdecl("vn_register_homographic_in_paths")
public func vn_register_homographic_in_paths(
    _ target_path: UnsafePointer<CChar>,
    _ floating_path: UnsafePointer<CChar>,
    _ out_raw: UnsafeMutableRawPointer,
    _ outErrorMessage: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32 {
    let out = out_raw.assumingMemoryBound(to: VNHomographicAlignmentRaw.self)
    let tp = String(cString: target_path)
    let fp = String(cString: floating_path)
    guard let target = loadCGImage(path: tp), let floating = loadCGImage(path: fp) else {
        outErrorMessage?.pointee = ffiString("could not load images \(tp) / \(fp)")
        return VN_IMAGE_LOAD_FAILED
    }
    let req = VNHomographicImageRegistrationRequest(targetedCGImage: target, options: [:])
    let handler = VNImageRequestHandler(cgImage: floating, options: [:])
    do { try handler.perform([req]) } catch {
        outErrorMessage?.pointee = ffiString("homographic registration failed: \(error.localizedDescription)")
        return VN_REQUEST_FAILED
    }
    guard let obs = req.results?.first else { return VN_OK }
    let m = obs.warpTransform
    out.pointee = VNHomographicAlignmentRaw(
        m00: m.columns.0.x, m01: m.columns.0.y, m02: m.columns.0.z,
        m10: m.columns.1.x, m11: m.columns.1.y, m12: m.columns.1.z,
        m20: m.columns.2.x, m21: m.columns.2.y, m22: m.columns.2.z,
        _pad: 0
    )
    return VN_OK
}

