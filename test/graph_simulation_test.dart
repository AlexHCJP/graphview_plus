import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphview_plus/graphview_plus.dart';

GraphNode<void> _node(int id, Offset position) =>
    GraphNode(id: '$id', label: '$id', position: position);

void main() {
  test('settles with no overlapping nodes', () {
    final random = Random(1);
    final nodes = [
      for (var i = 0; i < 40; i++)
        _node(i, Offset(random.nextDouble() * 100, random.nextDouble() * 100)),
    ];
    // A hub with many leaves plus a chain: the shapes that used to pile up.
    final edges = [
      for (var i = 1; i < 15; i++) GraphEdge(nodes[0], nodes[i]),
      for (var i = 15; i < 39; i++) GraphEdge(nodes[i], nodes[i + 1]),
    ];
    final sim = GraphSimulation<void>(
      nodes: nodes,
      edges: edges,
      halfExtent: const Offset(2500, 2500),
    );

    var ticks = 0;
    while (sim.tick()) {
      ticks++;
      expect(ticks, lessThan(1000), reason: 'never settled');
    }

    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final d = (nodes[i].position - nodes[j].position).distance;
        // Circles are 50 px wide; a gap must remain between any two.
        expect(d, greaterThan(50), reason: 'nodes $i,$j overlap');
      }
    }
    // Whatever is left when alpha hits the floor is sub-pixel.
    for (final node in nodes) {
      expect(node.velocity.distance, lessThan(0.5));
    }
  });

  test('two nodes on the same spot are pushed apart', () {
    final nodes = [_node(0, Offset.zero), _node(1, Offset.zero)];
    GraphSimulation<void>(
      nodes: nodes,
      edges: [],
      halfExtent: const Offset(2500, 2500),
    ).tick();
    expect((nodes[0].position - nodes[1].position).distance, greaterThan(50));
  });

  test('a dragged node is never moved by the simulation', () {
    final pinned = _node(0, const Offset(10, 10))..isDragging = true;
    final other = _node(1, const Offset(12, 10));
    final sim = GraphSimulation<void>(
      nodes: [pinned, other],
      edges: [GraphEdge(pinned, other)],
      halfExtent: const Offset(2500, 2500),
    );
    for (var i = 0; i < 50; i++) {
      sim.tick();
    }
    expect(pinned.position, const Offset(10, 10));
    expect((other.position - pinned.position).distance, greaterThan(50));
  });
}
