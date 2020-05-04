import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';



void statusDialog({Color color,Color textColor=Colors.white,
    String title}) {

   Fluttertoast.showToast(
      msg: title,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: color,
      textColor: textColor,
      fontSize: 16.0
  );


}
