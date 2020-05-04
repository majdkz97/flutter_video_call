import 'dart:core';
import 'package:flutter/material.dart';
import 'package:maidsvideocall/src/join_room.dart';
import 'src/create_room.dart';

void main() {

  runApp(new MyApp());

}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  initState() {
    super.initState();
   }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
          appBar: new AppBar(
            title: new Text('Maids.cc-Video Call example'),
          ),
          body: new ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12.0),
              itemCount:2,
              itemBuilder: (context, i) {
                return RaisedButton(onPressed: (){
                  if(i==0)
                    {
                      Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context){
                                return CreateRoom();}
                          )
                      );
                    }
                  else
                    {
                       _showAddressDialog(context);
                    }

                },
                child: Text(i==0?'Create Room':'Join Room'),
                );
              })),
    );
  }

}



void showDemoDialog<T>({BuildContext context, Widget child}) {
  showDialog<T>(
    context: context,
    builder: (BuildContext context) => child,
  ).then<void>((T value) {
    // The value passed to Navigator.pop() or null.
    if (value != null) {

    }
  });
}

_showAddressDialog(context) {
  TextEditingController textEditingController = TextEditingController();
  showDemoDialog<String>(
      context: context,
      child: new AlertDialog(
          title: const Text('Enter Room Id:'),
          content: TextField(
            controller: textEditingController,
            onChanged: (String text) {

            },
            decoration: InputDecoration(
            ),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            new FlatButton(
                child: const Text('CANCEL'),
                onPressed: () {
                  Navigator.pop(context);
                }),
            new FlatButton(
                child: const Text('CONNECT'),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context){
                    return JoinRoom(id:textEditingController.text ,);
                  }));
                })
          ]));
}
