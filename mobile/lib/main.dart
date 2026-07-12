import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const _ink = Color(0xFF1D2A35);
const _mint = Color(0xFF157A6E);
const _coral = Color(0xFFE56B4F);
const _canvas = Color(0xFFF6F7F5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = NotesStore();
  final diaryStore = DiaryStore();
  final taskStore = TaskStore();
  await store.load();
  await diaryStore.load();
  await taskStore.load();
  runApp(EssayPadMobile(
      store: store, diaryStore: diaryStore, taskStore: taskStore));
}

class EssayPadMobile extends StatelessWidget {
  const EssayPadMobile({
    super.key,
    required this.store,
    required this.diaryStore,
    required this.taskStore,
  });

  final NotesStore store;
  final DiaryStore diaryStore;
  final TaskStore taskStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EssayPad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: _mint, surface: _canvas),
        appBarTheme:
            const AppBarTheme(backgroundColor: _canvas, foregroundColor: _ink),
      ),
      home: MobileShell(
          store: store, diaryStore: diaryStore, taskStore: taskStore),
    );
  }
}

enum NoteCategory {
  idea('想法', Icons.lightbulb_outline, _mint),
  requirement('需求', Icons.layers_outlined, _coral),
  bug('Bug', Icons.bug_report_outlined, Color(0xFF5C70B8));

  const NoteCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class MobileNote {
  const MobileNote({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final NoteCategory category;
  final DateTime updatedAt;

  MobileNote copyWith(
      {String? title,
      String? content,
      NoteCategory? category,
      DateTime? updatedAt}) {
    return MobileNote(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'category': category.name,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MobileNote.fromJson(Map<String, dynamic> json) {
    return MobileNote(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: NoteCategory.values.byName(json['category'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

enum DiaryMood {
  joyful('愉快', Icons.sentiment_very_satisfied_outlined, Color(0xFFFFA83D)),
  calm('平静', Icons.sentiment_satisfied_outlined, Color(0xFF57A7E9)),
  tired('疲惫', Icons.sentiment_neutral_outlined, Color(0xFF8D97A8)),
  low('低落', Icons.sentiment_dissatisfied_outlined, Color(0xFF7A79B8));

  const DiaryMood(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

enum DiaryActivity {
  work('工作', Icons.work_outline),
  study('学习', Icons.auto_stories_outlined),
  outing('出游', Icons.luggage_outlined),
  rest('休息', Icons.weekend_outlined),
  game('游戏', Icons.sports_esports_outlined);

  const DiaryActivity(this.label, this.icon);
  final String label;
  final IconData icon;
}

class MobileDiary {
  const MobileDiary({
    required this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.activity,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String content;
  final DiaryMood mood;
  final DiaryActivity activity;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'mood': mood.name,
        'activity': activity.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MobileDiary.fromJson(Map<String, dynamic> json) {
    return MobileDiary(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      mood: DiaryMood.values.byName(json['mood'] as String),
      activity: DiaryActivity.values.byName(json['activity'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

enum TaskPriority {
  normal('普通', Color(0xFF93A0AF)),
  important('重要', Color(0xFFFF9A3D)),
  urgent('紧急', Color(0xFFE85D5D));

  const TaskPriority(this.label, this.color);
  final String label;
  final Color color;
}

enum TaskStatus { active, done, abandoned }

enum TaskGroup {
  today('今天'),
  yesterday('昨天'),
  week('本周'),
  all('全部'),
  longTerm('长期');

  const TaskGroup(this.label);
  final String label;
}

class MobileTask {
  const MobileTask({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.priority,
    required this.status,
    required this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    required this.focusMinutes,
  });

  final String id;
  final String title;
  final String description;
  final int progress;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int focusMinutes;

  bool get isDone => status == TaskStatus.done;

  MobileTask copyWith({
    String? title,
    String? description,
    int? progress,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? dueAt,
    DateTime? updatedAt,
    int? focusMinutes,
  }) =>
      MobileTask(
          id: id,
          title: title ?? this.title,
          description: description ?? this.description,
          progress: progress ?? this.progress,
          priority: priority ?? this.priority,
          status: status ?? this.status,
          dueAt: dueAt ?? this.dueAt,
          createdAt: createdAt,
          updatedAt: updatedAt ?? this.updatedAt,
          focusMinutes: focusMinutes ?? this.focusMinutes);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'progress': progress,
        'priority': priority.name,
        'status': status.name,
        'dueAt': dueAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'focusMinutes': focusMinutes,
      };

  factory MobileTask.fromJson(Map<String, dynamic> json) => MobileTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      progress: json['progress'] as int,
      priority: TaskPriority.values.byName(json['priority'] as String),
      status: TaskStatus.values.byName(json['status'] as String),
      dueAt: DateTime.parse(json['dueAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      focusMinutes: json['focusMinutes'] as int);
}

class MobileDatabase {
  MobileDatabase._();
  static final instance = MobileDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final directory = await getDatabasesPath();
    _database = await openDatabase(path.join(directory, 'essaypad_mobile.db'),
        version: 1, onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE notes (id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL, category TEXT NOT NULL, updated_at INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE diaries (id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL, mood TEXT NOT NULL, activity TEXT NOT NULL, created_at INTEGER NOT NULL)');
      await db.execute(
          'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL, progress INTEGER NOT NULL, priority TEXT NOT NULL, status TEXT NOT NULL, due_at INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, focus_minutes INTEGER NOT NULL)');
    });
    return _database!;
  }

  Future<List<Map<String, Object?>>> query(String table) async =>
      (await database).query(table);
  Future<void> upsert(String table, Map<String, Object?> values) async =>
      (await database)
          .insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> replaceAll(
      String table, List<Map<String, Object?>> values) async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.delete(table);
      final batch = transaction.batch();
      for (final value in values) {
        batch.insert(table, value);
      }
      await batch.commit(noResult: true);
    });
  }
}

class NotesStore extends ChangeNotifier {
  static const _storageKey = 'essaypad.mobile.notes.v1';
  NotesStore({List<MobileNote>? seed, bool persistent = true})
      : _notes = List.of(seed ?? const []),
        _persistent = persistent;

  final List<MobileNote> _notes;
  final bool _persistent;
  List<MobileNote> get notes => List.unmodifiable(
      _notes..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  Future<void> load() async {
    if (!_persistent) return;
    final preferences = await SharedPreferences.getInstance();
    if (!kIsWeb) {
      final rows = await MobileDatabase.instance.query('notes');
      if (rows.isNotEmpty) {
        _notes
          ..clear()
          ..addAll(rows.map((row) => MobileNote(
              id: row['id']! as String,
              title: row['title']! as String,
              content: row['content']! as String,
              category: NoteCategory.values.byName(row['category']! as String),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  row['updated_at']! as int))));
        notifyListeners();
        return;
      }
    }
    final raw = preferences.getString(_storageKey);
    if (raw == null) {
      if (_notes.isEmpty) {
        _notes.addAll(_seedNotes());
        await _persist();
      }
      return;
    }
    _notes
      ..clear()
      ..addAll((jsonDecode(raw) as List<dynamic>)
          .map((item) => MobileNote.fromJson(item as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<void> save(MobileNote note) async {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) {
      _notes.add(note);
    } else {
      _notes[index] = note;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _notes.removeWhere((note) => note.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (!_persistent) return;
    if (!kIsWeb) {
      await MobileDatabase.instance.replaceAll(
          'notes',
          _notes
              .map((note) => {
                    'id': note.id,
                    'title': note.title,
                    'content': note.content,
                    'category': note.category.name,
                    'updated_at': note.updatedAt.millisecondsSinceEpoch
                  })
              .toList());
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _storageKey, jsonEncode(_notes.map((note) => note.toJson()).toList()));
  }

  static List<MobileNote> _seedNotes() {
    final now = DateTime.now();
    return [
      MobileNote(
          id: 'seed-idea',
          title: '周复盘的朋友感',
          content: '减少官话，多给具体观察和小建议。',
          category: NoteCategory.idea,
          updatedAt: now),
      MobileNote(
          id: 'seed-requirement',
          title: '移动端首页',
          content: '笔记和日记放在一起，页面保持紧凑。',
          category: NoteCategory.requirement,
          updatedAt: now.subtract(const Duration(hours: 4))),
    ];
  }
}

class TaskStore extends ChangeNotifier {
  static const _storageKey = 'essaypad.mobile.tasks.v1';
  TaskStore({List<MobileTask>? seed, bool persistent = true})
      : _tasks = List.of(seed ?? const []),
        _persistent = persistent;
  final List<MobileTask> _tasks;
  final bool _persistent;

  List<MobileTask> get tasks {
    final result = List<MobileTask>.of(_tasks);
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(result);
  }

  Future<void> load() async {
    if (!_persistent) return;
    final preferences = await SharedPreferences.getInstance();
    if (!kIsWeb) {
      final rows = await MobileDatabase.instance.query('tasks');
      if (rows.isNotEmpty) {
        _tasks
          ..clear()
          ..addAll(rows.map((row) => MobileTask(
              id: row['id']! as String,
              title: row['title']! as String,
              description: row['description']! as String,
              progress: row['progress']! as int,
              priority: TaskPriority.values.byName(row['priority']! as String),
              status: TaskStatus.values.byName(row['status']! as String),
              dueAt: DateTime.fromMillisecondsSinceEpoch(row['due_at']! as int),
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                  row['created_at']! as int),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  row['updated_at']! as int),
              focusMinutes: row['focus_minutes']! as int)));
        notifyListeners();
        return;
      }
    }
    final raw = preferences.getString(_storageKey);
    if (raw == null) {
      if (_tasks.isEmpty) {
        _tasks.addAll(_seedTasks());
        await _persist();
      }
      return;
    }
    _tasks
      ..clear()
      ..addAll((jsonDecode(raw) as List<dynamic>)
          .map((item) => MobileTask.fromJson(item as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<void> save(MobileTask task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) {
      _tasks.add(task);
    } else {
      _tasks[index] = task;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateProgress(String id, int progress) async {
    final index = _tasks.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final value = progress.clamp(0, 100);
    _tasks[index] = _tasks[index].copyWith(
        progress: value,
        status: value == 100 ? TaskStatus.done : TaskStatus.active,
        updatedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<void> addFocusMinutes(String id, int minutes) async {
    final index = _tasks.indexWhere((item) => item.id == id);
    if (index < 0 || minutes <= 0) return;
    _tasks[index] = _tasks[index].copyWith(
        focusMinutes: _tasks[index].focusMinutes + minutes,
        updatedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (!_persistent) return;
    if (!kIsWeb) {
      await MobileDatabase.instance.replaceAll(
          'tasks',
          _tasks
              .map((task) => {
                    'id': task.id,
                    'title': task.title,
                    'description': task.description,
                    'progress': task.progress,
                    'priority': task.priority.name,
                    'status': task.status.name,
                    'due_at': task.dueAt.millisecondsSinceEpoch,
                    'created_at': task.createdAt.millisecondsSinceEpoch,
                    'updated_at': task.updatedAt.millisecondsSinceEpoch,
                    'focus_minutes': task.focusMinutes
                  })
              .toList());
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _storageKey, jsonEncode(_tasks.map((task) => task.toJson()).toList()));
  }

  static List<MobileTask> _seedTasks() {
    final now = DateTime.now();
    return [
      MobileTask(
          id: 'task-mobile',
          title: '完成移动端任务功能',
          description: '补齐任务列表、详情和专注计时。',
          progress: 50,
          priority: TaskPriority.urgent,
          status: TaskStatus.active,
          dueAt: now,
          createdAt: now,
          updatedAt: now,
          focusMinutes: 25),
      MobileTask(
          id: 'task-review',
          title: '整理本周产品反馈',
          description: '提炼反馈中的共性问题，写入下周计划。',
          progress: 25,
          priority: TaskPriority.important,
          status: TaskStatus.active,
          dueAt: now,
          createdAt: now,
          updatedAt: now.subtract(const Duration(hours: 2)),
          focusMinutes: 10),
      MobileTask(
          id: 'task-long',
          title: '规划多端同步',
          description: '为后续移动端与 Mac 端数据同步做准备。',
          progress: 0,
          priority: TaskPriority.important,
          status: TaskStatus.active,
          dueAt: now.add(const Duration(days: 30)),
          createdAt: now,
          updatedAt: now.subtract(const Duration(days: 1)),
          focusMinutes: 0),
    ];
  }
}

class DiaryStore extends ChangeNotifier {
  static const _storageKey = 'essaypad.mobile.diaries.v1';
  DiaryStore({List<MobileDiary>? seed, bool persistent = true})
      : _diaries = List.of(seed ?? const []),
        _persistent = persistent;

  final List<MobileDiary> _diaries;
  final bool _persistent;

  List<MobileDiary> get diaries {
    final sorted = List<MobileDiary>.of(_diaries);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  Future<void> load() async {
    if (!_persistent) return;
    final preferences = await SharedPreferences.getInstance();
    if (!kIsWeb) {
      final rows = await MobileDatabase.instance.query('diaries');
      if (rows.isNotEmpty) {
        _diaries
          ..clear()
          ..addAll(rows.map((row) => MobileDiary(
              id: row['id']! as String,
              title: row['title']! as String,
              content: row['content']! as String,
              mood: DiaryMood.values.byName(row['mood']! as String),
              activity: DiaryActivity.values.byName(row['activity']! as String),
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                  row['created_at']! as int))));
        notifyListeners();
        return;
      }
    }
    final raw = preferences.getString(_storageKey);
    if (raw == null) {
      if (_diaries.isEmpty) {
        _diaries.addAll(_seedDiaries());
        await _persist();
      }
      return;
    }
    _diaries
      ..clear()
      ..addAll((jsonDecode(raw) as List<dynamic>)
          .map((item) => MobileDiary.fromJson(item as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<void> save(MobileDiary diary) async {
    final index = _diaries.indexWhere((item) => item.id == diary.id);
    if (index == -1) {
      _diaries.add(diary);
    } else {
      _diaries[index] = diary;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (!_persistent) return;
    if (!kIsWeb) {
      await MobileDatabase.instance.replaceAll(
          'diaries',
          _diaries
              .map((diary) => {
                    'id': diary.id,
                    'title': diary.title,
                    'content': diary.content,
                    'mood': diary.mood.name,
                    'activity': diary.activity.name,
                    'created_at': diary.createdAt.millisecondsSinceEpoch
                  })
              .toList());
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey,
        jsonEncode(_diaries.map((diary) => diary.toJson()).toList()));
  }

  static List<MobileDiary> _seedDiaries() {
    final now = DateTime.now();
    return [
      MobileDiary(
        id: 'seed-diary-today',
        title: '热爱可抵岁月漫长',
        content: '今天是充实的一天。完成了几个重要功能，也把脑海里的想法慢慢落成了页面。',
        mood: DiaryMood.joyful,
        activity: DiaryActivity.work,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      MobileDiary(
        id: 'seed-diary-yesterday',
        title: '专注创造价值',
        content: '专注是最稀缺的能力，也是最有复利的投资。给自己留一点安静的时间。',
        mood: DiaryMood.calm,
        activity: DiaryActivity.study,
        createdAt: now.subtract(const Duration(days: 1, hours: 1)),
      ),
    ];
  }
}

class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.store,
    required this.diaryStore,
    required this.taskStore,
  });
  final NotesStore store;
  final DiaryStore diaryStore;
  final TaskStore taskStore;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      0 => HomePage(store: widget.store, diaryStore: widget.diaryStore),
      1 => TasksPage(taskStore: widget.taskStore),
      3 => const WeeklyReflectionPage(),
      _ => const PlaceholderPage(
          icon: Icons.person_outline,
          title: '我的',
          description: '同步、偏好和更多功能会在这里。'),
    };
    return Scaffold(
      body: SafeArea(child: page),
      bottomNavigationBar: _MobileBottomNav(
        index: _index,
        onTap: (selected) {
          if (selected == 2) {
            _showCreateSheet();
            return;
          }
          setState(() => _index = selected);
        },
      ),
    );
  }

  Future<void> _showCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0x22157A6E),
                  child: Icon(Icons.edit_note, color: _mint)),
              title: const Text('新建笔记'),
              subtitle: const Text('记录一个尚未成形的想法'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NoteEditorPage(store: widget.store)));
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0x22E56B4F),
                  child: Icon(Icons.menu_book_outlined, color: _coral)),
              title: const Text('写日记'),
              subtitle: const Text('记下今天的感受和经历'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            DiaryEditorPage(diaryStore: widget.diaryStore)));
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store, required this.diaryStore});
  final NotesStore store;
  final DiaryStore diaryStore;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _showDiaries = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.store, widget.diaryStore]),
      builder: (context, _) {
        final notes = widget.store.notes;
        final diaries = widget.diaryStore.diaries;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 108),
          children: [
            const _HomeGreeting(),
            const SizedBox(height: 26),
            const _WeeklyReportCard(),
            const SizedBox(height: 22),
            const _TodayOverview(),
            const SizedBox(height: 28),
            Row(children: [
              _HomeFeedTab(
                  label: '笔记',
                  selected: !_showDiaries,
                  onTap: () => setState(() => _showDiaries = false)),
              const SizedBox(width: 28),
              _HomeFeedTab(
                  label: '日记',
                  selected: _showDiaries,
                  onTap: () => setState(() => _showDiaries = true)),
              const Spacer(),
              TextButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _showDiaries
                              ? DiaryListPage(diaryStore: widget.diaryStore)
                              : NotesPage(store: widget.store))),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('更多')),
            ]),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .55,
              children: _showDiaries
                  ? diaries
                      .take(4)
                      .map((diary) => _DiaryFeedCard(
                          diary: diary,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DiaryEditorPage(
                                      diaryStore: widget.diaryStore,
                                      diary: diary)))))
                      .toList()
                  : notes
                      .take(4)
                      .map((note) => _FeedCard(
                          note: note,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => NoteEditorPage(
                                      store: widget.store, note: note)))))
                      .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting();

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('早上好，Fansea ☀️',
            style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: _ink)),
        SizedBox(height: 8),
        Text('每个微小的进步，都在让你变得更好',
            style: TextStyle(fontSize: 15, color: Color(0xFF6D7787))),
      ])),
      IconButton(
          onPressed: () {},
          icon: const Icon(Icons.search, size: 29),
          tooltip: '搜索'),
      const SizedBox(width: 8),
      const CircleAvatar(
        radius: 23,
        backgroundColor: Color(0xFFE9E5E7),
        child: Icon(Icons.face_3, color: Color(0xFF624B45), size: 30),
      ),
    ]);
  }
}

class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 258,
      padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: .86), width: 1.5),
        gradient: const LinearGradient(
            colors: [Color(0xFFFDFDFF), Color(0xFFF8EFFE), Color(0xFFF2EDFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: const [
          BoxShadow(
              color: Color(0x140E0F31), blurRadius: 26, offset: Offset(0, 14))
        ],
      ),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('AI 周报',
                style: TextStyle(
                    fontSize: 25, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(width: 9),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFECE7FF),
                    borderRadius: BorderRadius.circular(7)),
                child: const Text('新生成',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6558DF)))),
          ]),
          const SizedBox(height: 22),
          const Text('5月1日 - 5月7日 · 已生成',
              style: TextStyle(fontSize: 15, color: Color(0xFF687387))),
          const SizedBox(height: 10),
          const Text('本周完成 12 个任务，记录 8 篇日记',
              style: TextStyle(fontSize: 15, color: Color(0xFF687387))),
          const Spacer(),
          FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6354E8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24))),
              child: const Text('查看周报',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        ]),
        const Positioned(right: 4, top: 6, child: _ReportIllustration()),
      ]),
    );
  }
}

class _ReportIllustration extends StatelessWidget {
  const _ReportIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      height: 158,
      child: Stack(
        children: [
          Positioned(
            right: 2,
            top: 0,
            child: Icon(Icons.auto_awesome,
                size: 46,
                color: const Color(0xFF7566ED).withValues(alpha: .84)),
          ),
          Positioned(
            right: 17,
            top: 42,
            child: Transform.rotate(
              angle: -.06,
              child: Container(
                width: 114,
                height: 140,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D0FF),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x386350D7),
                        blurRadius: 18,
                        offset: Offset(0, 10))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 62,
                        height: 9,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .9),
                            borderRadius: BorderRadius.circular(8))),
                    const SizedBox(height: 10),
                    Container(
                        width: 39,
                        height: 8,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .82),
                            borderRadius: BorderRadius.circular(8))),
                    const Spacer(),
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 49,
                        height: 49,
                        child: CircularProgressIndicator(
                            value: .68,
                            strokeWidth: 12,
                            color: const Color(0xFF7058E6),
                            backgroundColor:
                                Colors.white.withValues(alpha: .8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                        width: 75,
                        height: 9,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .82),
                            borderRadius: BorderRadius.circular(8))),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
              left: 4,
              bottom: 22,
              child: _GlowDot(color: Color(0xFF7160E9), size: 13)),
          const Positioned(
              left: 27,
              top: 53,
              child: _GlowDot(color: Color(0xFFFFD5C9), size: 11)),
        ],
      ),
    );
  }
}

class _GlowDot extends StatelessWidget {
  const _GlowDot({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .7), blurRadius: 8)
          ]));
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .78),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white)),
      child: Column(children: [
        Row(
          children: [
            const Text('今日概览',
                style: TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w700, color: _ink)),
            const Spacer(),
            TextButton.icon(
              onPressed: () {},
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 18),
              label:
                  const Text('全部', style: TextStyle(color: Color(0xFF7D8695))),
            ),
          ],
        ),
        Container(
            height: 144,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Row(children: [
              Expanded(
                  child: _Metric(
                      icon: Icons.task_alt,
                      iconColor: Color(0xFF3983FF),
                      value: '3',
                      label: '已完成任务',
                      detail: '共 7 个')),
              VerticalDivider(
                  indent: 12, endIndent: 12, color: Color(0xFFE8EAF0)),
              Expanded(
                  child: _Metric(
                      icon: Icons.data_usage,
                      iconColor: Color(0xFFFF8B32),
                      value: '60%',
                      label: '今日进度',
                      detail: '专注时长 2.5h')),
              VerticalDivider(
                  indent: 12, endIndent: 12, color: Color(0xFFE8EAF0)),
              Expanded(
                  child: _Metric(
                      icon: Icons.eco_outlined,
                      iconColor: Color(0xFF4BC78C),
                      value: '1',
                      label: '今日记录',
                      detail: '日记 · 笔记')),
            ])),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.icon,
      required this.iconColor,
      required this.value,
      required this.label,
      required this.detail});
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(children: [
        CircleAvatar(
            radius: 20,
            backgroundColor: iconColor.withValues(alpha: .12),
            child: Icon(icon, color: iconColor, size: 25)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w700, color: _ink))
        ]),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7483))),
        const Spacer(),
        Text(detail,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9AA2AF))),
      ]));
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.note, required this.onTap});
  final MobileNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0E1D2A35),
                    blurRadius: 14,
                    offset: Offset(0, 8))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(note.category.icon, size: 19, color: note.category.color),
              const SizedBox(width: 7),
              Text(note.category.label,
                  style: TextStyle(fontSize: 12, color: note.category.color)),
              const Spacer(),
              const Icon(Icons.push_pin_outlined,
                  size: 18, color: Color(0xFFB4BAC6))
            ]),
            const SizedBox(height: 12),
            Text(note.title.isEmpty ? '未命名笔记' : note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: _ink)),
            const SizedBox(height: 8),
            Text(
                note.content.isEmpty
                    ? '从一个新的想法开始。'
                    : note.content.replaceAll('\n', ' '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF6F7988))),
            const Spacer(),
            Text('今天 09:30',
                style: const TextStyle(fontSize: 11, color: Color(0xFFABB2BE))),
          ])));
}

class _HomeFeedTab extends StatelessWidget {
  const _HomeFeedTab(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(label,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? const Color(0xFF6054DD)
                      : const Color(0xFF74808D)))));
}

class _DiaryFeedCard extends StatelessWidget {
  const _DiaryFeedCard({required this.diary, required this.onTap});

  final MobileDiary diary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0E1D2A35),
                    blurRadius: 14,
                    offset: Offset(0, 8))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(diary.activity.icon, size: 18, color: _mint),
              const SizedBox(width: 6),
              Text('日记',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF48BC87))),
              const Spacer(),
              Icon(diary.mood.icon, size: 19, color: diary.mood.color),
            ]),
            const SizedBox(height: 12),
            Text(diary.title.isEmpty ? '今天的记录' : diary.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: _ink)),
            const SizedBox(height: 8),
            Text(diary.content.replaceAll('\n', ' ').trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF6F7988))),
            const Spacer(),
            Text(_diaryTimeLabel(diary.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFFABB2BE))),
          ])));
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 82,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x140B1020),
                      blurRadius: 18,
                      offset: Offset(0, -4))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _NavItem(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home,
                          label: '首页',
                          selected: index == 0,
                          onTap: () => onTap(0))),
                  Expanded(
                      child: _NavItem(
                          icon: Icons.check_circle_outline,
                          selectedIcon: Icons.check_circle,
                          label: '任务',
                          selected: index == 1,
                          badge: '2',
                          onTap: () => onTap(1))),
                  const SizedBox(width: 80),
                  Expanded(
                      child: _NavItem(
                          icon: Icons.chat_bubble_outline,
                          selectedIcon: Icons.chat_bubble,
                          label: 'AI 对话',
                          selected: index == 3,
                          onTap: () => onTap(3))),
                  Expanded(
                      child: _NavItem(
                          icon: Icons.person_outline,
                          selectedIcon: Icons.person,
                          label: '我的',
                          selected: index == 4,
                          onTap: () => onTap(4))),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: -25,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(2),
                    borderRadius: BorderRadius.circular(38),
                    child: Ink(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [Color(0xFF7259EF), Color(0xFF5146DB)]),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x4A6953E6),
                              blurRadius: 20,
                              offset: Offset(0, 10))
                        ],
                      ),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 42),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.selectedIcon,
      required this.label,
      required this.selected,
      required this.onTap,
      this.badge});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(selected ? selectedIcon : icon,
                  color: selected
                      ? const Color(0xFF6454E5)
                      : const Color(0xFF697384),
                  size: 26),
              if (badge != null)
                Positioned(
                  right: -10,
                  top: -8,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xFFFF5B5B),
                    child: Text(badge!,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? const Color(0xFF6454E5)
                      : const Color(0xFF697384))),
        ],
      ),
    );
  }
}

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.taskStore});
  final TaskStore taskStore;
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  var _group = TaskGroup.today;

  List<MobileTask> _filtered(List<MobileTask> source) {
    final today = DateUtils.dateOnly(DateTime.now());
    return source.where((task) {
      final day = DateUtils.dateOnly(task.dueAt);
      return switch (_group) {
        TaskGroup.today => day == today,
        TaskGroup.yesterday => day == today.subtract(const Duration(days: 1)),
        TaskGroup.week =>
          !day.isBefore(today.subtract(Duration(days: today.weekday - 1))),
        TaskGroup.longTerm =>
          task.priority == TaskPriority.important && !task.isDone,
        TaskGroup.all => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.taskStore,
      builder: (context, _) {
        final tasks = _filtered(widget.taskStore.tasks);
        final active = tasks.where((task) => !task.isDone).toList();
        final done = tasks.where((task) => task.isDone).toList();
        return Scaffold(
          backgroundColor: _canvas,
          appBar: AppBar(
              title: Text('任务 · ${done.length}/${tasks.length} 完成',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                IconButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                TaskDetailPage(taskStore: widget.taskStore))),
                    icon: const Icon(Icons.add),
                    tooltip: '新建任务'),
              ]),
          body: Column(children: [
            SizedBox(
                height: 46,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: TaskGroup.values
                        .map((group) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: Text(group.label),
                                selected: _group == group,
                                selectedColor: const Color(0x226454E5),
                                onSelected: (_) =>
                                    setState(() => _group = group))))
                        .toList())),
            Expanded(
                child: active.isEmpty && done.isEmpty
                    ? const Center(child: Text('暂无任务'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                        children: [
                            ...TaskPriority.values.reversed.map((priority) {
                              final section = active
                                  .where((task) => task.priority == priority)
                                  .toList();
                              if (section.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8, bottom: 7),
                                        child: Text(
                                            '${priority.label} · ${section.length}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: priority.color))),
                                    ...section.map((task) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: TaskCard(
                                            task: task,
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        TaskDetailPage(
                                                            taskStore: widget
                                                                .taskStore,
                                                            task: task))),
                                            onComplete: () => widget.taskStore
                                                .updateProgress(
                                                    task.id, 100)))),
                                  ]);
                            }),
                            if (done.isNotEmpty) ...[
                              const Padding(
                                  padding: EdgeInsets.only(top: 14, bottom: 7),
                                  child: Text('已完成',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _mint))),
                              ...done.map((task) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: TaskCard(
                                      task: task,
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => TaskDetailPage(
                                                  taskStore: widget.taskStore,
                                                  task: task))),
                                      onComplete: () {}))),
                            ],
                          ])),
          ]),
        );
      });
}

class TaskCard extends StatelessWidget {
  const TaskCard(
      {super.key,
      required this.task,
      required this.onTap,
      required this.onComplete});
  final MobileTask task;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconButton(
                    onPressed: task.isDone ? null : onComplete,
                    icon: Icon(
                        task.isDone
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: task.isDone ? _mint : task.priority.color),
                    tooltip: '标记完成',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints()),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(task.title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color:
                                  task.isDone ? const Color(0xFF98A1AD) : _ink,
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null)),
                      if (task.description.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(task.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF778190)))),
                      const SizedBox(height: 10),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: task.progress / 100,
                              minHeight: 6,
                              color: task.isDone ? _mint : task.priority.color,
                              backgroundColor: const Color(0xFFE9EDF0))),
                      const SizedBox(height: 8),
                      Row(children: [
                        Text('${task.progress}%',
                            style: TextStyle(
                                fontSize: 11, color: task.priority.color)),
                        const Spacer(),
                        const Icon(Icons.timer_outlined,
                            size: 14, color: Color(0xFF7D8795)),
                        const SizedBox(width: 3),
                        Text('${task.focusMinutes} 分钟',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF7D8795)))
                      ]),
                    ])),
              ]))));
}

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key, required this.taskStore, this.task});
  final TaskStore taskStore;
  final MobileTask? task;
  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late final TextEditingController _title =
      TextEditingController(text: widget.task?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.task?.description ?? '');
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.normal;
  late int _progress = widget.task?.progress ?? 0;
  late DateTime _dueAt = widget.task?.dueAt ?? DateTime.now();
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(widget.task == null ? '新建任务' : '任务详情',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          actions: [TextButton(onPressed: _save, child: const Text('完成'))]),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            TextField(
                controller: _title,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                    hintText: '任务标题', border: InputBorder.none)),
            TextField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                    hintText: '补充任务说明…', border: OutlineInputBorder())),
            const SizedBox(height: 22),
            const Text('优先级', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                children: TaskPriority.values
                    .map((priority) => ChoiceChip(
                        label: Text(priority.label),
                        selected: _priority == priority,
                        selectedColor: priority.color.withValues(alpha: .15),
                        onSelected: (_) =>
                            setState(() => _priority = priority)))
                    .toList()),
            const SizedBox(height: 22),
            Text('进度 $_progress%',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
                value: _progress.toDouble(),
                min: 0,
                max: 100,
                divisions: 4,
                label: '$_progress%',
                onChanged: (value) =>
                    setState(() => _progress = value.round())),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('截止日期'),
                trailing: Text('${_dueAt.month}月${_dueAt.day}日'),
                onTap: () async {
                  final date = await showDatePicker(
                      context: context,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: _dueAt);
                  if (date != null) {
                    setState(() => _dueAt = date);
                  }
                }),
            if (widget.task != null) ...[
              const Divider(height: 36),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined, color: _coral),
                  title: const Text('专注'),
                  subtitle: Text('累计 ${widget.task!.focusMinutes} 分钟'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FocusTimerPage(
                              taskStore: widget.taskStore,
                              task: widget.task!)))),
            ],
          ]));
  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    final now = DateTime.now();
    final task = MobileTask(
        id: widget.task?.id ?? now.microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        description: _description.text.trim(),
        progress: _progress,
        priority: _priority,
        status: _progress == 100 ? TaskStatus.done : TaskStatus.active,
        dueAt: _dueAt,
        createdAt: widget.task?.createdAt ?? now,
        updatedAt: now,
        focusMinutes: widget.task?.focusMinutes ?? 0);
    await widget.taskStore.save(task);
    if (mounted) Navigator.pop(context);
  }
}

class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage(
      {super.key, required this.taskStore, required this.task});
  final TaskStore taskStore;
  final MobileTask task;
  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage> {
  var _seconds = 25 * 60;
  var _running = false;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() => _running = !_running);
    if (_running) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_seconds <= 0) {
          _finish();
        } else {
          setState(() => _seconds--);
        }
      });
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final minutes = ((25 * 60 - _seconds) / 60).ceil();
    await widget.taskStore.addFocusMinutes(widget.task.id, minutes);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return Scaffold(
        backgroundColor: const Color(0xFF17261F),
        appBar: AppBar(
            backgroundColor: const Color(0xFF17261F),
            foregroundColor: Colors.white,
            title: const Text('专注')),
        body: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(widget.task.title,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 26),
          Text('$m:$s',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 32),
          FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_running ? Icons.pause : Icons.play_arrow),
              label: Text(_running ? '暂停' : '开始专注'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF54B879),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 15))),
          const SizedBox(height: 14),
          TextButton(
              onPressed: _finish,
              child: const Text('结束并记录时长',
                  style: TextStyle(color: Colors.white70)))
        ])));
  }
}

class DiaryListPage extends StatelessWidget {
  const DiaryListPage({super.key, required this.diaryStore});

  final DiaryStore diaryStore;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: diaryStore,
      builder: (context, _) {
        final groups = <String, List<MobileDiary>>{};
        for (final diary in diaryStore.diaries) {
          groups
              .putIfAbsent(_diaryDayLabel(diary.createdAt), () => [])
              .add(diary);
        }
        return Scaffold(
          backgroundColor: _canvas,
          appBar: AppBar(
            title:
                const Text('日记', style: TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DiaryEditorPage(diaryStore: diaryStore))),
                  icon: const Icon(Icons.add),
                  tooltip: '写日记'),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text('把今天留给自己',
                  style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF687387).withValues(alpha: .9))),
              const SizedBox(height: 20),
              ...groups.entries.expand((entry) => [
                    _DiaryDateHeader(
                        label: entry.key, count: entry.value.length),
                    const SizedBox(height: 10),
                    ...entry.value.map((diary) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DiaryRow(
                            diary: diary,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => DiaryEditorPage(
                                        diaryStore: diaryStore,
                                        diary: diary))))))
                  ]),
            ],
          ),
        );
      },
    );
  }
}

class _DiaryDateHeader extends StatelessWidget {
  const _DiaryDateHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(width: 7),
        Text('$count 篇',
            style: const TextStyle(fontSize: 12, color: Color(0xFF939CA9))),
      ]);
}

class DiaryRow extends StatelessWidget {
  const DiaryRow({super.key, required this.diary, required this.onTap});

  final MobileDiary diary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = diary.content.replaceAll('\n', ' ').trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 12, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: diary.mood.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(diary.mood.icon, color: diary.mood.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(diary.title.isEmpty ? '今天的记录' : diary.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink)),
                  const SizedBox(height: 5),
                  Text(preview.isEmpty ? '还没有写下内容' : preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF747E8D))),
                  const SizedBox(height: 10),
                  Row(children: [
                    _DiaryTag(label: diary.mood.label, color: diary.mood.color),
                    const SizedBox(width: 6),
                    _DiaryTag(label: diary.activity.label, color: _mint),
                    const Spacer(),
                    Text(_diaryTimeLabel(diary.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFA1A9B5))),
                  ]),
                ])),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFFB4BBC6)),
          ]),
        ),
      ),
    );
  }
}

class _DiaryTag extends StatelessWidget {
  const _DiaryTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)));
}

class DiaryEditorPage extends StatefulWidget {
  const DiaryEditorPage({super.key, required this.diaryStore, this.diary});

  final DiaryStore diaryStore;
  final MobileDiary? diary;

  @override
  State<DiaryEditorPage> createState() => _DiaryEditorPageState();
}

class _DiaryEditorPageState extends State<DiaryEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final FocusNode _contentFocus;
  late DiaryMood _mood;
  late DiaryActivity _activity;
  var _preview = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.diary?.title ?? '');
    _content = TextEditingController(text: widget.diary?.content ?? '');
    _contentFocus = FocusNode();
    _mood = widget.diary?.mood ?? DiaryMood.calm;
    _activity = widget.diary?.activity ?? DiaryActivity.work;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back)),
          actions: [
            IconButton(
                onPressed: () => setState(() => _preview = !_preview),
                icon: Icon(
                    _preview ? Icons.edit_outlined : Icons.visibility_outlined),
                tooltip: _preview ? '继续编辑' : '预览 Markdown'),
            TextButton(onPressed: _save, child: const Text('完成')),
          ],
        ),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                  controller: _title,
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w700, color: _ink),
                  decoration: const InputDecoration(
                      hintText: '今天想记下什么？', border: InputBorder.none))),
          SizedBox(
              height: 40,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    ...DiaryMood.values.map((mood) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            avatar:
                                Icon(mood.icon, size: 16, color: mood.color),
                            label: Text(mood.label),
                            selected: _mood == mood,
                            selectedColor: mood.color.withValues(alpha: .15),
                            onSelected: (_) => setState(() => _mood = mood)))),
                    ...DiaryActivity.values.map((activity) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(activity.label),
                            selected: _activity == activity,
                            selectedColor: _mint.withValues(alpha: .13),
                            onSelected: (_) =>
                                setState(() => _activity = activity)))),
                  ])),
          const Divider(height: 24),
          _MarkdownToolbar(onInsert: _insertMarkdown),
          const Divider(height: 1),
          Expanded(
              child: _preview
                  ? Markdown(
                      data: _content.text.isEmpty ? '*还没有内容*' : _content.text,
                      padding: const EdgeInsets.all(20))
                  : TextField(
                      controller: _content,
                      focusNode: _contentFocus,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                          fontSize: 15, height: 1.6, color: _ink),
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(20),
                          hintText: '写下今天的片段、感受或念头…',
                          border: InputBorder.none))),
        ]),
      );

  void _insertMarkdown(String prefix, String suffix) {
    final value = _content.value;
    final range = value.selection;
    final selected =
        range.isValid ? value.text.substring(range.start, range.end) : '';
    final replacement = '$prefix${selected.isEmpty ? '文字' : selected}$suffix';
    _content.value = value.copyWith(
        text: value.text.replaceRange(range.start, range.end, replacement),
        selection:
            TextSelection.collapsed(offset: range.start + replacement.length));
    _contentFocus.requestFocus();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty && _content.text.trim().isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await widget.diaryStore.save(MobileDiary(
        id: widget.diary?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        content: _content.text,
        mood: _mood,
        activity: _activity,
        createdAt: widget.diary?.createdAt ?? DateTime.now()));
    if (mounted) Navigator.pop(context);
  }
}

String _diaryDayLabel(DateTime value) {
  final today = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(value);
  if (day == today) return '今天';
  if (day == today.subtract(const Duration(days: 1))) return '昨天';
  return '${value.month}月${value.day}日';
}

String _diaryTimeLabel(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${_diaryDayLabel(value)} $hour:$minute';
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.store});
  final NotesStore store;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  NoteCategory? _filter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final notes = widget.store.notes
            .where((note) => _filter == null || note.category == _filter)
            .toList();
        return Scaffold(
          backgroundColor: _canvas,
          appBar: AppBar(
              title: const Text('笔记',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              actions: [
                IconButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                NoteEditorPage(store: widget.store))),
                    icon: const Icon(Icons.add),
                    tooltip: '新建笔记')
              ]),
          body: Column(children: [
            SizedBox(
                height: 44,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _CategoryFilter(
                          label: '全部',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null)),
                      ...NoteCategory.values.map((category) => _CategoryFilter(
                          label: category.label,
                          selected: _filter == category,
                          onTap: () => setState(() => _filter = category))),
                    ])),
            Expanded(
                child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => NoteRow(
                        note: notes[index],
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => NoteEditorPage(
                                    store: widget.store,
                                    note: notes[index])))))),
          ]),
        );
      },
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
          label: Text(label), selected: selected, onSelected: (_) => onTap()));
}

class NoteRow extends StatelessWidget {
  const NoteRow({super.key, required this.note, required this.onTap});
  final MobileNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = note.content.replaceAll('\n', ' ').trim();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 7),
      onTap: onTap,
      leading: Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
              color: note.category.color,
              borderRadius: BorderRadius.circular(2))),
      title: Text(note.title.isEmpty ? '未命名笔记' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, color: _ink)),
      subtitle: Text(preview.isEmpty ? '没有正文' : preview,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(note.category.label,
          style: TextStyle(fontSize: 11, color: note.category.color)),
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.store, this.note});
  final NotesStore store;
  final MobileNote? note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late NoteCategory _category;
  late final FocusNode _contentFocus;
  var _preview = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _content = TextEditingController(text: widget.note?.content ?? '');
    _category = widget.note?.category ?? NoteCategory.idea;
    _contentFocus = FocusNode();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back)),
        actions: [
          IconButton(
              onPressed: () => setState(() => _preview = !_preview),
              icon: Icon(
                  _preview ? Icons.edit_outlined : Icons.visibility_outlined),
              tooltip: _preview ? '继续编辑' : '预览 Markdown'),
          TextButton(onPressed: _save, child: const Text('完成')),
        ],
      ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: TextField(
                controller: _title,
                style: const TextStyle(
                    fontSize: 25, fontWeight: FontWeight.w700, color: _ink),
                decoration: const InputDecoration(
                    hintText: '标题', border: InputBorder.none))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
                children: NoteCategory.values
                    .map((category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(category.label),
                            selected: _category == category,
                            selectedColor:
                                category.color.withValues(alpha: .18),
                            onSelected: (_) =>
                                setState(() => _category = category))))
                    .toList())),
        const Divider(height: 24),
        _MarkdownToolbar(onInsert: _insertMarkdown),
        const Divider(height: 1),
        Expanded(
            child: _preview
                ? Markdown(
                    data: _content.text.isEmpty ? '*还没有内容*' : _content.text,
                    padding: const EdgeInsets.all(20))
                : TextField(
                    controller: _content,
                    focusNode: _contentFocus,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style:
                        const TextStyle(fontSize: 15, height: 1.6, color: _ink),
                    decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(20),
                        hintText: '从一行想法开始…',
                        border: InputBorder.none))),
      ]),
    );
  }

  void _insertMarkdown(String prefix, String suffix) {
    final value = _content.value;
    final range = value.selection;
    final selected =
        range.isValid ? value.text.substring(range.start, range.end) : '';
    final replacement = '$prefix${selected.isEmpty ? '文字' : selected}$suffix';
    _content.value = value.copyWith(
        text: value.text.replaceRange(range.start, range.end, replacement),
        selection:
            TextSelection.collapsed(offset: range.start + replacement.length));
    _contentFocus.requestFocus();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final content = _content.text;
    if (title.isEmpty && content.trim().isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await widget.store.save(MobileNote(
        id: widget.note?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        content: content,
        category: _category,
        updatedAt: DateTime.now()));
    if (mounted) Navigator.pop(context);
  }
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({required this.onInsert});
  final void Function(String prefix, String suffix) onInsert;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 42,
        child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              IconButton(
                  onPressed: () => onInsert('**', '**'),
                  icon: const Text('B',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  tooltip: '加粗'),
              IconButton(
                  onPressed: () => onInsert('*', '*'),
                  icon: const Text('I',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w700)),
                  tooltip: '斜体'),
              IconButton(
                  onPressed: () => onInsert('`', '`'),
                  icon: const Icon(Icons.code, size: 20),
                  tooltip: '代码'),
              IconButton(
                  onPressed: () => onInsert('> ', ''),
                  icon: const Icon(Icons.format_quote, size: 20),
                  tooltip: '引用'),
              IconButton(
                  onPressed: () => onInsert('- ', ''),
                  icon: const Icon(Icons.format_list_bulleted, size: 20),
                  tooltip: '列表'),
            ]));
  }
}

class WeeklyReflectionPage extends StatefulWidget {
  const WeeklyReflectionPage({super.key});

  @override
  State<WeeklyReflectionPage> createState() => _WeeklyReflectionPageState();
}

class _WeeklyReflectionPageState extends State<WeeklyReflectionPage> {
  final _input = TextEditingController();
  final List<_ReflectionMessage> _messages = [
    const _ReflectionMessage(
        content:
            '这周你把移动端的笔记、日记和任务慢慢连成了一套体验。最让我高兴的是，你没有只停在功能清单，而是在反复问：它用起来会不会舒服？',
        isUser: false),
  ];
  final _questions = const ['我这周最值得保留的习惯是什么？', '下周我该先完成哪一件事？', '你觉得我哪里有点用力过猛？'];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send([String? value]) {
    final text = (value ?? _input.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ReflectionMessage(content: text, isUser: true));
      _messages.add(const _ReflectionMessage(
          content:
              '我会把它放回这周的记录里一起看。你已经把很多零散想法推进成了真实页面，下周不妨挑一个最想用的流程，连续用三天，再决定要不要继续加功能。🌱',
          isUser: false));
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
          title: const Text('AI 周复盘',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: SafeArea(
          top: false,
          child: Column(children: [
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    children: [
                  const _ReflectionHero(),
                  const SizedBox(height: 20),
                  const _ReflectionSection(
                      title: '本周故事',
                      icon: Icons.menu_book_outlined,
                      content:
                          '这周的主线很清楚：你一边修整桌面端的记录体验，一边把它带到移动端。任务、日记和笔记不再是分散的页面，开始有了同一个人的使用节奏。'),
                  const _ReflectionSection(
                      title: '我观察到的你',
                      icon: Icons.visibility_outlined,
                      content: '你最近特别在意“用起来是否顺手”。这不是反复折腾细节，而是产品感正在长出来。'),
                  const _ReflectionSection(
                      title: '本周成长',
                      icon: Icons.spa_outlined,
                      content: '你已经从“把功能做出来”走到了“让内容彼此连接”。这会让后面的 AI 和多端能力更有意义。'),
                  const _ReflectionSection(
                      title: '下周建议',
                      icon: Icons.flag_outlined,
                      content:
                          '先完整使用一次移动端的核心流程：记一篇日记、完成一项任务、做一次周复盘。把最不顺手的地方留下来，再动手。'),
                  const SizedBox(height: 22),
                  const Text('继续聊聊这一周',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _ink)),
                  const SizedBox(height: 10),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _questions
                          .map((question) => ActionChip(
                              label: Text(question,
                                  style: const TextStyle(fontSize: 12)),
                              onPressed: () => _send(question)))
                          .toList()),
                  const SizedBox(height: 14),
                  ..._messages
                      .map((message) => _MessageBubble(message: message)),
                ])),
            _ReflectionComposer(controller: _input, onSend: _send),
          ])));
}

class _ReflectionHero extends StatelessWidget {
  const _ReflectionHero();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
          color: const Color(0xFFECE9FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: Color(0xFF6959E8), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: Colors.white)),
        const SizedBox(width: 13),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('这一周过得怎么样？',
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700, color: _ink)),
          SizedBox(height: 7),
          Text('7月6日 - 7月12日 · 3 个任务 · 2 篇日记',
              style: TextStyle(fontSize: 13, color: Color(0xFF6C7287))),
          SizedBox(height: 10),
          Text('你没有停在“想做”，而是在一点点把自己的工具做成可用的样子。',
              style: TextStyle(fontSize: 14, height: 1.45, color: _ink)),
        ]))
      ]));
}

class _ReflectionSection extends StatelessWidget {
  const _ReflectionSection(
      {required this.title, required this.icon, required this.content});
  final String title;
  final IconData icon;
  final String content;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 19, color: _mint),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _ink))
            ]),
            const SizedBox(height: 10),
            Text(content,
                style: const TextStyle(
                    fontSize: 14, height: 1.55, color: Color(0xFF647081)))
          ])));
}

class _ReflectionMessage {
  const _ReflectionMessage({required this.content, required this.isUser});
  final String content;
  final bool isUser;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ReflectionMessage message;
  @override
  Widget build(BuildContext context) => Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          constraints: const BoxConstraints(maxWidth: 310),
          decoration: BoxDecoration(
              color: message.isUser ? const Color(0xFF6354E8) : Colors.white,
              borderRadius: BorderRadius.circular(14)),
          child: Text(message.content,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: message.isUser ? Colors.white : _ink))));
}

class _ReflectionComposer extends StatelessWidget {
  const _ReflectionComposer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: Colors.white,
      child: Row(children: [
        Expanded(
            child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                    hintText: '继续聊聊这一周…',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF5F6F8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none)))),
        const SizedBox(width: 8),
        IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.arrow_upward),
            color: Colors.white,
            style:
                IconButton.styleFrom(backgroundColor: const Color(0xFF6354E8)),
            tooltip: '发送')
      ]));
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage(
      {super.key,
      required this.icon,
      required this.title,
      required this.description});
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 36, color: _mint),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(color: Color(0xFF72808A)))
      ]));
}
