import 'package:flutter/material.dart';

/// Entrypoint of the application.
/// Starts the Flutter application by running the [MyApp] widget.
void main() {
  runApp(const MyApp());
}

/// The main widget of the application.
/// Builds a [MaterialApp] with a centered [Dock].
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey[200], // Light grey background
        body: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white, // Background color for the "dock"
              borderRadius: BorderRadius.circular(32), // Rounded edges
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.2 * 255).toInt()), //shadow
                  blurRadius: 20, // Blurred effect for depth
                  offset: const Offset(0, 10), // Downward offset for shadow
                ),
              ],
            ),
            child: Dock(
              items: const [
                {'icon': Icons.person, 'label': 'Person', 'color': Colors.blue},
                {
                  'icon': Icons.message,
                  'label': 'Message',
                  'color': Colors.green
                },
                {'icon': Icons.call, 'label': 'Call', 'color': Colors.red},
                {
                  'icon': Icons.camera,
                  'label': 'Camera',
                  'color': Colors.purple
                },
                {'icon': Icons.photo, 'label': 'Photo', 'color': Colors.orange},
              ],
              builder: (item, isDragging, isHovered) {
                // Extract the icon and color properties from the item
                final IconData icon = item['icon'] as IconData;
                final Color color = item['color'] as Color;

                // Define the icon's appearance
                return AnimatedScale(
                  scale: isHovered ? 1.2 : 1.0, // Enlarge the icon on hover
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white, // Icon background
                      shape: BoxShape.circle, // Circular shape
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(100), // Subtle glow
                          blurRadius: 10, // Blur radius for the shadow
                          spreadRadius: 2, // Spread radius for the shadow
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        icon, // The icon itself
                        color: isDragging
                            ? Colors.white
                            : color, // Change color if dragging
                        size: 32,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A customizable "dock" widget that allows drag-and-drop reordering of items.
class Dock<T extends Map<String, Object>> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  /// Initial list of items to display in the dock.
  final List<T> items;

  /// A builder function to render each individual item.
  /// Parameters:
  /// - `T` - The item data.
  /// - `bool` - Whether the item is currently being dragged.
  /// - `bool` - Whether the item is being hovered over.
  final Widget Function(T, bool, bool) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// The state of the [Dock] widget.
/// Manages the internal list of items and handles drag-and-drop logic.
class _DockState<T extends Map<String, Object>> extends State<Dock<T>> {
  // A copy of the initial items list for manipulation
  late List<T> _items = widget.items.toList();

  // Tracks the item currently being dragged
  T? _draggingItem;

  // Tracks the index of the item currently being hovered over
  int? _hoveredIndex;

  // Overlay entry for the tooltip
  OverlayEntry? _tooltipEntry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Shrink the row to fit the items
      children: _items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return MouseRegion(
          onEnter: (event) {
            setState(() {
              _hoveredIndex = index; // Track the hovered index
            });
            _showTooltip(context, entry.key, item['label'] as String);
          },
          onExit: (_) {
            setState(() {
              _hoveredIndex = null; // Clear the hovered index
            });
            _hideTooltip();
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300), // Smooth transition
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: DragTarget<T>(
              key: ValueKey(item),
              onAcceptWithDetails: (details) {
                // Reorder items in the dock
                setState(() {
                  final draggedItem = details.data;
                  final oldIndex = _items.indexOf(draggedItem);
                  _items.removeAt(oldIndex);
                  _items.insert(index, draggedItem);
                });
              },
              builder: (context, candidateData, rejectedData) {
                return Draggable<T>(
                  data: item,
                  feedback: Material(
                    color: Colors.transparent,
                    child: widget.builder(
                        item, true, false), // Show item as it's being dragged
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.5, // Fade the item when it's being dragged
                    child: widget.builder(item, false, false),
                  ),
                  onDragStarted: () {
                    setState(() {
                      _draggingItem = item; // Set the dragging item
                    });
                  },
                  onDragEnd: (details) {
                    setState(() {
                      _draggingItem = null; // Clear the dragging item
                    });
                  },
                  child: widget.builder(
                    item,
                    _draggingItem == item, // Is it the dragging item?
                    _hoveredIndex == index, // Is it the hovered item?
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Displays a tooltip above the hovered item.
  void _showTooltip(BuildContext context, int index, String text) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    final overlay = Overlay.of(context);
    _tooltipEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx + (index * 96), // Position tooltip above the item
          top: position.dy - 50,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black87, // Black background for tooltip
                borderRadius: BorderRadius.circular(8), // Rounded corners
              ),
              child: Text(
                text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12), // White text
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_tooltipEntry!);
  }

  /// Hides the tooltip.
  void _hideTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }
}
