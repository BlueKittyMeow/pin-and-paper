# iOS TestFlight Setup Guide

Complete guide to building signed iOS IPA files via GitHub Actions and distributing via TestFlight.

---

## Prerequisites

- **Apple Developer Account**: $99/year (https://developer.apple.com/programs/)
- **Mac access**: Needed for one-time certificate generation (Mac Mini or borrowed Mac)
- **iPad for testing**: Your iPad Air

---

## Part 1: Apple Developer Setup (One-Time, Requires Mac)

### Step 1.1: Create App Identifier

1. Go to: https://developer.apple.com/account/resources/identifiers/list
2. Click **"+"** to add new identifier
3. Select **"App IDs"** → Continue
4. Select **"App"** → Continue
5. Fill in:
   - **Description**: `Pin and Paper`
   - **Bundle ID**: `com.bluekitty.pinandpaper` (Explicit)
   - **Capabilities**: None needed yet
6. Click **Continue** → **Register**

### Step 1.2: Create Distribution Certificate

**On Mac Terminal:**

```bash
# Create workspace
mkdir ~/ios-signing && cd ~/ios-signing

# Generate private key
openssl genrsa -out pin_and_paper.key 2048

# Create Certificate Signing Request (CSR)
openssl req -new -key pin_and_paper.key \
  -out CertificateSigningRequest.certSigningRequest \
  -subj "/emailAddress=your@email.com, CN=Your Name, C=US"
```

**On Apple Developer Portal:**

1. Go to: https://developer.apple.com/account/resources/certificates/list
2. Click **"+"** → Select **"Apple Distribution"** → Continue
3. Upload `CertificateSigningRequest.certSigningRequest`
4. Download: `distribution.cer`

**Back in Terminal:**

```bash
# Convert certificate to PEM format
openssl x509 -in distribution.cer -inform DER \
  -out distribution.pem -outform PEM

# Create .p12 file (PKCS12 format)
openssl pkcs12 -export -out distribution.p12 \
  -inkey pin_and_paper.key -in distribution.pem

# Enter export password when prompted
# Example: PinAndPaper2025!
# REMEMBER THIS PASSWORD - you'll need it for GitHub Secrets
```

### Step 1.3: Create Provisioning Profile

1. Go to: https://developer.apple.com/account/resources/profiles/list
2. Click **"+"** → Select **"App Store"** → Continue
3. **App ID**: Select "Pin and Paper" → Continue
4. **Certificate**: Select your distribution certificate → Continue
5. **Profile Name**: `Pin and Paper App Store`
6. Click **Generate** → Download: `PinAndPaper_AppStore.mobileprovision`

---

## Part 2: Encode Signing Assets for GitHub

**In Terminal (still in ~/ios-signing/):**

```bash
# 1. Encode distribution certificate
base64 -i distribution.p12 -o distribution_base64.txt
cat distribution_base64.txt | pbcopy
# Certificate is now in clipboard - paste into GitHub Secret

# 2. Encode provisioning profile
base64 -i PinAndPaper_AppStore.mobileprovision -o provisioning_base64.txt
cat provisioning_base64.txt | pbcopy
# Profile is now in clipboard - paste into GitHub Secret
```

**Save this info for GitHub Secrets:**
- ✅ distribution_base64.txt contents → `IOS_DISTRIBUTION_CERT`
- ✅ provisioning_base64.txt contents → `IOS_PROVISIONING_PROFILE`
- ✅ Your .p12 export password → `IOS_CERT_PASSWORD`

---

## Part 3: App Store Connect Setup

### Step 3.1: Create App Record

1. Go to: https://appstoreconnect.apple.com/apps
2. Click **"+"** (My Apps) → **"New App"**
3. Fill in:
   - **Platform**: iOS
   - **Name**: `Pin and Paper`
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: Select `com.bluekitty.pinandpaper`
   - **SKU**: `pinandpaper` (unique identifier)
   - **User Access**: Full Access
4. Click **Create**

### Step 3.2: Enable TestFlight

1. In App Store Connect, go to your app
2. Navigate to **TestFlight** tab
3. **Internal Testing** is automatically enabled
4. Add yourself as an internal tester:
   - Go to **App Store Connect Users and Access**
   - Add your Apple ID if not already there
   - Assign "Internal Tester" role

---

## Part 4: Configure GitHub Secrets

1. Go to: https://github.com/BlueKittyMeow/pin-and-paper/settings/secrets/actions
2. Click **"New repository secret"** for each:

### Required Secrets:

| Secret Name | Value | Where to Get It |
|-------------|-------|-----------------|
| `IOS_DISTRIBUTION_CERT` | Base64 encoded distribution.p12 | Part 2, Step 1 |
| `IOS_PROVISIONING_PROFILE` | Base64 encoded .mobileprovision | Part 2, Step 2 |
| `IOS_CERT_PASSWORD` | Your .p12 export password | Part 1.2 (password you created) |

### Optional (for auto-upload to TestFlight):

| Secret Name | Value | Where to Get It |
|-------------|-------|-----------------|
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID (e.g., ABC123XYZ) | App Store Connect → Users & Access → Keys |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (UUID format) | Same page as Key ID |
| `APP_STORE_CONNECT_API_KEY` | Base64 encoded .p8 file | Download .p8, encode: `base64 -i AuthKey_*.p8` |

---

## Part 5: Update Bundle Identifier in Project

**On Linux (your dev machine):**

Update the Xcode project to use your new Bundle ID:

```bash
cd pin_and_paper

# Update bundle identifier
sed -i 's/com.example.pinAndPaper/com.bluekitty.pinandpaper/g' \
  ios/Runner.xcodeproj/project.pbxproj

# Verify the change
grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj
# Should show: com.bluekitty.pinandpaper
```

---

## Part 6: Run GitHub Actions Workflow

### Manual Trigger:

1. Go to: https://github.com/BlueKittyMeow/pin-and-paper/actions
2. Select **"iOS Build & TestFlight"** workflow
3. Click **"Run workflow"** dropdown
4. Select branch (e.g., `main`)
5. Click **"Run workflow"**

### Workflow Progress:

- ⏱️ Build time: ~8-12 minutes
- 📦 Output: Signed `.ipa` file
- ✅ Success: IPA uploaded as artifact + (optionally) to TestFlight

### Download IPA:

1. Go to workflow run page
2. Scroll to **"Artifacts"** section
3. Download: `ios-ipa-signed.zip`
4. Unzip to get: `pin_and_paper.ipa`

---

## Part 7: Install on iPad

### Method A: TestFlight (Recommended)

If you enabled auto-upload (Part 4, optional secrets):

1. Install **TestFlight** app on iPad from App Store
2. Sign in with your Apple ID (same as internal tester)
3. App should appear automatically
4. Tap **Install** → Test!

### Method B: Manual Install via Xcode

If TestFlight auto-upload is not configured:

1. **On Mac**, open Xcode
2. Connect iPad via USB or WiFi
3. Go to **Window** → **Devices and Simulators**
4. Select your iPad
5. Click **"+"** under **"Installed Apps"**
6. Select downloaded `pin_and_paper.ipa`
7. App installs on iPad

### Method C: Apple Configurator (No Xcode)

1. Download **Apple Configurator 2** (Mac App Store)
2. Connect iPad
3. Drag `.ipa` file onto iPad in Configurator
4. App installs

---

## Troubleshooting

### "Untrusted Developer" on iPad

1. iPad Settings → General → VPN & Device Management
2. Tap your developer profile
3. Tap **Trust**

### Build Fails: "Code signing error"

- Check GitHub Secrets are correct (no extra spaces/newlines)
- Verify .p12 password matches
- Ensure Bundle ID matches provisioning profile

### Build Fails: "Provisioning profile expired"

- Provisioning profiles expire after 12 months
- Regenerate on Apple Developer portal
- Re-encode and update GitHub Secret

### TestFlight: "This build is invalid"

- Ensure `CFBundleVersion` (build number) increments each build
- Check Info.plist has correct version/build numbers

---

## Quick Reference

### Commands Summary:

```bash
# 1. Generate certificates (Mac, one-time)
cd ~/ios-signing
openssl genrsa -out pin_and_paper.key 2048
openssl req -new -key pin_and_paper.key -out CSR.certSigningRequest -subj "..."
# Upload CSR to Apple, download distribution.cer
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM
openssl pkcs12 -export -out distribution.p12 -inkey pin_and_paper.key -in distribution.pem

# 2. Encode for GitHub (Mac)
base64 -i distribution.p12 | pbcopy
base64 -i PinAndPaper_AppStore.mobileprovision | pbcopy

# 3. Update bundle ID (Linux dev machine)
cd pin_and_paper
sed -i 's/com.example.pinAndPaper/com.bluekitty.pinandpaper/g' ios/Runner.xcodeproj/project.pbxproj

# 4. Run workflow (GitHub UI)
# Actions → iOS Build & TestFlight → Run workflow

# 5. Install (iPad)
# TestFlight app → Auto-appears
```

---

## Cost Summary

- **Apple Developer Program**: $99/year
- **GitHub Actions (macOS runners)**: Free for public repos
- **Per build**: ~10 minutes = FREE (public repo) or ~$0.08 (private repo)

---

## Next Steps

1. ✅ Sign up for Apple Developer Program ($99/year)
2. ✅ Wait for Mac Mini reassembly (or borrow Mac for 1 hour)
3. ✅ Follow Part 1-4 to generate certificates (one-time setup)
4. ✅ Update Bundle ID (Part 5)
5. ✅ Commit workflow file to GitHub
6. ✅ Run workflow → Get IPA → Install on iPad!

---

**Questions?** Check the workflow logs on GitHub Actions for detailed error messages.
