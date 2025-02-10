import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:test_webrtc_mobile/src/services/websocket_service.dart';

class CallPage extends StatefulWidget {
  final String myUserId, remoteId;
  final dynamic offer;

  const CallPage({
    super.key,
    required this.myUserId,
    required this.remoteId,
    this.offer,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final socket = WebsocketService.instance.socket;
  final _localVideoRenderer = RTCVideoRenderer();
  final _remoteVideoRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  bool isAudioOn = true, isVideoOn = true, isFrontCamera = true;

  @override
  void initState() {
    _initRenderer();
    _createPeerConnection();
    super.initState();
  }

  @override
  void dispose() {
    _localVideoRenderer.dispose();
    _remoteVideoRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }

  void _initRenderer() {
    _localVideoRenderer.initialize();
    _remoteVideoRenderer.initialize();
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {
          "urls": [
            'stun:pen4sjaov.localto.net:1817',
            // "stun:stun2.l.google.com:19302",
          ]
        },
      ]
    };

    _peerConnection = await createPeerConnection(configuration, {
      "offerToReceiveAudio": true,
      "offerToReceiveVideo": true,
    });

    _localStream = await navigator.mediaDevices.getUserMedia({
      "audio": isAudioOn,
      "video": isVideoOn ? {"facingMode": "user"} : false,
    });

    _localVideoRenderer.srcObject = _localStream;
    setState(() {});

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onTrack = (event) {
      _remoteVideoRenderer.srcObject = event.streams[0];
      setState(() {});
    };

    socket!.on("receive_ice_candidate", (data) async {
      try {
        RTCIceCandidate iceCandidates = RTCIceCandidate(
          data["candidate"],
          data["sdpMid"],
          data["sdpMLineIndex"],
        );
        await _peerConnection!.addCandidate(iceCandidates);
      } catch (e) {
        log("Gagal on ice candidate: $e");
      }
    });

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        socket!.emit(
          "send_ice_candidate",
          {
            "iceCandidate": {
              "candidate": candidate.candidate,
              "sdpMid": candidate.sdpMid,
              "sdpMLineIndex": candidate.sdpMLineIndex
            },
            "to": widget.remoteId,
          },
        );
      }
    };

    if (widget.offer != null) {
      try {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            widget.offer["sdp"],
            widget.offer["type"],
          ),
        );
      } catch (e) {
        log("Gagal on set remote description: $e");
      }

      RTCSessionDescription answer = await _peerConnection!.createAnswer();

      await _peerConnection!.setLocalDescription(answer);

      socket!.emit("send_answer", {
        "answer": answer.toMap(),
        "to": widget.remoteId,
        "from": widget.myUserId,
      });
    } else {
      RTCSessionDescription offer = await _peerConnection!.createOffer();

      await _peerConnection!.setLocalDescription(offer);

      socket!.emit("send_offer", {
        "offer": offer.toMap(),
        "to": widget.remoteId,
        "from": widget.myUserId,
      });

      socket!.on("receive_answer", (data) async {
        try {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(
              data["answer"]["sdp"],
              data["answer"]["type"],
            ),
          );
        } catch (e) {
          log("Gagal on answer: $e");
        }
      });
    }
  }

  _leaveCall() {
    Navigator.pop(context);
  }

  _toggleMic() {
    isAudioOn = !isAudioOn;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  _toggleCamera() {
    isVideoOn = !isVideoOn;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
    setState(() {});
  }

  _switchCamera() {
    isFrontCamera = !isFrontCamera;

    _localStream?.getVideoTracks().forEach((track) {
      // ignore: deprecated_member_use
      track.switchCamera();
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RTCVideoView(
              _remoteVideoRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
            Positioned(
              right: 20.0,
              bottom: 100.0,
              child: SizedBox(
                height: 150,
                width: 120,
                child: RTCVideoView(
                  _localVideoRenderer,
                  mirror: isFrontCamera,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 15.0, horizontal: 5.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.cameraswitch),
                        color: Colors.white,
                        onPressed: _switchCamera,
                      ),
                      IconButton(
                        icon: Icon(
                          isVideoOn ? Icons.videocam : Icons.videocam_off,
                          color: isVideoOn ? Colors.white : Colors.redAccent,
                        ),
                        onPressed: _toggleCamera,
                      ),
                      IconButton(
                        icon: Icon(
                          isAudioOn ? Icons.mic : Icons.mic_off,
                          color: isAudioOn ? Colors.white : Colors.redAccent,
                        ),
                        onPressed: _toggleMic,
                      ),
                      IconButton(
                        icon: const Icon(Icons.call_end),
                        color: Colors.redAccent,
                        onPressed: _leaveCall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 20.0),
                child: Text(
                  "Dalam Panggilan",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
