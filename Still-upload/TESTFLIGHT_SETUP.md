# TestFlight setup

The checked-in workflow is intentionally **manual-only**. It does nothing until someone opens GitHub Actions and chooses **Run workflow**. It also stops before checkout or signing when any required secret is missing.

> Apple requires the Apple Developer Program account holder to be an adult or a company. If the app is student-led, an adult or organization should own the membership, accept Apple's agreements, and control the signing material.

## What you need

You need an active paid [Apple Developer Program](https://developer.apple.com/programs/) membership, access to [App Store Connect](https://appstoreconnect.apple.com/), and repository-admin access in GitHub. Create the Still app record in App Store Connect with bundle ID `com.cocomedia.still`. The widget uses `com.cocomedia.still.widgets`.

## 1. Create the App Store Connect API key

In App Store Connect, open **Users and Access → Integrations → App Store Connect API**. Create a team API key with **App Manager** access. Download its `.p8` file immediately; Apple only offers the download once. Record the **Key ID** and **Issuer ID** shown on the page.

In GitHub, open the repository, then **Settings → Secrets and variables → Actions → New repository secret**. Add:

| Secret | What to paste |
|---|---|
| `ASC_KEY_ID` | The API Key ID. |
| `ASC_ISSUER_ID` | The Issuer ID. |
| `ASC_KEY_P8` | The complete text of the downloaded `.p8` file, including the BEGIN/END lines. |

## 2. Create the distribution certificate

On a trusted Mac, use Xcode's **Settings → Accounts → Manage Certificates** to create an **Apple Distribution** certificate. Open **Keychain Access → My Certificates**, select that certificate together with its private key, and export it as a password-protected `.p12` file.

Convert that binary file to one line in Terminal:

```sh
base64 < AppleDistribution.p12 | tr -d '\n'
```

Add two GitHub repository secrets:

| Secret | What to paste |
|---|---|
| `SIGNING_CERTIFICATE_P12_BASE64` | The one-line Base64 output. |
| `SIGNING_CERTIFICATE_PASSWORD` | The password chosen during `.p12` export. |

Treat the certificate, password, and API key as sensitive. Do not commit them or send them in chat.

## 3. Create both App Store profiles

In the [Apple Developer account](https://developer.apple.com/account/), create **App Store Connect** distribution provisioning profiles for both identifiers:

1. `com.cocomedia.still`
2. `com.cocomedia.still.widgets`

Download each `.mobileprovision` file. Convert each with the same command:

```sh
base64 < Still_AppStore.mobileprovision | tr -d '\n'
base64 < StillWidgets_AppStore.mobileprovision | tr -d '\n'
```

Add these GitHub repository secrets:

| Secret | What to paste |
|---|---|
| `APP_PROVISIONING_PROFILE_BASE64` | Base64 for the main app profile. |
| `WIDGET_PROVISIONING_PROFILE_BASE64` | Base64 for the widget profile. |

The profiles must belong to the same team as the distribution certificate. Regenerate them when capabilities or certificates change.

## 4. Check agreements and app information

In App Store Connect, resolve any banner asking the account holder to accept an updated agreement. Complete the app's basic information, privacy answers, age rating, export-compliance questions, and TestFlight contact details. Uploading a build does not publish the app.

Increment `CURRENT_PROJECT_VERSION` in `Still.xcodeproj` before each upload. App Store Connect rejects a build number already used for the same marketing version.

## 5. Run the workflow

Open **Actions → TestFlight → Run workflow**, choose the intended branch, and confirm. The workflow will:

1. list every missing secret and stop early if setup is incomplete;
2. install the API key, certificate, and two profiles on the temporary GitHub runner;
3. archive the Release configuration with `xcodebuild`;
4. export a signed `.ipa`; and
5. upload it to App Store Connect with the API key.

After upload, processing usually continues in App Store Connect. Open **TestFlight**, answer any compliance question, then add internal testers. External testing requires Apple's Beta App Review.

## Troubleshooting

If signing fails, first confirm that both provisioning profiles are **App Store Connect** profiles, have the exact bundle IDs above, and were generated after the current distribution certificate. If upload fails because a build already exists, increment the build number. If the workflow lists missing secrets, add exactly the names it prints; secrets are case-sensitive.

The workflow lives at `../.github/workflows/testflight.yml` because GitHub only recognizes workflow files at the repository root. It stays manual-only until the owner intentionally runs it.
