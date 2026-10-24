# SmartERP Mobile

Native iPhone and iPad ERP prototype for iOS 17 and later. Open `SmartERPMobile.xcodeproj` in Xcode 27.

The app starts with a choice between a local demo workspace and Google sign-in for a separate account workspace. Customer, product, order, purchase, receipt, invoice and visit data is stored on device for evaluation. No demo action posts to Inventolo or sends notifications to other people. Firebase upload occurs only when explicitly requested in settings. Financial and stock records in this workspace are sample records, not authoritative business records.

## Run

1. Select the `SmartERPMobile` scheme and an iPhone or iPad Pro 11-inch simulator.
2. Build and run. Onboarding explains the demo boundary.
3. For barcode scanning, use a physical iPhone or iPad; the simulator offers manual barcode entry.

Run `xcodebuild -project SmartERPMobile.xcodeproj -scheme SmartERPMobile -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` for the included domain tests.

On iPad, the five main areas appear in a sidebar and the overview, reports, and welcome screen use a centered reading width. In compact Split View, the app uses the same tab navigation as iPhone.

## Project structure and viva walkthrough

```text
SmartERPMobile/
├── App/                 App entry point and tab navigation
├── Domain/              ERP models and small business rules
├── Data/                Local demo data, saving, and transactions
├── Core/                Shared UI, camera scanning, and API foundation
└── Features/
    ├── Onboarding/     Welcome screen and demo entry
    ├── Dashboard/      Overview and quick actions
    ├── Customers/      Customer list, details, and form
    ├── Inventory/      Product list, details, and form
    ├── Sales/          Orders, invoices, and payments
    ├── Purchasing/     Purchase orders and goods receiving
    ├── Transactions/   Shared sales/purchase draft form
    ├── Operations/     Visits, map, and work location session
    ├── Reports/        Charts and summary metrics
    └── Settings/       Demo status and reset controls
SmartERPTests/           Domain and local receipt tests
```

**Suggested walkthrough:** Start at `App/SmartERPApp.swift`: it creates `DemoStore` and injects it into the UI. `App/RootView.swift` chooses the welcome screen or the five main tabs. Open a feature folder to show its SwiftUI screens. The screens read models from `Domain/Models.swift` and call methods on `Data/DemoStore.swift` to change local data. `DemoStore` saves a JSON snapshot in SwiftData on the device. `Core/APIClient.swift` is a foundation for future Inventolo backend integration; the current screens do not call it. Firebase backup is a separate explicit option in Settings.

For a concrete example, demonstrate **Purchasing → New purchase → Receive goods**. The shared transaction form creates a purchase draft through `DemoStore.addPurchase`; `ReceivingForm` calls `DemoStore.receive`, which caps received quantities and updates the matching product's local stock. `SmartERPTests/DomainTests.swift` checks this partial receipt rule. This shows the UI, data flow, and a tested business rule in one short path.

## Backend contracts needed before a commercial beta

The Inventolo API specification and credentials were not supplied. The app deliberately does not guess endpoints. Integration needs documented contracts for: authentication and token refresh; tenant/branch selection; permissions; customers and products; authoritative inventory availability and movements; orders, purchases, partial receipts, invoices and payments; dashboard and reports; location session and visit events; notification registration and delivery. Every mutation needs an idempotency key and a server response that distinguishes draft, accepted and posted states. Tenant and branch identifiers must be validated on the server.

`Core/APIClient.swift` contains a typed HTTPS client and Keychain token storage ready for an adapter once those contracts exist. `DemoStore` is an isolated local JSON repository and never masquerades as a server response. SwiftData-backed encrypted caches and a durable offline sync queue remain production work.

## Native capabilities and privacy

- Camera usage is declared for barcode capture. Scanning never posts stock movements.
- Foreground location permission is requested only after a salesperson starts an explicit demo work session. The map shows demo team positions with timestamps and labels them as sample data.
- Background location, geofence monitoring, and APNs are not enabled. Widgets and local Live Activities are included and need physical-device validation and correct signing identifiers.
- No employee location is silently collected. Ending a session stops location updates.

## Production checklist

Connect the documented API; add server permission checks and token refresh; implement encrypted/isolated caches and a durable sync queue; configure the App Group and Widget extension with production signing identifiers; configure APNs and server delivery; add localization for Sinhala and Tamil; test camera, location and notifications on physical devices; complete accessibility and App Store privacy review.

## Map, widgets, Live Activity, and Firebase backup

The visit map shows saved assignments, lets you select and recenter on a visit, and opens driving directions in Apple Maps. The user-location control uses the system location permission. Visit pins are assignments, not live colleague positions.

The `SmartERPWidgets` extension provides **Business overview** and **Next visit** Home Screen widgets using an App Group snapshot written after each local save. The work-session screen starts a Live Activity after foreground location is authorized, and ends it when you end the session. Location is not uploaded. Widgets refresh on saves and the system's timeline; they are not a continuous feed. Live Activities use local ActivityKit updates; remote push updates are not configured.

For a signed device build, replace `com.example.SmartERPMobile`, `com.example.SmartERPMobile.widgets`, and `group.com.example.SmartERPMobile` consistently with identifiers owned by your Apple Developer team. Enable the App Groups capability for both targets and register the group. Enable Live Activities for the app if your signing setup requires it.

Firebase backup uses Firebase Authentication and Firestore REST APIs. In the Firebase console, create a Firestore database and enable **Google** sign-in. In **Sign in with Google** (or **More → Google sign-in**), enter the Firebase project ID and Web API key. Upload explicitly saves the current account workspace snapshot to `users/{auth.uid}/backups/current`; restore explicitly replaces local records after confirmation. The Firebase refresh token is stored in Keychain. Signing into the same Google account on another device can restore its cloud snapshot. Local records are separated by Firebase user ID. This is explicit snapshot backup, not automatic ERP sync.

A minimal Firestore rule for this backup path is:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/backups/{backupId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Publish rules in the Firebase console before using backup. Set stricter size and validation limits before production use. Firebase and Google credentials were not supplied in this repository, so the sign-in and cloud round trip need validation with your project.

## Google sign-in setup

1. Register the app's final iOS bundle ID in Firebase and Google Cloud. In Firebase Authentication, enable the **Google** provider and select a support email.
2. In `SmartERPMobile/Info.plist`, replace `YOUR_IOS_CLIENT_ID` with the iOS OAuth client ID (ending in `.apps.googleusercontent.com`) and `YOUR_REVERSED_CLIENT_ID` with that same client ID reversed by dot-delimited parts (for example, `com.googleusercontent.apps.123-abc`). These values must belong to the same app bundle ID used for signing.
3. Run the app, open **Sign in with Google**, and enter the Firebase project ID and Web API key. These are project identifiers, not a service-account secret. The app exchanges Google's ID token with Firebase Authentication, then stores Firebase's refresh token in Keychain.
4. Sign in and use **More → Firebase backup** to upload or restore data. Signing out returns to the local demo workspace. Each Google account has a separate local database snapshot.

The Google Sign-In SDK is installed with Swift Package Manager and its version is pinned in `Package.resolved`. Existing anonymous Firebase backups from older builds are not linked automatically to a Google account; existing local demo records remain in the demo workspace. Inventolo service authentication still requires its own API contract.
