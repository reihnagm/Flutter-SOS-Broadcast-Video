import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:stream_broadcast_sos/basewidgets/button/bounce.dart';

class CustomButton extends StatelessWidget {
  final Function() onTap;
  final String btnTxt;
  final double width;
  final double height;
  final Color loadingColor;
  final Color btnColor;
  final Color btnTextColor;
  final Color btnBorderColor;
  final bool isBorder;
  final bool isBorderRadius;
  final bool isLoading;
  final bool isBoxShadow;

  const CustomButton({
    Key? key, 
    required this.onTap, 
    required this.btnTxt, 
    this.width = double.infinity,
    this.height = 45.0,
    this.isLoading = false,
    this.loadingColor = Colors.white,
    this.btnColor = Colors.black87,
    this.btnTextColor = Colors.white,
    this.btnBorderColor = Colors.transparent,
    this.isBorder = false,
    this.isBorderRadius = false,
    this.isBoxShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Bouncing(
      onPress: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          boxShadow: isBoxShadow ? [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2.0,
              blurRadius: 2.0,
              offset: const Offset(0.0, 0.0),
            ),  
          ] : [],
          color: btnColor,
          border: Border.all(
            color: isBorder ? btnBorderColor : Colors.transparent,
          ),
          borderRadius: isBorderRadius 
          ? BorderRadius.circular(20.0)
          : BorderRadius.circular(10.0)
        ),
        child: isLoading ? 
          Center(
            child: SpinKitFadingCircle(
              color: loadingColor,
              size: 25.0
            ),
          )
        : Center(
          child: Text(btnTxt,
            style: TextStyle(
              color: btnTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 16
            )
          ),
        )
      ),
    );
  }
}
