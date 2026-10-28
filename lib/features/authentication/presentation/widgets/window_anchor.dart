import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Paints [child] from the window's centre into its own layout slot.
///
/// At [progress] 0 the child is drawn centred on the **full window** — the
/// app is edge to edge, and the Android system splash centres its icon on
/// the whole window — and scaled so its width is [startExtent] logical
/// pixels. At 1 it is drawn where it was laid out, untouched (the identity).
///
/// Paint only: the slot is read at paint time and the child never relays
/// out, so a late font swap or a large text size simply moves the landing
/// spot. Hit tests and `localToGlobal` follow the painted position.
class WindowAnchor extends SingleChildRenderObjectWidget {
  const WindowAnchor({
    required this.progress,
    required this.startExtent,
    required super.child,
    super.key,
  });

  final Animation<double> progress;

  /// Logical pixels (dp, not `.fx`): the child's width at [progress] 0.
  final double startExtent;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWindowAnchor(
    progress: progress,
    startExtent: startExtent,
    windowCentre: MediaQuery.sizeOf(context).center(Offset.zero),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderWindowAnchor)
      ..progress = progress
      ..startExtent = startExtent
      ..windowCentre = MediaQuery.sizeOf(context).center(Offset.zero);
  }
}

class _RenderWindowAnchor extends RenderProxyBox {
  _RenderWindowAnchor({
    required Animation<double> progress,
    required double startExtent,
    required Offset windowCentre,
  }) : _progress = progress,
       _startExtent = startExtent,
       _windowCentre = windowCentre;

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (value == _progress) return;
    if (attached) _progress.removeListener(markNeedsPaint);
    _progress = value;
    if (attached) _progress.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _startExtent;
  set startExtent(double value) {
    if (value == _startExtent) return;
    _startExtent = value;
    markNeedsPaint();
  }

  Offset _windowCentre;
  set windowCentre(Offset value) {
    if (value == _windowCentre) return;
    _windowCentre = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  /// Toward the window centre by (1 − p), scaled about the slot's own centre.
  Matrix4 get _transform {
    final double p = _progress.value;
    if (p >= 1 || size.isEmpty) return Matrix4.identity();
    final Offset centre = size.center(Offset.zero);
    final Offset shift = (_windowCentre - localToGlobal(centre)) * (1 - p);
    final double scale = lerpDouble(_startExtent / size.width, 1, p)!;
    return Matrix4.translationValues(
        shift.dx + centre.dx,
        shift.dy + centre.dy,
        0,
      )
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (_progress.value >= 1) {
      layer = null;
      return super.paint(context, offset);
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          super.hitTestChildren(result, position: position),
    );
  }
}
