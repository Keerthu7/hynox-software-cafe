# Frontend update — 13 October 2026

- Restored Flutter 3.47.7 / Dart 3.13.5; verified Flutter version and Samsung SM M356B discovery.
- Fixed SDK and launcher paths for the project at its current root, and configured Windows user PATH and VS Code.
- Common login, team vendor creation, subscription management, profile editing and vendor workspaces now use device-local storage without a backend.
- Analysis of lib and test passed without issues. Existing billing/export checks passed. Four local-account and mobile-navigation checks passed after fixing the menu's Material background.
- Source archive excludes the SDK, build files and private access notes.

The notes below concern the earlier backend version.

# Latest WhatsApp change

Customer WhatsApp delivery is text-only. Submit opens a prepared text bill when Business Platform is unconfigured; the user must tap Send. The PDF remains a merchant download. Text format and provider payload tests passed; no real messages were sent. Review requests are included; a real shop review URL must be configured by its owner.

Final text-bill APK installed and launched successfully on Samsung SM M356B after USB reconnection. Native app process 20488 was running and the startup error check was clear. The latest APK is ../Hynox-Android.apk. Physical WhatsApp sending and Android Save As interaction remain user checks; no real messages were sent by these tests.

# Latest billing update — 13 October 2026

- Live common-login API verified for the two owner-provided vendor accounts and Hynox team account. Dashboard role/shop comes from the account, not URL parameters. Arbitrary credentials are rejected.
- Existing shop data preserved; SQLite backup saved before account migration. Passwords stored as salted scrypt hashes. Password change verifies the current password and revokes other sessions.
- 20 Flutter tests passed, including customer-required validation, explicit payment Submit, money/refund history, PDF generation, and workbook export. The additional WhatsApp text-format test passed (21 checks total).
- 13 Python backend tests passed: role/shop isolation, revision conflicts, required customer details, text-only template submission (no media upload or PDF attachment), missing-provider behavior, duplicate prevention, uncertain submission handling, and password changes.
- Analysis has no errors or warnings; one existing package-name style information notice remains.
- Web release build succeeded. Common login visually verified at http://127.0.0.1:8766/ with demo/portal labels removed.
- Receipt sample rendered and visually checked: one page, accented name, paid amount, greeting, clickable review link and QR code. Excel opened independently with correct totals and phone/text cells; formula-looking customer names remain plain text.
- Initial updated Android debug APK built, installed and launched on Samsung SM M356B. Native startup error log was empty. Final rebuild includes the Android Save As implementation.
- No WhatsApp Business sender is connected. No real messages were sent. Provider behavior was tested using mocks. API acceptance is not confirmed delivery.
- Physical phone Save As interaction, iOS, release signing, hosted HTTPS operation and live WhatsApp delivery have not been verified.

## Earlier verification history

# Validation — Hynox 0.2

13 October 2026, Windows, Flutter 3.47.7 / Dart 3.13.5.

- Flutter analyze: passed, no issues.
- Flutter tests: 16 passed. Includes desktop paid-order and phone pay-later journeys, persistence failures, exact money, tax/discount rounding, legacy data and PDF generation with greeting/review QR.
- Python backend tests: 7 passed. Covers unauthorized requests, portal/shop isolation, team restrictions, conflicting revisions, logout revocation and invalid prices. SQLite connections are closed after transactions.

Live WhatsApp, payments, cloud deployment, subscription collection, Android/iOS builds and statutory tax compliance are not validated or implemented. PDF library warns about Unicode; the app uses an ASCII fallback.

- Release web build passed; local API health check passed. Updated vendor sign-in screen visually verified in the browser.

Android verification on 13 October 2026: debug APK built, installed and launched on Samsung SM M356B (Android 16). Flutter first-frame and VM-service startup confirmed; USB backend forwarding verified. Native PDF sharing and live WhatsApp delivery are not covered by this startup check.

