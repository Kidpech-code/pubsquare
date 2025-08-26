// Stub for platforms without dart:io (e.g., Web). Always returns false.
Future<bool> performDnsLookup(List<String> hosts, Duration timeout) async {
  return false;
}
