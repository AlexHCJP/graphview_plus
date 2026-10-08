import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'graph_node.dart';
import 'graph_simulation.dart';

/// Owns the graph: its nodes, links, physics and the reveal animation.
///
/// Call [setGraph] whenever your data changes; nodes with a known [GraphNode.id]
/// keep their place, new ones pop in one by one next to a visible neighbour.
/// [GraphView] drives [step] every frame and repaints when it returns true.
class GraphController<T> extends ChangeNotifier {
  GraphController({this.canvasSize = const Size(5000, 5000)})
    : simulation = GraphSimulation<T>(
        nodes: [],
        edges: [],
        halfExtent: Offset(canvasSize.width / 2, canvasSize.height / 2),
      );

  /// The scrollable area; nodes stay inside it.
  final Size canvasSize;

  final GraphSimulation<T> simulation;

  /// Visible nodes, in reveal order.
  List<GraphNode<T>> get nodes => simulation.nodes;
  List<GraphEdge<T>> get edges => simulation.edges;

  final _byId = <String, GraphNode<T>>{};
  final _pending = <GraphNode<T>>[];
  int _ticksToReveal = 0;
  final _random = Random();

  bool _physicsEnabled = true;

  /// Pause the layout while keeping drag, zoom and reveal working.
  bool get physicsEnabled => _physicsEnabled;
  set physicsEnabled(bool value) {
    if (_physicsEnabled == value) return;
    _physicsEnabled = value;
    if (value) simulation.reheat(0.5);
    notifyListeners();
  }

  /// Weak pull towards the centre; see [GraphSimulation.centerForce].
  double get centerForce => simulation.centerForce;
  set centerForce(double value) => _tune(() => simulation.centerForce = value);

  /// See [GraphSimulation.repulsion].
  double get repulsion => simulation.repulsion;
  set repulsion(double value) => _tune(() => simulation.repulsion = value);

  /// See [GraphSimulation.linkStrength].
  double get linkStrength => simulation.linkStrength;
  set linkStrength(double value) =>
      _tune(() => simulation.linkStrength = value);

  /// See [GraphSimulation.linkDistance].
  double get linkDistance => simulation.linkDistance;
  set linkDistance(double value) =>
      _tune(() => simulation.linkDistance = value);

  void _tune(void Function() change) {
    change();
    simulation.reheat(1);
    notifyListeners();
  }

  /// Replaces the graph. Nodes whose id already exists keep position,
  /// velocity and animation state; the rest are queued to appear.
  /// Links to unknown ids are ignored.
  void setGraph({
    required List<GraphNode<T>> nodes,
    required List<GraphLink> links,
  }) {
    _links = List.of(links);
    final previous = Map.of(_byId);
    _byId.clear();
    _pending.clear();
    simulation.nodes.clear();

    for (final node in nodes) {
      final old = previous[node.id];
      _byId[node.id] = node;
      if (old != null && old.appear > 0) {
        node
          ..position = old.position
          ..velocity = old.velocity
          ..appear = old.appear
          ..isDragging = old.isDragging;
        simulation.nodes.add(node);
      } else {
        _pending.add(node..appear = 0);
      }
    }
    simulation.edges = [
      for (final link in links)
        if (_byId[link.sourceId] case final s?)
          if (_byId[link.targetId] case final t?) GraphEdge(s, t),
    ];
    simulation.reheat(1);
    notifyListeners();
  }

  List<GraphLink> _links = const [];

  /// Adds one node (or replaces the one with the same id) and reveals it.
  void addNode(GraphNode<T> node) => setGraph(
    nodes: [..._all.where((n) => n.id != node.id), node],
    links: _links,
  );

  /// Removes a node and every link that touches it.
  void removeNode(String id) => setGraph(
    nodes: [..._all.where((n) => n.id != id)],
    links: [
      for (final l in _links)
        if (l.sourceId != id && l.targetId != id) l,
    ],
  );

  /// Links two existing nodes; unknown ids are ignored.
  void addLink(GraphLink link) =>
      setGraph(nodes: _all, links: [..._links, link]);

  void removeLink(GraphLink link) => setGraph(
    nodes: _all,
    links: [
      for (final l in _links)
        if (!(l.sourceId == link.sourceId && l.targetId == link.targetId)) l,
    ],
  );

  void clear() => setGraph(nodes: const [], links: const []);

  /// Every node, shown or still queued.
  List<GraphNode<T>> get _all => [..._byId.values];

  /// Repaints after you changed a node's colour or label data.
  void refresh() => notifyListeners();

  /// Warms the layout up again, e.g. after a window resize.
  void reheat([double alpha = 0.5]) => simulation.reheat(alpha);

  GraphNode<T>? nodeById(String id) => _byId[id];

  /// Advances reveal and physics by one frame. True when anything moved.
  bool step() {
    final revealed = _revealStep();
    if (revealed) simulation.reheat(0.3);
    final moved = _physicsEnabled && simulation.tick();
    return revealed || moved;
  }

  /// Shows the next node from the queue next to a visible neighbour and
  /// grows the ones already appearing. True when something changed.
  bool _revealStep() {
    var changed = false;
    for (final node in simulation.nodes) {
      if (node.appear < 1) {
        node.appear = min(1, node.appear + 0.06);
        changed = true;
      }
    }
    if (_pending.isEmpty || _ticksToReveal-- > 0) return changed;
    // ~2.5 s for the whole graph: 2–6 ticks apart, big graphs in batches.
    final total = _byId.length;
    _ticksToReveal = (150 ~/ max(total, 1)).clamp(2, 6);
    for (var i = (total / 75).ceil(); i > 0 && _pending.isNotEmpty; i--) {
      GraphNode<T>? neighbor;
      var index = 0;
      for (; index < _pending.length && neighbor == null; index++) {
        neighbor = _visibleNeighbor(_pending[index]);
      }
      final node = _pending.removeAt(neighbor == null ? 0 : index - 1);
      final kick = Offset(
        _random.nextDouble() - 0.5,
        _random.nextDouble() - 0.5,
      );
      node
        ..position = neighbor == null
            ? kick * 300
            : neighbor.position + kick * 40
        ..velocity = kick * 4
        ..appear = 0.01;
      simulation.nodes.add(node);
    }
    return true;
  }

  GraphNode<T>? _visibleNeighbor(GraphNode<T> node) {
    for (final edge in simulation.edges) {
      if (edge.source == node && edge.target.appear > 0) return edge.target;
      if (edge.target == node && edge.source.appear > 0) return edge.source;
    }
    return null;
  }

  /// Node under [canvasPoint] (relative to the canvas origin), if any.
  GraphNode<T>? hitTest(Offset canvasPoint) {
    for (final node in simulation.nodes.reversed) {
      if ((node.position - canvasPoint).distance <= node.size / 2) return node;
    }
    return null;
  }

  // Dragging: the view calls these; the node stays pinned in between.

  void beginDrag(GraphNode<T> node) {
    simulation
      ..alphaTarget = 0.3
      ..reheat(0.3);
    node
      ..velocity = Offset.zero
      ..isDragging = true;
    notifyListeners();
  }

  void dragTo(GraphNode<T> node, Offset canvasPoint) {
    node
      ..position = Offset(
        canvasPoint.dx.clamp(-canvasSize.width / 2, canvasSize.width / 2),
        canvasPoint.dy.clamp(-canvasSize.height / 2, canvasSize.height / 2),
      )
      ..velocity = Offset.zero;
    notifyListeners();
  }

  void endDrag(GraphNode<T> node) {
    simulation.alphaTarget = 0;
    node.isDragging = false;
    notifyListeners();
  }
}
