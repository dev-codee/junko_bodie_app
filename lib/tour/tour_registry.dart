/// Maps string tour ids (the equivalent of the web's `data-tour` attribute)
/// to live [GlobalKey]s so the tour overlay can measure and spotlight them.
library;

import 'package:flutter/widgets.dart';

/// Global singleton registry of tour targets. Only one screen is mounted at a
/// time, so id collisions across screens are naturally avoided; the most
/// recently mounted [TourTarget] for an id wins.
class TourRegistry {
  TourRegistry._();
  static final TourRegistry instance = TourRegistry._();

  final Map<String, GlobalKey> _keys = {};

  GlobalKey register(String id) {
    return _keys.putIfAbsent(id, () => GlobalKey());
  }

  void bind(String id, GlobalKey key) {
    _keys[id] = key;
  }

  void unbind(String id, GlobalKey key) {
    if (_keys[id] == key) {
      _keys.remove(id);
    }
  }

  GlobalKey? keyFor(String id) => _keys[id];

  /// Current on-screen rect of the target, in global (screen) coordinates.
  /// Returns null when the target is not mounted or has no size yet.
  Rect? rectFor(String id) {
    final key = _keys[id];
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final render = ctx.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return null;
    if (render.size.isEmpty) return null;
    final topLeft = render.localToGlobal(Offset.zero);
    return topLeft & render.size;
  }
}

/// Wraps a widget so the tour can find and spotlight it by [id].
/// The web equivalent is `data-tour="id"`.
class TourTarget extends StatefulWidget {
  final String id;
  final Widget child;

  const TourTarget({super.key, required this.id, required this.child});

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TourRegistry.instance.bind(widget.id, _key);
  }

  @override
  void didUpdateWidget(TourTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      TourRegistry.instance.unbind(oldWidget.id, _key);
      TourRegistry.instance.bind(widget.id, _key);
    }
  }

  @override
  void dispose() {
    TourRegistry.instance.unbind(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
