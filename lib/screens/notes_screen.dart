import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final Box<Note> _notesBox = Hive.box<Note>('notesBox');
  final Box _settingsBox = Hive.box('settingsBox');
  bool _isGridMode = true;

  @override
  void initState() {
    super.initState();
    // Safely load the layout preference
    _isGridMode = _settingsBox.get('notesGridMode', defaultValue: true);
  }

  // --- REORDER LOGIC ---
  void _onReorder(int oldIndex, int newIndex, List<Note> currentNotes) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final Note item = currentNotes.removeAt(oldIndex);
      currentNotes.insert(newIndex, item);

      // Save the new custom order to settings
      List<int> newOrder = currentNotes.map((n) => n.key as int).toList();
      _settingsBox.put('noteOrder', newOrder);
    });
  }

  // --- DRAG ANIMATION ---
  Widget _dragDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = 1.0 + (0.05 * animValue);
        final double elevation = 12.0 * animValue;
        return Transform.scale(
          scale: scale,
          child: Material(
            elevation: elevation,
            color: Colors.transparent,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // --- DELETE CONFIRMATION DIALOG ---
  void _confirmDelete(BuildContext context, Note note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Note?', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${note.title.isNotEmpty ? note.title : 'Untitled'}"? This cannot be undone.',
            style: TextStyle(color: Colors.grey.shade500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              note.delete();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final screenWidth = MediaQuery.of(context).size.width;
    int gridColumns = screenWidth > 1400 ? 5 : (screenWidth > 1000 ? 4 : (screenWidth > 700 ? 3 : 2));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Notes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              IconButton(
                icon: Icon(_isGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded, color: textColor),
                onPressed: () {
                  setState(() {
                    _isGridMode = !_isGridMode;
                    _settingsBox.put('notesGridMode', _isGridMode);
                  });
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: ValueListenableBuilder<Box<Note>>(
            valueListenable: _notesBox.listenable(),
            builder: (context, box, _) {
              if (box.values.isEmpty) return Center(child: Text('No notes yet. Jot something down!', style: TextStyle(color: Colors.grey.shade500)));

              List<Note> notes = box.values.toList();

              List<dynamic> rawOrder = _settingsBox.get('noteOrder', defaultValue: []);
              List<int> savedOrder = rawOrder.map((e) => e as int).toList();

              notes.sort((a, b) {
                int indexA = savedOrder.indexOf(a.key as int);
                int indexB = savedOrder.indexOf(b.key as int);

                if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
                if (indexA == -1 && indexB != -1) return -1;
                if (indexA != -1 && indexB == -1) return 1;

                if (a.isPinned && !b.isPinned) return -1;
                if (!a.isPinned && b.isPinned) return 1;
                return b.updatedAt.compareTo(a.updatedAt);
              });

              if (_isGridMode) {
                return ReorderableGridView.builder(
                  key: const ValueKey('notes_grid_view'),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridColumns, crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: 220,
                  ),
                  itemCount: notes.length,
                  onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, notes),
                  itemBuilder: (context, index) {
                    // THE GRID requires this custom drag listener
                    return ReorderableDelayedDragStartListener(
                      index: index,
                      key: ValueKey('grid_note_${notes[index].key}'),
                      child: _buildNoteCard(notes[index], isDark, textColor, true),
                    );
                  },
                );
              } else {
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ReorderableListView.builder(
                      key: const ValueKey('notes_list_view'),
                      padding: const EdgeInsets.all(16),
                      itemCount: notes.length,
                      onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, notes),
                      itemBuilder: (context, index) {
                        // FIX: Native Flutter List just needs a plain Container and a Key!
                        // Removed the conflicting drag listener entirely.
                        return Container(
                          key: ValueKey('list_note_${notes[index].key}'),
                          child: _buildNoteCard(notes[index], isDark, textColor, false),
                        );
                      },
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(Note note, bool isDark, Color textColor, bool isGrid) {
    Color cardBgColor = (!isDark && note.colorValue == 0xFF1E1E2C) ? Colors.white : Color(note.colorValue);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditorScreen(existingNote: note))),
      child: Container(
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, spreadRadius: 1)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // THE FIX: When in a List, the Column must shrink-wrap its children.
          // It cannot be set to 'max' if its children are expanding!
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    note.title.isNotEmpty ? note.title : 'Untitled',
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (note.isPinned)
                  Padding(padding: const EdgeInsets.only(right: 8.0), child: Icon(Icons.push_pin, color: textColor, size: 16)),
                GestureDetector(
                  onTap: () => _confirmDelete(context, note),
                  child: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.8), size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // THE FIX: If it's a Grid (fixed height of 220px), we MUST use Expanded so the text fills the box.
            // If it's a List (infinite height), we CANNOT use Expanded. We just use normal Text and let it size itself!
            if (isGrid)
              Expanded(
                child: Text(
                  note.content,
                  style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14, height: 1.4),
                  maxLines: 6,
                  overflow: TextOverflow.fade,
                ),
              )
            else
              Text(
                note.content,
                style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: 8),
            Text(DateFormat('MMM d').format(note.updatedAt), style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}