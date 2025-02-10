import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:test_webrtc_mobile/src/services/websocket_service.dart';

class ChatPage extends StatefulWidget {
  final String myUserId, remoteId;
  final dynamic offer;

  const ChatPage({
    super.key,
    required this.myUserId,
    required this.remoteId,
    this.offer,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final socket = WebsocketService.instance.socket;

  RTCPeerConnection? _peerConnection;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:pen4sjaov.localto.net:1817',
          // 'stun:stun2.l.google.com:19302',
        ]
      },
    ]
  };

  @override
  void initState() {
    _initWebrtc();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _initWebrtc() async {
    try {
      _peerConnection = await createPeerConnection(_configuration, {
        "offerToReceiveAudio": false,
        "offerToReceiveVideo": false,
      });
      log('Success create peer connection');
    } catch (e) {
      log('Failed create peer connection: $e');
    }

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        try {
          socket!.emit(
            'ice candidate',
            {
              'iceCandidate': {
                'candidate': candidate.candidate,
                'sdpMid': candidate.sdpMid,
                'sdpMLineIndex': candidate.sdpMLineIndex,
              },
              'to': widget.remoteId,
            },
          );
          log('Success emit ice');
        } catch (e) {
          log('Failed emit ice: $e');
        }
      }
    };

    socket!.on('ice candidate', (data) async {
      try {
        RTCIceCandidate iceCandidates = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(iceCandidates);
        socket!.emit('ice added');
        log('Success set ice');
      } catch (e) {
        log('Failed set ice: $e');
      }
    });

    if (widget.offer == null) {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      log('Offer: ${offer.sdp}');

      try {
        await _peerConnection!.setLocalDescription(offer);
        log('Success set local description');
      } catch (e) {
        log('Failed set local description: $e');
      }

      try {
        socket!.emit('offer', {
          'offer': offer.toMap(),
          'to': widget.remoteId,
          'from': widget.myUserId,
        });
        log('Success emit offer');
      } catch (e) {
        log('Failed emit offer: $e');
      }

      socket!.on('answer', (data) async {
        try {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            ),
          );
          log('Success in remote description');
        } catch (e) {
          log('Failed in remote description: $e');
        }
      });
    } else {
      try {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            widget.offer['sdp'],
            widget.offer['type'],
          ),
        );
        log('Success set remote description');
      } catch (e) {
        log('Failed set remote description: $e');
      }

      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      log('Answer: ${answer.sdp}');

      try {
        await _peerConnection!.setLocalDescription(answer);
        log('Success set local description');
      } catch (e) {
        log('Failed set local description: $e');
      }

      try {
        socket!.emit('answer', {
          'answer': answer.toMap(),
          'to': widget.remoteId,
          'from': widget.myUserId,
        });
        log('Success emit answer');
      } catch (e) {
        log('Failed emit answer: $e');
      }
    }

    _peerConnection!.onConnectionState = (state) {
      log('Connection state: $state');
    };

    _peerConnection!.onIceConnectionState = (state) {
      log('Ice connection state: $state');
    };
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}
