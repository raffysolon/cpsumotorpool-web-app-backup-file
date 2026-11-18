import 'package:flutter/material.dart';

/// Consistent spacing for admin pages and dialogs.
class AdminSpacing {
  static double gutter(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 700 ? 12 : 20;

  static EdgeInsets page(BuildContext context) =>
      EdgeInsets.all(gutter(context));
}

/// Keeps actions beside a heading on desktop and below it on small screens.
class AdminToolbar extends StatelessWidget {
  const AdminToolbar({super.key, required this.title, required this.actions});

  final Widget title;
  final Widget actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaled = MediaQuery.textScalerOf(context).scale(14) / 14;
      if (constraints.maxWidth < 600 * scaled) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 12), actions],
        );
      }
      return Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 16),
          actions,
        ],
      );
    },
  );
}

/// A table owns its horizontal controller so its scrollbar stays usable even
/// when the page also has a vertical scroll view.
class AdminTableScroll extends StatefulWidget {
  const AdminTableScroll({super.key, required this.child});
  final Widget child;

  @override
  State<AdminTableScroll> createState() => _AdminTableScrollState();
}

class _AdminTableScrollState extends State<AdminTableScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: true,
    trackVisibility: true,
    scrollbarOrientation: ScrollbarOrientation.bottom,
    notificationPredicate: (notification) => notification.depth == 0,
    child: SingleChildScrollView(
      controller: _controller,
      primary: false,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 12),
      child: widget.child,
    ),
  );
}
