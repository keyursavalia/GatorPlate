import AVFoundation
import SwiftUI
import UIKit

/// Reads the current rotation angles for the camera. The preview view installs the coordinator; the
/// capture button reads the angle at the moment of the tap.
final class CameraRotationSource {
    fileprivate(set) var coordinator: AVCaptureDevice.RotationCoordinator?

    /// Portrait (90) until a coordinator exists.
    var captureAngle: CGFloat {
        coordinator?.videoRotationAngleForHorizonLevelCapture ?? 90
    }
}

/// Hosts an `AVCaptureVideoPreviewLayer`. The only UIKit view in the camera flow.
struct CameraPreview: UIViewRepresentable {
    let session: CameraSessionBox
    let rotation: CameraRotationSource
    /// Tap point converted to capture-device coordinates (0...1).
    let onFocus: (CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.installRotation(device: session.device, source: rotation)
        view.onFocus = onFocus
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.onFocus = onFocus
    }
}

final class PreviewView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    var onFocus: ((CGPoint) -> Void)?

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewAngleObservation: NSKeyValueObservation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layer.addSublayer(previewLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }

    func installRotation(device: AVCaptureDevice?, source: CameraRotationSource) {
        guard let device else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        source.coordinator = coordinator
        previewAngleObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in self?.applyPreviewAngle(angle) }
        }
    }

    private func applyPreviewAngle(_ angle: CGFloat) {
        previewLayer.connection?.videoRotationAngle = angle
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: gesture.location(in: self))
        onFocus?(devicePoint)
    }
}
