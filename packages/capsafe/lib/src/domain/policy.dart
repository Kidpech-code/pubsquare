class ProtectionPolicy {
  final bool androidFlagSecure;
  final bool iosOverlayOnCapture; // used for full overlay mode
  final bool iosAppSwitcherPrivacy;
  final bool
  allowAndroidScreenShare; // relax secure for legit flows (e.g., meetings)

  const ProtectionPolicy({
    required this.androidFlagSecure,
    required this.iosOverlayOnCapture,
    required this.iosAppSwitcherPrivacy,
    this.allowAndroidScreenShare = false,
  });

  factory ProtectionPolicy.secure() => const ProtectionPolicy(
    androidFlagSecure: true,
    iosOverlayOnCapture: true,
    iosAppSwitcherPrivacy: true,
  );

  ProtectionPolicy copyWith({
    bool? androidFlagSecure,
    bool? iosOverlayOnCapture,
    bool? iosAppSwitcherPrivacy,
    bool? allowAndroidScreenShare,
  }) {
    return ProtectionPolicy(
      androidFlagSecure: androidFlagSecure ?? this.androidFlagSecure,
      iosOverlayOnCapture: iosOverlayOnCapture ?? this.iosOverlayOnCapture,
      iosAppSwitcherPrivacy:
          iosAppSwitcherPrivacy ?? this.iosAppSwitcherPrivacy,
      allowAndroidScreenShare:
          allowAndroidScreenShare ?? this.allowAndroidScreenShare,
    );
  }
}
