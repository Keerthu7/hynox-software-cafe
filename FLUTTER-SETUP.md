# Flutter development on this computer

Flutter is installed at:

`C:\Users\keert\Documents\Codex\2026-10-12\hynos-company-work-h-y-n\work\flutter`

The SDK's bin folder is in the Windows user PATH. Restart PowerShell and your editor, or refresh an existing PowerShell window:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
flutter --version
flutter devices
flutter run -d RZCY40JG2MD
```

Run from the project's main folder. For another phone, use the ID listed by flutter devices.

- Flutter 3.47.7 / Dart 3.13.5.
- Android SDK: `C:\Users\keert\AppData\Local\Android\Sdk`.
- Java: `C:\Program Files\Java\jdk-17`.
- Package cache: `C:\Users\keert\AppData\Local\Pub\Cache`.
- Samsung SM M356B: `RZCY40JG2MD`.

Connect the phone, unlock it, enable USB debugging and approve the computer. RUN-ANDROID.cmd launches the app on one connected Android phone. START-HYNOS.cmd starts Chrome on port 8766. Both use the local SDK directly.

The app needs no backend or USB port forwarding. Accounts, bills and settings are stored separately on each device or browser.

The SDK was restored from the installer ZIP, which was deleted with your approval. The Windows launcher includes the official $git to git correction documented at https://github.com/flutter/flutter/issues/187907. A missing SDK fallback Roboto font was restored from the SDK's bundled material-font cache.
