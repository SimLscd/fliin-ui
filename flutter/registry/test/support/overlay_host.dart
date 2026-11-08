import 'package:flutter/widgets.dart';

/// Un `Overlay` d'une seule entrée qui reconstruit [child] quand il change :
/// `Overlay.initialEntries` ne sert qu'au premier build, et un champ de texte
/// a besoin d'un overlay pour ses poignées et sa barre.
class OverlayHost extends StatefulWidget {
  const OverlayHost({super.key, required this.child});

  final Widget child;

  @override
  State<OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<OverlayHost> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(OverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
