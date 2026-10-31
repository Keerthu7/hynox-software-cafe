# BillDesk Version 2: Vercel, Neon and WhatsApp

Version 1 remains the device-local app. Version 2 uses the Vercel API and Neon database. The production web build enables the remote API automatically; local and Android builds remain in Version 1 mode unless the remote flag and API URL are supplied.

## Before the first V2 web test

The Connect button appears only after signing in to a V2 vendor account. Before testing the Vercel site, make sure its project is deploying this repository and add the following minimum Vercel environment variables: `DATABASE_URL`, `HYNOX_ADMIN_PHONE`, `HYNOX_ADMIN_PASSWORD`, `META_APP_ID`, `META_APP_SECRET`, `META_CONFIG_ID`, `BILLDESK_WEB_URL`, and `WHATSAPP_TOKEN_ENCRYPTION_KEY`. Connect Neon before the first API request. Set `BILLDESK_WEB_URL` to `https://hynox-software-cafe.vercel.app` if that is the deployment domain you will use. The build reads the Meta app ID/config ID and website URL to enable the browser signup button and its callback.

After deployment, sign in with the initial Hynox team phone/password, create a vendor account, then sign in as that vendor and open **Settings → WhatsApp**. The approved receipt template and webhook verify token are needed for full receipt delivery/status updates; they are not substitutes for the minimum login and connection settings above.

## 1. Create and connect Neon

1. Create a Neon project in the region nearest the Vercel deployment.
2. In Vercel, open the BillDesk project and add Neon from **Storage / Marketplace Integrations**. Select the Neon project and allow it to add `DATABASE_URL` to the Vercel environment.
3. Deploy after adding environment variables. The API creates its tables and the starter subscription plan on its first request.

## 2. Add Vercel environment variables

Add these under the Vercel project’s **Settings → Environment Variables** for Production (and Preview if needed):

| Variable | Value |
| --- | --- |
| `HYNOX_ADMIN_PHONE` | Hynox team login phone, 10 digits |
| `HYNOX_ADMIN_PASSWORD` | One-time strong password; remove this variable after the first successful API deployment/account creation |
| `META_APP_ID` | BillDesk Meta app ID |
| `META_APP_SECRET` | BillDesk Meta app secret; secret only, never add to Flutter |
| `META_CONFIG_ID` | The Embedded Signup configuration ID used by this deployment |
| `BILLDESK_WEB_URL` | Deployed HTTPS origin, for example `https://billdesk.example.com` (needed for native app signup handoff) |
| `META_GRAPH_API_VERSION` | A Graph API version currently supported by the Meta app |
| `META_WEBHOOK_VERIFY_TOKEN` | A random private string you create and also enter in Meta Webhooks |
| `WHATSAPP_TOKEN_ENCRYPTION_KEY` | Base64 encoding of a randomly generated 32-byte key |
| `WHATSAPP_RECEIPT_TEMPLATE` | Exact name of an approved WhatsApp Utility template |
| `WHATSAPP_RECEIPT_TEMPLATE_LANGUAGE` | Exact approved template language code, such as `en` or `en_US` |

To create the encryption value on Windows PowerShell, run `$bytes = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Fill($bytes); [Convert]::ToBase64String($bytes)` and paste its output into Vercel. Generate a new value for production and store a secure backup.

Use `.env.example` as the list of names, never as a place to commit real secrets. The encryption key is required to decrypt saved vendor tokens; back it up securely and do not rotate it without a migration plan.

## 3. Prepare Meta Embedded Signup

The BillDesk app needs WhatsApp Business Platform and Facebook Login for Business configured for a Tech Provider onboarding flow. Configure the deployed BillDesk web origin and the Meta redirect/origin allowlists in the app settings. Set the `META_CONFIG_ID` to the configuration ID that you intend to use for your vendor signup flow. Meta's current Embedded Signup steps are in its [official Postman documentation](https://www.postman.com/meta/whatsapp-business-platform/documentation/du6gzjv/embedded-signup).

For this Tech Provider flow, configure the **system-user access token** option and use the expiry choice shown by Meta for your app. The saved configuration the team previously created is labeled as a 60-day expiry token, so treat connected vendor accounts as expiring unless Meta confirms the resulting business token does not expire. This code records an expiry when Meta returns one, but it does not silently renew an expiring token. Plan to reauthorize before expiry if Meta returns a 60-day token. Meta's v4 migration instructions require moving v2/v3 configs to v4; those earlier configurations stopped onboarding new businesses on October 15, 2026, so check that the saved ID is a v4 config before using it.

If using WhatsApp Coexistence, make sure the Meta configuration is the supported Embedded Signup version and includes the appropriate coexistence setup. Do not assume an older saved configuration ID supports coexistence just because it was created from a Meta template. Confirm the setup with the actual vendor number before onboarding more cafes.

## 4. Configure the Meta webhook

In the Meta app’s WhatsApp webhook configuration, use:

- Callback URL: `https://YOUR-VERCEL-DOMAIN/api/whatsapp-webhook`
- Verify token: the exact `META_WEBHOOK_VERIFY_TOKEN` value in Vercel
- Subscribe to the `messages` field so send, delivery, read and failure statuses can update BillDesk

The WhatsApp account is subscribed to the app when a cafe completes connection. Keep the app secret server-side so webhook signatures can be validated.

## 5. Create the receipt template

Create and get Meta approval for a WhatsApp **Utility** template with a **Document** header and three text body parameters in this order: customer name, cafe name, bill total. Set its exact template name and language in the Vercel variables. The API uploads the generated PDF receipt and supplies it as the template document header. Meta decides template eligibility, quality and delivery.

## 6. Deploy and create the first team login

1. Import the project repository into Vercel and set the project output directory to `build/web` (the repository’s `vercel.json` already sets it).
2. The build command is `npm run build`. It installs the current stable Flutter SDK in Vercel when one is not preconfigured and creates a remote-mode web build.
3. Deploy. Open `https://YOUR-VERCEL-DOMAIN/api/health`; a successful response is `{"ok":true}`.
4. Sign in using the 10-digit phone and one-time password configured for `HYNOX_ADMIN_*`.
5. Remove `HYNOX_ADMIN_PASSWORD` from Vercel after the first deployment has created the team account. The saved account can then change its password in BillDesk.
6. From the Hynox team workspace, create each cafe’s vendor login. Each cafe then connects its own WhatsApp Business account inside its vendor **Settings → WhatsApp** page.

## 7. Connect the cafe and send receipts

Open the deployed BillDesk site in Chrome, Edge, Firefox, Safari, or another current browser, sign in as that cafe, and choose **Settings → WhatsApp → Connect with Meta**. In the signup page, click **Continue with Facebook** so the browser allows Meta’s secure login. The cafe owner/admin chooses the cafe’s WhatsApp account in Meta. BillDesk saves the access token encrypted in Neon, associated with that cafe only. Staff do not need the owner’s WhatsApp Web session to remain logged in.

At payment time, BillDesk sends a receipt only when the customer has opted in to WhatsApp invoices. Check the order’s receipt status for accepted, delivered, read, or failed. The normal 24-hour customer-service window does not replace the approved template requirement for a business-initiated receipt.

## 8. Android / local development

Embedded Signup is launched in the device browser and returns to the BillDesk app using the registered `billdesk://whatsapp-connect` deep link. Android and iOS return schemes are configured in their platform projects. Build Android remote mode with the deployed API URL; include the app identifiers and web URL for the app signup handoff:

```powershell
.\flutter-local.ps1 build apk --release --dart-define=Hynox_REMOTE_API=true --dart-define=Hynox_API_URL=https://YOUR-VERCEL-DOMAIN/ --dart-define=Hynox_META_APP_ID=YOUR_META_APP_ID --dart-define=Hynox_META_CONFIG_ID=YOUR_META_CONFIG_ID --dart-define=Hynox_BILLDESK_WEB_URL=https://YOUR-VERCEL-DOMAIN
```

Without the remote flag, the existing local Version 1 behaviour remains selected. Never put a Meta access token, app secret, or encryption key in a Flutter define, source file, or mobile APK.

## What is implemented

- Neon tables for vendor workspaces, users, sessions, cafe WhatsApp connections and receipt delivery statuses.
- Vercel API functions for team/vendor login, vendor workspace sync, WhatsApp connection, receipt sends and the signed Meta webhook.
- Per-cafe encrypted Meta tokens and a separate sender number/account for every vendor.
- Browser Embedded Signup entry point and a real connection status / disconnect screen.
- PDF template receipt submission after a newly recorded payment; the staff member’s WhatsApp login is not used.
- Existing local Version 1 path remains available.

Deployment still requires the actual Vercel and Neon accounts, Meta app configuration, approved receipt template, and each cafe’s authorization. Those account actions cannot be completed from this source code alone.
