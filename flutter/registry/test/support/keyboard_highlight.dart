import 'package:flutter/widgets.dart';

/// Le focus clavier ne se montre qu'en mode de surbrillance « traditionnel »
/// (clavier) ; un test démarre en mode tactile sur iOS et Android.
class KeyboardHighlight extends StatefulWidget {
  const KeyboardHighlight({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardHighlight> createState() => _KeyboardHighlightState();
}

class _KeyboardHighlightState extends State<KeyboardHighlight> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  }

  @override
  void dispose() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
