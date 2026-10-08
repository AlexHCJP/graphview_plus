import 'package:flutter_test/flutter_test.dart';
import 'package:graphview_plus/graphview_plus.dart';

void main() {
  test('new nodes are revealed one by one, then everything settles', () {
    final controller = GraphController<void>();
    controller.setGraph(
      nodes: [for (var i = 0; i < 5; i++) GraphNode(id: '$i', label: '$i')],
      links: [for (var i = 1; i < 5; i++) GraphLink('0', '$i')],
    );
    expect(controller.nodes, isEmpty, reason: 'nodes start queued');

    var steps = 0;
    while (controller.step()) {
      steps++;
      expect(steps, lessThan(2000));
    }
    expect(controller.nodes.length, 5);
    expect(controller.edges.length, 4);
    expect(controller.nodes.every((n) => n.appear == 1), isTrue);
  });

  test('setGraph keeps the place of nodes it already knows', () {
    final controller = GraphController<void>();
    controller.setGraph(
      nodes: [
        GraphNode(id: 'a', label: 'a'),
        GraphNode(id: 'b', label: 'b'),
      ],
      links: const [GraphLink('a', 'b')],
    );
    while (controller.step()) {}
    final a = controller.nodeById('a')!.position;

    controller.setGraph(
      nodes: [
        GraphNode(id: 'a', label: 'a renamed'),
        GraphNode(id: 'c', label: 'c'),
      ],
      links: const [GraphLink('a', 'c'), GraphLink('a', 'missing')],
    );
    expect(controller.nodeById('a')!.position, a);
    expect(controller.nodeById('a')!.label, 'a renamed');
    expect(controller.nodeById('b'), isNull);
    expect(controller.nodes.map((n) => n.id), ['a'], reason: 'c is queued');
    expect(controller.edges.length, 1, reason: 'link to unknown id dropped');
  });

  test('hitTest finds the node under a canvas point', () {
    final controller = GraphController<void>();
    controller.setGraph(
      nodes: [GraphNode(id: 'a', label: 'a')],
      links: const [],
    );
    while (controller.step()) {}
    final node = controller.nodeById('a')!;
    expect(controller.hitTest(node.position + const Offset(10, 0)), node);
    expect(controller.hitTest(node.position + const Offset(60, 0)), isNull);
  });

  test('addNode, addLink and removeNode edit the graph in place', () {
    final controller = GraphController<void>()
      ..setGraph(
        nodes: [GraphNode(id: 'a', label: 'a')],
        links: const [],
      );
    while (controller.step()) {}
    final a = controller.nodeById('a')!.position;

    controller
      ..addNode(GraphNode(id: 'b', label: 'b'))
      ..addLink(const GraphLink('a', 'b'));
    // Known nodes keep their place at the moment of the change; the layout
    // may of course move them afterwards.
    expect(controller.nodeById('a')!.position, a);
    while (controller.step()) {}
    expect(controller.edges.length, 1);

    controller.removeNode('b');
    expect(controller.nodeById('b'), isNull);
    expect(controller.edges, isEmpty);
  });
}
