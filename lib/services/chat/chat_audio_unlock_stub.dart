/// Non-web platforms have no browser autoplay policy: nothing to unlock.
void unlockWebAudioOnGesture() {}

/// Non-web platforms: no browser audio diagnostics.
String describeWebAudioEnvironment() => 'native';
