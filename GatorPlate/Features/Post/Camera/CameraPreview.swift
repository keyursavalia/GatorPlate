import AVFoundation
import SwiftUI
import UIKit

/// Live camera preview. The only UIKit view in the app: SwiftUI has no `AVCaptureVideoPreviewLayer`.
struct CameraPreview: UIViewRepresentable {
    let source: CameraPreviewSource
    /// `devicePoint` is normalized for the capture device; `viewPoint` is in this view's coordinates.
    var onTap: (_ devicePoint: CGPoint, _ viewPoint: CGPoint) -> Void = { _, _ in }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Camera preview"
        view.accessibilityHint = "Double-tap to focus on the center."
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                         action: #selector(Coordinator.handleTap(_:))))
        source.connect(to: view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        var onTap: (CGPoint, CGPoint) -> Void

        init(onTap: @escaping (CGPoint, CGPoint) -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? PreviewView else { return }
            let viewPoint = gesture.location(in: view)
            onTap(view.previewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint), viewPoint)
        }
    }

    final class PreviewView: UIView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = bounds
            CATransaction.commit()
        }
    }
}
