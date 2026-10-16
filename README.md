# SmartERP Mobile

Native iPhone ERP prototype for iOS 17 and later. Open `SmartERPMobile.xcodeproj` in Xcode 27.

The app starts in an explicitly labelled **local demo workspace**. Customer, product, order, purchase, receipt, invoice and visit data is stored on device for evaluation. No demo action posts to Inventolo or sends notifications to other people. Financial and stock records in this workspace are sample records, not authoritative business records.

## Run

1. Select the `SmartERPMobile` scheme and an iPhone simulator.
2. Build and run. Onboarding explains the demo boundary.
3. For barcode scanning, use a physical iPhone; the simulator offers manual barcode entry.

Run `xcodebuild -project SmartERPMobile.xcodeproj -scheme SmartERPMobile -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` for the included domain tests.

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

**Suggested walkthrough:** Start at `App/SmartERPApp.swift`: it creates `DemoStore` and injects it into the UI. `App/RootView.swift` chooses the welcome screen or the five main tabs. Open a feature folder to show its SwiftUI screens. The screens read models from `Domain/Models.swift` and call methods on `Data/DemoStore.swift` to change local data. `DemoStore` saves a JSON snapshot on the device. `Core/APIClient.swift` is only a foundation for future backend integration; the current screens do not call it.

For a concrete example, demonstrate **Purchasing → New purchase → Receive goods**. The shared transaction form creates a purchase draft through `DemoStore.addPurchase`; `ReceivingForm` calls `DemoStore.receive`, which caps received quantities and updates the matching product's local stock. `SmartERPTests/DomainTests.swift` checks this partial receipt rule. This shows the UI, data flow, and a tested business rule in one short path.

## Backend contracts needed before a commercial beta

The Inventolo API specification and credentials were not supplied. The app deliberately does not guess endpoints. Integration needs documented contracts for: authentication and token refresh; tenant/branch selection; permissions; customers and products; authoritative inventory availability and movements; orders, purchases, partial receipts, invoices and payments; dashboard and reports; location session and visit events; notification registration and delivery. Every mutation needs an idempotency key and a server response that distinguishes draft, accepted and posted states. Tenant and branch identifiers must be validated on the server.

`Core/APIClient.swift` contains a typed HTTPS client and Keychain token storage ready for an adapter once those contracts exist. `DemoStore` is an isolated local JSON repository and never masquerades as a server response. SwiftData-backed encrypted caches and a durable offline sync queue remain production work.

## Native capabilities and privacy

- Camera usage is declared for barcode capture. Scanning never posts stock movements.
- Foreground location permission is requested only after a salesperson starts an explicit demo work session. The map shows demo team positions with timestamps and labels them as sample data.
- Background location, geofence monitoring, APNs, widgets and Live Activities require approved product behavior, backend contracts, entitlements and physical-device validation. They are not enabled in this prototype.
- No employee location is silently collected. Ending a session stops location updates.

## Production checklist

Connect the documented API; add server permission checks and token refresh; implement encrypted/isolated caches and a durable sync queue; add App Group and Widget extension after shared-data privacy rules are agreed; configure APNs and server delivery; add localization for Sinhala and Tamil; test camera, location and notifications on physical devices; complete accessibility and App Store privacy review.
