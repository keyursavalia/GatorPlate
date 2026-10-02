import SwiftUI

/// Design tokens. Colors live in the asset catalog (light and dark variants); Xcode generates
/// `Color.brandPurple`, `.brandGold`, `.surface`, `.surfaceSecondary`, `.success`, `.warning`, `.danger`.
enum Theme {
    /// 8-pt grid.
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 20
        static let photo: CGFloat = 16
        static let button: CGFloat = 16
    }

    static let buttonHeight: CGFloat = 52
    static let minTapTarget: CGFloat = 44
}
