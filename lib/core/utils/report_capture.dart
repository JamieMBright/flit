import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/flit_colors.dart';

/// Captures the [RepaintBoundary] under [boundaryKey] as a PNG.
/// Returns null if the boundary isn't laid out yet.
Future<Uint8List?> captureReportPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 3,
}) async {
  final render = boundaryKey.currentContext?.findRenderObject();
  if (render is! RenderRepaintBoundary) return null;
  final image = await render.toImage(pixelRatio: pixelRatio);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Shares (or on platforms without a share sheet, downloads) a captured
/// report image. Falls back to copying [fallbackText] to the clipboard if
/// image sharing fails entirely, so the player always leaves with
/// something shareable.
Future<void> shareReportImage(
  BuildContext context, {
  required Uint8List png,
  required String filename,
  required String fallbackText,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: [filename],
        // Browsers without the Web Share API (desktop) download instead.
        downloadFallbackEnabled: true,
      ),
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: fallbackText));
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: FlitColors.cardBackground,
        content: Text(
          'Image sharing unavailable — result copied as text instead.',
          style: TextStyle(color: FlitColors.textPrimary),
        ),
      ),
    );
  }
}
