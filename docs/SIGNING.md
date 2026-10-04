# Signing and distribution

Sandbox Lens v0.1.0 is packaged as a universal arm64/x86_64 app and ad-hoc signed with Hardened Runtime enabled. It is not signed with an Apple Developer ID certificate and is not notarized.

## What the signature establishes

The ad-hoc signature lets macOS and the release scripts detect changes after staging. Strict `codesign` verification confirms the internal bundle seal at the time of inspection. It does not establish a verified developer identity, Apple notarization, or Gatekeeper approval.

The app is not App Sandbox enabled. Reading the standard system sandbox-profile directories is the product’s core function and is not compatible with a conventional container-only policy. The app still runs as the current user and has no privileged helper or elevation path.

## Verify a downloaded release

From the folder containing both release files:

```sh
shasum -a 256 -c SHA256SUMS.txt
unzip Sandbox-Lens-v0.1.0-macOS-universal.zip
codesign --verify --deep --strict --verbose=2 "Sandbox Lens.app"
lipo -archs "Sandbox Lens.app/Contents/MacOS/SandboxLens"
codesign -d --verbose=4 "Sandbox Lens.app" 2>&1
```

The architecture command should report `x86_64 arm64` in either order. Signature details should show an ad-hoc signature and runtime version. `spctl --assess` is expected to reject this initial build because it has no Developer ID/notarization ticket.

## Open the initial build safely

After verifying the checksum, Control-click **Sandbox Lens.app**, choose **Open**, and confirm once. Do not disable Gatekeeper globally and do not remove quarantine recursively from unrelated files.

## Future signed distribution

A future Developer ID release requires an authorized `Developer ID Application` identity, timestamped signing, notarization through Apple’s notary service, stapling, and a clean downloaded-artifact Gatekeeper test. Those steps cannot be truthfully simulated without the certificate and Apple credentials.
