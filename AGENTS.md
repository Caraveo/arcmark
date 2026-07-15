# ArcMark delivery rules

- Always create a Git commit for completed work.
- Every commit increments the `Commit` badge in `README.md` as the next patch version on the current app line (for example, `v0.2.0` becomes `v0.2.1`).
- Every push or release increments the app and release version using the format `v0.X.0`, unless the user explicitly requests a different version. Update the README `Version` badge, `CFBundleShortVersionString`, release/tag name, and release artifact name together.
- Keep the macOS, Swift, SwiftUI, Version, Commit, and Status badges at the top of `README.md`.
