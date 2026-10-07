import AVFoundation
import Synchronization

/// Delegate for a single capture. Resumes its continuation exactly once, then reports `onFinish`
/// so `CameraService` can release it.
nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, Sendable {
    private let continuation: Mutex<CheckedContinuation<Data, any Error>?>
    private let onWillCapture: @Sendable () -> Void
    private let onFinish: @Sendable () -> Void

    init(continuation: CheckedContinuation<Data, any Error>,
         onWillCapture: @escaping @Sendable () -> Void,
         onFinish: @escaping @Sendable () -> Void) {
        self.continuation = Mutex(continuation)
        self.onWillCapture = onWillCapture
        self.onFinish = onFinish
    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        onWillCapture()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: (any Error)?) {
        if let error {
            resume(with: .failure(error))
        } else if let data = photo.fileDataRepresentation() {
            resume(with: .success(data))
        } else {
            resume(with: .failure(AppError.captureFailed))
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: (any Error)?) {
        // No-op when the photo already resumed; covers captures that fail before processing.
        resume(with: .failure(error ?? AppError.captureFailed))
        onFinish()
    }

    private func resume(with result: Result<Data, any Error>) {
        continuation.withLock { continuation in
            continuation?.resume(with: result)
            continuation = nil
        }
    }
}
