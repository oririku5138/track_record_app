import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ihgjmpfmgrjmwrpihzdo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImloZ2ptcGZtZ3JqbXdycGloemRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE3MTA3NTcsImV4cCI6MjEwNzI4Njc1N30.8t238RWSBrok0bhn9XfSvwgBW1NIrtle07CLBelzslI',
  );

  runApp(const TrackRecordApp());
}

final supabase = Supabase.instance.client;

// 今日の日付を8桁の文字列(YYYYMMDD)で取得する関数
String getTodayDateString() {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

class TrackRecordApp extends StatelessWidget {
  const TrackRecordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '陸上記録アプリ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const TopSelectionPage(),
    );
  }
}

// 8桁の日付（例: 20261011）を保存用(2026-10-11)と表示用(2026/10/11)に変換する関数
String parseDateInput(String input) {
  final clean = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (clean.length == 8) {
    final y = clean.substring(0, 4);
    final m = clean.substring(4, 6);
    final d = clean.substring(6, 8);
    return '$y-$m-$d';
  }
  return input;
}

String formatDateDisplay(String dateStr) {
  if (dateStr.length == 10 && dateStr[4] == '-' && dateStr[7] == '-') {
    return dateStr.replaceAll('-', '/');
  }
  return dateStr;
}

// 共通競技場リスト
const List<String> stadiumList = [
  '茅野市運動公園陸上競技場',
  '飯田市松尾総合運動場陸上競技場',
  '長野市営陸上競技場',
  '松本平広域公園陸上競技場',
  '佐久総合運動公園陸上競技場',
  '伊那市陸上競技場',
];

// 風力判定（リレーは除外）
bool hasWindSpeed(String eventName) {
  final windEvents = ['100m', '150m', '200m', '80mH', '100mH', '110mH', '走幅跳', '三段跳'];
  return windEvents.contains(eventName);
}

// ==========================================
// 陸上混成得点計算エンジン (World Athletics 準拠)
// ==========================================
int calculateSubEventPoint(String subEvent, String recordText) {
  if (recordText.trim().isEmpty) return 0;
  final double? val = double.tryParse(recordText);
  if (val == null || val <= 0) return 0;

  Map<String, List<num>> params = {
    '100m': [25.4347, 18.0, 1.81, 1],
    '200m': [5.8425, 38.0, 1.81, 1],
    '400m': [1.53775, 82.0, 1.81, 1],
    '800m': [0.11193, 254.0, 1.88, 1],
    '1500m': [0.03768, 480.0, 1.85, 1],
    '100mH': [9.23076, 26.7, 1.835, 1],
    '110mH': [5.74352, 28.5, 1.92, 1],
    '80mH': [12.0, 20.0, 1.835, 1],
    '走高跳': [0.8465, 75.0, 1.42, 2],
    '棒高跳': [0.2797, 100.0, 1.35, 2],
    '走幅跳': [0.14354, 220.0, 1.40, 2],
    '砲丸投': [51.39, 1.5, 1.05, 3],
    '円盤投': [12.91, 4.0, 1.10, 3],
    'やり投': [10.14, 7.0, 1.08, 3],
  };

  if (!params.containsKey(subEvent)) return 0;

  final p = params[subEvent]!;
  final double a = p[0].toDouble();
  final double b = p[1].toDouble();
  final double c = p[2].toDouble();
  final int type = p[3].toInt();

  double score = 0;
  if (type == 1) {
    if (val >= b) return 0;
    score = a * pow((b - val), c);
  } else if (type == 2) {
    double cm = val < 10 ? val * 100 : val;
    if (cm <= b) return 0;
    score = a * pow((cm - b), c);
  } else if (type == 3) {
    if (val <= b) return 0;
    score = a * pow((val - b), c);
  }

  return max(0, score.floor());
}

// ==========================================
// 1. 【TOP】ページ（選手選択）
// ==========================================
class TopSelectionPage extends StatelessWidget {
  const TopSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade800, Colors.blue.shade50],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_run, size: 80, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'ジュニア陸上記録ノート',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '選手を選んでください',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AthleteButton(
                      name: '美音',
                      avatarIcon: Icons.face_3,
                      color: Colors.pink.shade400,
                      onTap: () => _navigateToHome(context, '美音'),
                    ),
                    const SizedBox(width: 24),
                    _AthleteButton(
                      name: '奏太',
                      avatarIcon: Icons.face,
                      color: Colors.indigo.shade400,
                      onTap: () => _navigateToHome(context, '奏太'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToHome(BuildContext context, String name) async {
    try {
      final response = await supabase.from('athletes').select('id').eq('name', name).single();
      final athleteId = response['id'] as String;

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AthleteHomePage(athleteName: name, athleteId: athleteId),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: アスリート情報の取得に失敗しました ($e)')),
        );
      }
    }
  }
}

class _AthleteButton extends StatelessWidget {
  const _AthleteButton({
    required this.name,
    required this.avatarIcon,
    required this.color,
    required this.onTap,
  });

  final String name;
  final IconData avatarIcon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        width: 130,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(avatarIcon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. 個別アスリートのホーム画面
// ==========================================
class AthleteHomePage extends StatelessWidget {
  const AthleteHomePage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$athleteName の記録ルーム'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _MenuCard(
            title: '陸上記録',
            icon: Icons.emoji_events,
            color: Colors.amber.shade700,
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordListPage(athleteName: athleteName, athleteId: athleteId),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('見る'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordTypeSelectPage(athleteName: athleteName, athleteId: athleteId),
                    ),
                  );
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('書く'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickAccessCard(
                  title: 'ベスト記録',
                  icon: Icons.star,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BestRecordPage(athleteName: athleteName, athleteId: athleteId),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _QuickAccessCard(
                  title: 'グラフ推移',
                  icon: Icons.show_chart,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GraphPage(athleteName: athleteName, athleteId: athleteId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuCard(
            title: '練習日記',
            icon: Icons.book,
            color: Colors.purple.shade400,
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DiaryListPage(athleteName: athleteName, athleteId: athleteId),
                    ),
                  );
                },
                icon: const Icon(Icons.list, size: 18),
                label: const Text('見る'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DiaryInputPage(athleteName: athleteName, athleteId: athleteId),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('書く'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.title, required this.icon, required this.color, required this.actions});
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.title, required this.icon, required this.color, required this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. 種目タイプ選択ページ
// ==========================================
class RecordTypeSelectPage extends StatelessWidget {
  const RecordTypeSelectPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$athleteName - 種目タイプの選択')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('入力する記録の種類を選んでください', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrackRecordInputPage(athleteName: athleteName, athleteId: athleteId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.directions_run, size: 28),
                  label: const Text('トラック種目 (リレー含む)', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FieldRecordInputPage(athleteName: athleteName, athleteId: athleteId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.straighten, size: 28),
                  label: const Text('フィールド種目', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CombinedRecordInputPage(athleteName: athleteName, athleteId: athleteId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium, size: 28),
                  label: const Text('混成種目 (自動スコア計算付)', style: TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. トラック結果入力ページ
// ==========================================
class TrackRecordInputPage extends StatefulWidget {
  const TrackRecordInputPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  State<TrackRecordInputPage> createState() => _TrackRecordInputPageState();
}

class _TrackRecordInputPageState extends State<TrackRecordInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  final _tournamentController = TextEditingController();
  final _stadiumController = TextEditingController(text: stadiumList[0]);
  final _weatherController = TextEditingController();
  final _heatIndexController = TextEditingController();
  final _conditionController = TextEditingController();
  final _windController = TextEditingController();
  final _laneController = TextEditingController();
  final _recordController = TextEditingController();
  
  final _overallRankController = TextEditingController();
  final _heatRankController = TextEditingController();

  final List<TextEditingController> _relayControllers = List.generate(4, (_) => TextEditingController());

  String selectedEvent = '100m';
  bool isCustomStadium = false;
  bool isRelay = false;
  bool isLoading = false;

  final List<String> trackEvents = [
    '100m', '150m', '200m', '300m', '400m', '800m', '1000m', '1500m', '3000m', '5000m', '10000m',
    '80mH', '100mH', '110mH', '300mH', '400mH', '3000mSC',
    '4x100mリレー', '4x400mリレー'
  ];

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: getTodayDateString());
  }

  @override
  Widget build(BuildContext context) {
    final showWind = hasWindSpeed(selectedEvent);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} - トラック記録入力')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _dateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '日付 (例: YYYYMMDD)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return '日付を入力してください';
                  final parsed = parseDateInput(v);
                  if (parsed.length != 10) return '8桁の数字で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _tournamentController, decoration: const InputDecoration(labelText: '大会名', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? '入力してください' : null),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: isCustomStadium
                        ? TextFormField(
                            controller: _stadiumController,
                            decoration: const InputDecoration(labelText: '競技場名（手入力）', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? '入力してください' : null,
                          )
                        : DropdownButtonFormField<String>(
                            value: stadiumList.contains(_stadiumController.text) ? _stadiumController.text : stadiumList[0],
                            decoration: const InputDecoration(labelText: '競技場選択', border: OutlineInputBorder()),
                            items: stadiumList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _stadiumController.text = val!),
                          ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(() => isCustomStadium = !isCustomStadium),
                    child: Text(isCustomStadium ? '一覧から選択' : '手入力する'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _weatherController, decoration: const InputDecoration(labelText: '天気', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heatIndexController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '暑さ指数 (1〜15)', border: OutlineInputBorder()),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 15) return '1〜15の範囲で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conditionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'コンディション (1〜100)', border: OutlineInputBorder()),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 100) return '1〜100の範囲で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedEvent,
                decoration: const InputDecoration(labelText: '種目', border: OutlineInputBorder()),
                items: trackEvents.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedEvent = val!;
                    isRelay = val.contains('リレー');
                  });
                },
              ),
              if (isRelay) ...[
                const SizedBox(height: 16),
                const Text('【リレー走順 4人分の名前】', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (int i = 0; i < 4; i++) ...[
                  TextFormField(
                    controller: _relayControllers[i],
                    decoration: InputDecoration(labelText: '第${i + 1}走者', border: const OutlineInputBorder()),
                    validator: (v) => isRelay && (v == null || v.isEmpty) ? '走者名を入力してください' : null,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (showWind) ...[
                const SizedBox(height: 16),
                TextFormField(controller: _windController, decoration: const InputDecoration(labelText: '風力 (例: +1.2)', border: OutlineInputBorder())),
              ],
              const SizedBox(height: 16),
              TextFormField(controller: _laneController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'レーン', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _overallRankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '全体何位 (必須)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? '全体順位を入力してください' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heatRankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '組何位 (任意)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recordController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '記録 (例: 14.55秒 → 1455 と入力)', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? '記録を入力してください' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: isLoading ? null : _saveRecord,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('保存する', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final rawRecord = int.parse(_recordController.text);
      final formatted = '${(rawRecord / 100).toStringAsFixed(2)}秒';
      final formattedDate = parseDateInput(_dateController.text);
      final showWind = hasWindSpeed(selectedEvent);

      await supabase.from('competition_results').insert({
        'athlete_id': widget.athleteId,
        'date': formattedDate,
        'event_type': 'track',
        'tournament_name': _tournamentController.text,
        'stadium': _stadiumController.text,
        'weather': _weatherController.text,
        'heat_index': int.parse(_heatIndexController.text),
        'condition': int.parse(_conditionController.text),
        'event_name': selectedEvent,
        'wind_speed': showWind ? double.tryParse(_windController.text) : null,
        'lane': int.tryParse(_laneController.text),
        'overall_rank': int.tryParse(_overallRankController.text),
        'heat_rank': int.tryParse(_heatRankController.text),
        'relay_members': isRelay ? _relayControllers.map((c) => c.text).toList() : null,
        'best_value_integer': rawRecord,
        'formatted_record': formatted,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('トラック記録を保存しました！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}

// ==========================================
// 5. フィールド結果入力ページ
// ==========================================
class JumpAttempt {
  final TextEditingController heightController = TextEditingController();
  List<String> results = ['×'];
}

class FieldRecordInputPage extends StatefulWidget {
  const FieldRecordInputPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  State<FieldRecordInputPage> createState() => _FieldRecordInputPageState();
}

class _FieldRecordInputPageState extends State<FieldRecordInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  final _tournamentController = TextEditingController();
  final _stadiumController = TextEditingController(text: stadiumList[0]);
  final _weatherController = TextEditingController();
  final _heatIndexController = TextEditingController();
  final _conditionController = TextEditingController();
  final _windController = TextEditingController();

  final _overallRankController = TextEditingController();
  final _heatRankController = TextEditingController();

  final List<TextEditingController> _trialControllers = List.generate(6, (_) => TextEditingController());
  final List<JumpAttempt> _jumpAttempts = [JumpAttempt()];

  String selectedEvent = '走幅跳';
  bool isCustomStadium = false;
  bool isTop8 = false;
  bool isNoTop8 = false;
  bool isLoading = false;

  final List<String> fieldEvents = [
    '走幅跳', '三段跳', '走高跳', '棒高跳', '砲丸投', '円盤投', 'ハンマー投', 'やり投', 'ジャベリックスロー'
  ];

  bool get isVerticalJump => selectedEvent == '走高跳' || selectedEvent == '棒高跳';

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: getTodayDateString());
  }

  @override
  Widget build(BuildContext context) {
    final showWind = hasWindSpeed(selectedEvent);
    // 「TOP8あり」が選ばれたときだけ6試技、それ以外（未選択またはTOP8なし）は3試技
    final bool showSixTrials = isTop8;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} - フィールド記録入力')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _dateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '日付 (例: YYYYMMDD)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return '日付を入力してください';
                  final parsed = parseDateInput(v);
                  if (parsed.length != 10) return '8桁の数字で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _tournamentController, decoration: const InputDecoration(labelText: '大会名', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? '入力してください' : null),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: isCustomStadium
                        ? TextFormField(
                            controller: _stadiumController,
                            decoration: const InputDecoration(labelText: '競技場名（手入力）', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? '入力してください' : null,
                          )
                        : DropdownButtonFormField<String>(
                            value: stadiumList.contains(_stadiumController.text) ? _stadiumController.text : stadiumList[0],
                            decoration: const InputDecoration(labelText: '競技場選択', border: OutlineInputBorder()),
                            items: stadiumList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _stadiumController.text = val!),
                          ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(() => isCustomStadium = !isCustomStadium),
                    child: Text(isCustomStadium ? '一覧から選択' : '手入力する'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _weatherController, decoration: const InputDecoration(labelText: '天気', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heatIndexController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '暑さ指数 (1〜15)', border: OutlineInputBorder()),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 15) return '1〜15の範囲で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conditionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'コンディション (1〜100)', border: OutlineInputBorder()),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 100) return '1〜100の範囲で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedEvent,
                decoration: const InputDecoration(labelText: '種目', border: OutlineInputBorder()),
                items: fieldEvents.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedEvent = val!;
                  });
                },
              ),
              if (showWind) ...[
                const SizedBox(height: 16),
                TextFormField(controller: _windController, decoration: const InputDecoration(labelText: '風力 (例: +1.2)', border: OutlineInputBorder())),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _overallRankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '全体何位 (必須)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? '全体順位を入力してください' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heatRankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '組何位 (任意)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isVerticalJump) ...[
                const Text('【高さごとの試技入力 (最大3回)】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                for (int i = 0; i < _jumpAttempts.length; i++) ...[
                  Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _jumpAttempts[i].heightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: '第${i + 1}高さ (例: 1.45m or 145)',
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (v) => v == null || v.isEmpty ? '高さを入力してください' : null,
                                ),
                              ),
                              if (_jumpAttempts.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => setState(() => _jumpAttempts.removeAt(i)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('試技結果: '),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    for (int r = 0; r < _jumpAttempts[i].results.length; r++)
                                      ChoiceChip(
                                        label: Text(
                                          _jumpAttempts[i].results[r],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: _jumpAttempts[i].results[r] == '〇' ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                        selected: true,
                                        showCheckmark: false,
                                        selectedColor: _jumpAttempts[i].results[r] == '〇' ? Colors.green.shade200 : Colors.red.shade200,
                                        onSelected: (bool selected) {
                                          setState(() {
                                            if (_jumpAttempts[i].results[r] == '×') {
                                              if (!_jumpAttempts[i].results.contains('〇')) {
                                                _jumpAttempts[i].results[r] = '〇';
                                              }
                                            } else {
                                              _jumpAttempts[i].results[r] = '×';
                                            }
                                          });
                                        },
                                      ),
                                    if (!_jumpAttempts[i].results.contains('〇') && _jumpAttempts[i].results.length < 3)
                                      ActionChip(
                                        avatar: const Icon(Icons.add, size: 16),
                                        label: const Text('追加'),
                                        onPressed: () {
                                          setState(() {
                                            _jumpAttempts[i].results.add('×');
                                          });
                                        },
                                      ),
                                    if (_jumpAttempts[i].results.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.backspace_outlined, size: 20, color: Colors.grey),
                                        onPressed: () {
                                          setState(() {
                                            _jumpAttempts[i].results.removeLast();
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                ElevatedButton.icon(
                  onPressed: () => setState(() => _jumpAttempts.add(JumpAttempt())),
                  icon: const Icon(Icons.add),
                  label: const Text('次の高さを追加'),
                ),
              ] else ...[
                const Text('【試技の選択】', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('TOP8なし (3試技)'),
                        value: isNoTop8,
                        onChanged: (val) {
                          setState(() {
                            isNoTop8 = val ?? false;
                            if (isNoTop8) isTop8 = false;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('TOP8あり (6試技)'),
                        value: isTop8,
                        onChanged: (val) {
                          setState(() {
                            isTop8 = val ?? false;
                            if (isTop8) isNoTop8 = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 「TOP8あり」なら6試技、未選択または「TOP8なし」なら3試技
                for (int i = 0; i < (showSixTrials ? 6 : 3); i++) ...[
                  TextFormField(
                    controller: _trialControllers[i],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '第${i + 1}試技の記録 (例: 22.55m → 2255)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (i == 0 && (v == null || v.isEmpty)) return '第1試技を入力してください';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: isLoading ? null : _saveFieldRecord,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('保存する', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFieldRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      int maxVal = -1;
      List<int> trials = [];
      List<String> jumpSummary = [];

      if (isVerticalJump) {
        for (var att in _jumpAttempts) {
          final hText = att.heightController.text.replaceAll('m', '');
          final dH = double.tryParse(hText) ?? 0;
          if (dH <= 0) continue;
          final cmVal = dH < 10 ? (dH * 100).round() : dH.round();
          
          if (att.results.contains('〇')) {
            if (cmVal > maxVal) maxVal = cmVal;
          }
          jumpSummary.add('${dH}m: [${att.results.join()}]');
        }
      } else {
        // 「TOP8あり」なら6試技、それ以外（未選択・TOP8なし）なら3試技まで対象
        final trialCount = isTop8 ? 6 : 3;
        for (int i = 0; i < trialCount; i++) {
          final textVal = _trialControllers[i].text.trim();
          if (textVal.isNotEmpty) {
            final val = int.tryParse(textVal) ?? 0;
            trials.add(val);
            if (val > maxVal) maxVal = val;
          }
        }
      }

      final formatted = '${(maxVal / 100).toStringAsFixed(2)}m';
      final formattedDate = parseDateInput(_dateController.text);
      final showWind = hasWindSpeed(selectedEvent);

      // 「TOP8なし」を選んだ時だけ false (TOP8無)、未選択やTOP8ありなら true (TOP8有)
      final bool saveTop8Flag = !isNoTop8;

      await supabase.from('competition_results').insert({
        'athlete_id': widget.athleteId,
        'date': formattedDate,
        'event_type': 'field',
        'tournament_name': _tournamentController.text,
        'stadium': _stadiumController.text,
        'weather': _weatherController.text,
        'heat_index': int.parse(_heatIndexController.text),
        'condition': int.parse(_conditionController.text),
        'event_name': selectedEvent,
        'wind_speed': showWind ? double.tryParse(_windController.text) : null,
        'implement_weight': null,
        'is_top8': saveTop8Flag,
        'overall_rank': int.tryParse(_overallRankController.text),
        'heat_rank': int.tryParse(_heatRankController.text),
        'trials': isVerticalJump ? jumpSummary : trials,
        'best_value_integer': maxVal,
        'formatted_record': formatted,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('フィールド記録を保存しました！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}

// ==========================================
// 5.5 混成競技結果入力ページ (各試技詳細・TOP8無/有対応)
// ==========================================
class CombinedSubAttempt {
  final TextEditingController heightController = TextEditingController();
  List<String> results = ['×'];
}

class CombinedSubEventInput {
  final String subEventName;
  final TextEditingController recordController = TextEditingController();
  final TextEditingController windController = TextEditingController();
  final List<TextEditingController> trialControllers = List.generate(6, (_) => TextEditingController());
  final List<CombinedSubAttempt> jumpAttempts = [CombinedSubAttempt()];
  bool isTop8 = false;
  bool isNoTop8 = false;

  CombinedSubEventInput(this.subEventName);

  bool get isVertical => subEventName == '走高跳' || subEventName == '棒高跳';
}

class CombinedRecordInputPage extends StatefulWidget {
  const CombinedRecordInputPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  State<CombinedRecordInputPage> createState() => _CombinedRecordInputPageState();
}

class _CombinedRecordInputPageState extends State<CombinedRecordInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  final _tournamentController = TextEditingController();
  final _stadiumController = TextEditingController(text: stadiumList[0]);
  final _weatherController = TextEditingController();
  final _heatIndexController = TextEditingController();
  final _conditionController = TextEditingController();

  final _overallRankController = TextEditingController();
  final _heatRankController = TextEditingController();

  String selectedCombinedType = '四種競技 (男子)';
  bool isCustomStadium = false;
  bool isLoading = false;

  final Map<String, List<String>> combinedSubEventsList = {
    '四種競技 (男子)': ['110mH', '砲丸投', '走高跳', '400m'],
    '四種競技 (女子)': ['100mH', '走高跳', '砲丸投', '200m'],
    '七種競技 (女子)': ['100mH', '走高跳', '砲丸投', '200m', '走幅跳', 'やり投', '800m'],
    '十種競技 (男子)': ['100m', '走幅跳', '砲丸投', '走高跳', '400m', '110mH', '円盤投', '棒高跳', 'やり投', '1500m'],
  };

  List<CombinedSubEventInput> subInputs = [];

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: getTodayDateString());
    _initSubEvents();
  }

  void _initSubEvents() {
    final names = combinedSubEventsList[selectedCombinedType]!;
    subInputs = names.map((n) => CombinedSubEventInput(n)).toList();
  }

  int get calculatedTotalScore {
    int total = 0;
    for (var sub in subInputs) {
      final bestVal = _getSubEventBestValue(sub);
      total += calculateSubEventPoint(sub.subEventName, (bestVal / 100).toString());
    }
    return total;
  }

  int _getSubEventBestValue(CombinedSubEventInput sub) {
    if (sub.isVertical) {
      int maxCm = 0;
      for (var att in sub.jumpAttempts) {
        final hText = att.heightController.text.replaceAll('m', '');
        final dH = double.tryParse(hText) ?? 0;
        if (dH <= 0) continue;
        final cmVal = dH < 10 ? (dH * 100).round() : dH.round();
        if (att.results.contains('〇') && cmVal > maxCm) {
          maxCm = cmVal;
        }
      }
      return maxCm;
    } else if (hasWindSpeed(sub.subEventName) || sub.subEventName == '400m' || sub.subEventName == '800m' || sub.subEventName == '1500m') {
      return int.tryParse(sub.recordController.text.trim()) ?? 0;
    } else {
      int maxVal = 0;
      final count = sub.isTop8 ? 6 : 3;
      for (int i = 0; i < count; i++) {
        final val = int.tryParse(sub.trialControllers[i].text.trim()) ?? 0;
        if (val > maxVal) maxVal = val;
      }
      return maxVal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} - 混成記録入力 (詳細)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _dateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '日付 (例: YYYYMMDD)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return '日付を入力してください';
                  final parsed = parseDateInput(v);
                  if (parsed.length != 10) return '8桁の数字で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _tournamentController, decoration: const InputDecoration(labelText: '大会名', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? '入力してください' : null),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: isCustomStadium
                        ? TextFormField(
                            controller: _stadiumController,
                            decoration: const InputDecoration(labelText: '競技場名（手入力）', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? '入力してください' : null,
                          )
                        : DropdownButtonFormField<String>(
                            value: stadiumList.contains(_stadiumController.text) ? _stadiumController.text : stadiumList[0],
                            decoration: const InputDecoration(labelText: '競技場選択', border: OutlineInputBorder()),
                            items: stadiumList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _stadiumController.text = val!),
                          ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(() => isCustomStadium = !isCustomStadium),
                    child: Text(isCustomStadium ? '一覧から選択' : '手入力する'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _weatherController, decoration: const InputDecoration(labelText: '天気', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heatIndexController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '暑さ指数 (1〜15)', border: OutlineInputBorder()),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 15) return '1〜15の範囲で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conditionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'コンディション (1〜100)', border: OutlineInputBorder()),
                validator: (val) {
                  final n = int.tryParse(val ?? '');
                  if (n == null || n < 1 || n > 100) return '1〜100の範囲で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCombinedType,
                decoration: const InputDecoration(labelText: '混成種目の種類', border: OutlineInputBorder()),
                items: combinedSubEventsList.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedCombinedType = val!;
                    _initSubEvents();
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _overallRankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '全体何位 (必須)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? '全体順位を入力してください' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heatRankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '組何位 (任意)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('【$selectedCombinedType 各種目の詳細記録】', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
              const SizedBox(height: 12),
              
              for (var sub in subInputs) ...[
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(sub.subEventName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
                            Text(
                              '${calculateSubEventPoint(sub.subEventName, (_getSubEventBestValue(sub) / 100).toString())} 点',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        if (hasWindSpeed(sub.subEventName) || sub.subEventName == '400m' || sub.subEventName == '800m' || sub.subEventName == '1500m') ...[
                          if (hasWindSpeed(sub.subEventName)) ...[
                            TextFormField(
                              controller: sub.windController,
                              decoration: const InputDecoration(labelText: '風力 (例: +1.2)', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: sub.recordController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '記録 (例: 14.55秒 → 1455)', border: OutlineInputBorder()),
                            validator: (v) => v == null || v.isEmpty ? '${sub.subEventName}の記録を入力してください' : null,
                            onChanged: (_) => setState(() {}),
                          ),
                        ]
                        else if (sub.isVertical) ...[
                          for (int i = 0; i < sub.jumpAttempts.length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: sub.jumpAttempts[i].heightController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: '第${i + 1}高さ (例: 1.45)',
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator: (v) => v == null || v.isEmpty ? '高さを入力' : null,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: Wrap(
                                      spacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        for (int r = 0; r < sub.jumpAttempts[i].results.length; r++)
                                          ChoiceChip(
                                            label: Text(
                                              sub.jumpAttempts[i].results[r],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: sub.jumpAttempts[i].results[r] == '〇' ? Colors.green.shade800 : Colors.red.shade800,
                                              ),
                                            ),
                                            selected: true,
                                            showCheckmark: false,
                                            selectedColor: sub.jumpAttempts[i].results[r] == '〇' ? Colors.green.shade200 : Colors.red.shade200,
                                            onSelected: (_) {
                                              setState(() {
                                                if (sub.jumpAttempts[i].results[r] == '×') {
                                                  if (!sub.jumpAttempts[i].results.contains('〇')) {
                                                    sub.jumpAttempts[i].results[r] = '〇';
                                                  }
                                                } else {
                                                  sub.jumpAttempts[i].results[r] = '×';
                                                }
                                              });
                                            },
                                          ),
                                        if (!sub.jumpAttempts[i].results.contains('〇') && sub.jumpAttempts[i].results.length < 3)
                                          ActionChip(
                                            avatar: const Icon(Icons.add, size: 14),
                                            label: const Text('追加'),
                                            onPressed: () => setState(() => sub.jumpAttempts[i].results.add('×')),
                                          ),
                                        if (sub.jumpAttempts[i].results.length > 1)
                                          IconButton(
                                            icon: const Icon(Icons.backspace_outlined, size: 18, color: Colors.grey),
                                            onPressed: () => setState(() => sub.jumpAttempts[i].results.removeLast()),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          ElevatedButton.icon(
                            onPressed: () => setState(() => sub.jumpAttempts.add(CombinedSubAttempt())),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('次の高さを追加'),
                          ),
                        ]
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  title: const Text('TOP8なし (3試技)'),
                                  value: sub.isNoTop8,
                                  onChanged: (val) => setState(() {
                                    sub.isNoTop8 = val ?? false;
                                    if (sub.isNoTop8) sub.isTop8 = false;
                                  }),
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  title: const Text('TOP8あり (6試技)'),
                                  value: sub.isTop8,
                                  onChanged: (val) => setState(() {
                                    sub.isTop8 = val ?? false;
                                    if (sub.isTop8) sub.isNoTop8 = false;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (int i = 0; i < (sub.isTop8 ? 6 : 3); i++) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: TextFormField(
                                controller: sub.trialControllers[i],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '第${i + 1}試技 (例: 2255 = 22.55m)',
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (i == 0 && (v == null || v.isEmpty)) return '第1試技を入力してください';
                                  return null;
                                },
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('合計算出スコア:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('$calculatedTotalScore 点', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: isLoading ? null : _saveCombinedRecord,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('混成記録を保存する', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveCombinedRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final pts = calculatedTotalScore;
      final formatted = '$pts点';
      final formattedDate = parseDateInput(_dateController.text);

      List<String> subDetails = [];
      for (var sub in subInputs) {
        final best = _getSubEventBestValue(sub);
        final pt = calculateSubEventPoint(sub.subEventName, (best / 100).toString());

        if (sub.isVertical) {
          List<String> details = [];
          for (var att in sub.jumpAttempts) {
            details.add('${att.heightController.text}m:[${att.results.join()}]');
          }
          subDetails.add('${sub.subEventName} (${details.join(", ")}) -> $pt点');
        } else if (hasWindSpeed(sub.subEventName) || sub.subEventName == '400m' || sub.subEventName == '800m' || sub.subEventName == '1500m') {
          final w = sub.windController.text.isNotEmpty ? ' (${sub.windController.text})' : '';
          subDetails.add('${sub.subEventName}: ${sub.recordController.text}$w -> $pt点');
        } else {
          final count = sub.isTop8 ? 6 : 3;
          List<String> trials = [];
          for (int i = 0; i < count; i++) {
            if (sub.trialControllers[i].text.isNotEmpty) {
              trials.add(sub.trialControllers[i].text);
            }
          }
          final top8Text = sub.isNoTop8 ? '【TOP8無】' : '【TOP8有】';
          subDetails.add('$top8Text ${sub.subEventName} [試技: ${trials.join(", ")}] -> $pt点');
        }
      }

      await supabase.from('competition_results').insert({
        'athlete_id': widget.athleteId,
        'date': formattedDate,
        'event_type': 'combined',
        'tournament_name': _tournamentController.text,
        'stadium': _stadiumController.text,
        'weather': _weatherController.text,
        'heat_index': int.parse(_heatIndexController.text),
        'condition': int.parse(_conditionController.text),
        'event_name': selectedCombinedType,
        'overall_rank': int.tryParse(_overallRankController.text),
        'heat_rank': int.tryParse(_heatRankController.text),
        'relay_members': subDetails,
        'best_value_integer': pts,
        'formatted_record': formatted,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('混成記録を保存しました！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}

// ==========================================
// 6. 陸上記録【見る】ページ
// ==========================================
class RecordListPage extends StatelessWidget {
  const RecordListPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$athleteName の陸上記録一覧')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase
            .from('competition_results')
            .select()
            .eq('athlete_id', athleteId)
            .order('date', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('まだ記録が登録されていません'));
          }

          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (var item in data) {
            final key = '${item['date']}_${item['tournament_name']}';
            grouped.putIfAbsent(key, () => []).add(item);
          }
          final keys = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final groupKey = keys[index];
              final items = grouped[groupKey]!;
              final first = items.first;
              final displayDate = formatDateDisplay(first['date']);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TournamentDetailPage(
                          athleteName: athleteName,
                          tournamentName: first['tournament_name'],
                          date: displayDate,
                          items: items,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$displayDate - ${first['tournament_name']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                            ),
                            const Row(
                              children: [
                                Text('詳細を見る', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
                              ],
                            ),
                          ],
                        ),
                        const Divider(thickness: 1.5, height: 20),
                        for (int i = 0; i < items.length; i++) ...[
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(items[i]['event_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('競技場: ${items[i]['stadium']} / 天気: ${items[i]['weather']}'),
                            trailing: Text(
                              items[i]['formatted_record'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo),
                            ),
                          ),
                          if (i < items.length - 1) const Divider(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 6.5 大会詳細ページ
// ==========================================
class TournamentDetailPage extends StatelessWidget {
  const TournamentDetailPage({
    super.key,
    required this.athleteName,
    required this.tournamentName,
    required this.date,
    required this.items,
  });

  final String athleteName;
  final String tournamentName;
  final String date;
  final List<Map<String, dynamic>> items;

  Future<void> _deleteResult(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: const Text('この記録を削除してもよろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('いいえ')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('competition_results').delete().eq('id', id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('記録を削除しました')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$tournamentName の詳細'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('選手名: $athleteName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('大会名: $tournamentName', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('開催日: $date', style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('【エントリー種目と詳細結果】', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (var item in items) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['event_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        Row(
                          children: [
                            Text(item['formatted_record'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteResult(context, item['id']),
                              tooltip: 'この記録を削除',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text('競技場: ${item['stadium']}'),
                    Text('天気: ${item['weather']}'),
                    Text('暑さ指数: ${item['heat_index']}'),
                    Text('コンディション: ${item['condition']}'),
                    if (hasWindSpeed(item['event_name']) && item['wind_speed'] != null)
                      Text('風力: ${item['wind_speed']}'),
                    if (item['overall_rank'] != null) ...[
                      const SizedBox(height: 4),
                      Text('順位: 全体 ${item['overall_rank']}位' + (item['heat_rank'] != null ? ' / 組 ${item['heat_rank']}位' : '')),
                    ],
                    if (item['event_type'] == 'track') ...[
                      if (item['lane'] != null) Text('レーン: ${item['lane']}'),
                      if (item['relay_members'] != null && (item['relay_members'] as List).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('リレー走順:', style: TextStyle(fontWeight: FontWeight.bold)),
                        for (int r = 0; r < (item['relay_members'] as List).length; r++)
                          Text('  第${r + 1}走者: ${item['relay_members'][r]}'),
                      ],
                    ] else if (item['event_type'] == 'combined') ...[
                      if (item['relay_members'] != null && (item['relay_members'] as List).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('【各種目詳細と算出点】', style: TextStyle(fontWeight: FontWeight.bold)),
                        for (var subStr in item['relay_members'])
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 4),
                            child: Text('・$subStr', style: const TextStyle(fontSize: 14)),
                          ),
                      ],
                    ] else ...[
                      if (item['is_top8'] != null)
                        Text(item['is_top8'] == true ? '【TOP8有】' : '【TOP8無】', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                      if (item['trials'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          item['event_name'] == '走高跳' || item['event_name'] == '棒高跳' ? '高さごとの試技推移:' : '試技ごとの記録:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (int t = 0; t < (item['trials'] as List).length; t++)
                              Chip(
                                label: Text(
                                  item['event_name'] == '走高跳' || item['event_name'] == '棒高跳'
                                      ? '${item['trials'][t]}'
                                      : '試技${t + 1}: ${((item['trials'][t] as int) / 100).toStringAsFixed(2)}m',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// 7. ベスト記録ページ
// ==========================================
class BestRecordPage extends StatelessWidget {
  const BestRecordPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$athleteName のベスト記録')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase
            .from('competition_results')
            .select()
            .eq('athlete_id', athleteId)
            .order('best_value_integer', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('まだ記録が登録されていません'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final item = data[index];
              final displayDate = formatDateDisplay(item['date']);
              return ListTile(
                leading: const Icon(Icons.star, color: Colors.amber, size: 36),
                title: Text(item['event_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('日付: $displayDate / 大会: ${item['tournament_name']}'),
                trailing: Text(
                  item['formatted_record'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 8. グラフページ (fl_chart 対応完全版)
// ==========================================
class GraphPage extends StatefulWidget {
  const GraphPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  String? selectedEvent;
  List<Map<String, dynamic>> eventResults = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      final response = await supabase
          .from('competition_results')
          .select('event_name')
          .eq('athlete_id', widget.athleteId);

      final data = response as List<dynamic>;
      final events = data.map((e) => e['event_name'].toString()).toSet().toList();

      if (events.isNotEmpty) {
        setState(() {
          selectedEvent = events.first;
        });
        await _fetchResultsForEvent(selectedEvent!);
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchResultsForEvent(String eventName) async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('competition_results')
          .select()
          .eq('athlete_id', widget.athleteId)
          .eq('event_name', eventName)
          .order('date', ascending: true);

      setState(() {
        eventResults = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} の記録グラフ')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : eventResults.isEmpty
              ? const Center(child: Text('表示できる記録データがまだありません。\n記録をたくさん入力してみましょう！', textAlign: TextAlign.center))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder(
                        future: supabase
                            .from('competition_results')
                            .select('event_name')
                            .eq('athlete_id', widget.athleteId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final data = snapshot.data as List<dynamic>;
                          final uniqueEvents = data.map((e) => e['event_name'].toString()).toSet().toList();

                          if (!uniqueEvents.contains(selectedEvent) && uniqueEvents.isNotEmpty) {
                            selectedEvent = uniqueEvents.first;
                          }

                          return DropdownButtonFormField<String>(
                            value: selectedEvent,
                            decoration: const InputDecoration(
                              labelText: 'グラフ化する種目',
                              border: OutlineInputBorder(),
                            ),
                            items: uniqueEvents.map((evt) {
                              return DropdownMenuItem(value: evt, child: Text(evt));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => selectedEvent = val);
                                _fetchResultsForEvent(val);
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Text(
                        '【$selectedEvent】の推移グラフ',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                      const SizedBox(height: 24),

                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    int index = value.toInt();
                                    if (index >= 0 && index < eventResults.length) {
                                      String dateStr = eventResults[index]['date'].toString();
                                      if (dateStr.length >= 10) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text('${dateStr.substring(5, 7)}/${dateStr.substring(8, 10)}',
                                              style: const TextStyle(fontSize: 10)),
                                        );
                                      }
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 45,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(eventResults.length, (index) {
                                  final num val = eventResults[index]['best_value_integer'] ?? 0;
                                  return FlSpot(index.toDouble(), val.toDouble());
                                }),
                                isCurved: true,
                                color: Colors.blue.shade600,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blue.withOpacity(0.15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '※ 縦軸は数値（タイムは秒×100、フィールドはcm、混成・得点はポイント）で表示されます。',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ==========================================
// 9. 練習日記【見る】ページ
// ==========================================
class DiaryListPage extends StatelessWidget {
  const DiaryListPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  Future<void> _deleteDiary(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除の確認'),
        content: const Text('この練習日記を削除してもよろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('いいえ')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('practice_diaries').delete().eq('id', id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('練習日記を削除しました')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$athleteName の練習日記一覧')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase
            .from('practice_diaries')
            .select()
            .eq('athlete_id', athleteId)
            .order('date', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('まだ練習日記が登録されていません'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final ratingVal = (item['rating'] as num?)?.toInt() ?? 3;
              final stars = '★' * ratingVal + '☆' * (5 - ratingVal);
              final displayDate = formatDateDisplay(item['date']);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text(stars, style: const TextStyle(color: Colors.amber, fontSize: 16)),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('【練習内容】', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                              const SizedBox(height: 4),
                              Text(item['content'] ?? '', style: const TextStyle(fontSize: 15)),
                              if (item['reflection'] != null && item['reflection'].toString().isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text('【課題や気づき】', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                                const SizedBox(height: 4),
                                Text(item['reflection'], style: const TextStyle(fontSize: 15)),
                              ],
                            ],
                          ),
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteDiary(context, item['id']),
                            tooltip: 'この日記を削除',
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('閉じる'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            Row(
                              children: [
                                Text(stars, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '【練習内容】\n${item['content']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// 10. 練習日記【書く】ページ
// ==========================================
class DiaryInputPage extends StatefulWidget {
  const DiaryInputPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  State<DiaryInputPage> createState() => _DiaryInputPageState();
}

class _DiaryInputPageState extends State<DiaryInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  final _contentController = TextEditingController();
  final _reflectionController = TextEditingController();
  int rating = 3;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: getTodayDateString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} - 練習日記を書く')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _dateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '日付 (例: YYYYMMDD)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return '日付を入力してください';
                  final parsed = parseDateInput(v);
                  if (parsed.length != 10) return '8桁の数字で入力してください';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '練習内容', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? '練習内容を入力してください' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reflectionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '課題や気づき', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              const Text('自己評価 (★)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setState(() => rating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: isLoading ? null : _saveDiary,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('日記を保存する', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDiary() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final formattedDate = parseDateInput(_dateController.text);

      await supabase.from('practice_diaries').insert({
        'athlete_id': widget.athleteId,
        'date': formattedDate,
        'content': _contentController.text,
        'reflection': _reflectionController.text,
        'rating': rating,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('練習日記を保存しました！')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}