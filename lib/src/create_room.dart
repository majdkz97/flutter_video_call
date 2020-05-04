import 'dart:core';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:share/share.dart';

import 'Dialogs.dart';

class CreateRoom extends StatefulWidget {
  static String tag = 'loopback_sample';

  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<CreateRoom> {
  MediaStream _localStream;
  RTCPeerConnection _peerConnection;

  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();
  bool _inCalling = false;
  String id = 'id';
  Timer _timer;
  var room= Firestore.instance.collection('rooms').document();

  @override
  initState() {
    super.initState();
    initRenderers();
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
    if(state == RTCIceGatheringState.RTCIceGatheringStateComplete)
      {
        print('Connection Ready');
        statusDialog(
            title: 'Room Ready to join',
            color: Colors.green
        );
        print('Share Opened');
        Share.share(id);

      }

    print(state);
  }

  _onIceConnectionState(RTCIceConnectionState state) {
    if(state == RTCIceConnectionState.RTCIceConnectionStateFailed)
      {
        statusDialog(
            title: 'Failed',
            color: Colors.red
        );
      }
    print(state);

  }

  _onAddStream(MediaStream stream) {
    print('addStream: ' + stream.id);
    _remoteRenderer.srcObject = stream;
  }

  _onRemoveStream(MediaStream stream) {
    _remoteRenderer.srcObject = null;
  }

  _onCandidate(RTCIceCandidate candidate) {
    var callerCandidatesCollection = room.collection('callerCandidates');

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
          "minWidth":'600', // Provide your own width, height and frame rate here
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
      _localRenderer.mirror = true;
      statusDialog(
          title: 'Local Camera Ready',
          color: Color(0xFFE7AE25)
      );
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
      RTCSessionDescription description =
          await _peerConnection.createOffer(offerSdpConstraints);
      print(description.sdp);
      _peerConnection.setLocalDescription(description);
      //change for loopback.

      var roomWithOffer = {
        'offer': {
          "type": description.type,
          "sdp": description.sdp,
        },
      };
      print(roomWithOffer);
      await room.setData(roomWithOffer);
      print("Room Id: "+room.documentID);
      statusDialog(
          title: 'Room Id : ${room.documentID}',
          color: Color(0xFFE7AE25)
      );

      setState(() {
        id = room.documentID;
      });

      room.snapshots().listen((event) {
        if(event.data.containsKey('answer'))
          {
            print('In Answer');
            description.type = 'answer';
            var sdp = event.data['answer']['sdp'];
            RTCSessionDescription remoteDescription = RTCSessionDescription(sdp,'answer');
            _peerConnection.setRemoteDescription(remoteDescription);

            var calleeCandidatesCollection = room.collection('calleeCandidates');

            calleeCandidatesCollection.snapshots().listen((event) {
              event.documentChanges.forEach((element) {
                if(element.type == DocumentChangeType.added)
                {
                  var temp = element.document.data;
                  RTCIceCandidate remoteCandidate =
                  RTCIceCandidate(temp['candidate'],temp['sdpMid'],temp['sdpMLineIndex']);
                  print('Add new Reomte Candidate');
                  _peerConnection.addCandidate(remoteCandidate);

                }
              });

            });

            if (!mounted) return;

           // _timer = new Timer.periodic(Duration(seconds: 1), handleStatsReport);

            setState(() {
              _inCalling = true;
            });

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
        title: new Text('Create Room'),
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
      floatingActionButton: new FloatingActionButton(
        onPressed: _inCalling ? _hangUp : _makeCall,
        tooltip: _inCalling ? 'Hangup' : 'Call',
        child: new Icon(_inCalling ? Icons.call_end : Icons.phone),
      ),
    );
  }
}
