# Google Maps Setup Guide for Ntwaza

## Issue: Map Not Displaying in APK/Release Build

If the map is showing correctly in debug mode but not in release APK, follow these steps:

### 1. Get Your Release SHA-1 Fingerprint

#### Option A: Using Gradle (Recommended)
```bash
cd android
./gradlew signingReport
```

Look for the **SHA-1** under `Variant: release` section.

#### Option B: Using Keytool
For debug build:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

For release build (if you have your signing key):
```bash
keytool -list -v -keystore /path/to/your-release-key.keystore -alias your-key-alias
```

### 2. Add SHA-1 to Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one if you haven't)
3. Navigate to **APIs & Services** > **Credentials**
4. Click on your Android API key (or create one)
5. Under **Application restrictions**, choose **Android apps**
6. Click **Add an item** and enter:
   - **Package name**: `com.ntwaza.ntwaza`
   - **SHA-1 certificate fingerprint**: [Your SHA-1 from step 1]
7. Add BOTH debug and release SHA-1 fingerprints
8. Click **Save**

### 3. Enable Required APIs

Make sure these APIs are enabled in Google Cloud Console:

1. **Maps SDK for Android** ✅
2. **Places API** ✅
3. **Geocoding API** ✅

To enable:
- Go to **APIs & Services** > **Library**
- Search for each API
- Click **Enable**

### 4. Verify API Key in Project

The API key should be in `android/local.properties`:
```properties
GOOGLE_MAPS_ANDROID_KEY=your-google-maps-android-key
```

⚠️ **Important**: This key is currently in `local.properties` which is gitignored. For production:
- Consider using environment variables
- Or hardcode it in `AndroidManifest.xml` (less secure)
- Or use Google's recommended secrets management

For web builds, keep the browser key out of Git as well:

```bash
copy web\maps-config.example.js web\maps-config.js
```

Then set `googleMapsWebKey` in `web/maps-config.js` locally before building or deploying web.

### 5. Test the Release Build

After adding SHA-1 fingerprints:

```bash
flutter clean
flutter build apk --release
flutter install
```

Or for app bundle:
```bash
flutter build appbundle --release
```

### 6. Common Issues

#### Map shows gray/blank screen
- **Cause**: API key not authorized for release SHA-1
- **Fix**: Add release SHA-1 to Google Cloud Console

#### Map works in debug but not release
- **Cause**: Only debug SHA-1 is registered
- **Fix**: Add both debug AND release SHA-1 fingerprints

#### "Authorization failure" error
- **Cause**: Package name or SHA-1 mismatch
- **Fix**: Verify package name is exactly `com.ntwaza.ntwaza`

#### Map loads slowly
- **Cause**: Network issues or quota limits
- **Fix**: Check internet connection and API quotas in Cloud Console

### 7. ProGuard Rules

The project already has ProGuard rules in `android/app/proguard-rules.pro`:

```proguard
# Google Maps (already added)
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
```

These ensure Google Maps classes aren't stripped during release builds.

### 8. Permissions Check

Verify these permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

✅ Already configured in your project!

### 9. Testing Checklist

Before releasing:

- [ ] Debug build shows map correctly
- [ ] Release build shows map correctly
- [ ] Location permission requested on first launch
- [ ] "My Location" button works
- [ ] Search functionality works
- [ ] Address lookup works (requires Geocoding API)
- [ ] Map loads within 5 seconds on good connection

### 10. Monitoring & Quotas

Monitor your API usage:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. **APIs & Services** > **Dashboard**
3. Check usage and set up billing alerts

**Free tier limits**:
- Maps SDK: $200 free credit/month
- Geocoding: $200 free credit/month
- Places: $200 free credit/month

### Need Help?

If maps still don't work after following all steps:

1. Check logcat for errors: `adb logcat | grep -i "maps\|google"`
2. Verify API key is valid in Cloud Console
3. Ensure billing is enabled (required even for free tier)
4. Try creating a new API key
5. Clear app data and reinstall

---

**Last Updated**: March 2026
**Current API Key**: Configured in `local.properties`
**Project Package**: `com.ntwaza.ntwaza`
