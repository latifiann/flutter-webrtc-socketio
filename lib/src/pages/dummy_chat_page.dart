import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:test_webrtc_mobile/src/services/websocket_service.dart';

class DummyChatPage extends StatefulWidget {
  final String myUserId, remoteId;
  final dynamic offer;

  const DummyChatPage({
    super.key,
    required this.myUserId,
    required this.remoteId,
    this.offer,
  });

  @override
  State<DummyChatPage> createState() => _DummyChatPageState();
}

class _DummyChatPageState extends State<DummyChatPage> {
  final socket = WebsocketService.instance.socket;

  RTCPeerConnection? alice;
  RTCPeerConnection? bob;

  RTCDataChannel? aliceChannel;
  RTCDataChannel? bobChannel;

  List<String> messages = [];

  TextEditingController messageController = TextEditingController();
  final scrollController = ScrollController();

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
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
    alice!.close();
    bob!.close();
    super.dispose();
  }

  _initWebrtc() async {
    alice = await createPeerConnection(_configuration);
    bob = await createPeerConnection(_configuration);

    aliceChannel = await alice!.createDataChannel('test', RTCDataChannelInit());
    bobChannel = await bob!.createDataChannel('test', RTCDataChannelInit());

    alice!.onDataChannel = (channel) {
      _setupDataChannel(channel, 'Bob');
    };

    bob!.onDataChannel = (channel) {
      _setupDataChannel(channel, 'Alice');
    };

    RTCSessionDescription offer = await alice!.createOffer();
    await alice!.setLocalDescription(offer);
    socket!.emit('offer', {
      'offer': offer.toMap(),
      'to': socket!.id,
      'from': socket!.id,
    });

    socket!.on('offer', (data) async {
      await bob!.setRemoteDescription(
        RTCSessionDescription(
          data['offer']['sdp'],
          data['offer']['type'],
        ),
      );
      RTCSessionDescription answer = await bob!.createAnswer();
      await bob!.setLocalDescription(answer);
      socket!.emit('answer', {
        'answer': answer.toMap(),
        'to': socket!.id,
        'from': socket!.id,
      });
    });

    socket!.on('answer', (data) async {
      await alice!.setRemoteDescription(
        RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        ),
      );

      alice!.onIceCandidate = (candidate) {
        if (candidate.candidate != null) {
          log('Peer alice on ice candidate');
          socket!.emit(
            'ice candidate',
            {
              'iceCandidate': {
                'candidate': candidate.candidate,
                'sdpMid': candidate.sdpMid,
                'sdpMLineIndex': candidate.sdpMLineIndex,
              },
              'to': socket!.id,
            },
          );
        }
      };
    });

    socket!.on('ice candidate', (data) async {
      log('Socket bob on ice candidate');
      RTCIceCandidate iceCandidates = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      await bob!.addCandidate(iceCandidates);
    });
  }

  _setupDataChannel(RTCDataChannel channel, String sender) {
    channel.onMessage = (data) {
      log('$sender: ${data.text}');
      setState(() {
        messages.add(data.text);
      });
    };
  }

  Future<void> _sendAlice(String message) async {
    if (aliceChannel != null &&
        aliceChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      messageController.clear();
      await aliceChannel!.send(RTCDataChannelMessage(message));
      setState(() {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      });
    } else {
      log('Data channel not set up');
    }
  }

  Future<void> _sendBob(String message) async {
    if (bobChannel != null &&
        bobChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      messageController.clear();
      await bobChannel!.send(RTCDataChannelMessage(message));
      setState(() {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      });
    } else {
      log('Data channel not set up');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('WebRTC DataChannel Demo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              controller: scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Text(messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: messageController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 17, vertical: 5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    maxLines: 1,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (messageController.text.isNotEmpty) {
                      _sendAlice(messageController.text);
                    }
                  },
                  child: const Text('Alice'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (messageController.text.isNotEmpty) {
                      _sendBob(messageController.text);
                    }
                  },
                  child: const Text('Bob'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
