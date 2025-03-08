import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A quick and easy way to style the navigation bar bar in Android
/// to be transparent and edge-to-edge, like iOS is by default.
SystemUiOverlayStyle customOverlayStyle(
    {final bool transparentStatusBar = false}) {
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  final statusBarColor = transparentStatusBar ? Colors.transparent : null;
  return SystemUiOverlayStyle(
    statusBarColor: statusBarColor,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}

class EdgeToEdgeWrapperWidget extends StatelessWidget {
  final Widget child;
  final bool transparentStatusBar;

  EdgeToEdgeWrapperWidget(
      {super.key, this.transparentStatusBar = false, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: customOverlayStyle(transparentStatusBar: transparentStatusBar),
      child: child,
    );
  }
}
