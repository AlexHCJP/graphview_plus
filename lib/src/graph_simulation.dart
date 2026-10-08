import 'dart:math';

import 'package:flutter/painting.dart';

import 'graph_node.dart';

/// Force-directed layout in the spirit of d3-force.
///
/// Forces are scaled by [alpha], which cools towards [alphaTarget] every
/// tick, so the graph settles and stops instead of jittering forever.
/// A collision pass keeps circles from overlapping, and a node being
/// dragged ([GraphNode.isDragging]) is pinned: it pushes others but is
/// never moved by them.
///
/// You normally drive it through [GraphController]; it is exported for
/// tests and for apps that want their own render loop.
class GraphSimulation<T> {
  GraphSimulation({
    required this.nodes,
    required this.edges,
    required this.halfExtent,
  });

  List<GraphNode<T>> nodes;
  List<GraphEdge<T>> edges;

  /// Positions are clamped to ±halfExtent on both axes.
  final Offset halfExtent;

  /// Weak pull towards the origin on top of centre-of-mass centring.
  /// 0 disables it; 0.0003 is a gentle default.
  double centerForce = 0.0003;

  /// How hard nodes push each other apart. 0.8 is the default.
  double repulsion = 0.8;

  /// Spring stiffness of links, 0–0.3; higher snaps to [linkDistance] faster.
  double linkStrength = 0.15;

  /// Rest length of a link in canvas pixels.
  double linkDistance = 150;

  static const alphaMin = 0.001;

  /// Cooling per tick; 1 - alphaMin^(1/ticks). 0.0228 ≈ 300 ticks.
  double alphaDecay = 0.0228;

  static const _velocityDecay = 0.6;
  static const _collidePadding = 16.0;
  static const _collideIterations = 2;

  // Tuned on a 14-leaf hub plus a 25-node chain and on 40 unlinked nodes:
  // no two circles touch, leaves fan out evenly, 40 nodes span ~600 px.
  static const _repulsionScale = 400.0;
  static const _gravityScale = 10.0;
  static const _rangeFactor = 2.5;

  double alpha = 1;
  double alphaTarget = 0;

  final _random = Random();

  bool get isSettled => alpha < alphaMin && alphaTarget == 0;

  /// Warms the simulation back up after a change (new nodes, new settings).
  void reheat([double value = 0.5]) => alpha = max(alpha, value);

  /// Advances one frame. Returns false when nothing moved.
  bool tick() {
    if (isSettled) return false;
    alpha += (alphaTarget - alpha) * alphaDecay;

    final degree = <GraphNode<T>, int>{};
    for (final edge in edges) {
      degree
        ..update(edge.source, (d) => d + 1, ifAbsent: () => 1)
        ..update(edge.target, (d) => d + 1, ifAbsent: () => 1);
    }

    _applyRepulsion(degree);
    _applyLinks(degree);
    _applyGravity();
    _recenter();

    for (final node in nodes) {
      if (node.isDragging) {
        node.velocity = Offset.zero;
        continue;
      }
      node
        ..velocity *= _velocityDecay
        ..position += node.velocity;
    }

    for (var i = 0; i < _collideIterations; i++) {
      _separateOverlaps();
    }
    _clampToBounds();
    return true;
  }

  /// Many-body repulsion as in d3: falls off as 1/d, not 1/d², so nodes
  /// still feel each other across a ring and space out evenly. Hubs push a
  /// little harder so they get room.
  void _applyRepulsion(Map<GraphNode<T>, int> degree) {
    for (var i = 0; i < nodes.length; i++) {
      final a = nodes[i];
      for (var j = i + 1; j < nodes.length; j++) {
        final b = nodes[j];
        var delta = b.position - a.position;
        if (delta.distanceSquared < 1) delta = _jiggle();
        final d2 = max(delta.distanceSquared, 400); // never explode below 20px
        // Fades out by [_rangeFactor] link lengths (d3's distanceMax):
        // without a horizon, far-away nodes blow a hub's leaves into a
        // tight fan on its far side.
        final range = 1 - sqrt(d2) / (linkDistance * _rangeFactor);
        if (range <= 0) continue;
        final hubs = 1 + 0.15 * ((degree[a] ?? 0) + (degree[b] ?? 0));
        final push =
            delta * (repulsion * _repulsionScale * hubs * alpha * range / d2);
        a.velocity -= push;
        b.velocity += push;
      }
    }
  }

  /// Springs towards [linkDistance]. Like d3, the better-connected end of
  /// a link moves less, so hubs stay put and leaves arrange around them.
  /// A hub's links grow with its degree so every leaf fits on the ring
  /// with room to spare; otherwise leaves jam into a double layer.
  void _applyLinks(Map<GraphNode<T>, int> degree) {
    final strength = (linkStrength * 6).clamp(0.0, 1.0);
    for (final edge in edges) {
      final s = edge.source;
      final t = edge.target;
      if (s.appear == 0 || t.appear == 0) continue;
      var delta = (t.position + t.velocity) - (s.position + s.velocity);
      if (delta.distanceSquared < 1) delta = _jiggle();
      final d = delta.distance;
      final ds = degree[s] ?? 1;
      final dt = degree[t] ?? 1;
      // Leaves fan out on the far side of a hub, so size the ring for a
      // half circle, not a full one.
      final slot = (s.size + t.size) / 2 + _collidePadding + 30;
      final ringDistance = max(ds, dt) * slot / pi;
      final k =
          (d - max(linkDistance, ringDistance)) /
          d *
          alpha *
          strength /
          min(ds, dt);
      final bias = ds / (ds + dt);
      t.velocity -= delta * (k * bias);
      s.velocity += delta * (k * (1 - bias));
    }
  }

  /// Keeps the graph's centre of mass at the origin by translation, like
  /// d3's forceCenter: it never squeezes the layout. Skipped while a node
  /// is held, so the graph does not slide under the finger.
  void _recenter() {
    if (nodes.isEmpty || nodes.any((n) => n.isDragging)) return;
    var sum = Offset.zero;
    for (final node in nodes) {
      sum += node.position;
    }
    final shift = sum / nodes.length.toDouble();
    for (final node in nodes) {
      node.position -= shift;
    }
  }

  void _applyGravity() {
    final k = (centerForce * _gravityScale).clamp(0.0, 1.0) * alpha;
    if (k == 0) return;
    for (final node in nodes) {
      node.velocity -= node.position * k;
    }
  }

  /// Pushes intersecting circles apart along the line between centres.
  /// Pinned nodes take none of the correction.
  void _separateOverlaps() {
    for (var i = 0; i < nodes.length; i++) {
      final a = nodes[i];
      for (var j = i + 1; j < nodes.length; j++) {
        final b = nodes[j];
        final minDistance = (a.size + b.size) / 2 + _collidePadding;
        var delta = b.position - a.position;
        if (delta.distanceSquared < 1) delta = _jiggle();
        final d = delta.distance;
        if (d >= minDistance) continue;
        // A touch of sideways push: two nodes stacked exactly in line
        // (a leaf behind a leaf) would otherwise never slide apart.
        final dir = delta / d;
        final side =
            Offset(-dir.dy, dir.dx) * ((_random.nextDouble() - 0.5) * 0.4);
        final shift = (dir + side) * (minDistance - d);
        if (a.isDragging) {
          b.position += shift;
        } else if (b.isDragging) {
          a.position -= shift;
        } else {
          a.position -= shift / 2;
          b.position += shift / 2;
        }
      }
    }
  }

  void _clampToBounds() {
    for (final node in nodes) {
      final p = node.position;
      final clamped = Offset(
        p.dx.clamp(-halfExtent.dx, halfExtent.dx),
        p.dy.clamp(-halfExtent.dy, halfExtent.dy),
      );
      if (clamped != p) {
        node
          ..position = clamped
          ..velocity = Offset.zero;
      }
    }
  }

  /// A tiny random offset so coincident nodes have a direction to part in.
  Offset _jiggle() =>
      Offset(_random.nextDouble() - 0.5, _random.nextDouble() - 0.5) * 1e-3;
}
