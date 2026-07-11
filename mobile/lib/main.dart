import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ink = Color(0xFF1D2A35);
const _mint = Color(0xFF157A6E);
const _coral = Color(0xFFE56B4F);
const _canvas = Color(0xFFF6F7F5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = NotesStore();
  await store.load();
  runApp(EssayPadMobile(store: store));
}

class EssayPadMobile extends StatelessWidget {
  const EssayPadMobile({super.key, required this.store});

  final NotesStore store;

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
      home: MobileShell(store: store),
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

class NotesStore extends ChangeNotifier {
  static const _storageKey = 'essaypad.mobile.notes.v1';
  NotesStore({List<MobileNote>? seed}) : _notes = List.of(seed ?? const []);

  final List<MobileNote> _notes;
  List<MobileNote> get notes => List.unmodifiable(
      _notes..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
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

class MobileShell extends StatefulWidget {
  const MobileShell({super.key, required this.store});
  final NotesStore store;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      0 => HomePage(store: widget.store),
      1 => const PlaceholderPage(
          icon: Icons.check_circle_outline,
          title: '任务',
          description: '今天的重要事情会在这里。'),
      3 => const PlaceholderPage(
          icon: Icons.chat_bubble_outline,
          title: 'AI 对话',
          description: '从周报里的发现，继续聊下去。'),
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
              subtitle: const Text('日记功能会在下一阶段接入'),
              onTap: () => Navigator.pop(context),
            ),
          ]),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});
  final NotesStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final notes = store.notes;
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
              const Text('笔记',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6054DD))),
              const SizedBox(width: 34),
              const Text('日记',
                  style: TextStyle(fontSize: 18, color: Color(0xFF74808D))),
              const Spacer(),
              TextButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NotesPage(store: store))),
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
              children: [
                ...notes.take(2).map((note) => _FeedCard(
                    note: note,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                NoteEditorPage(store: store, note: note))))),
                const _DiaryPreviewCard(
                  title: '热爱可抵岁月漫长',
                  content: '今天是充实的一天，完成了几个重要的功能，也学到了新的知识…',
                  time: '今天 22:45',
                  imageUrls: [
                    'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=400',
                    'https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=400',
                    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400'
                  ],
                ),
                const _DiaryPreviewCard(
                  title: '专注创造价值',
                  content: '专注是最稀缺的能力，也是最有复利的投资。',
                  time: '昨天 21:30',
                  imageUrls: [
                    'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800'
                  ],
                ),
              ],
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

class _DiaryPreviewCard extends StatelessWidget {
  const _DiaryPreviewCard(
      {required this.title,
      required this.content,
      required this.time,
      required this.imageUrls});
  final String title;
  final String content;
  final String time;
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0E1D2A35), blurRadius: 14, offset: Offset(0, 8))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.menu_book_outlined, size: 18, color: Color(0xFF48BC87)),
          SizedBox(width: 6),
          Text('日记', style: TextStyle(fontSize: 12, color: Color(0xFF48BC87))),
          Spacer(),
          Icon(Icons.push_pin_outlined, size: 18, color: Color(0xFFB4BAC6))
        ]),
        const SizedBox(height: 12),
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: _ink)),
        const SizedBox(height: 8),
        Text(content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: Color(0xFF6F7988))),
        const Spacer(),
        if (imageUrls.length == 1)
          _Photo(url: imageUrls.first, width: double.infinity)
        else
          Row(
              children: imageUrls
                  .map((url) => Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: _Photo(url: url, width: double.infinity))))
                  .toList()),
        const SizedBox(height: 9),
        Text(time,
            style: const TextStyle(fontSize: 11, color: Color(0xFFABB2BE))),
      ]));
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url, required this.width});
  final String url;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: width,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: 76,
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFFD4D9D5), Color(0xFFF2F1ED)])),
        ),
      ),
    );
  }
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
