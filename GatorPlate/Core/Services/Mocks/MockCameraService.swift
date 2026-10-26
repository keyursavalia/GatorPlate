import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if DEBUG
/// Camera without hardware: configurable permission, a black preview, and a solid-color "photo".
actor MockCameraService: CameraCapturing {
    nonisolated let previewSource = CameraPreviewSource(session: nil)
    nonisolated let isCameraAvailable: Bool
    nonisolated let canSwitchCamera = true

    private var currentAuthorization: CameraAuthorization
    private var eventContinuation: AsyncStream<CameraEvent>.Continuation?

    init(authorization: CameraAuthorization = .authorized, isCameraAvailable: Bool = true) {
        currentAuthorization = authorization
        self.isCameraAvailable = isCameraAvailable
    }

    func authorization() -> CameraAuthorization { currentAuthorization }

    func requestAccess() -> CameraAuthorization {
        if currentAuthorization == .notDetermined { currentAuthorization = .authorized }
        return currentAuthorization
    }

    func events() -> AsyncStream<CameraEvent> {
        eventContinuation?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: CameraEvent.self)
        eventContinuation = continuation
        return stream
    }

    func start() throws(AppError) {
        guard isCameraAvailable, currentAuthorization == .authorized else { throw .cameraUnavailable }
    }

    func stop() {}

    func supportedFlashModes() -> [CameraFlashMode] { CameraFlashMode.allCases }

    func capturePhoto(flash: CameraFlashMode) throws(AppError) -> Data {
        eventContinuation?.yield(.willCapture)
        guard let data = Self.solidColorJPEG() else { throw .captureFailed }
        return data
    }

    func focus(at devicePoint: CGPoint) {}

    func switchCamera() -> [CameraFlashMode] { CameraFlashMode.allCases }

    private static func solidColorJPEG(width: Int = 1600, height: Int = 1200) -> Data? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(red: 0.46, green: 0.32, blue: 0.75, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData,
                                                                 UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
#endif
