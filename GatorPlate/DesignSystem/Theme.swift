import SwiftUI

/// Design tokens. Colors live in the asset catalog (light and dark variants).
enum Theme {
    enum Palette {
        static let brandPurple = Color("BrandPurple")
        static let brandGold = Color("BrandGold")
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        /// Interactive accents inside lists on the post, filter and Custom notifications screens (checkmarks,
        /// "Add places", "+ Custom"). Brand purple stays for filled buttons, auth screens and Settings icons.
        static let accent = Color.blue
    }

    /// 8-pt grid.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 20
        static let photo: CGFloat = 16
        static let field: CGFloat = 12
    }

    enum Size {
        static let minTapTarget: CGFloat = 44
        static let primaryButtonHeight: CGFloat = 52
    }
}

extension EnvironmentValues {
    /// Icon and checkmark color for `ListRow`, `CheckRow` and `NoteRow`. Brand purple by default (Settings);
    /// the post, filter and Custom notifications screens set `Theme.Palette.accent`.
    @Entry var listAccent: Color = Theme.Palette.brandPurple
}
