import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/todo.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => TodoScreenState();
}

class TodoScreenState extends State<TodoScreen> {
  final Box<Todo> _todoBox = Hive.box<Todo>('todoBox');
  final Box _settingsBox = Hive.box('settingsBox');
  bool _isGridMode = false;

  @override
  void initState() {
    super.initState();
    // Safely load the layout preference
    _isGridMode = _settingsBox.get('todoGridMode', defaultValue: false);
  }

  // --- REORDER LOGIC ---
  void _onReorder(int oldIndex, int newIndex, List<Todo> currentTodos) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final Todo item = currentTodos.removeAt(oldIndex);
      currentTodos.insert(newIndex, item);

      // Save the new custom order to settings
      List<int> newOrder = currentTodos.map((t) => t.key as int).toList();
      _settingsBox.put('todoOrder', newOrder);
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
  void _confirmDelete(BuildContext context, Todo todo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Task?', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${todo.title}"?', style: TextStyle(color: Colors.grey.shade500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              todo.delete();
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- THE PRO TASK EDITOR SHEET ---
  static void showTaskSheet(BuildContext context, {Todo? existingTask}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade100;

    final TextEditingController titleController = TextEditingController(text: existingTask?.title ?? '');
    final TextEditingController descController = TextEditingController(text: existingTask?.description ?? '');

    DateTime? selectedDate = existingTask?.dueDate;
    int selectedPriority = existingTask?.priority ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121421) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(existingTask == null ? 'New Task' : 'Edit Task', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: titleController,
                    autofocus: existingTask == null,
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Task Title',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                    ),
                  ),

                  TextField(
                    controller: descController,
                    maxLines: 3,
                    minLines: 1,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add details...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today, color: selectedDate != null ? const Color(0xFF673AB7) : Colors.grey, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  selectedDate != null ? DateFormat('MMM d, y').format(selectedDate!) : 'Set Date',
                                  style: TextStyle(color: selectedDate != null ? const Color(0xFF673AB7) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedPriority,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                              icon: const Icon(Icons.flag, color: Colors.grey, size: 18),
                              items: [
                                DropdownMenuItem(value: 0, child: Text('No Priority', style: TextStyle(color: textColor, fontSize: 13))),
                                const DropdownMenuItem(value: 1, child: Text('Low Priority', style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold))),
                                const DropdownMenuItem(value: 2, child: Text('Med Priority', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold))),
                                const DropdownMenuItem(value: 3, child: Text('High Priority', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedPriority = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF673AB7),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (titleController.text.trim().isNotEmpty) {
                          if (existingTask != null) {
                            existingTask.title = titleController.text.trim();
                            existingTask.description = descController.text.trim();
                            existingTask.dueDate = selectedDate;
                            existingTask.priority = selectedPriority;
                            existingTask.save();
                          } else {
                            Hive.box<Todo>('todoBox').add(
                              Todo(
                                title: titleController.text.trim(),
                                description: descController.text.trim(),
                                dueDate: selectedDate,
                                priority: selectedPriority,
                                createdAt: DateTime.now(),
                              ),
                            );
                          }
                          Navigator.pop(context);
                        }
                      },
                      child: Text(existingTask == null ? 'Create Task' : 'Save Changes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getPriorityColor(int priority) {
    if (priority == 3) return Colors.red;
    if (priority == 2) return Colors.orange;
    if (priority == 1) return Colors.blue;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = Theme.of(context).cardColor;
    final screenWidth = MediaQuery.of(context).size.width;
    int gridColumns = screenWidth > 1400 ? 5 : (screenWidth > 1000 ? 4 : (screenWidth > 700 ? 3 : 2));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Tasks', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              IconButton(
                icon: Icon(_isGridMode ? Icons.view_list_rounded : Icons.grid_view_rounded, color: textColor),
                onPressed: () {
                  setState(() {
                    _isGridMode = !_isGridMode;
                    _settingsBox.put('todoGridMode', _isGridMode);
                  });
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: ValueListenableBuilder<Box<Todo>>(
            valueListenable: _todoBox.listenable(),
            builder: (context, box, _) {
              if (box.values.isEmpty) {
                return Center(child: Text('You are all caught up!', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)));
              }

              List<Todo> todos = box.values.toList();

              List<dynamic> rawOrder = _settingsBox.get('todoOrder', defaultValue: []);
              List<int> savedOrder = rawOrder.map((e) => e as int).toList();

              todos.sort((a, b) {
                int indexA = savedOrder.indexOf(a.key as int);
                int indexB = savedOrder.indexOf(b.key as int);

                if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
                if (indexA == -1 && indexB != -1) return -1;
                if (indexA != -1 && indexB == -1) return 1;

                if (a.isCompleted && !b.isCompleted) return 1;
                if (!a.isCompleted && b.isCompleted) return -1;
                if (a.priority != b.priority) return b.priority.compareTo(a.priority);
                if (a.dueDate != null && b.dueDate != null) return a.dueDate!.compareTo(b.dueDate!);
                if (a.dueDate != null) return -1;
                if (b.dueDate != null) return 1;

                return b.createdAt.compareTo(a.createdAt);
              });

              if (_isGridMode) {
                return ReorderableGridView.builder(
                  key: const ValueKey('todo_grid_view'),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridColumns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 140,
                  ),
                  itemCount: todos.length,
                  onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, todos),
                  itemBuilder: (context, index) {
                    // THE GRID requires this custom drag listener
                    return ReorderableDelayedDragStartListener(
                      index: index,
                      key: ValueKey('grid_todo_${todos[index].key}'),
                      child: _buildGridItem(todos[index], cardColor, textColor),
                    );
                  },
                );
              } else {
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ReorderableListView.builder(
                      key: const ValueKey('todo_list_view'),
                      padding: const EdgeInsets.all(16),
                      itemCount: todos.length,
                      onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, todos),
                      itemBuilder: (context, index) {
                        // FIX: Native Flutter List just needs a plain Container and a Key!
                        // Removed the conflicting drag listener entirely.
                        return Container(
                          key: ValueKey('list_todo_${todos[index].key}'),
                          child: _buildListItem(todos[index], cardColor, textColor),
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

  // --- LIST LAYOUT ---
  Widget _buildListItem(Todo todo, Color cardColor, Color textColor) {
    Color pColor = _getPriorityColor(todo.priority);

    return Dismissible(
      key: Key('dismiss_${todo.key}'),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) => todo.delete(),
      child: GestureDetector(
        onTap: () => showTaskSheet(context, existingTask: todo),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: pColor == Colors.transparent ? Colors.transparent : pColor, width: 4)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            leading: GestureDetector(
              onTap: () {
                todo.isCompleted = !todo.isCompleted;
                todo.save();
              },
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: todo.isCompleted ? const Color(0xFF673AB7) : Colors.transparent,
                  border: Border.all(color: todo.isCompleted ? const Color(0xFF673AB7) : Colors.grey, width: 2),
                ),
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.check, size: 16, color: todo.isCompleted ? Colors.white : Colors.transparent),
              ),
            ),
            title: Text(
              todo.title,
              style: TextStyle(
                color: todo.isCompleted ? Colors.grey : textColor,
                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: (todo.dueDate != null || todo.description.isNotEmpty)
                ? Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  if (todo.dueDate != null) ...[
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(DateFormat('MMM d').format(todo.dueDate!), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    const SizedBox(width: 12),
                  ],
                  if (todo.description.isNotEmpty)
                    Expanded(child: Text(todo.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))),
                ],
              ),
            )
                : null,
          ),
        ),
      ),
    );
  }

  // --- GRID LAYOUT ---
  Widget _buildGridItem(Todo todo, Color cardColor, Color textColor) {
    Color pColor = _getPriorityColor(todo.priority);

    return GestureDetector(
      onTap: () => showTaskSheet(context, existingTask: todo),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: todo.isCompleted ? cardColor.withOpacity(0.5) : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: todo.isCompleted ? Colors.transparent : (pColor == Colors.transparent ? Colors.grey.withOpacity(0.2) : pColor.withOpacity(0.5)), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    todo.isCompleted = !todo.isCompleted;
                    todo.save();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: todo.isCompleted ? const Color(0xFF673AB7) : Colors.transparent,
                      border: Border.all(color: todo.isCompleted ? const Color(0xFF673AB7) : Colors.grey, width: 2),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.check, size: 14, color: todo.isCompleted ? Colors.white : Colors.transparent),
                  ),
                ),
                Row(
                  children: [
                    if (pColor != Colors.transparent)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.flag, color: pColor, size: 18),
                      ),
                    GestureDetector(
                      onTap: () => _confirmDelete(context, todo),
                      child: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.7), size: 20),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Text(
              todo.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: todo.isCompleted ? Colors.grey : textColor,
                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (todo.dueDate != null)
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(DateFormat('MMM d').format(todo.dueDate!), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}