# Hynox Café Workspace

Flutter app for Android, iOS and the browser. This version is a frontend with device-local storage and no backend.

## Workspaces

Common login opens the Hynox team dashboard or the account's vendor workspace.

- Team: vendor totals, subscription status, vendor creation and editing, published subscription plans, profile and password settings.
- Vendor: orders, received payments, bills, customer details, reports, business settings and subscription requests.
- Creating a vendor with shop details, mobile number and password creates a separate, empty workspace with a 15-day trial.

Accounts and saved data remain on the current device or browser. They do not synchronize between devices. Subscription controls record status without collecting payments.

## Billing

New orders require the customer's name and WhatsApp number. Choose Cash, UPI or Card and press Submit to record payment. This opens a WhatsApp text bill with a greeting and review request; the sender must tap Send in WhatsApp. Configure the shop's actual review URL in business settings.

PDF bills remain available as merchant downloads. Reports export all saved data to an Excel workbook. Backup exports the complete vendor workspace as JSON.

## Run

From this folder:

```powershell
.\flutter-local.ps1 pub get
.\flutter-local.ps1 run -d chrome --web-port=8766
```

For Android, connect an unlocked phone with USB debugging enabled and double-click RUN-ANDROID.cmd. START-HYNOS.cmd starts the browser version.

```powershell
.\flutter-local.ps1 analyze --no-pub lib test
.\flutter-local.ps1 test --no-pub
.\flutter-local.ps1 build apk --debug --target-platform android-arm64
```

See FLUTTER-SETUP.md for SDK and PATH configuration, and VALIDATION.md for completed checks.
