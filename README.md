# OqushyCompass (Flutter) — Stage 1

Working now: Tasks screen (add, edit, delete, complete, filters, search, sort,
validation, empty/error states), saved on the device, optional deadline
reminders (local notifications).

Not built yet: Today, Planner, Focus, Statistics, Settings, bottom navigation.

## Build without a Mac
1. Put this folder in a GitHub repository.
2. Sign up at codemagic.io, connect the repository, use `codemagic.yaml`.
3. Replace `com.yourname` with your own identifier (lowercase, no spaces).
4. Add an App Store Connect API key (needs the Apple Developer Program).
5. Run the workflow. Builds appear in TestFlight for beta testers.

`flutter create .` runs during the build and makes the ios/ and android/
folders. If you run it yourself, delete test/widget_test.dart (the default
test refers to a class this project doesn't have).

## Known gaps
- Never compiled or run by the author of this code. Expect to fix small errors.
- On iPhone, reminders show when the app is closed. Showing them while the app
  is open needs a small AppDelegate change (stage 2).
- Tasks are stored only on the device; deleting the app deletes the data.
