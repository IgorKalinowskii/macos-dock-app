import 'package:flutter/material.dart';

/// Entry point of our Flutter app.
/// We’ll load up [MyApp] and display our custom Dock widget.
void main() {
  runApp(const MyApp());
}

/// Basic Flutter app that shows a "Dock" with draggable icons.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We’re going for a simple screen with a single Dock in the middle.
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey[200],
        body: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.2 * 255).toInt()),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Dock(
              // This is our initial set of icons in the dock.
              items: const [
                {'icon': Icons.person, 'label': 'Person', 'color': Colors.blue},
                {'icon': Icons.message, 'label': 'Message', 'color': Colors.green},
                {'icon': Icons.call, 'label': 'Call', 'color': Colors.red},
                {'icon': Icons.camera, 'label': 'Camera', 'color': Colors.purple},
                {'icon': Icons.photo, 'label': 'Photo', 'color': Colors.orange},
              ],
              builder: (item, isDragging, isHovered) {
                // We expect each 'item' to be a map like:
                // { icon: Icons.xyz, label: 'Something', color: SomeColor }
                final iconData = item['icon'] as IconData;
                final iconColor = item['color'] as Color;

                // We’ll slightly enlarge icons on mouse hover, 
                // and if it’s dragged, change its color to white.
                return AnimatedScale(
                  scale: isHovered ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(100),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        iconData,
                        color: isDragging ? Colors.white : iconColor,
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

/// The Dock itself: shows draggable icons in a horizontal layout.
/// 
/// Features:
/// - Icons "push apart" (reorder) when you drag one over the other.
/// - If you drop an icon outside the Dock, it flies back to where it started.
/// - If you drop an icon inside the Dock, it flies to its new position.
class Dock<T extends Map<String, Object>> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  /// The set of items to appear in the dock. Typically a list of maps
  /// holding info like icon data, label, and color.
  final List<T> items;

  /// A function that tells the Dock how to build each icon widget.
  /// We pass it a single item plus two flags: dragging or hovered.
  final Widget Function(T item, bool isDragging, bool isHovered) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

class _DockState<T extends Map<String, Object>> extends State<Dock<T>>
    with TickerProviderStateMixin {
  /// We store a local copy of all items so we can manipulate their order.
  late List<T> _items = widget.items.toList();

  /// When we start dragging, we record the item’s original index
  /// so if it’s dropped outside the Dock, we can put it back correctly.
  final Map<T, int> _originalIndices = {};

  /// Which item is currently being dragged (if any).
  T? _draggingItem;

  /// Index of the item currently hovered by the mouse, if any.
  int? _hoveredIndex;

  /// A set of items we temporarily hide in the Dock when they’re
  /// “flying” in an overlay animation.
  final Set<T> _hiddenItems = {};

  /// We’ll use just one overlay entry for the “flying” icon animation.
  OverlayEntry? _flyOverlayEntry;

  /// And a single animation controller for the flight.
  late AnimationController _flyController;
  late Animation<Offset> _flyAnimation;

  /// Flight path: start and end offsets in the global coordinate space.
  Offset _startFlyOffset = Offset.zero;
  Offset _endFlyOffset = Offset.zero;

  /// Some basic dimensions: each icon will occupy a slot of this width in the row.
  static const double _itemSlotWidth = 88;
  static const double _itemSlotHeight = 88;

  /// For showing quick “tooltip” labels above icons on hover.
  OverlayEntry? _tooltipEntry;

  @override
  void initState() {
    super.initState();
    // Set up the flight animation stuff. We do this once.
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // This is a throwaway tween initially; we’ll set a real tween each time we fly.
    _flyAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _flyController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // We have to dispose the controller or it’ll leak.
    _flyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The total width is just # of items times slot width.
    final totalWidth = _items.length * _itemSlotWidth;
    return SizedBox(
      width: totalWidth,
      height: _itemSlotHeight,
      child: Stack(
        children: [
          // We place an AnimatedPositioned for each item so that
          // reordering happens smoothly in a Row-like layout.
          for (int i = 0; i < _items.length; i++)
            _buildPositionedItem(i),
        ],
      ),
    );
  }

  /// Build one “slot” in the dock at index [i].
  Widget _buildPositionedItem(int i) {
    final item = _items[i];
    final isDragging = (item == _draggingItem);
    final isHovered = (i == _hoveredIndex);
    // If the item is in “hidden items,” we make it invisible here
    // (because it might be flying around in the overlay).
    final isHidden = _hiddenItems.contains(item);

    final leftPos = i * _itemSlotWidth;

    return AnimatedPositioned(
      key: ValueKey(item),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: leftPos,
      top: 0,
      width: _itemSlotWidth,
      height: _itemSlotHeight,
      child: Opacity(
        opacity: isHidden ? 0.0 : 1.0,
        child: MouseRegion(
          // We track hover for the tooltip and small scale-up effect.
          onEnter: (_) {
            setState(() => _hoveredIndex = i);
            _showTooltip(context, i, item['label'] as String);
          },
          onExit: (_) {
            setState(() => _hoveredIndex = null);
            _hideTooltip();
          },
          // The DragTarget is the main part: items can be dropped onto this slot.
          child: DragTarget<T>(
            onWillAccept: (incoming) {
              if (incoming == null || incoming == item) return false;
              // We remove it from old index and insert it at new index,
              // so the icons push each other away in real time.
              setState(() {
                final oldIndex = _items.indexOf(incoming);
                final newIndex = _items.indexOf(item);
                _items.removeAt(oldIndex);
                final insertIndex = (oldIndex < newIndex) ? newIndex : newIndex;
                _items.insert(insertIndex, incoming);
              });
              return true;
            },
            onAcceptWithDetails: (details) {
              // Dropped inside the Dock -> animate it from the drop point
              // to the item’s new index.
              final droppedItem = details.data;
              _flyBackOrForward(
                droppedItem,
                details.offset,
                newIndex: _items.indexOf(droppedItem),
              );
            },
            builder: (ctx, candidate, rejected) {
              // The item itself is also draggable, so we can pick it up
              // and move it to a new spot or outside the Dock entirely.
              return Draggable<T>(
                data: item,
                feedback: Material(
                  color: Colors.transparent,
                  child: widget.builder(item, true, false),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: widget.builder(item, false, false),
                ),
                onDragStarted: () {
                  final oldIndex = _items.indexOf(item);
                  // We store this so we know where to fly back if user drops it outside.
                  _originalIndices[item] = oldIndex;
                  setState(() => _draggingItem = item);
                },
                onDragEnd: (_) {
                  // We’re no longer dragging, so clear the state.
                  setState(() => _draggingItem = null);
                },
                // If the Dock doesn’t accept it (meaning we dropped it outside),
                // we can animate it back to its old slot.
                onDraggableCanceled: (velocity, offset) {
                  final oldIndex = _originalIndices[item];
                  if (oldIndex == null) return;
                  _flyBackOrForward(item, offset, newIndex: oldIndex);
                },
                child: widget.builder(item, isDragging, isHovered),
              );
            },
          ),
        ),
      ),
    );
  }

  /// This method triggers the “flight” animation from where we dropped the item 
  /// to the slot at [newIndex]. If [newIndex] is its original index, 
  /// that’s effectively “flying back” to where it was.
  void _flyBackOrForward(T item, Offset dropOffset, {required int newIndex}) {
    // Temporarily hide the item in the Dock so it doesn’t appear duplicated.
    setState(() {
      _hiddenItems.add(item);
    });

    final startGlobal = dropOffset; // Where user dropped it
    final endLocal = Offset(newIndex * _itemSlotWidth, 0);
    final box = context.findRenderObject() as RenderBox;
    final endGlobal = box.localToGlobal(endLocal);

    // Perform the flight in an Overlay so it looks like the item is floating around
    // above the rest of the UI.
    _startFlightAnimation(item, startGlobal, endGlobal);
  }

  /// Actually sets up and runs the flight animation using our single overlay entry
  /// and a single animation controller.
  void _startFlightAnimation(T item, Offset start, Offset end) {
    _flyController.stop();
    _flyOverlayEntry?.remove();
    _flyOverlayEntry = null;

    final tween = Tween<Offset>(begin: start, end: end);
    _flyAnimation = tween.animate(
      CurvedAnimation(
        parent: _flyController,
        curve: Curves.easeInOut,
      ),
    );

    _flyOverlayEntry = OverlayEntry(
      builder: (_) {
        return AnimatedBuilder(
          animation: _flyAnimation,
          builder: (context, child) {
            final pos = _flyAnimation.value;
            return Positioned(
              left: pos.dx,
              top: pos.dy,
              child: IgnorePointer(
                ignoring: true,
                child: Material(
                  color: Colors.transparent,
                  // We treat it as "dragging" just for consistent visuals.
                  child: widget.builder(item, true, false),
                ),
              ),
            );
          },
        );
      },
    );

    // Place the overlay entry on the screen.
    Overlay.of(context).insert(_flyOverlayEntry!);

    // Fire up the animation.
    _flyController.reset();
    _flyController.forward().whenComplete(() {
      // Once we’re done flying, remove the overlay
      // and show the item in the Dock again.
      _flyOverlayEntry?.remove();
      _flyOverlayEntry = null;

      setState(() {
        _hiddenItems.remove(item);
      });
    });
  }

  /// Displays a tooltip above the hovered icon.
  void _showTooltip(BuildContext context, int index, String text) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context);

    _tooltipEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx + index * _itemSlotWidth + (_itemSlotWidth / 2) - 20,
          top: position.dy - 40,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_tooltipEntry!);
  }

  /// Removes the tooltip when the mouse is no longer hovering the item.
  void _hideTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }
}

