import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sip_ua/src/sip_ua_helper.dart';
import 'package:sip_ua/src/transports/websocket_dart_impl.dart';
import 'package:test/test.dart';

// Loopback integration tests: raw peers intentionally do not answer WS ping.
// No production network or machine firewall changes are involved.
void main() {
  for (final bool allowBadCertificate in <bool>[false, true]) {
    group('native WebSocket (allowBadCertificate=$allowBadCertificate)', () {
      late HttpServer server;
      late SIPUAWebSocketImpl client;
      final List<Socket> peers = <Socket>[];
      late WebSocketSettings settings;

      setUp(() async {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        client = SIPUAWebSocketImpl('ws://127.0.0.1:${server.port}/sip', 0);
        settings = WebSocketSettings()
          ..allowBadCertificate = allowBadCertificate;
      });
      tearDown(() async {
        client.close();
        for (final Socket peer in peers) {
          peer.destroy();
        }
        peers.clear();
        await server.close(force: true);
      });

      Future<Socket> upgrade(HttpRequest request) async {
        final String accept = base64.encode(sha1
            .convert(utf8.encode('${request.headers.value('Sec-WebSocket-Key')}'
                '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
            .bytes);
        request.response
          ..statusCode = HttpStatus.switchingProtocols
          ..headers.set('Connection', 'Upgrade')
          ..headers.set('Upgrade', 'websocket')
          ..headers.set('Sec-WebSocket-Accept', accept)
          ..headers.set('Sec-WebSocket-Protocol', 'sip');
        final Socket peer = await request.response.detachSocket();
        peers.add(peer);
        return peer;
      }

      test('missing pong closes an opted-in connection', () async {
        final Completer<void> ping = Completer<void>();
        final Completer<int?> closed = Completer<int?>();
        server.listen((HttpRequest request) async {
          final Socket peer = await upgrade(request);
          peer.listen((Uint8List bytes) {
            if (bytes.isNotEmpty &&
                bytes.first & 0x0f == 9 &&
                !ping.isCompleted) {
              ping.complete();
            }
          });
        });
        settings.pingInterval = const Duration(milliseconds: 100);
        // Exercise the custom-client production path as well as the test path.
        settings.connectionTimeout = const Duration(seconds: 1);
        client.onClose = (int? code, _) => closed.complete(code);
        client.connect(protocols: <String>['sip'], webSocketSettings: settings);

        await ping.future.timeout(const Duration(seconds: 5));
        expect(await closed.future.timeout(const Duration(seconds: 5)),
            WebSocketStatus.goingAway);
      });

      test('default settings keep a silent connection open without ping',
          () async {
        final Completer<void> opened = Completer<void>();
        final List<int> received = <int>[];
        bool closed = false;
        server.listen((HttpRequest request) async {
          final Socket peer = await upgrade(request);
          peer.listen(received.addAll);
        });
        client.onOpen = opened.complete;
        client.onClose = (_, __) => closed = true;
        client.connect(protocols: <String>['sip'], webSocketSettings: settings);
        await opened.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 350));
        expect(received, isEmpty);
        expect(closed, isFalse);
      });

      test('pong keeps the connection usable with a configured timeout',
          () async {
        final Completer<void> opened = Completer<void>();
        final Completer<void> echoed = Completer<void>();
        bool closed = false;
        server.listen((HttpRequest request) async {
          final WebSocket peer = WebSocket.fromUpgradedSocket(
              await upgrade(request),
              serverSide: true);
          peer.listen(peer.add);
        });
        settings
          ..pingInterval = const Duration(milliseconds: 100)
          ..connectionTimeout = const Duration(seconds: 1);
        client.onOpen = opened.complete;
        client.onClose = (_, __) => closed = true;
        client.onMessage = (dynamic data) {
          expect(data, 'after several pongs');
          echoed.complete();
        };
        client.connect(protocols: <String>['sip'], webSocketSettings: settings);
        await opened.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 350));
        client.send('after several pongs');
        await echoed.future.timeout(const Duration(seconds: 5));
        expect(closed, isFalse);
      });

      test('configures TCP timeout for connection attempts',
          () async {
        final _FailingHttpClient httpClient = _FailingHttpClient();
        final Completer<int?> closed = Completer<int?>();
        settings.connectionTimeout = const Duration(seconds: 10);
        client.onClose = (int? code, _) => closed.complete(code);
        HttpOverrides.runZoned(
          () => client
              .connect(protocols: <String>['sip'], webSocketSettings: settings),
          createHttpClient: (_) => httpClient,
        );
        expect(await closed.future.timeout(const Duration(seconds: 5)), 500);
        expect(httpClient.connectionTimeout, const Duration(seconds: 10));
        if (!allowBadCertificate) {
          expect(httpClient.closed, isTrue);
        }
        expect(httpClient.acceptsBadCertificate, allowBadCertificate);
      });
    });
  }
}

class _FailingHttpClient implements HttpClient {
  @override
  Duration? connectionTimeout;
  bool closed = false;
  bool acceptsBadCertificate = false;

  @override
  set badCertificateCallback(
      bool Function(X509Certificate, String, int)? callback) {
    acceptsBadCertificate = callback != null;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      throw const SocketException('test connect failure');

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);

  @override
  void close({bool force = false}) => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
