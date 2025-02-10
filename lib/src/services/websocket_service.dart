import 'dart:async';
import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart';

class WebsocketService {
  Socket? socket;
  final String _socketUrl = 'http://192.168.0.179:3000';

  WebsocketService._();
  static final instance = WebsocketService._();

  final Completer<void> _socketConnCompleter = Completer<void>();

  Future<void> connect() async {
    socket = io(
      _socketUrl,
      OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );

    socket!.connect();

    socket!.onConnect((_) async {
      log('Socket Connected');
      log('Socket ID: ${socket!.id!}');
      _socketConnCompleter.complete();
    });

    socket!.onDisconnect((reason) {
      log('Socket disconnected');
      if (reason == 'io server disconnect') {
        socket!.connect();
      }
    });

    socket!.onError((e) {
      log("Socket Error: $e");
      _socketConnCompleter.completeError(e);
    });

    socket!.on('server_response', (data) => log('Server response: $data'));
  }

  Future<void> waitUntilSocketConnected() {
    return _socketConnCompleter.future;
  }
}