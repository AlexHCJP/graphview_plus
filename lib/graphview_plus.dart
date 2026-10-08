/// Interactive force-directed graph for Flutter.
///
/// Build a [GraphController], feed it nodes and links with
/// [GraphController.setGraph], and show it with [GraphView]:
///
/// ```dart
/// final controller = GraphController();
/// controller.setGraph(
///   nodes: [GraphNode(id: 'a', label: 'Alpha'), GraphNode(id: 'b', label: 'Beta')],
///   links: const [GraphLink('a', 'b')],
/// );
/// // ...
/// GraphView(controller: controller, onNodeTap: (node) => print(node.id));
/// ```
library;

export 'src/graph_controller.dart';
export 'src/graph_node.dart';
export 'src/graph_simulation.dart' show GraphSimulation;
export 'src/graph_view.dart';
