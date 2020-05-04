import 'dart:core';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:share/share.dart';

class JoinRoom extends StatefulWidget {
   final String id;

  const JoinRoom({Key key, this.id}) : super(key: key);
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<JoinRoom> {
  MediaStream _localStream;
  RTCPeerConnection _peerConnection;

  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();
  bool _inCalling = false;
  bool ready = false;
  Timer _timer;
   var room;
   var roomSnapshot;
  @override
  initState() {
    super.initState();
    ininini();
    initRenderers();
  }

  Future<void> ininini() async {
    room = await Firestore.instance.collection('rooms').document(widget.id);
    roomSnapshot =await room.get();
    setState(() {
      ready = true;
    });
  }

  @override
  deactivate() {
    super.deactivate();
    if (_inCalling) {
      _hangUp();
    }
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void handleStatsReport(Timer timer) async {

  }

  _onSignalingState(RTCSignalingState state) {
    print(state);
  }

  _onIceGatheringState(RTCIceGatheringState state) {
    print(state);
  }

  _onIceConnectionState(RTCIceConnectionState state) {
    print(state);
  }

  _onAddStream(MediaStream stream) {
    print('addStream: ' + stream.id);
    _remoteRenderer.srcObject = stream;
    setState(() {
      _inCalling = true;
    });

  }

  _onRemoveStream(MediaStream stream) {
    _remoteRenderer.srcObject = null;
  }

  _onCandidate(RTCIceCandidate candidate) {
    var callerCandidatesCollection = room.collection('calleeCandidates');

    callerCandidatesCollection.add(candidate.toMap());

    print('onCandidate: ' + candidate.candidate);
    _peerConnection.addCandidate(candidate);


  }

  _onRenegotiationNeeded() {
    print('RenegotiationNeeded');
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  _makeCall() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth":
              '600', // Provide your own width, height and frame rate here
          "minHeight": '600',
          "minFrameRate": '30',
        },
        "facingMode": "user",
        "optional": [],
      }
    };

    Map<String, dynamic> configuration = {
      "iceServers": [
        {
          "url": 'turn:18.224.253.192:3478',
          "credential": 'FmxvrY6nADxaAskhmrNrAL2N4CRtZ8',
          "username": 'turnBKhETPNa8M7tsxD'
        }
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    final Map<String, dynamic> loopbackConstraints = {
      "mandatory": {},
      "optional": [
        {"DtlsSrtpKeyAgreement": true},
      ],
    };

    if (_peerConnection != null) return;

    try {
      _localStream = await navigator.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;
      _peerConnection =
          await createPeerConnection(configuration, loopbackConstraints);

      _peerConnection.onSignalingState = _onSignalingState;
      _peerConnection.onIceGatheringState = _onIceGatheringState;
      _peerConnection.onIceConnectionState = _onIceConnectionState;
      _peerConnection.onAddStream = _onAddStream;
      _peerConnection.onRemoveStream = _onRemoveStream;
      _peerConnection.onIceCandidate = _onCandidate;
      _peerConnection.onRenegotiationNeeded = _onRenegotiationNeeded;
       _peerConnection.addStream(_localStream);

      var offer = roomSnapshot.data['offer'];
       var sdp = offer['sdp'];
      RTCSessionDescription remoteDescription = RTCSessionDescription(sdp,'offer');

      _peerConnection.setRemoteDescription(remoteDescription);

      RTCSessionDescription description =
      await _peerConnection.createAnswer(offerSdpConstraints);

      _peerConnection.setLocalDescription(description);


      var roomWithAnswer = {
        'answer': {
          "type": description.type,
          "sdp": description.sdp,
        },
      };
      print(roomWithAnswer);
      await room.updateData(roomWithAnswer);

        //change for loopback.


      var callerCandidatesCollection = room.collection('callerCandidates');

      callerCandidatesCollection.snapshots().listen((event) {
        if(event.documents.length>0)
          {
            var temp = event.documents.last.data;
            RTCIceCandidate remoteCandidate =
            RTCIceCandidate(temp['candidate'],temp['sdpMid'],temp['sdpMLineIndex']);
            print('Add new Reomte Candidate');
            _peerConnection.addCandidate(remoteCandidate);
          }
      });



    } catch (e) {
      print(e.toString());
    }

  }

  _hangUp() async {
    try {
      await _localStream.dispose();
      await _peerConnection.close();
      _peerConnection = null;
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    } catch (e) {
      print(e.toString());
    }
    setState(() {
      _inCalling = false;
    });
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    var widgets = <Widget>[
      new Expanded(
        child: new RTCVideoView(_localRenderer),
      ),
      new Expanded(
        child: new RTCVideoView(_remoteRenderer),
      )
    ];
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('Join Room'),
      ),
      body: new OrientationBuilder(
        builder: (context, orientation) {
          return new Center(
            child: new Container(
              decoration: new BoxDecoration(color: Colors.black54),
              child: orientation == Orientation.portrait
                  ? new Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: widgets)
                  : new Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: widgets),
            ),
          );
        },
      ),
      floatingActionButton: ready? FloatingActionButton(
        onPressed:_inCalling ? _hangUp : _makeCall ,
        tooltip: _inCalling ? 'Hangup' : 'Call',
        child: new Icon(_inCalling ? Icons.call_end : Icons.phone),
      ):SizedBox(),
    );
  }
}

