import 'package:flutter/painting.dart';

/// A circle on the graph.
///
/// [id] is how [GraphController.setGraph] recognises a node across updates,
/// so its position and animation survive. [data] is yours: keep a model or
/// a key there and read it back in `onNodeTap`.
class GraphNode<T> {
  GraphNode({
    required this.id,
    required this.label,
    this.color = const Color(0xFF888888),
    this.size = 50,
    this.data,
    Offset? position,
  }) : position = position ?? Offset.zero;

  final String id;
  final String label;

  /// Fill colour; change it and call [GraphController.refresh] to repaint.
  Color color;

  /// Diameter in canvas pixels.
  final double size;
  final T? data;

  /// Centre, relative to the canvas origin.
  Offset position;
  Offset velocity = Offset.zero;

  /// Pinned while the user drags it: it pushes others but is never moved.
  bool isDragging = false;

  /// 0 — not shown yet, 0..1 — growing in, 1 — in place.
  double appear = 1;

  @override
  String toString() => 'GraphNode($id)';
}

/// A connection between two nodes of a controller.
class GraphEdge<T> {
  const GraphEdge(this.source, this.target);

  final GraphNode<T> source;
  final GraphNode<T> target;
}

/// A connection by node ids, for [GraphController.setGraph].
class GraphLink {
  const GraphLink(this.sourceId, this.targetId);

  final String sourceId;
  final String targetId;
}

extension OffsetDirection on Offset {
  /// Unit vector in this direction; zero stays zero.
  Offset normalized() {
    final magnitude = distance;
    return magnitude == 0 ? Offset.zero : this / magnitude;
  }
}
