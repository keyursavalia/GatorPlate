import FirebaseFirestore

/// Lets a stream's termination handler remove its Firestore listener: `ListenerRegistration.remove()` is thread-safe.
nonisolated final class FirestoreListenerHandle: @unchecked Sendable {
    private let registration: any ListenerRegistration

    init(_ registration: any ListenerRegistration) {
        self.registration = registration
    }

    func remove() {
        registration.remove()
    }
}
