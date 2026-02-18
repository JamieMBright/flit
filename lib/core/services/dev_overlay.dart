import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'error_service.dart';

/// Enhanced floating debug overlay that displays runtime errors.
///
/// Features:
/// - Only rendered in debug / profile mode ([kReleaseMode] gate).
/// - Draggable to any screen edge.
/// - Minimize / expand toggle with error count badge.
/// - Last 5 errors with severity-colored badges.
/// - Tap to expand full stack trace.
/// - Long-press to copy the full error JSON to clipboard.
/// - Reactively updates via [ErrorService.errorCountNotifier].
///
/// Place this widget in a [Stack] above your app's [Navigator] so it
/// persists across screen navigation:
///
/// ```dart
/// Stack(
///   children: [
///     child ?? const SizedBox.shrink(),
///     if (!kReleaseMode) const DevOverlay(),
///   ],
/// );
/// ```
class DevOverlay extends StatefulWidget {
  const DevOverlay({super.key});

  @override
  State<DevOverlay> createState() => _DevOverlayState();
}

class _DevOverlayState extends State<DevOverlay> {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _minimized = true;
  int? _expandedIndex;

  /// Current drag position (offset from top-left of screen).
  Offset _position = const Offset(16, 80);

  /// Track drag delta.
  Offset _dragStart = Offset.zero;
  Offset _positionStart = Offset.zero;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Gate: never render in release builds.
    if (kReleaseMode) return const SizedBox.shrink();

    return ValueListenableBuilder<int>(
      valueListenable: ErrorService.instance.errorCountNotifier,
      builder: (context, totalCount, _) {
        if (totalCount == 0) return const SizedBox.shrink();
        return _buildPositioned(context);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  Widget _buildPositioned(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safePadding = MediaQuery.of(context).padding;

    // Clamp position within safe area.
    final maxX = screenSize.width - (_minimized ? 56 : 320);
    final maxY = screenSize.height - (_minimized ? 56 : 200);
    final clampedX = _position.dx.clamp(safePadding.left + 4, maxX);
    final clampedY = _position.dy.clamp(safePadding.top + 4, maxY);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanStart: _onDragStart,
        onPanUpdate: _onDragUpdate,
        child: _minimized ? _buildMinimized() : _buildExpanded(context),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Minimized state: floating badge
  // ---------------------------------------------------------------------------

  Widget _buildMinimized() {
    final errors = ErrorService.instance.displayErrors;
    final criticalCount =
        errors.where((e) => e.severity == ErrorSeverity.critical).length;
    final errorCount =
        errors.where((e) => e.severity == ErrorSeverity.error).length;
    final warningCount =
        errors.where((e) => e.severity == ErrorSeverity.warning).length;

    final badgeColor =
        criticalCount > 0
            ? const Color(0xFFFF1744)
            : errorCount > 0
            ? const Color(0xFFFF6D00)
            : const Color(0xFFFFD600);

    final total = criticalCount + errorCount + warningCount;

    return GestureDetector(
      onTap: () => setState(() => _minimized = false),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xE6212121),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: badgeColor.withAlpha(180), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x60000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.bug_report, color: badgeColor, size: 24),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Expanded state: error list panel
  // ---------------------------------------------------------------------------

  Widget _buildExpanded(BuildContext context) {
    final errors = ErrorService.instance.displayErrors;
    final visibleErrors = errors.take(5).toList();

    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: const Color(0xE6181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF424242), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(errors.length),
          if (visibleErrors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No errors captured.',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: visibleErrors.length,
                separatorBuilder:
                    (_, __) =>
                        const Divider(color: Color(0xFF333333), height: 1),
                itemBuilder:
                    (context, index) =>
                        _buildErrorTile(visibleErrors[index], index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(int totalErrors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: Color(0xFFFF6D00), size: 18),
          const SizedBox(width: 8),
          Text(
            'Errors ($totalErrors)',
            style: const TextStyle(
              color: Color(0xFFEEEEEE),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap:
                  () => setState(() {
                    _minimized = true;
                    _expandedIndex = null;
                  }),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Color(0xFF9E9E9E), size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorTile(CapturedError error, int index) {
    final isExpanded = _expandedIndex == index;
    final severityColor = _severityColor(error.severity);

    return GestureDetector(
      onTap:
          () => setState(() {
            _expandedIndex = isExpanded ? null : index;
          }),
      onLongPress: () => _copyErrorToClipboard(error),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: severityColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Severity badge + timestamp row
            Row(
              children: [
                _buildSeverityBadge(error.severity),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatTimestamp(error.timestamp),
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF616161),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Error message (truncated when collapsed)
            Text(
              error.error,
              maxLines: isExpanded ? null : 2,
              overflow: isExpanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.4,
                decoration: TextDecoration.none,
              ),
            ),
            // Expanded: stack trace
            if (isExpanded && error.stackTrace != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(
                    error.stackTrace!,
                    style: const TextStyle(
                      color: Color(0xFF8BC34A),
                      fontSize: 9,
                      fontFamily: 'monospace',
                      height: 1.3,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
            // Expanded: context metadata
            if (isExpanded && error.context != null) ...[
              const SizedBox(height: 6),
              ...error.context!.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(
                      color: Color(0xFF64B5F6),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
            // Long-press hint
            if (isExpanded)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Long-press to copy JSON',
                  style: TextStyle(
                    color: Color(0xFF616161),
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Severity styling
  // ---------------------------------------------------------------------------

  Widget _buildSeverityBadge(ErrorSeverity severity) {
    final color = _severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(120), width: 0.5),
      ),
      child: Text(
        severity.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Color _severityColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.critical:
        return const Color(0xFFFF1744);
      case ErrorSeverity.error:
        return const Color(0xFFFF6D00);
      case ErrorSeverity.warning:
        return const Color(0xFFFFD600);
    }
  }

  // ---------------------------------------------------------------------------
  // Drag handling
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails details) {
    _dragStart = details.globalPosition;
    _positionStart = _position;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _position = _positionStart + (details.globalPosition - _dragStart);
    });
  }

  // ---------------------------------------------------------------------------
  // Clipboard
  // ---------------------------------------------------------------------------

  void _copyErrorToClipboard(CapturedError error) {
    final json = error.toJsonString();
    Clipboard.setData(ClipboardData(text: json));

    // Show a brief snackbar confirmation if we have a scaffold.
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Error JSON copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
