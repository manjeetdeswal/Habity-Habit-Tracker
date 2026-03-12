import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? existingNote;
  const NoteEditorScreen({super.key, this.existingNote});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late int _selectedColor;
  late bool _isPinned;

  final List<int> _noteColors = [
    0xFF1E1E2C, // Default Dark
    0xFF7C4DFF, // Purple
    0xFFFF5252, // Red
    0xFFFF9800, // Orange
    0xFF4CAF50, // Green
    0xFF00BCD4, // Blue
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingNote?.title ?? '');
    _contentController = TextEditingController(text: widget.existingNote?.content ?? '');
    _selectedColor = widget.existingNote?.colorValue ?? _noteColors[0];
    _isPinned = widget.existingNote?.isPinned ?? false;
  }

  // Professional Auto-Save Logic
  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Don't save if both are completely empty
    if (title.isEmpty && content.isEmpty) return;

    if (widget.existingNote != null) {
      widget.existingNote!.title = title;
      widget.existingNote!.content = content;
      widget.existingNote!.colorValue = _selectedColor;
      widget.existingNote!.isPinned = _isPinned;
      widget.existingNote!.updatedAt = DateTime.now();
      widget.existingNote!.save();
    } else {
      Hive.box<Note>('notesBox').add(
        Note(
          title: title,
          content: content,
          colorValue: _selectedColor,
          isPinned: _isPinned,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Override the default dark color to white if in light mode
    final activeColor = (!isDark && _selectedColor == 0xFF1E1E2C) ? Colors.white : Color(_selectedColor);

    return WillPopScope(
      onWillPop: () async {
        _saveNote(); // Auto-save when the user swipes back!
        return true;
      },
      child: Scaffold(
        backgroundColor: activeColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () {
              _saveNote();
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: textColor),
              onPressed: () => setState(() => _isPinned = !_isPinned),
            ),
            if (widget.existingNote != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: textColor),
                onPressed: () {
                  widget.existingNote!.delete();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
        body: Column(
          children: [
            // Title Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextField(
                controller: _titleController,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                  border: InputBorder.none,
                ),
              ),
            ),

            // Content Field
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: TextField(
                  controller: _contentController,
                  maxLines: null, // Allows infinite scrolling like a real text editor
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(fontSize: 16, height: 1.5, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Start typing...',
                    hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            // Color Picker Bottom Bar
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _noteColors.map((colorHex) {
                  final isSelected = _selectedColor == colorHex;
                  final displayColor = (!isDark && colorHex == 0xFF1E1E2C) ? Colors.grey.shade300 : Color(colorHex);

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorHex),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 35, height: 35,
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: textColor, width: 2) : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}