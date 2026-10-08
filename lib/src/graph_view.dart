import 'package:flutter/material.dart';

import 'graph_controller.dart';
import 'graph_node.dart';
import 'graph_painter.dart';

/// Pannable, zoomable canvas showing a [GraphController]'s graph.
///
/// Nodes can be dragged (the layout follows), hovered and tapped. The view
/// runs the controller's physics on its own ticker and only repaints while
/// something moves.
class GraphView<T> extends StatefulWidget {
  const GraphView({
    required this.controller,
    this.onNodeTap,
    this.showLabels = false,
    this.initialScale = 0.3,
    this.minScale = 0.1,
    this.maxScale = 4,
    this.highlightColor,
    this.edgeColor,
    super.key,
  });

  final GraphController<T> controller;
  final void Function(GraphNode<T> node)? onNodeTap;

  /// Draw the full label under each node, not just its initials.
  final bool showLabels;

  final double initialScale;
  final double minScale;
  final double maxScale;

  /// Selected node border and its edges; defaults to the theme's primary.
  final Color? highlightColor;

  /// Edge colour; defaults to the theme's onSurface.
  final Color? edgeColor;

  @override
  State<GraphView<T>> createState() => _GraphViewState<T>();
}

class _GraphViewState<T> extends State<GraphView<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final _transformation = TransformationController();
  GraphNode<T>? _selected;
  GraphNode<T>? _hovered;
  GraphNode<T>? _dragging;
  bool _centered = false;

  Size get _canvas => widget.controller.canvasSize;

  @override
  void initState() {
    super.initState();
    _ticker =
        AnimationController(vsync: this, duration: const Duration(days: 1))
          ..addListener(_onTick)
          ..repeat();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(GraphView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    _transformation.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onTick() {
    if (mounted && widget.controller.step()) setState(() {});
  }

  /// Puts the canvas origin in the middle of the viewport on first layout.
  void _centerOnce(Size viewport) {
    if (_centered) return;
    _centered = true;
    final scale = widget.initialScale;
    _transformation.value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - _canvas.width / 2 * scale,
        viewport.height / 2 - _canvas.height / 2 * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Offset _toCanvas(Offset local) =>
      local - Offset(_canvas.width / 2, _canvas.height / 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        _centerOnce(constraints.biggest);
        return InteractiveViewer(
          transformationController: _transformation,
          panEnabled: _dragging == null,
          scaleEnabled: _dragging == null,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          constrained: false,
          child: SizedBox.fromSize(
            size: _canvas,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                final node = controller.hitTest(_toCanvas(event.localPosition));
                if (node == null) return;
                controller.beginDrag(node);
                setState(() {
                  _dragging = node;
                  _selected = node;
                });
              },
              onPointerMove: (event) {
                final node = _dragging;
                if (node != null) {
                  controller.dragTo(node, _toCanvas(event.localPosition));
                }
              },
              onPointerUp: (_) => _endDrag(),
              onPointerCancel: (_) => _endDrag(),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) {
                  final node = controller.hitTest(
                    _toCanvas(details.localPosition),
                  );
                  if (node != null) widget.onNodeTap?.call(node);
                },
                child: MouseRegion(
                  cursor: _hovered != null
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  onHover: (event) {
                    final node = controller.hitTest(
                      _toCanvas(event.localPosition),
                    );
                    if (node != _hovered) setState(() => _hovered = node);
                  },
                  onExit: (_) {
                    if (_hovered != null) setState(() => _hovered = null);
                  },
                  child: CustomPaint(
                    size: _canvas,
                    isComplex: true,
                    painter: GraphPainter<T>(
                      nodes: controller.nodes,
                      edges: controller.edges,
                      selectedNode: _selected,
                      hoveredNode: _hovered,
                      highlightColor:
                          widget.highlightColor ?? theme.colorScheme.primary,
                      edgeColor:
                          widget.edgeColor ?? theme.colorScheme.onSurface,
                      showLabels: widget.showLabels,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _endDrag() {
    final node = _dragging;
    if (node == null) return;
    widget.controller.endDrag(node);
    setState(() => _dragging = null);
  }
}
