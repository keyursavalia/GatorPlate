import Foundation

/// What a tapped notification asks the app to do, from its data payload. Pure, so the harness can test payloads.
/// Kinds (`data.kind`, written by the functions): free food alerts carry `postId` only; `postRemoved`,
/// `appealResolved` and `adminReview` carry no post. Anything unknown or malformed just opens the app.
nonisolated enum NotificationTap: Equatable, Sendable {
    /// A free food alert: open this post.
    case openPost(String)
    /// The admin decided an appeal: show the Posting paused sheet if a ban is still running.
    case appealResolved
    /// Open the app and do nothing else (`postRemoved`, `adminReview`, unknown kinds, a bad post ID).
    case openApp

    static let kindKey = "kind"

    static func parse(_ userInfo: [AnyHashable: Any]) -> NotificationTap {
        if let postId = postId(from: userInfo) { return .openPost(postId) }
        if userInfo[kindKey] as? String == "appealResolved" { return .appealResolved }
        return .openApp
    }

    /// Post IDs are 20 alphanumeric characters (40 allowed); anything else in a payload is ignored.
    static func postId(from userInfo: [AnyHashable: Any]) -> String? {
        guard let postId = userInfo[AppConfig.notificationPostIdKey] as? String,
              (1...40).contains(postId.count),
              postId.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return postId
    }
}
