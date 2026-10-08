import 'package:flutter/material.dart';
import 'package:graphview_plus/graphview_plus.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final _controller = GraphController<String>();

  @override
  void initState() {
    super.initState();
    // Three teams of tasks around their leads, a few cross-team links and
    // a chain of follow-ups: the shapes a real graph is made of.
    const teams = [
      (
        'Design',
        Color(0xFF8E7CF3),
        ['Moodboard', 'Wireframes', 'Icons', 'Typography', 'Palette'],
      ),
      (
        'Backend',
        Color(0xFF55C7A5),
        ['Auth', 'Billing', 'Search', 'Sync', 'Backups', 'Metrics'],
      ),
      (
        'Mobile',
        Color(0xFFF2A65A),
        ['Onboarding', 'Offline', 'Push', 'Widgets'],
      ),
    ];
    final nodes = <GraphNode<String>>[];
    final links = <GraphLink>[];
    for (final (lead, color, tasks) in teams) {
      nodes.add(
        GraphNode(id: lead, label: lead, color: color, size: 64, data: lead),
      );
      for (final task in tasks) {
        nodes.add(GraphNode(id: task, label: task, color: color, data: task));
        links.add(GraphLink(lead, task));
      }
    }
    links.addAll(const [
      GraphLink('Wireframes', 'Onboarding'),
      GraphLink('Auth', 'Onboarding'),
      GraphLink('Sync', 'Offline'),
      GraphLink('Icons', 'Widgets'),
    ]);
    const followUps = [
      'Release 1.0',
      'Beta feedback',
      'Fix crashes',
      'Release 1.1',
    ];
    for (var i = 0; i < followUps.length; i++) {
      nodes.add(
        GraphNode(
          id: followUps[i],
          label: followUps[i],
          color: const Color(0xFFE5667A),
          data: followUps[i],
        ),
      );
      links.add(GraphLink(i == 0 ? 'Push' : followUps[i - 1], followUps[i]));
    }
    _controller.setGraph(nodes: nodes, links: links);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.dark(
      useMaterial3: true,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFF131112)),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('graphview_plus'),
        backgroundColor: const Color(0xFF131112),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              icon: Icon(
                _controller.physicsEnabled ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () =>
                  _controller.physicsEnabled = !_controller.physicsEnabled,
            ),
          ),
        ],
      ),
      body: GraphView<String>(
        controller: _controller,
        showLabels: true,
        initialScale: 0.55,
        onNodeTap: (node) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(node.data!))),
      ),
    ),
  );
}
