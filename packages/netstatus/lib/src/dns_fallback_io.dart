import 'dart:async';
import 'dart:io';

Future<bool> performDnsLookup(List<String> hosts, Duration timeout) async {
  for (final h in hosts) {
    try {
      final result = await InternetAddress.lookup(h).timeout(timeout);
      if (result.isNotEmpty) return true;
    } catch (_) {
      // try next
    }
  }
  return false;
}
