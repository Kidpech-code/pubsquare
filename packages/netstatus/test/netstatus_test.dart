import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:netstatus/netstatus.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class _FakeConnectivity {
  final controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> current = const [ConnectivityResult.none];

  void emit(List<ConnectivityResult> results) {
    current = results;
    controller.add(results);
  }
}

class _HttpOkClient extends http.BaseClient {
  final int status;
  _HttpOkClient(this.status);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream<List<int>>.empty(), status);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('noNetwork emits noNetwork', () async {
    final fake = _FakeConnectivity();
    final service = NetStatusService(
      NetCheckConfig(
        httpClientFactory: () => _HttpOkClient(204),
        minIntervalBetweenChecks: const Duration(milliseconds: 1),
        emitNetworkOnlyBeforePing: false,
      ),
      fake.controller.stream,
      () async => fake.current,
    );

    // Start with none
    fake.emit(const [ConnectivityResult.none]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(service.lastStatus, NetStatus.noNetwork);
    service.dispose();
  });

  test('networkOnly when HTTP fails', () async {
    final fake = _FakeConnectivity();
    final service = NetStatusService(
      NetCheckConfig(
        httpClientFactory: () => _HttpOkClient(503),
        minIntervalBetweenChecks: const Duration(milliseconds: 1),
        emitNetworkOnlyBeforePing: false,
        retry: 0,
      ),
      fake.controller.stream,
      () async => fake.current,
    );
    // First, with no network
    await service.checkNow();
    // Then bring network up
    fake.emit(const [ConnectivityResult.wifi]);
    await service.checkNow();
    expect(service.lastStatus, NetStatus.networkOnly);
    service.dispose();
  });

  test('HEAD→GET fallback succeeds', () async {
    var calls = 0;
    final fake = _FakeConnectivity();
    final client = _HeadThenGetClient(() => calls++);
    final service = NetStatusService(
      NetCheckConfig(
        pingMethod: 'HEAD',
        httpClientFactory: () => client,
        minIntervalBetweenChecks: const Duration(milliseconds: 1),
        emitNetworkOnlyBeforePing: false,
        retry: 0,
      ),
      fake.controller.stream,
      () async => fake.current,
    );
    // First, with no network to flush initial
    await service.checkNow();
    // Then enable wifi and recheck
    fake.emit(const [ConnectivityResult.wifi]);
    await service.checkNow();
    expect(service.lastStatus, NetStatus.internet);
    expect(calls > 0, true);
    service.dispose();
  });
}

class _HeadThenGetClient extends http.BaseClient {
  final void Function() onSend;
  _HeadThenGetClient(this.onSend);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    onSend();
    if (request.method == 'HEAD') {
      // simulate 405
      return http.StreamedResponse(Stream<List<int>>.empty(), 405);
    }
    return http.StreamedResponse(Stream<List<int>>.empty(), 204);
  }
}
