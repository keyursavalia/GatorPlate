# GatorPlate

**Leftover campus food, posted in seconds, found on a map.**

GatorPlate is a native iOS app where SFSU students and student organizations post leftover food on campus. Students nearby see it live on a campus map and can walk straight to it. Gemini turns a single photo into a complete, reviewable post.

## The problem

Student orgs often finish evening events with edible leftovers. SFSU's Gator Grub Alert only lets trained staff and faculty post, and that rarely happens at 8 PM. The food gets thrown away while students who could use it never find out.

GatorPlate **extends** Gator Grub Alert. It adds a student-initiated, after-hours, photo-first layer. It does not replace it.

## How it works

1. **Snap**: the poster photographs the food with the in-app camera (or picks a photo).
2. **AI drafts**: Gemini checks that it is food and fills in the title, description, items, dietary class, calorie range, allergen warnings, and food-safety notes.
3. **Review and publish**: the poster edits anything, picks the location and duration (default 30 min, max 60), and publishes. AI never auto-publishes, and AI failure never blocks posting. The poster can always fill the form in by hand.
4. **Discover**: students see live pins on a campus-locked map and a real-time feed, with time remaining on every post.
5. **Go**: tap a pin for the bottom card, then get an in-app walking route or open Apple Maps.
6. **Mark as gone**: the poster can end a post early when the food runs out.

## Features

- Email sign-up and login restricted to SFSU addresses (Student or Student Organization accounts), with Terms of Use acceptance
- MapKit map locked to the SFSU campus, with rotation, user location, and live pins for active posts
- Custom AVFoundation camera with photo-library fallback and on-device image preprocessing (downscale, EXIF/GPS stripped)
- Gemini photo-to-post analysis through Firebase AI Logic with a response schema and defensive decoding
- Editable review form, Firestore publishing, and photo storage with expiry
- Real-time feed and map backed by Firestore listeners
- Walking directions with ETA and an "Open in Apple Maps" handoff
- Report and Mark as gone actions

## Responsible AI

- **Human in the loop**: every AI field is editable, and nothing is published without the poster's confirmation.
- **Honest labeling**: calories are shown as a range labeled "estimate", and allergen output carries a disclaimer.
- **Privacy by design**: we do not track who picks up food. Photos are stripped of EXIF/GPS and deleted after the post expires. The camera prompt asks users to keep people out of the frame.
- **Safety**: food-safety notes, a report button, a capped post duration that mirrors the school's 30-minute rule, and Terms of Use with food-safety waiver language.
- **No secrets in the app**: Gemini is called only through Firebase AI Logic protected by App Check. There is no raw API key anywhere in source.

See [`docs/05-RESPONSIBLE-AI.md`](docs/05-RESPONSIBLE-AI.md) for the full plan, including the pilot path with SFSU Basic Needs.

## Tech stack

- iOS 26+, Swift 6, SwiftUI, MVVM with `@Observable`
- Firebase: Auth, Firestore, App Check, AI Logic (Gemini)
- MapKit, CoreLocation, AVFoundation
- Swift Testing for unit tests, XCUITest for the critical path
- Every service sits behind a protocol with a Firebase and a Mock implementation, so previews and UI tests run without a backend

## Project layout

```
GatorPlate/
  App/            App entry point and environment wiring
  Core/           Models, services (protocols, Firebase, Mock), campus data, utilities
  DesignSystem/   Shared UI components and tokens
  Features/       Auth, Map, Post, Feed, Settings
  Resources/      Terms of Use and bundled resources
  docs/           Product spec, architecture, design system, AI spec, responsible AI, sprint logs
GatorPlateTests/
GatorPlateUITests/
firestore.rules
```

## Running it

1. Open `GatorPlate.xcodeproj` in Xcode 26 or later.
2. Add your own `GoogleService-Info.plist` to the `GatorPlate/` folder. It is gitignored, so each developer supplies their own Firebase project.
3. In the Firebase console, enable Email/Password Auth, Firestore, and Firebase AI Logic, and deploy `firestore.rules`.
4. Run a debug build once and register the App Check debug token printed in the console log.
5. Run on a simulator or device. The simulator has no camera, so use the photo picker or the DEBUG-only sample image.

UI tests launch with `-UITestMock` and use mock services, so they need no Firebase.

## Docs

| Doc | Contents |
|-----|----------|
| [`docs/01-PRODUCT-SPEC.md`](docs/01-PRODUCT-SPEC.md) | Problem, users, features, demo script |
| [`docs/02-ARCHITECTURE.md`](docs/02-ARCHITECTURE.md) | Architecture, data model, rules |
| [`docs/03-DESIGN-SYSTEM.md`](docs/03-DESIGN-SYSTEM.md) | UI guidelines |
| [`docs/04-AI-GEMINI-SPEC.md`](docs/04-AI-GEMINI-SPEC.md) | Gemini prompt, schema, validation |
| [`docs/05-RESPONSIBLE-AI.md`](docs/05-RESPONSIBLE-AI.md) | Privacy, safety, bias, accessibility |
| [`docs/PROGRESS.md`](docs/PROGRESS.md) | Sprint status, decisions, parking lot |

## Status

This is a hackathon prototype. Sprints 0 to 6 are complete: auth, campus map, camera, AI analysis, post and publish, and the live feed with directions. Push notifications and final polish are planned next. Known gaps and ideas are listed in the parking lot in `docs/PROGRESS.md`.

## Team

Built for an SFSU hackathon by the GatorPlate team.
