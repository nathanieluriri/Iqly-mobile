# Android signing

Every build, debug and release, is signed with the iQLY upload key so Google
sign-in sees one certificate everywhere.

- Upload key SHA-1: `98:E6:4F:E7:1C:58:FC:15:A8:30:59:68:AC:DF:84:6E:24:F6:C9:9E`
- Package name: `net.iqly.app`
- The key file (`iqly-upload.jks`) and its passwords live in the owner's password manager. Never commit them.

## Local builds

Create `android/key.properties` (git ignores it):

```
storeFile=C:\\path\\to\\iqly-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

## CI

Repository secrets read by `.github/workflows/ci.yml`:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The `.jks` file, base64 encoded |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | The key password |

Without these, CI builds fall back to the runner's own debug key, which Google sign-in will reject.

Once the app is in Play Console, add the Play app signing key's SHA-1 (App integrity) to the same Google Android OAuth client.
