import 'package:flutter/material.dart';

import '../theme/flit_theme.dart';

/// Centers and constrains menu/screen content to [kMaxContentWidth] on wide
/// displays so that column-of-buttons style screens keep a phone-like feel on
/// desktop browsers without regressing the narrow-screen (phone) layout.
///
/// Use this to wrap the **content** inside a Scaffold body, NOT the full
/// Scaffold itself — the background/globe must always fill the screen.
///
/// On phones, [kMaxContentWidth] is never hit, so layout is unchanged.
class MenuContentWrapper extends StatelessWidget {
  const MenuContentWrapper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: child,
        ),
      );
}
