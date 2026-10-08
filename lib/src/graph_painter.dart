import 'dart:math';

import 'package:flutter/material.dart';

import 'graph_node.dart';

/// Draws edges, then nodes, with the canvas origin at the centre.
class GraphPainter<T> extends CustomPainter {
  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.selectedNode,
    required this.hoveredNode,
    required this.highlightColor,
    required this.edgeColor,
    required this.showLabels,
  });

  final List<GraphNode<T>> nodes;
  final List<GraphEdge<T>> edges;
  final GraphNode<T>? selectedNode;
  final GraphNode<T>? hoveredNode;
  final Color highlightColor;
  final Color edgeColor;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    for (final edge in edges) {
      if (edge.source.appear == 0 || edge.target.appear == 0) continue;
      final highlighted =
          selectedNode != null &&
          (edge.source == selectedNode || edge.target == selectedNode);
      _drawEdge(canvas, edge, center, highlighted);
    }
    for (final node in nodes) {
      _drawNode(canvas, node, center);
    }
  }

  void _drawEdge(
    Canvas canvas,
    GraphEdge<T> edge,
    Offset center,
    bool highlighted,
  ) {
    final sourceCenter = edge.source.position + center;
    final targetCenter = edge.target.position + center;
    final direction = (targetCenter - sourceCenter).normalized();
    final start = sourceCenter + direction * (edge.source.size / 2);
    final end = targetCenter - direction * (edge.target.size / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlighted ? 3 : 1.5
      ..color = highlighted
          ? highlightColor
          : edgeColor.withAlpha(
              (100 * min(edge.source.appear, edge.target.appear)).round(),
            );
    canvas.drawLine(start, end, paint);
  }

  void _drawNode(Canvas canvas, GraphNode<T> node, Offset center) {
    final position = node.position + center;
    final isSelected = node == selectedNode;
    final isHovered = node == hoveredNode;

    final radius =
        node.size /
        2 *
        (isHovered ? 1.15 : 1.0) *
        Curves.easeOutBack.transform(node.appear);
    if (radius <= 0) return;

    canvas
      ..drawCircle(position, radius, Paint()..color = node.color.withAlpha(80))
      ..drawCircle(position, radius, Paint()..color = node.color.withAlpha(220))
      ..drawCircle(
        position,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 3 : 2
          ..color = isSelected ? highlightColor : Colors.white.withAlpha(180),
      );

    if (node.appear < 1) return; // text once the node has grown
    final initials = TextPainter(
      text: TextSpan(
        text: node.label.substring(0, min(2, node.label.length)).toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: node.size / 2.5,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    initials.paint(
      canvas,
      position - Offset(initials.width / 2, initials.height / 2),
    );

    if (!showLabels) return;
    final label = TextPainter(
      text: TextSpan(
        text: node.label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 100);
    final labelPosition =
        position + Offset(-label.width / 2, node.size / 2 + 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelPosition.dx - 6,
          labelPosition.dy - 2,
          label.width + 12,
          label.height + 4,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.black87,
    );
    label.paint(canvas, labelPosition);
  }

  @override
  bool shouldRepaint(covariant GraphPainter<T> oldDelegate) => true;
}
