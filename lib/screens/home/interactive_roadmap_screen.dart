import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../../core/theme.dart';
import '../../data/models/career_model.dart';

class InteractiveRoadmapScreen extends StatefulWidget {
  final CareerModel career;

  const InteractiveRoadmapScreen({super.key, required this.career});

  @override
  State<InteractiveRoadmapScreen> createState() => _InteractiveRoadmapScreenState();
}

class _InteractiveRoadmapScreenState extends State<InteractiveRoadmapScreen> {
  final Graph _graph = Graph()..isTree = true;
  final SugiyamaConfiguration _builder = SugiyamaConfiguration();
  bool _isGraphInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeGraph();
  }

  void _initializeGraph() {
    if (widget.career.roadmapSteps.isEmpty) {
      setState(() => _isGraphInitialized = true);
      return;
    }

    Map<String, Node> graphNodes = {};
    
    for (var step in widget.career.roadmapSteps) {
      graphNodes[step.id] = Node.Id(step.id);
    }

    for (var step in widget.career.roadmapSteps) {
      if (graphNodes.containsKey(step.id)) {
        for (var childId in step.nextSteps) {
          if (graphNodes.containsKey(childId)) {
            _graph.addEdge(graphNodes[step.id]!, graphNodes[childId]!);
          }
        }
      }
    }

    _builder
      ..nodeSeparation = (60)
      ..levelSeparation = (120)
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;

    setState(() => _isGraphInitialized = true);
  }

  Widget _buildGraphNode(String nodeId, bool isDark) {
    final nodeData = widget.career.roadmapSteps.firstWhere(
      (n) => n.id == nodeId, 
      orElse: () => RoadmapNode(id: '', label: 'Unknown', nextSteps: [])
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 200), 
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondaryAccent, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryAccent.withValues(alpha: 0.3), // 🚀 FIXED
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5)
          )
        ]
      ),
      child: Text(
        nodeData.label, 
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, 
          fontWeight: FontWeight.bold, 
          fontSize: 14,
          height: 1.4,
        )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 REMOVED UNUSED isDark VARIABLE

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Career Canvas', style: TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.career.name, style: const TextStyle(color: AppTheme.secondaryAccent, fontSize: 12)),
          ],
        ),
        iconTheme: const IconThemeData(color: AppTheme.textWhite),
      ),
      body: Stack(
        children: [
          if (!_isGraphInitialized)
            const Center(child: CircularProgressIndicator(color: AppTheme.secondaryAccent))
          else if (widget.career.roadmapSteps.isEmpty)
            const Center(child: Text("No roadmap data available.", style: TextStyle(color: AppTheme.textWhite)))
          else
            SizedBox.expand(
              child: InteractiveViewer(
                constrained: false, 
                boundaryMargin: const EdgeInsets.all(2000), 
                minScale: 0.1,
                maxScale: 3.0,
                child: Padding(
                  padding: const EdgeInsets.all(150.0), 
                  child: GraphView(
                    graph: _graph,
                    algorithm: SugiyamaAlgorithm(_builder),
                    paint: Paint()
                      ..color = AppTheme.primaryAccent.withValues(alpha: 0.6) // 🚀 FIXED
                      ..strokeWidth = 3
                      ..style = PaintingStyle.stroke,
                    builder: (Node node) => _buildGraphNode(node.key!.value as String, true),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7), // 🚀 FIXED
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pinch, color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Text("Pinch to zoom, drag to pan", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}