/// Non-web platforms always record AAC (.m4a); nothing to negotiate.
bool mediaRecorderSupports(String mimeType) => false;

/// Non-web platforms: no browser recording diagnostics.
String describeWebRecordingSupport() => 'native';
