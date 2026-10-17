import 'package:flutter/material.dart';

void main() {
  runApp(const CadFloorPlannerApp());
}

class CadFloorPlannerApp extends StatelessWidget {
  const CadFloorPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CAD Floor Studio Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00B0FF),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        useMaterial3: true,
      ),
      home: const CadWorkspaceScreen(),
    );
  }
}

enum ToolMode { wall, stamp, select, pan }

enum WallType { external9Inch, internal4Inch, beamLine }

enum ArchElementType {
  doorSingle,
  doorDouble,
  windowGlass,
  bedKing,
  sofaL,
  diningSet,
  kitchenSinkStove,
  toiletBath,
  staircase,
  rccColumn
}

class WallSegment {
  Offset start;
  Offset end;
  WallType type;

  WallSegment({
    required this.start,
    required this.end,
    this.type = WallType.external9Inch,
  });

  double get pixelLength => (end - start).distance;

  double get thicknessPx {
    switch (type) {
      case WallType.external9Inch:
        return 10.0;
      case WallType.internal4Inch:
        return 5.5;
      case WallType.beamLine:
        return 3.0;
    }
  }

  WallSegment copy() => WallSegment(start: start, end: end, type: type);
}

class ArchItem {
  String label;
  ArchElementType type;
  Offset position;
  Size size;
  double rotationDeg;

  ArchItem({
    required this.label,
    required this.type,
    required this.position,
    required this.size,
    this.rotationDeg = 0.0,
  });

  ArchItem copy() => ArchItem(
        label: label,
        type: type,
        position: position,
        size: size,
        rotationDeg: rotationDeg,
      );
}

class ClosedRoom {
  final List<Offset> polygon;
  final double areaSqFt;
  final Offset center;
  String customName;
  Color tintColor;

  ClosedRoom({
    required this.polygon,
    required this.areaSqFt,
    required this.center,
    required this.customName,
    this.tintColor = const Color(0xFF1E88E5),
  });
}

class CanvasSnapshot {
  final List<WallSegment> walls;
  final List<ArchItem> items;
  final Map<String, String> roomNames;

  CanvasSnapshot({
    required this.walls,
    required this.items,
    required this.roomNames,
  });
}

class CadWorkspaceScreen extends StatefulWidget {
  const CadWorkspaceScreen({super.key});

  @override
  State<CadWorkspaceScreen> createState() => _CadWorkspaceScreenState();
}

class _CadWorkspaceScreenState extends State<CadWorkspaceScreen> {
  static const double pxPerFoot = 25.0;

  ToolMode activeTool = ToolMode.wall;
  WallType activeWallType = WallType.external9Inch;

  List<WallSegment> walls = [];
  List<ArchItem> items = [];
  List<ClosedRoom> detectedRooms = [];
  Map<String, String> savedRoomNames = {};
  Map<String, Color> savedRoomColors = {};

  final List<CanvasSnapshot> undoStack = [];
  final List<CanvasSnapshot> redoStack = [];

  Offset? draftWallStart;
  Offset? draftWallEnd;
  dynamic selectedObject;

  bool showMetric = false;
  bool isBlueprintMode = false;

  String projectName = "PROPOSED RESIDENTIAL BUILDING";
  String clientName = "MR. SURESH DESHMUKH";
  String firmName = "STRUCTURAL & CENTERING CONSULTANTS";
  double slabThicknessInches = 5.0;
  double wallHeightFeet = 10.0;

  final TransformationController _zoomController = TransformationController();

  CanvasSnapshot _snapshot() => CanvasSnapshot(
        walls: walls.map((w) => w.copy()).toList(),
        items: items.map((i) => i.copy()).toList(),
        roomNames: Map.from(savedRoomNames),
      );

  void _saveStateForUndo() {
    undoStack.add(_snapshot());
    if (undoStack.length > 30) undoStack.removeAt(0);
    redoStack.clear();
  }

  void _undo() {
    if (undoStack.isEmpty) return;
    redoStack.add(_snapshot());
    final prev = undoStack.removeLast();
    setState(() {
      walls = prev.walls;
      items = prev.items;
      savedRoomNames = prev.roomNames;
      selectedObject = null;
      _recalculateRooms();
    });
  }

  void _redo() {
    if (redoStack.isEmpty) return;
    undoStack.add(_snapshot());
    final next = redoStack.removeLast();
    setState(() {
      walls = next.walls;
      items = next.items;
      savedRoomNames = next.roomNames;
      selectedObject = null;
      _recalculateRooms();
    });
  }

  Offset _snapToGrid(Offset raw) {
    const double step = pxPerFoot / 2;
    double sx = (raw.dx / step).round() * step;
    double sy = (raw.dy / step).round() * step;

    for (var w in walls) {
      if ((w.start - raw).distance < 14.0) return w.start;
      if ((w.end - raw).distance < 14.0) return w.end;
    }
    return Offset(sx, sy);
  }

  void _spawnArchElement(
      String label, ArchElementType type, double widthFt, double heightFt) {
    _saveStateForUndo();
    setState(() {
      final newItem = ArchItem(
        label: label,
        type: type,
        position: const Offset(200, 275),
        size: Size(widthFt * pxPerFoot, heightFt * pxPerFoot),
      );
      items.add(newItem);
      selectedObject = newItem;
      activeTool = ToolMode.select;
    });
  }

  void _loadPresetTemplate(String preset) {
    _saveStateForUndo();
    walls.clear();
    items.clear();
    selectedObject = null;

    if (preset == '2BHK') {
      const double x0 = 50, y0 = 75, x1 = 350, y1 = 475;
      walls.addAll([
        WallSegment(start: const Offset(x0, y0), end: const Offset(x1, y0)),
        WallSegment(start: const Offset(x1, y0), end: const Offset(x1, y1)),
        WallSegment(start: const Offset(x1, y1), end: const Offset(x0, y1)),
        WallSegment(start: const Offset(x0, y1), end: const Offset(x0, y0)),
        WallSegment(
          start: const Offset(200, y0),
          end: const Offset(200, y1),
          type: WallType.internal4Inch,
        ),
        WallSegment(
          start: const Offset(x0, 275),
          end: const Offset(200, 275),
          type: WallType.internal4Inch,
        ),
        WallSegment(
          start: const Offset(200, 250),
          end: const Offset(x1, 250),
          type: WallType.internal4Inch,
        ),
      ]);
      for (var pt in [
        const Offset(x0, y0),
        const Offset(200, y0),
        const Offset(x1, y0),
        const Offset(x0, 275),
        const Offset(200, 250),
        const Offset(x1, 250),
        const Offset(x0, y1),
        const Offset(200, y1),
        const Offset(x1, y1),
      ]) {
        items.add(ArchItem(
          label: 'C1',
          type: ArchElementType.rccColumn,
          position: pt,
          size: const Size(18, 18),
        ));
      }
      items.addAll([
        ArchItem(
            label: 'Bed',
            type: ArchElementType.bedKing,
            position: const Offset(125, 160),
            size: const Size(125, 140)),
        ArchItem(
            label: 'Sofa',
            type: ArchElementType.sofaL,
            position: const Offset(275, 360),
            size: const Size(110, 80)),
        ArchItem(
            label: 'Kitchen',
            type: ArchElementType.kitchenSinkStove,
            position: const Offset(275, 130),
            size: const Size(110, 45)),
        ArchItem(
            label: 'Main Door',
            type: ArchElementType.doorSingle,
            position: const Offset(275, y1),
            size: const Size(75, 75)),
      ]);
    }
    setState(() {
      _recalculateRooms();
    });
  }

  void _recalculateRooms() {
    detectedRooms.clear();
    if (walls.length < 3) return;

    Map<String, List<Offset>> adj = {};
    String key(Offset p) => "${p.dx.round()}_${p.dy.round()}";

    for (var w in walls) {
      String k1 = key(w.start);
      String k2 = key(w.end);
      adj.putIfAbsent(k1, () => []).add(w.end);
      adj.putIfAbsent(k2, () => []).add(w.start);
    }

    List<List<Offset>> rawCycles = [];

    void dfs(Offset curr, Offset targetStart, List<Offset> path, int depth) {
      if (depth > 10) return;
      String k = key(curr);
      for (var nb in adj[k] ?? <Offset>[]) {
        if ((nb - targetStart).distance < 2.0 && path.length >= 3) {
          rawCycles.add(List.from(path));
          return;
        }
        if (!path.any((p) => (p - nb).distance < 2.0)) {
          path.add(nb);
          dfs(nb, targetStart, path, depth + 1);
          path.removeLast();
        }
      }
    }

    for (var w in walls) {
      dfs(w.start, w.start, [w.start], 1);
    }

    List<Set<String>> uniqueSets = [];
    int roomCounter = 1;

    for (var cycle in rawCycles) {
      final sig = cycle.map((p) => key(p)).toSet();
      bool exists =
          uniqueSets.any((s) => s.length == sig.length && s.containsAll(sig));
      if (!exists) {
        uniqueSets.add(sig);

        double signedArea = 0;
        double cx = 0, cy = 0;
        for (int i = 0; i < cycle.length; i++) {
          Offset p1 = cycle[i];
          Offset p2 = cycle[(i + 1) % cycle.length];
          signedArea += (p1.dx * p2.dy) - (p2.dx * p1.dy);
          cx += p1.dx;
          cy += p1.dy;
        }
        double areaPx = signedArea.abs() / 2.0;
        double sqFt = areaPx / (pxPerFoot * pxPerFoot);

        if (sqFt >= 12.0 && sqFt < 2500.0) {
          Offset center = Offset(cx / cycle.length, cy / cycle.length);
          String cKey =
              "${(center.dx / 25).round()}_${(center.dy / 25).round()}";
          String rName = savedRoomNames[cKey] ?? "ROOM $roomCounter";
          Color rColor = savedRoomColors[cKey] ?? const Color(0xFF00B0FF);
          roomCounter++;

          detectedRooms.add(
            ClosedRoom(
              polygon: cycle,
              areaSqFt: sqFt,
              center: center,
              customName: rName,
              tintColor: rColor,
            ),
          );
        }
      }
    }
  }

  String _formatDistance(double px) {
    double totalFeet = px / pxPerFoot;
    if (showMetric) {
      double meters = totalFeet * 0.3048;
      return "${meters.toStringAsFixed(2)} m";
    }
    int wholeFeet = totalFeet.floor();
    int inches = ((totalFeet - wholeFeet) * 12).round();
    if (inches == 12) {
      wholeFeet += 1;
      inches = 0;
    }
    return inches == 0 ? "$wholeFeet'" : "$wholeFeet' $inches\"";
  }

  void _showCivilEstimatorSheet() {
    double totalCarpetSqFt = detectedRooms.fold(0.0, (s, r) => s + r.areaSqFt);
    if (totalCarpetSqFt == 0 && walls.isNotEmpty) {
      totalCarpetSqFt = 400.0;
    }
    double slabSuperAreaSqFt = totalCarpetSqFt * 1.15;
    double totalWallRunningFt =
        walls.fold(0.0, (s, w) => s + (w.pixelLength / pxPerFoot));

    double slabVolumeCuFt = slabSuperAreaSqFt * (slabThicknessInches / 12.0);
    double slabVolumeCuM = slabVolumeCuFt / 35.3147;
    double centeringPlatesSqFt = slabSuperAreaSqFt + (totalWallRunningFt * 1.5);
    int woodenPropsCount = (centeringPlatesSqFt / 12.0).ceil();

    double wallVolumeCuFt = totalWallRunningFt * wallHeightFeet * 0.75;
    int totalBricks = (wallVolumeCuFt * 13.5).ceil();
    int cementBags = ((slabVolumeCuM * 8.0) + (wallVolumeCuFt * 0.06)).ceil();
    double steelKg = slabVolumeCuM * 85.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calculate, color: Colors.amberAccent, size: 28),
                    SizedBox(width: 10),
                    Text(
                      "Civil & Centering BOQ",
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            _boqSectionHeader("1. CENTERING & SHUTTERING"),
            _boqMetricTile(
              "Total Slab Shuttering Area",
              "${slabSuperAreaSqFt.toStringAsFixed(1)} Sq. Ft.",
              "Includes +15% beam/cantilever margin",
              Icons.grid_on,
              Colors.cyanAccent,
            ),
            _boqMetricTile(
              "Total Centering Area (with Beam Sides)",
              "${centeringPlatesSqFt.toStringAsFixed(1)} Sq. Ft.",
              "~(3'x2' Steel Plates: ${(centeringPlatesSqFt / 6).ceil()} Nos)",
              Icons.layers,
              Colors.lightBlueAccent,
            ),
            _boqMetricTile(
              "Adjustable Acrow Props (Supports)",
              "$woodenPropsCount Nos",
              "Spaced at 3.5 ft c/c under slab & beams",
              Icons.vertical_align_center,
              Colors.amberAccent,
            ),
            const SizedBox(height: 16),
            _boqSectionHeader("2. RCC SLAB & CONCRETE WORK"),
            _boqMetricTile(
              "Slab Concrete Volume (${slabThicknessInches.toInt()}\" Thick)",
              "${slabVolumeCuM.toStringAsFixed(2)} m³ (${slabVolumeCuFt.toStringAsFixed(0)} Cu.Ft)",
              "M20 Grade Ready-Mix / Site Mix",
              Icons.view_in_ar,
              Colors.greenAccent,
            ),
            _boqMetricTile(
              "TMT Steel Reinforcement",
              "${steelKg.toStringAsFixed(0)} Kg (${(steelKg / 1000).toStringAsFixed(2)} Tons)",
              "10mm & 8mm main/distribution bars + stirrups",
              Icons.linear_scale,
              Colors.orangeAccent,
            ),
            const SizedBox(height: 16),
            _boqSectionHeader(
                "3. MASONRY & WALLS (${wallHeightFeet.toInt()} FT HEIGHT)"),
            _boqMetricTile(
              "Total Running Wall Length",
              "${totalWallRunningFt.toStringAsFixed(1)} RFT",
              "${walls.length} wall segments drawn",
              Icons.straighten,
              Colors.purpleAccent,
            ),
            _boqMetricTile(
              "Red Clay / Fly-Ash Bricks",
              "$totalBricks Bricks",
              "Standard 9\"x4\"x3\" modular size",
              Icons.apps,
              Colors.redAccent,
            ),
            _boqMetricTile(
              "Total Cement Required (50 Kg Bags)",
              "$cementBags Bags",
              "Combined RCC Slab + Brickwork Mortar",
              Icons.inventory_2,
              Colors.tealAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _boqSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _boqMetricTile(
      String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _openRoomRenameDialog(ClosedRoom room) {
    final ctrl = TextEditingController(text: room.customName);
    String cKey =
        "${(room.center.dx / 25).round()}_${(room.center.dy / 25).round()}";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text("Customize Room"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: "Room Label (e.g. Living Hall, Bedroom)",
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (var preset in [
                  "LIVING HALL",
                  "MASTER BEDROOM",
                  "KITCHEN",
                  "BATH / WC",
                  "PORCH / PARKING",
                  "STAIRCASE"
                ])
                  ActionChip(
                    label: Text(preset, style: const TextStyle(fontSize: 10)),
                    onPressed: () => ctrl.text = preset,
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                savedRoomNames[cKey] = ctrl.text.toUpperCase();
                _recalculateRooms();
              });
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _openTitleBlockDialog() {
    final pCtrl = TextEditingController(text: projectName);
    final cCtrl = TextEditingController(text: clientName);
    final fCtrl = TextEditingController(text: firmName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Blueprint Sheet Setup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: fCtrl,
                decoration:
                    const InputDecoration(labelText: 'Firm / Centering Name')),
            TextField(
                controller: pCtrl,
                decoration: const InputDecoration(labelText: 'Project Title')),
            TextField(
                controller: cCtrl,
                decoration: const InputDecoration(labelText: 'Client Name')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                projectName = pCtrl.text.toUpperCase();
                clientName = cCtrl.text.toUpperCase();
                firmName = fCtrl.text.toUpperCase();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _inPoly(Offset p, List<Offset> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  ArchItem? _hitItem(Offset p) {
    for (final it in items.reversed) {
      final rect = Rect.fromCenter(
          center: it.position, width: it.size.width, height: it.size.height);
      if (rect.contains(p)) return it;
    }
    return null;
  }

  void _onTap(Offset p) {
    if (activeTool != ToolMode.select) return;
    final hit = _hitItem(p);
    if (hit != null) {
      setState(() => selectedObject = hit);
      return;
    }
    setState(() => selectedObject = null);
    for (final r in detectedRooms) {
      if (_inPoly(p, r.polygon)) {
        _openRoomRenameDialog(r);
        return;
      }
    }
  }

  void _deleteSelected() {
    if (selectedObject == null) return;
    _saveStateForUndo();
    setState(() {
      items.remove(selectedObject);
      walls.remove(selectedObject);
      selectedObject = null;
      _recalculateRooms();
    });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(firmName, style: const TextStyle(fontSize: 13)),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: _undo),
          IconButton(icon: const Icon(Icons.redo), onPressed: _redo),
          IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected),
          IconButton(
              icon: const Icon(Icons.calculate),
              onPressed: _showCivilEstimatorSheet),
          IconButton(
              icon: const Icon(Icons.edit_note),
              onPressed: _openTitleBlockDialog),
          IconButton(
              icon: const Icon(Icons.straighten),
              onPressed: () => setState(() => showMetric = !showMetric)),
          IconButton(
              icon: const Icon(Icons.blur_on),
              onPressed: () =>
                  setState(() => isBlueprintMode = !isBlueprintMode)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.home_work),
            onSelected: _loadPresetTemplate,
            itemBuilder: (_) => const [
              PopupMenuItem(value: '2BHK', child: Text('Load 2BHK')),
            ],
          ),
        ],
      ),
      body: InteractiveViewer(
        transformationController: _zoomController,
        panEnabled: activeTool == ToolMode.pan,
        scaleEnabled: true,
        minScale: 0.5,
        maxScale: 4,
        constrained: false,
        child: GestureDetector(
          onTapUp: (d) => _onTap(d.localPosition),
          onPanStart: (d) {
            final p = d.localPosition;
            if (activeTool == ToolMode.wall) {
              setState(() {
                draftWallStart = _snapToGrid(p);
                draftWallEnd = draftWallStart;
              });
            } else if (activeTool == ToolMode.select) {
              final hit = _hitItem(p);
              if (hit != null) {
                _saveStateForUndo();
                setState(() => selectedObject = hit);
              }
            }
          },
          onPanUpdate: (d) {
            final p = d.localPosition;
            if (activeTool == ToolMode.wall && draftWallStart != null) {
              setState(() => draftWallEnd = _snapToGrid(p));
            } else if (activeTool == ToolMode.select &&
                selectedObject is ArchItem) {
              setState(() => (selectedObject as ArchItem).position += d.delta);
            }
          },
          onPanEnd: (_) {
            if (activeTool == ToolMode.wall &&
                draftWallStart != null &&
                draftWallEnd != null) {
              if ((draftWallEnd! - draftWallStart!).distance > 5) {
                _saveStateForUndo();
                walls.add(WallSegment(
                    start: draftWallStart!,
                    end: draftWallEnd!,
                    type: activeWallType));
                _recalculateRooms();
              }
            }
            setState(() {
              draftWallStart = null;
              draftWallEnd = null;
            });
          },
          child: CustomPaint(
            size: const Size(400, 550),
            painter: _PlanPainter(
              walls: walls,
              items: items,
              rooms: detectedRooms,
              draftStart: draftWallStart,
              draftEnd: draftWallEnd,
              selected: selectedObject,
              fmt: _formatDistance,
              blueprint: isBlueprintMode,
              title: '$projectName • $clientName',
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in ToolMode.values)
                TextButton(
                  onPressed: () => setState(() => activeTool = t),
                  child: Text(t.name.toUpperCase(),
                      style: TextStyle(
                          color:
                              t == activeTool ? Colors.amberAccent : null)),
                ),
              PopupMenuButton<WallType>(
                icon: const Icon(Icons.line_weight),
                onSelected: (v) => setState(() => activeWallType = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: WallType.external9Inch, child: Text('9" wall')),
                  PopupMenuItem(
                      value: WallType.internal4Inch, child: Text('4" wall')),
                  PopupMenuItem(
                      value: WallType.beamLine, child: Text('Beam line')),
                ],
              ),
              PopupMenuButton<int>(
                icon: const Icon(Icons.chair),
                onSelected: (i) {
                  const defs = [
                    ('Door', ArchElementType.doorSingle, 3.0, 3.0),
                    ('Window', ArchElementType.windowGlass, 4.0, 0.5),
                    ('Bed', ArchElementType.bedKing, 5.0, 5.5),
                    ('Sofa', ArchElementType.sofaL, 4.5, 3.0),
                    ('Column', ArchElementType.rccColumn, 0.75, 0.75),
                  ];
                  final d = defs[i];
                  _spawnArchElement(d.$1, d.$2, d.$3, d.$4);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 0, child: Text('Door')),
                  PopupMenuItem(value: 1, child: Text('Window')),
                  PopupMenuItem(value: 2, child: Text('Bed')),
                  PopupMenuItem(value: 3, child: Text('Sofa')),
                  PopupMenuItem(value: 4, child: Text('Column')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanPainter extends CustomPainter {
  final List<WallSegment> walls;
  final List<ArchItem> items;
  final List<ClosedRoom> rooms;
  final Offset? draftStart;
  final Offset? draftEnd;
  final dynamic selected;
  final String Function(double) fmt;
  final bool blueprint;
  final String title;

  _PlanPainter({
    required this.walls,
    required this.items,
    required this.rooms,
    required this.draftStart,
    required this.draftEnd,
    required this.selected,
    required this.fmt,
    required this.blueprint,
    required this.title,
  });

  void _text(Canvas c, String s, Offset at, double fs, Color col) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fs, color: col)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color =
              blueprint ? const Color(0xFF0B3D91) : const Color(0xFF111820));

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 25) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += 25) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final r in rooms) {
      final path = Path()..addPolygon(r.polygon, true);
      canvas.drawPath(
          path, Paint()..color = r.tintColor.withValues(alpha: 0.15));
      _text(canvas, r.customName, r.center, 10, Colors.white);
      _text(canvas, '${r.areaSqFt.toStringAsFixed(0)} sq ft',
          r.center + const Offset(0, 13), 9, Colors.white60);
    }

    for (final w in walls) {
      canvas.drawLine(
        w.start,
        w.end,
        Paint()
          ..color = identical(w, selected) ? Colors.amberAccent : Colors.white
          ..strokeWidth = w.thicknessPx
          ..strokeCap = StrokeCap.square,
      );
      _text(canvas, fmt(w.pixelLength),
          (w.start + w.end) / 2 + const Offset(0, -12), 8, Colors.cyanAccent);
    }

    for (final it in items) {
      canvas.save();
      canvas.translate(it.position.dx, it.position.dy);
      canvas.rotate(it.rotationDeg * 3.1415926535 / 180);
      final rect = Rect.fromCenter(
          center: Offset.zero, width: it.size.width, height: it.size.height);
      canvas.drawRect(
          rect, Paint()..color = Colors.orangeAccent.withValues(alpha: 0.25));
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = identical(it, selected) ? 2.5 : 1
          ..color = identical(it, selected)
              ? Colors.amberAccent
              : Colors.orangeAccent,
      );
      _text(canvas, it.label, Offset.zero, 9, Colors.white);
      canvas.restore();
    }

    if (draftStart != null && draftEnd != null) {
      canvas.drawLine(
          draftStart!,
          draftEnd!,
          Paint()
            ..color = Colors.lightBlueAccent
            ..strokeWidth = 4);
      _text(
          canvas,
          fmt((draftEnd! - draftStart!).distance),
          (draftStart! + draftEnd!) / 2 + const Offset(0, -14),
          10,
          Colors.lightBlueAccent);
    }

    _text(canvas, title, Offset(size.width / 2, size.height - 12), 9,
        Colors.white54);
  }

  @override
  bool shouldRepaint(covariant _PlanPainter old) => true;
}
   
