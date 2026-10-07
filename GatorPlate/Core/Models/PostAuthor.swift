import Foundation

/// Who is posting. Name and org must match the user's profile (enforced by Firestore rules).
nonisolated struct PostAuthor: Equatable, Sendable {
    var uid: String
    var displayName: String
    var orgName: String?

    init(uid: String, displayName: String, orgName: String?) {
        self.uid = uid
        self.displayName = displayName
        self.orgName = orgName
    }

    init(profile: UserProfile) {
        self.init(uid: profile.uid, displayName: profile.displayName, orgName: profile.orgName)
    }
}
