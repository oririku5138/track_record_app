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
      title: 'ジュニア陸上記録ノート',
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

bool isValidDateString(String input) {
  final clean = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (clean.length != 8) return false;
  final y = int.tryParse(clean.substring(0, 4)) ?? 0;
  final m = int.tryParse(clean.substring(4, 6)) ?? 0;
  final d = int.tryParse(clean.substring(6, 8)) ?? 0;
  
  final date = DateTime(y, m, d);
  return date.year == y && date.month == m && date.day == d;
}

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

String formatRecordDisplay(String eventName, int rawValue) {
  if (rawValue <= 0) return '記録なし';
  
  if (isCombinedEvent(eventName)) {
    return '$rawValue点';
  }
  
  if (!isTrackOrLowerBetter(eventName) && !isCombinedEvent(eventName)) {
    return '${(rawValue / 100).toStringAsFixed(2)}m';
  }

  if (rawValue < 6000) {
    return '${(rawValue / 100).toStringAsFixed(2)}秒';
  }

  if (rawValue >= 10000) {
    int minutes = rawValue ~/ 10000;
    int remainder = rawValue % 10000;
    int seconds = remainder ~/ 100;
    int millis = remainder % 100;

    if (minutes < 60 && seconds < 60) {
      int totalSecondsInt = (minutes * 60) + seconds;
      return '$minutes:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}($totalSecondsInt秒)';
    }
  }

  int totalSec = rawValue ~/ 100;
  int m = totalSec ~/ 60;
  int s = totalSec % 60;
  int ms = rawValue % 100;
  
  return '$m:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}($totalSec秒)';
}

const List<String> stadiumList = [
  '茅野市運動公園陸上競技場',
  '飯田市松尾総合運動場陸上競技場',
  '長野市営陸上競技場',
  '松本平広域公園陸上競技場',
  '佐久総合運動公園陸上競技場',
  '伊那市陸上競技場',
];

bool hasWindSpeed(String eventName) {
  final windEvents = ['100m', '150m', '200m', '300m', '400m', '80mH', '100mH', '110mH', '走幅跳', '三段跳'];
  return windEvents.contains(eventName);
}

bool isTrackOrLowerBetter(String eventName) {
  const trackEvents = [
    '100m', '150m', '200m', '300m', '400m', '800m', '1000m', '1500m', '3000m', '5000m', '10000m',
    '80mH', '100mH', '110mH', '300mH', '400mH', '3000mSC',
    '4x100mリレー', '4x400mリレー'
  ];
  return trackEvents.contains(eventName);
}

bool isCombinedEvent(String eventName) {
  return eventName.contains('競技');
}

int? getEventDistanceMeters(String eventName) {
  final reg = RegExp(r'(\d+)m');
  final match = reg.firstMatch(eventName);
  if (match != null) {
    return int.tryParse(match.group(1)!);
  }
  if (eventName == '3000mSC') return 3000;
  if (eventName == '4x100mリレー') return 400;
  if (eventName == '4x400mリレー') return 1600;
  return null;
}

// ==========================================
// 1. 【TOP】ページ
// ==========================================
class TopSelectionPage extends StatelessWidget {
  const TopSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LongDistanceConverterPage()),
                );
              },
              icon: const Icon(Icons.calculate),
              label: const Text('長距離換算', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
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
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                const Text('選手を選んでください', style: TextStyle(fontSize: 16, color: Colors.white70)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: アスリート情報の取得に失敗しました ($e)')));
      }
    }
  }
}

class _AthleteButton extends StatelessWidget {
  const _AthleteButton({required this.name, required this.avatarIcon, required this.color, required this.onTap});
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))],
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
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1.5 長距離ペース換算ツールページ
// ==========================================
class LongDistanceConverterPage extends StatefulWidget {
  const LongDistanceConverterPage({super.key});

  @override
  State<LongDistanceConverterPage> createState() => _LongDistanceConverterPageState();
}

class _LongDistanceConverterPageState extends State<LongDistanceConverterPage> {
  final _distanceController = TextEditingController(text: '1000');
  final _timeController = TextEditingController(text: '30000');
  List<Map<String, dynamic>> paceList = [];

  @override
  void initState() {
    super.initState();
    _calculatePace();
  }

  double _parseInputTime(double rawVal, double distance) {
    int m = (rawVal ~/ 10000);
    int sAndMs = (rawVal ~/ 1) % 10000;
    double totalSeconds = (m * 60) + (sAndMs / 100.0);
    return totalSeconds * 100.0;
  }

  void _calculatePace() {
    final double? distance = double.tryParse(_distanceController.text);
    final double? rawTime = double.tryParse(_timeController.text);

    if (distance == null || distance <= 0 || rawTime == null || rawTime <= 0) {
      setState(() => paceList = []);
      return;
    }

    final double correctedRawTime = _parseInputTime(rawTime, distance);

    List<Map<String, dynamic>> results = [];
    int currentMeter = 100;
    while (currentMeter < distance) {
      final double targetRawTime = correctedRawTime * (currentMeter / distance);
      results.add({
        'meter': currentMeter,
        'rawTime': targetRawTime,
      });
      currentMeter += 100;
    }
    results.add({
      'meter': distance.toInt(),
      'rawTime': correctedRawTime,
    });

    setState(() {
      paceList = results;
    });
  }

  String _formatPaceTime(double rawVal) {
    int totalSecRound = (rawVal / 100.0).round();
    int m = totalSecRound ~/ 60;
    int s = totalSecRound % 60;
    if (m > 0) {
      return '$m:${s.toString().padLeft(2, '0')}($totalSecRound秒)';
    } else {
      return '$totalSecRound秒';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('長距離ペース換算ツール')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '距離 (m) (例: 1000)', border: OutlineInputBorder()),
                    onChanged: (_) => _calculatePace(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _timeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'タイム数値 (例: 30000)', border: OutlineInputBorder()),
                    onChanged: (_) => _calculatePace(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '※タイムは分入力の場合 3分00秒00 → 30000 のように入力してください',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            const Text('【100m刻み通過ペース一覧】', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 10),
            Expanded(
              child: paceList.isEmpty
                  ? const Center(child: Text('正しい数値を入力してください'))
                  : ListView.builder(
                      itemCount: paceList.length,
                      itemBuilder: (context, index) {
                        final item = paceList[index];
                        final meter = item['meter'] as int;
                        final rawVal = item['rawTime'] as double;
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text('$meter', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                            ),
                            title: Text('$meter m 通過ペース', style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Text(
                              _formatPaceTime(rawVal),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. ホーム画面
// ==========================================
class AthleteHomePage extends StatelessWidget {
  const AthleteHomePage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$athleteName の記録ルーム'), centerTitle: true),
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
                  Navigator.push(context, MaterialPageRoute(builder: (context) => RecordListPage(athleteName: athleteName, athleteId: athleteId)));
                },
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('見る'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => RecordTypeSelectPage(athleteName: athleteName, athleteId: athleteId)));
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
                    Navigator.push(context, MaterialPageRoute(builder: (context) => BestRecordPage(athleteName: athleteName, athleteId: athleteId)));
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
                    Navigator.push(context, MaterialPageRoute(builder: (context) => GraphPage(athleteName: athleteName, athleteId: athleteId)));
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
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DiaryListPage(athleteName: athleteName, athleteId: athleteId)));
                },
                icon: const Icon(Icons.list, size: 18),
                label: const Text('見る'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DiaryInputPage(athleteName: athleteName, athleteId: athleteId)));
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
                  label: const Text('混成種目', style: TextStyle(fontSize: 17)),
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
// 4. トラック結果入力ページ（ラップタイム距離上限バリデーション追加）
// ==========================================
class LapTimeInput {
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  bool isMinuteMode = false;
}

class TrackRecordInputPage extends StatefulWidget {
  const TrackRecordInputPage({super.key, required this.athleteName, required this.athleteId, this.editItem});
  final String athleteName;
  final String athleteId;
  final Map<String, dynamic>? editItem;

  @override
  State<TrackRecordInputPage> createState() => _TrackRecordInputPageState();
}

class _TrackRecordInputPageState extends State<TrackRecordInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _tournamentController;
  late final TextEditingController _stadiumController;
  late final TextEditingController _weatherController;
  late final TextEditingController _heatIndexController;
  late final TextEditingController _conditionController;
  late final TextEditingController _windController;
  late final TextEditingController _laneController;
  late final TextEditingController _recordController;
  late final TextEditingController _overallRankController;
  late final TextEditingController _heatRankController;

  late List<TextEditingController> _relayControllers;
  final List<LapTimeInput> _lapTimes = [];

  String selectedEvent = '100m';
  bool isCustomStadium = false;
  bool isRelay = false;
  bool isLoading = false;
  bool isMinuteInputMode = false;

  final List<String> trackEvents = [
    '100m', '150m', '200m', '300m', '400m', '800m', '1000m', '1500m', '3000m', '5000m', '10000m',
    '80mH', '100mH', '110mH', '300mH', '400mH', '3000mSC',
    '4x100mリレー', '4x400mリレー'
  ];

  bool get _is300mOrMore {
    const targetEvents = ['300m', '400m', '800m', '1000m', '1500m', '3000m', '5000m', '10000m', '300mH', '400mH', '3000mSC', '4x400mリレー'];
    return targetEvents.contains(selectedEvent);
  }

  bool get _is800mOrMore {
    const targetEvents = ['800m', '1000m', '1500m', '3000m', '5000m', '10000m', '3000mSC', '4x400mリレー'];
    return targetEvents.contains(selectedEvent);
  }

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    _dateController = TextEditingController(text: item != null ? item['date'].toString().replaceAll('-', '') : getTodayDateString());
    _tournamentController = TextEditingController(text: item?['tournament_name'] ?? '');
    _stadiumController = TextEditingController(text: item?['stadium'] ?? stadiumList[0]);
    _weatherController = TextEditingController(text: item?['weather'] ?? '');
    _heatIndexController = TextEditingController(text: item?['heat_index']?.toString() ?? '');
    _conditionController = TextEditingController(text: item?['condition']?.toString() ?? '');
    _windController = TextEditingController(text: item?['wind_speed']?.toString() ?? '');
    _laneController = TextEditingController(text: item?['lane']?.toString() ?? '');
    _recordController = TextEditingController(text: item?['best_value_integer']?.toString() ?? '');
    _overallRankController = TextEditingController(text: item?['overall_rank']?.toString() ?? '');
    _heatRankController = TextEditingController(text: item?['heat_rank']?.toString() ?? '');

    if (item != null && trackEvents.contains(item['event_name'])) {
      selectedEvent = item['event_name'];
    }
    isRelay = selectedEvent.contains('リレー');

    if (_is300mOrMore && item != null) {
      final val = item['best_value_integer'] ?? 0;
      if (val >= 10000) {
        isMinuteInputMode = true;
      }
    }

    if (item != null && item['lap_times'] is List) {
      final List laps = item['lap_times'];
      for (var l in laps) {
        final lap = LapTimeInput();
        lap.distanceController.text = l['distance']?.toString() ?? '';
        lap.timeController.text = l['time']?.toString() ?? '';
        lap.isMinuteMode = l['is_minute_mode'] == true;
        _lapTimes.add(lap);
      }
    }

    List relMembers = (item?['relay_members'] is List) ? item!['relay_members'] : [];
    _relayControllers = List.generate(4, (i) => TextEditingController(text: i < relMembers.length ? relMembers[i] : ''));
    isCustomStadium = !stadiumList.contains(_stadiumController.text);
  }

  @override
  Widget build(BuildContext context) {
    final showWind = hasWindSpeed(selectedEvent);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} - トラック記録${widget.editItem != null ? '編集' : '入力'}')),
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
                  if (!isValidDateString(v)) return '実在する正しい日付（8桁）を入力してください';
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
                  if (val == null || val.isEmpty) return null;
                  final n = int.tryParse(val);
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
                  if (val == null || val.isEmpty) return null;
                  final n = int.tryParse(val);
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _overallRankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '総合順位', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _heatRankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '組順位', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _laneController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'レーン', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _recordController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _is300mOrMore && isMinuteInputMode
                            ? '記録 (例: 3分15秒00 → 31500)'
                            : '記録 (例: 68.00秒 → 6800)',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? '記録を入力してください' : null,
                    ),
                  ),
                  if (_is300mOrMore) ...[
                    const SizedBox(width: 8),
                    ToggleButtons(
                      isSelected: [isMinuteInputMode, !isMinuteInputMode],
                      onPressed: (index) {
                        setState(() {
                          isMinuteInputMode = (index == 0);
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('分', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('秒', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (_is800mOrMore) ...[
                const SizedBox(height: 24),
                Text('【ラップタイム入力 (最大 ${getEventDistanceMeters(selectedEvent) ?? 0}m)】', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 8),
                for (int i = 0; i < _lapTimes.length; i++) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _lapTimes[i].distanceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: '距離 (m)', border: OutlineInputBorder(), isDense: true),
                              validator: (val) {
                                if (val == null || val.isEmpty) return null;
                                final d = int.tryParse(val) ?? 0;
                                final maxD = getEventDistanceMeters(selectedEvent);
                                if (maxD != null && d > maxD) {
                                  return '${maxD}m以下';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _lapTimes[i].timeController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _lapTimes[i].isMinuteMode ? 'タイム (例: 31500)' : 'タイム (例: 7500)',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ToggleButtons(
                            isSelected: [_lapTimes[i].isMinuteMode, !_lapTimes[i].isMinuteMode],
                            onPressed: (idx) {
                              setState(() {
                                _lapTimes[i].isMinuteMode = (idx == 0);
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            constraints: const BoxConstraints(minHeight: 40, minWidth: 32),
                            children: const [
                              Text('分', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('秒', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _lapTimes.removeAt(i);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _lapTimes.add(LapTimeInput());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('ラップタイムを追加'),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: isLoading ? null : _saveRecord,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.editItem != null ? '更新する' : '保存する', style: const TextStyle(fontSize: 16)),
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

    // ラップタイムの距離が種目距離を超えていないか厳密にチェック
    final maxDist = getEventDistanceMeters(selectedEvent);
    if (maxDist != null) {
      for (var lap in _lapTimes) {
        final d = int.tryParse(lap.distanceController.text.trim()) ?? 0;
        if (d > maxDist) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: ラップ距離(${d}m)が種目の総距離(${maxDist}m)を超えています')),
          );
          return;
        }
      }
    }

    setState(() => isLoading = true);

    try {
      final rawRecord = int.parse(_recordController.text);
      String formatted = formatRecordDisplay(selectedEvent, rawRecord);

      final formattedDate = parseDateInput(_dateController.text);
      final showWind = hasWindSpeed(selectedEvent);

      List<Map<String, dynamic>> lapTimesData = _lapTimes.map((l) {
        return {
          'distance': int.tryParse(l.distanceController.text.trim()) ?? 0,
          'time': int.tryParse(l.timeController.text.trim()) ?? 0,
          'is_minute_mode': l.isMinuteMode,
        };
      }).toList();

      final dataMap = {
        'athlete_id': widget.athleteId,
        'date': formattedDate,
        'event_type': 'track',
        'tournament_name': _tournamentController.text,
        'stadium': _stadiumController.text,
        'weather': _weatherController.text,
        'heat_index': _heatIndexController.text.trim().isNotEmpty ? int.tryParse(_heatIndexController.text) : null,
        'condition': _conditionController.text.trim().isNotEmpty ? int.tryParse(_conditionController.text) : null,
        'event_name': selectedEvent,
        'wind_speed': showWind && _windController.text.trim().isNotEmpty ? double.tryParse(_windController.text) : null,
        'lane': _laneController.text.trim().isNotEmpty ? int.tryParse(_laneController.text) : null,
        'overall_rank': _overallRankController.text.trim().isNotEmpty ? int.tryParse(_overallRankController.text) : null,
        'heat_rank': _heatRankController.text.trim().isNotEmpty ? int.tryParse(_heatRankController.text) : null,
        'relay_members': isRelay ? _relayControllers.map((c) => c.text).toList() : null,
        'lap_times': _is800mOrMore ? lapTimesData : null,
        'best_value_integer': rawRecord,
        'formatted_record': formatted,
      };

      if (widget.editItem != null) {
        final targetId = widget.editItem!['id'];
        await supabase.from('competition_results').update(dataMap).eq('id', targetId);
      } else {
        await supabase.from('competition_results').insert(dataMap);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.editItem != null ? 'トラック記録を更新しました！' : 'トラック記録を保存しました！')),
        );
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

class FieldTrialInput {
  final TextEditingController controller = TextEditingController();
  bool isFoul = false;
}

class FieldRecordInputPage extends StatefulWidget {
  const FieldRecordInputPage({super.key, required this.athleteName, required this.athleteId, this.editItem});
  final String athleteName;
  final String athleteId;
  final Map<String, dynamic>? editItem;

  @override
  State<FieldRecordInputPage> createState() => _FieldRecordInputPageState();
}

class _FieldRecordInputPageState extends State<FieldRecordInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _tournamentController;
  late final TextEditingController _stadiumController;
  late final TextEditingController _weatherController;
  late final TextEditingController _heatIndexController;
  late final TextEditingController _conditionController;
  late final TextEditingController _windController;
  late final TextEditingController _overallRankController;
  late final TextEditingController _heatRankController;

  final List<FieldTrialInput> _fieldTrials = List.generate(6, (_) => FieldTrialInput());
  List<JumpAttempt> _jumpAttempts = [JumpAttempt()];

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
    final item = widget.editItem;
    _dateController = TextEditingController(text: item != null ? item['date'].toString().replaceAll('-', '') : getTodayDateString());
    _tournamentController = TextEditingController(text: item?['tournament_name'] ?? '');
    _stadiumController = TextEditingController(text: item?['stadium'] ?? stadiumList[0]);
    _weatherController = TextEditingController(text: item?['weather'] ?? '');
    _heatIndexController = TextEditingController(text: item?['heat_index']?.toString() ?? '');
    _conditionController = TextEditingController(text: item?['condition']?.toString() ?? '');
    _windController = TextEditingController(text: item?['wind_speed']?.toString() ?? '');
    _overallRankController = TextEditingController(text: item?['overall_rank']?.toString() ?? '');
    _heatRankController = TextEditingController(text: item?['heat_rank']?.toString() ?? '');

    if (item != null && fieldEvents.contains(item['event_name'])) {
      selectedEvent = item['event_name'];
    }

    if (!isVerticalJump) {
      isTop8 = item?['is_top8'] == true;
      isNoTop8 = item?['is_top8'] == false;
    }

    if (item != null && item['trials'] is List) {
      final List trials = item['trials'];
      if (isVerticalJump) {
        _jumpAttempts = [];
        for (var t in trials) {
          final attempt = JumpAttempt();
          attempt.heightController.text = t.toString();
          _jumpAttempts.add(attempt);
        }
        if (_jumpAttempts.isEmpty) _jumpAttempts.add(JumpAttempt());
      } else {
        for (int i = 0; i < trials.length && i < 6; i++) {
          final valStr = trials[i].toString();
          if (valStr == 'F') {
            _fieldTrials[i].isFoul = true;
            _fieldTrials[i].controller.text = 'F';
          } else {
            _fieldTrials[i].controller.text = valStr;
          }
        }
      }
    }
    isCustomStadium = !stadiumList.contains(_stadiumController.text);
  }

  bool canAddNextHeight() {
    if (_jumpAttempts.isEmpty) return true;
    return _jumpAttempts.last.results.contains('〇');
  }

  @override
  Widget build(BuildContext context) {
    final showWind = hasWindSpeed(selectedEvent);
    final bool showSixTrials = isTop8;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} - フィールド記録${widget.editItem != null ? '編集' : '入力'}')),
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
                  if (!isValidDateString(v)) return '実在する正しい日付（8桁）を入力してください';
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
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conditionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'コンディション (1〜100)', border: OutlineInputBorder()),
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
                      decoration: const InputDecoration(labelText: '総合順位', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _heatRankController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '組順位', border: OutlineInputBorder()),
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
                                        showCheckmark: false,
                                        label: Text(
                                          _jumpAttempts[i].results[r],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: _jumpAttempts[i].results[r] == '〇' ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                        selected: true,
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
                if (canAddNextHeight())
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
                for (int i = 0; i < (showSixTrials ? 6 : 3); i++) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fieldTrials[i].controller,
                            enabled: !_fieldTrials[i].isFoul,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '第${i + 1}試技の記録 (例: 22.55m → 2255)',
                              border: const OutlineInputBorder(),
                              filled: _fieldTrials[i].isFoul,
                              fillColor: Colors.grey.shade200,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: _fieldTrials[i].isFoul ? Colors.red.shade200 : Colors.grey.shade200,
                          ),
                          icon: Text(
                            '×',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _fieldTrials[i].isFoul ? Colors.red.shade900 : Colors.black87,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _fieldTrials[i].isFoul = !_fieldTrials[i].isFoul;
                              if (_fieldTrials[i].isFoul) {
                                _fieldTrials[i].controller.text = 'F';
                              } else {
                                _fieldTrials[i].controller.text = '';
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
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
                      : Text(widget.editItem != null ? '更新する' : '保存する', style: const TextStyle(fontSize: 16)),
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
      List<dynamic> trialsData = [];

      if (isVerticalJump) {
        for (var att in _jumpAttempts) {
          final hText = att.heightController.text.replaceAll('m', '');
          final dH = double.tryParse(hText) ?? 0;
          if (dH <= 0) continue;
          final cmVal = dH < 10 ? (dH * 100).round() : dH.round();
          
          if (att.results.contains('〇')) {
            if (cmVal > maxVal) maxVal = cmVal;
          }
          trialsData.add(cmVal);
        }
      } else {
        final trialCount = isTop8 ? 6 : 3;
        for (int i = 0; i < trialCount; i++) {
          if (_fieldTrials[i].isFoul) {
            trialsData.add('F');
          } else {
            final textVal = _fieldTrials[i].controller.text.trim();
            if (textVal.isNotEmpty) {
              final val = int.tryParse(textVal) ?? 0;
              trialsData.add(val);
              if (val > maxVal) maxVal = val;
            }
          }
        }
      }

      final formatted = maxVal > 0 ? '${(maxVal / 100).toStringAsFixed(2)}m' : '記録なし';
      final formattedDate = parseDateInput(_dateController.text);
      final showWind = hasWindSpeed(selectedEvent);
      final bool saveTop8Flag = isVerticalJump ? false : !isNoTop8;

      final dataMap = {
        'athlete_id': widget.athleteId,
        'date': formattedDate,
        'event_type': 'field',
        'tournament_name': _tournamentController.text,
        'stadium': _stadiumController.text,
        'weather': _weatherController.text,
        'heat_index': _heatIndexController.text.trim().isNotEmpty ? int.tryParse(_heatIndexController.text) : null,
        'condition': _conditionController.text.trim().isNotEmpty ? int.tryParse(_conditionController.text) : null,
        'event_name': selectedEvent,
        'wind_speed': showWind && _windController.text.trim().isNotEmpty ? double.tryParse(_windController.text) : null,
        'is_top8': saveTop8Flag,
        'overall_rank': _overallRankController.text.trim().isNotEmpty ? int.tryParse(_overallRankController.text) : null,
        'heat_rank': _heatRankController.text.trim().isNotEmpty ? int.tryParse(_heatRankController.text) : null,
        'trials': trialsData,
        'best_value_integer': maxVal > 0 ? maxVal : 0,
        'formatted_record': formatted,
      };

      if (widget.editItem != null) {
        final targetId = widget.editItem!['id'];
        await supabase.from('competition_results').update(dataMap).eq('id', targetId);
      } else {
        await supabase.from('competition_results').insert(dataMap);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.editItem != null ? 'フィールド記録を更新しました！' : 'フィールド記録を保存しました！')),
        );
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
// 5.5 混成競技結果入力ページ
// ==========================================
class SubEventDetailInput {
  final String subEventName;
  final bool isTrack;
  
  final TextEditingController pointController = TextEditingController(text: '0');
  final TextEditingController windController = TextEditingController();
  final TextEditingController rankController = TextEditingController();
  final TextEditingController recordController = TextEditingController();

  List<JumpAttempt> jumpAttempts = [JumpAttempt()];
  final List<FieldTrialInput> fieldTrials = List.generate(3, (_) => FieldTrialInput());

  SubEventDetailInput({required this.subEventName, required this.isTrack});
}

class CombinedRecordInputPage extends StatefulWidget {
  const CombinedRecordInputPage({super.key, required this.athleteName, required this.athleteId, this.editItem});
  final String athleteName;
  final String athleteId;
  final Map<String, dynamic>? editItem;

  @override
  State<CombinedRecordInputPage> createState() => _CombinedRecordInputPageState();
}

class _CombinedRecordInputPageState extends State<CombinedRecordInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _tournamentController;
  late final TextEditingController _stadiumController;
  late final TextEditingController _weatherController;
  late final TextEditingController _heatIndexController;
  late final TextEditingController _conditionController;
  late final TextEditingController _overallRankController;
  late final TextEditingController _reflectionController;

  String selectedCombinedEvent = '四種競技 (男子)';
  bool isCustomStadium = false;
  bool isLoading = false;

  List<SubEventDetailInput> _subEvents = [];

  final List<String> combinedEvents = [
    '四種競技 (男子)',
    '四種競技 (女子)',
    '七種競技 (女子)',
    '十種競技 (男子)',
  ];

  List<String> _getDefaultSubEvents(String combinedName) {
    if (combinedName == '四種競技 (男子)') {
      return ['110mH', '砲丸投', '走高跳', '400m'];
    } else if (combinedName == '四種競技 (女子)') {
      return ['100mH', '走高跳', '砲丸投', '200m'];
    } else if (combinedName == '七種競技 (女子)') {
      return ['100mH', '走高跳', '砲丸投', '200m', '走幅跳', 'やり投', '800m'];
    } else if (combinedName == '十種競技 (男子)') {
      return ['100m', '走幅跳', '砲丸投', '走高跳', '400m', '110mH', '円盤投', '棒高跳', 'やり投', '1500m'];
    }
    return ['110mH', '砲丸投', '走高跳', '400m'];
  }

  bool _isSubEventTrack(String name) {
    const tracks = ['100m', '150m', '200m', '300m', '400m', '800m', '1000m', '1500m', '80mH', '100mH', '110mH', '300mH', '400mH', '3000mSC'];
    return tracks.contains(name);
  }

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    _dateController = TextEditingController(text: item != null ? item['date'].toString().replaceAll('-', '') : getTodayDateString());
    _tournamentController = TextEditingController(text: item?['tournament_name'] ?? '');
    _stadiumController = TextEditingController(text: item?['stadium'] ?? stadiumList[0]);
    _weatherController = TextEditingController(text: item?['weather'] ?? '');
    _heatIndexController = TextEditingController(text: item?['heat_index']?.toString() ?? '');
    _conditionController = TextEditingController(text: item?['condition']?.toString() ?? '');
    _overallRankController = TextEditingController(text: item?['overall_rank']?.toString() ?? '');
    _reflectionController = TextEditingController(text: item?['reflection'] ?? '');

    if (item != null && combinedEvents.contains(item['event_name'])) {
      selectedCombinedEvent = item['event_name'];
    }

    if (item != null && item['trials'] is List && (item['trials'] as List).isNotEmpty) {
      final List trials = item['trials'];
      _subEvents = trials.map((t) {
        final name = t['sub_event'] ?? '100m';
        final isTrk = _isSubEventTrack(name);
        final sub = SubEventDetailInput(subEventName: name, isTrack: isTrk);
        sub.pointController.text = t['point']?.toString() ?? '0';
        sub.windController.text = t['wind_speed']?.toString() ?? '';
        sub.rankController.text = t['rank']?.toString() ?? '';

        if (isTrk) {
          sub.recordController.text = t['raw_value']?.toString() ?? '';
        } else {
          if (name == '走高跳' || name == '棒高跳') {
            sub.jumpAttempts = [];
            final rawTrials = t['raw_trials'] as List? ?? [];
            for (var rt in rawTrials) {
              final att = JumpAttempt();
              att.heightController.text = rt['height']?.toString() ?? '';
              att.results = List<String>.from(rt['results'] ?? ['×']);
              sub.jumpAttempts.add(att);
            }
            if (sub.jumpAttempts.isEmpty) sub.jumpAttempts.add(JumpAttempt());
          } else {
            final rawTrials = t['raw_trials'] as List? ?? [];
            for (int i = 0; i < rawTrials.length && i < 3; i++) {
              final val = rawTrials[i];
              if (val == 'F') {
                sub.fieldTrials[i].isFoul = true;
                sub.fieldTrials[i].controller.text = 'F';
              } else {
                sub.fieldTrials[i].controller.text = val?.toString() ?? '';
              }
            }
          }
        }
        return sub;
      }).toList();
    } else {
      _initSubEventsForSelected();
    }

    isCustomStadium = !stadiumList.contains(_stadiumController.text);
  }

  void _initSubEventsForSelected() {
    final names = _getDefaultSubEvents(selectedCombinedEvent);
    _subEvents = names.map((name) {
      final isTrk = _isSubEventTrack(name);
      return SubEventDetailInput(subEventName: name, isTrack: isTrk);
    }).toList();
  }

  int get totalCalculatedScore {
    int total = 0;
    for (var sub in _subEvents) {
      total += int.tryParse(sub.pointController.text) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} - 混成記録${widget.editItem != null ? '編集' : '入力'}')),
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
                  if (!isValidDateString(v)) return '実在する正しい日付（8桁）を入力してください';
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
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _conditionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'コンディション (1〜100)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCombinedEvent,
                decoration: const InputDecoration(labelText: '混成種目', border: OutlineInputBorder()),
                items: combinedEvents.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedCombinedEvent = val;
                      if (widget.editItem == null) {
                        _initSubEventsForSelected();
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _overallRankController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '総合順位', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('総合成績（各得点の合計SUM）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                    Text('$totalCalculatedScore点', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('【各専門種目の記録・手動得点・種目順位入力】', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 8),
              for (int i = 0; i < _subEvents.length; i++) ...[
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${i + 1}. ${_subEvents[i].subEventName}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            SizedBox(
                              width: 110,
                              child: TextFormField(
                                controller: _subEvents[i].pointController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '手動得点',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) => v!.isEmpty ? '点数を入力' : null,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _subEvents[i].rankController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: '種目順位', border: OutlineInputBorder(), isDense: true),
                              ),
                            ),
                            if (hasWindSpeed(_subEvents[i].subEventName)) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _subEvents[i].windController,
                                  decoration: const InputDecoration(labelText: '風力', border: OutlineInputBorder(), isDense: true),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_subEvents[i].isTrack) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _subEvents[i].recordController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '記録数値 (例: 1566 = 15.66秒)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          if (_subEvents[i].subEventName == '走高跳' || _subEvents[i].subEventName == '棒高跳') ...[
                            const Text('高さごとの試技 (最大3回)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 6),
                            for (int h = 0; h < _subEvents[i].jumpAttempts.length; h++) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _subEvents[i].jumpAttempts[h].heightController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: '第${h + 1}高さ (例: 145)',
                                              border: const OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        if (_subEvents[i].jumpAttempts.length > 1)
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () {
                                              setState(() => _subEvents[i].jumpAttempts.removeAt(h));
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        for (int r = 0; r < _subEvents[i].jumpAttempts[h].results.length; r++)
                                          ChoiceChip(
                                            showCheckmark: false,
                                            label: Text(
                                              _subEvents[i].jumpAttempts[h].results[r],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: _subEvents[i].jumpAttempts[h].results[r] == '〇' ? Colors.green.shade800 : Colors.red.shade800,
                                              ),
                                            ),
                                            selected: true,
                                            selectedColor: _subEvents[i].jumpAttempts[h].results[r] == '〇' ? Colors.green.shade200 : Colors.red.shade200,
                                            onSelected: (_) {
                                              setState(() {
                                                if (_subEvents[i].jumpAttempts[h].results[r] == '×') {
                                                  if (!_subEvents[i].jumpAttempts[h].results.contains('〇')) {
                                                    _subEvents[i].jumpAttempts[h].results[r] = '〇';
                                                  }
                                                } else {
                                                  _subEvents[i].jumpAttempts[h].results[r] = '×';
                                                }
                                              });
                                            },
                                          ),
                                        if (!_subEvents[i].jumpAttempts[h].results.contains('〇') && _subEvents[i].jumpAttempts[h].results.length < 3)
                                          ActionChip(
                                            avatar: const Icon(Icons.add, size: 14),
                                            label: const Text('追加'),
                                            onPressed: () {
                                              setState(() => _subEvents[i].jumpAttempts[h].results.add('×'));
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_subEvents[i].jumpAttempts.isEmpty || _subEvents[i].jumpAttempts.last.results.contains('〇'))
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _subEvents[i].jumpAttempts.add(JumpAttempt()));
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('次の高さを追加'),
                              ),
                          ] else ...[
                            const Text('3試技の記録', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 6),
                            for (int t = 0; t < 3; t++) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _subEvents[i].fieldTrials[t].controller,
                                        enabled: !_subEvents[i].fieldTrials[t].isFoul,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: '第${t + 1}試技 (例: 2255)',
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                          filled: _subEvents[i].fieldTrials[t].isFoul,
                                          fillColor: Colors.grey.shade200,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      style: IconButton.styleFrom(
                                        backgroundColor: _subEvents[i].fieldTrials[t].isFoul ? Colors.red.shade200 : Colors.grey.shade200,
                                      ),
                                      icon: Text(
                                        '×',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _subEvents[i].fieldTrials[t].isFoul ? Colors.red.shade900 : Colors.black87,
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _subEvents[i].fieldTrials[t].isFoul = !_subEvents[i].fieldTrials[t].isFoul;
                                          if (_subEvents[i].fieldTrials[t].isFoul) {
                                            _subEvents[i].fieldTrials[t].controller.text = 'F';
                                          } else {
                                            _subEvents[i].fieldTrials[t].controller.text = '';
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _reflectionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '振り返り・課題・気づき',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: isLoading ? null : _saveCombinedRecord,
                  child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(widget.editItem != null ? '更新する' : '保存する', style: const TextStyle(fontSize: 16)),
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
      int totalScore = totalCalculatedScore;
      List<Map<String, dynamic>> subEventsData = [];

      for (var sub in _subEvents) {
        final int pt = int.tryParse(sub.pointController.text.trim()) ?? 0;
        final String rankStr = sub.rankController.text.trim();
        final int? rank = rankStr.isNotEmpty ? int.tryParse(rankStr) : null;
        final String windVal = sub.windController.text.trim();

        dynamic rawValOrTrials;
        if (sub.isTrack) {
          final String rText = sub.recordController.text.trim();
          rawValOrTrials = rText.isNotEmpty ? int.tryParse(rText) : null;
        } else {
          if (sub.subEventName == '走高跳' || sub.subEventName == '棒高跳') {
            rawValOrTrials = sub.jumpAttempts.map((ja) => {
              'height': ja.heightController.text.trim(),
              'results': ja.results,
            }).toList();
          } else {
            rawValOrTrials = sub.fieldTrials.map((ft) {
              if (ft.isFoul) return 'F';
              final tText = ft.controller.text.trim();
              return tText.isNotEmpty ? int.tryParse(tText) : null;
            }).toList();
          }
        }

        subEventsData.add({
          'sub_event': sub.subEventName,
          'point': pt,
          'rank': rank,
          'wind_speed': windVal.isNotEmpty ? double.tryParse(windVal) : null,
          'raw_value': sub.isTrack ? rawValOrTrials : null,
          'raw_trials': !sub.isTrack ? rawValOrTrials : null,
        });
      }

      final formatted = '$totalScore点';
      final formattedDate = parseDateInput(_dateController.text);

      final dataMap = {
        'athlete_id': widget.athleteId,
        'date': formattedDate,
        'event_type': 'field',
        'tournament_name': _tournamentController.text.trim(),
        'stadium': _stadiumController.text.trim(),
        'weather': _weatherController.text.trim(),
        'heat_index': _heatIndexController.text.trim().isNotEmpty ? int.tryParse(_heatIndexController.text.trim()) : null,
        'condition': _conditionController.text.trim().isNotEmpty ? int.tryParse(_conditionController.text.trim()) : null,
        'event_name': selectedCombinedEvent,
        'overall_rank': _overallRankController.text.trim().isNotEmpty ? int.tryParse(_overallRankController.text.trim()) : null,
        'heat_rank': null,
        'trials': subEventsData,
        'reflection': _reflectionController.text.trim(),
        'best_value_integer': totalScore,
        'formatted_record': formatted,
      };

      if (widget.editItem != null) {
        final targetId = widget.editItem!['id'];
        await supabase.from('competition_results').update(dataMap).eq('id', targetId);
      } else {
        await supabase.from('competition_results').insert(dataMap);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.editItem != null ? '混成記録を更新しました！' : '混成記録を保存しました！')),
        );
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
// 6. 記録一覧ページ
// ==========================================
class RecordListPage extends StatefulWidget {
  const RecordListPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  State<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends State<RecordListPage> {
  void _reload() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} の陸上記録一覧')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase
            .from('competition_results')
            .select()
            .eq('athlete_id', widget.athleteId)
            .order('date', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(child: Text('まだ記録が登録されていません'));
          }

          final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
          for (var item in data) {
            final dateKey = item['date'] ?? '';
            groupedByDate.putIfAbsent(dateKey, () => []).add(item);
          }
          final dateKeys = groupedByDate.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dateKeys.length,
            itemBuilder: (context, index) {
              final dateKey = dateKeys[index];
              final itemsOnDate = groupedByDate[dateKey]!;
              final displayDate = formatDateDisplay(dateKey);

              final Map<String, List<Map<String, dynamic>>> groupedByTournament = {};
              for (var item in itemsOnDate) {
                final tournamentName = item['tournament_name'] ?? 'その他の大会';
                groupedByTournament.putIfAbsent(tournamentName, () => []).add(item);
              }
              final tournamentNames = groupedByTournament.keys.toList();

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800),
                      ),
                      const Divider(thickness: 1.5, height: 16),
                      
                      for (int tIdx = 0; tIdx < tournamentNames.length; tIdx++) ...[
                        const SizedBox(height: 4),
                        Text(
                          '🏆 ${tournamentNames[tIdx]}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final tournamentItems = groupedByTournament[tournamentNames[tIdx]]!;
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TournamentDetailPage(
                                  athleteName: widget.athleteName,
                                  athleteId: widget.athleteId,
                                  tournamentName: tournamentNames[tIdx],
                                  date: displayDate,
                                  items: tournamentItems,
                                ),
                              ),
                            );
                            if (updated == true) {
                              _reload();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < groupedByTournament[tournamentNames[tIdx]]!.length; i++) ...[
                                  Builder(builder: (context) {
                                    final item = groupedByTournament[tournamentNames[tIdx]]![i];
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(item['event_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('競技場: ${item['stadium'] ?? ''}'),
                                      trailing: Text(
                                        formatRecordDisplay(item['event_name'] ?? '', item['best_value_integer'] ?? 0),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                                      ),
                                    );
                                  }),
                                  if (i < groupedByTournament[tournamentNames[tIdx]]!.length - 1)
                                    const Divider(height: 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (tIdx < tournamentNames.length - 1) const SizedBox(height: 12),
                      ],
                    ],
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
class TournamentDetailPage extends StatefulWidget {
  const TournamentDetailPage({
    super.key,
    required this.athleteName,
    required this.athleteId,
    required this.tournamentName,
    required this.date,
    required this.items,
  });

  final String athleteName;
  final String athleteId;
  final String tournamentName;
  final String date;
  final List<Map<String, dynamic>> items;

  @override
  State<TournamentDetailPage> createState() => TournamentDetailPageState();
}

class TournamentDetailPageState extends State<TournamentDetailPage> {
  late List<Map<String, dynamic>> currentItems;

  @override
  void initState() {
    super.initState();
    currentItems = widget.items;
  }

  Future<void> _deleteResult(BuildContext context, dynamic id) async {
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
        
        setState(() {
          currentItems.removeWhere((item) => item['id'] == id);
        });

        if (context.mounted) {
          if (currentItems.isEmpty) {
            Navigator.pop(context, true);
          }
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('記録を削除しました')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
        }
      }
    }
  }

  String _formatLapDisplay(Map<dynamic, dynamic> lap) {
    final dist = lap['distance'] ?? 0;
    final timeVal = lap['time'] ?? 0;
    final isMin = lap['is_minute_mode'] == true;

    if (timeVal <= 0) return '$dist m: -';

    if (isMin) {
      int minutes = timeVal ~/ 10000;
      int remainder = timeVal % 10000;
      int seconds = remainder ~/ 100;
      int millis = remainder % 100;
      int totalSec = (minutes * 60) + seconds;
      return '$dist m: $minutes:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(2, '0')}($totalSec秒)';
    } else {
      return '$dist m: ${(timeVal / 100).toStringAsFixed(2)}秒';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.tournamentName} の詳細'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, true),
          ),
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
                    Text('選手名: ${widget.athleteName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('大会名: ${widget.tournamentName}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('開催日: ${widget.date}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('【エントリー種目と詳細結果】', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var item in currentItems)
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
                              Text(formatRecordDisplay(item['event_name'] ?? '', item['best_value_integer'] ?? 0), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.teal),
                                onPressed: () async {
                                  final eventType = item['event_type'];
                                  final isCombined = isCombinedEvent(item['event_name']);
                                  final updated = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => isCombined
                                          ? CombinedRecordInputPage(athleteName: widget.athleteName, athleteId: widget.athleteId, editItem: item)
                                          : (eventType == 'track'
                                              ? TrackRecordInputPage(athleteName: widget.athleteName, athleteId: widget.athleteId, editItem: item)
                                              : FieldRecordInputPage(athleteName: widget.athleteName, athleteId: widget.athleteId, editItem: item)),
                                    ),
                                  );
                                  if (updated == true || true) {
                                    final res = await supabase.from('competition_results').select().eq('id', item['id']);
                                    if (res.isNotEmpty && mounted) {
                                      setState(() {
                                        final index = currentItems.indexWhere((element) => element['id'] == item['id']);
                                        if (index != -1) {
                                          currentItems[index] = res.first;
                                        }
                                      });
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteResult(context, item['id']),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Text('競技場: ${item['stadium'] ?? ''}'),
                      if (item['heat_index'] != null) Text('暑さ指数: ${item['heat_index']}'),
                      if (item['condition'] != null) Text('コンディション: ${item['condition']}'),
                      if (hasWindSpeed(item['event_name']) && item['wind_speed'] != null)
                        Text('風力: ${item['wind_speed']}'),
                      if (item['overall_rank'] != null || item['heat_rank'] != null) ...[
                        const SizedBox(height: 4),
                        Text('順位: ' + (item['overall_rank'] != null ? '総合 ${item['overall_rank']}位 ' : '') + (item['heat_rank'] != null ? '組 ${item['heat_rank']}位' : '')),
                      ],
                      const SizedBox(height: 8),
                      if (item['lap_times'] != null && (item['lap_times'] as List).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('【ラップタイム】', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        for (var lap in (item['lap_times'] as List))
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 2),
                            child: Text('・ ${_formatLapDisplay(lap)}', style: const TextStyle(fontSize: 14)),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 7. ベスト記録ページ
// ==========================================
class BestRecordPage extends StatefulWidget {
  const BestRecordPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  @override
  State<BestRecordPage> createState() => _BestRecordPageState();
}

class _BestRecordPageState extends State<BestRecordPage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} のベスト記録')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('First Best')),
              ButtonSegment<int>(value: 1, label: Text('Second Best')),
            ],
            selected: {selectedIndex},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                selectedIndex = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: supabase.from('competition_results').select().eq('athlete_id', widget.athleteId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return const Center(child: Text('まだ記録が登録されていません'));
                }

                final Map<String, List<Map<String, dynamic>>> grouped = {};
                for (var item in data) {
                  final eventName = item['event_name'] ?? '不明な種目';
                  final int itemVal = item['best_value_integer'] ?? 0;
                  if (itemVal <= 0) continue;
                  grouped.putIfAbsent(eventName, () => []).add(item);
                }

                final List<Map<String, dynamic>> displayList = [];

                grouped.forEach((eventName, items) {
                  items.sort((a, b) {
                    final int valA = a['best_value_integer'] ?? 0;
                    final int valB = b['best_value_integer'] ?? 0;
                    if (isTrackOrLowerBetter(eventName)) {
                      return valA.compareTo(valB);
                    } else {
                      return valB.compareTo(valA);
                    }
                  });

                  if (selectedIndex == 0 && items.isNotEmpty) {
                    displayList.add(items[0]);
                  } else if (selectedIndex == 1 && items.length >= 2) {
                    displayList.add(items[1]);
                  }
                });

                if (displayList.isEmpty) {
                  return Center(
                    child: Text(
                      selectedIndex == 0 ? '記録がありません' : 'Second Best（2番目の記録）はまだありません',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayList.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = displayList[index];
                    return ListTile(
                      leading: Icon(
                        Icons.star,
                        color: selectedIndex == 0 ? Colors.amber : Colors.grey.shade600,
                        size: 36,
                      ),
                      title: Text(item['event_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text('日付: ${formatDateDisplay(item['date'])} / 大会: ${item['tournament_name']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatRecordDisplay(item['event_name'] ?? '', item['best_value_integer'] ?? 0), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ],
                      ),
                      onTap: () async {
                        final res = await supabase.from('competition_results').select().eq('athlete_id', widget.athleteId).eq('date', item['date']).eq('tournament_name', item['tournament_name']);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TournamentDetailPage(
                                athleteName: widget.athleteName,
                                athleteId: widget.athleteId,
                                tournamentName: item['tournament_name'],
                                date: formatDateDisplay(item['date']),
                                items: List<Map<String, dynamic>>.from(res),
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 8. グラフページ
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
      final response = await supabase.from('competition_results').select('event_name').eq('athlete_id', widget.athleteId);
      final data = response as List<dynamic>;
      final events = data.map((e) => e['event_name'].toString()).toSet().toList();

      if (events.isNotEmpty) {
        setState(() => selectedEvent = events.first);
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

      final rawList = List<Map<String, dynamic>>.from(response);
      final Map<String, Map<String, dynamic>> dailyBestMap = {};
      final bool isLower = isTrackOrLowerBetter(eventName);

      for (var item in rawList) {
        final date = item['date']?.toString();
        final int val = item['best_value_integer'] ?? 0;
        if (date == null || val <= 0) continue;

        if (!dailyBestMap.containsKey(date)) {
          dailyBestMap[date] = item;
        } else {
          final int currentVal = dailyBestMap[date]!['best_value_integer'] ?? 0;
          if (isLower ? val < currentVal : val > currentVal) {
            dailyBestMap[date] = item;
          }
        }
      }

      final sortedList = dailyBestMap.values.toList();
      sortedList.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

      setState(() {
        eventResults = sortedList;
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
              ? const Center(child: Text('表示できる記録データがまだありません'))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder(
                        future: supabase.from('competition_results').select('event_name').eq('athlete_id', widget.athleteId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final data = snapshot.data as List<dynamic>;
                          final uniqueEvents = data.map((e) => e['event_name'].toString()).toSet().toList();

                          if (!uniqueEvents.contains(selectedEvent) && uniqueEvents.isNotEmpty) {
                            selectedEvent = uniqueEvents.first;
                          }

                          return DropdownButtonFormField<String>(
                            value: selectedEvent,
                            decoration: const InputDecoration(labelText: 'グラフ化する種目', border: OutlineInputBorder()),
                            items: uniqueEvents.map((evt) => DropdownMenuItem(value: evt, child: Text(evt))).toList(),
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
                      Text('【$selectedEvent】の推移グラフ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      const SizedBox(height: 24),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final val = spot.y.toInt();
                                    final displayStr = formatRecordDisplay(selectedEvent ?? '', val);
                                    return LineTooltipItem(
                                      displayStr,
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    int index = value.toInt();
                                    if (index >= 0 && index < eventResults.length) {
                                      String dateStr = eventResults[index]['date'].toString();
                                      if (dateStr.length >= 10) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text('${dateStr.substring(5, 7)}/${dateStr.substring(8, 10)}', style: const TextStyle(fontSize: 10)),
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
                                  reservedSize: 65,
                                  getTitlesWidget: (value, meta) {
                                    int valInt = value.toInt();
                                    return Text(
                                      formatRecordDisplay(selectedEvent ?? '', valInt),
                                      style: const TextStyle(fontSize: 9),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300, width: 1)),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(eventResults.length, (index) {
                                  final num val = eventResults[index]['best_value_integer'] ?? 0;
                                  return FlSpot(index.toDouble(), val.toDouble());
                                }),
                                isCurved: false,
                                color: Colors.blue.shade600,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.15)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ==========================================
// 9. 練習日記ページ
// ==========================================
class DiaryListPage extends StatelessWidget {
  const DiaryListPage({super.key, required this.athleteName, required this.athleteId});
  final String athleteName;
  final String athleteId;

  Future<void> _deleteDiary(BuildContext context, String id) async {
    await supabase.from('practice_diaries').delete().eq('id', id);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('練習日記を削除しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$athleteName の練習日記一覧')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase.from('practice_diaries').select().eq('athlete_id', athleteId).order('date', ascending: false),
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
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(stars, style: const TextStyle(color: Colors.amber)),
                    ],
                  ),
                  subtitle: Text(item['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(displayDate),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('【練習内容】', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(item['content'] ?? ''),
                            const SizedBox(height: 12),
                            const Text('【課題や気づき】', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(item['reflection'] ?? ''),
                          ],
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.teal),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DiaryInputPage(athleteName: athleteName, athleteId: athleteId, editItem: item),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteDiary(context, item['id']),
                          ),
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DiaryInputPage extends StatefulWidget {
  const DiaryInputPage({super.key, required this.athleteName, required this.athleteId, this.editItem});
  final String athleteName;
  final String athleteId;
  final Map<String, dynamic>? editItem;

  @override
  State<DiaryInputPage> createState() => _DiaryInputPageState();
}

class _DiaryInputPageState extends State<DiaryInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _contentController;
  late final TextEditingController _reflectionController;
  int rating = 3;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    _dateController = TextEditingController(text: item != null ? item['date'].toString().replaceAll('-', '') : getTodayDateString());
    _contentController = TextEditingController(text: item?['content'] ?? '');
    _reflectionController = TextEditingController(text: item?['reflection'] ?? '');
    rating = (item?['rating'] as num?)?.toInt() ?? 3;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.athleteName} - 練習日記${widget.editItem != null ? '編集' : 'を書く'}')),
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
                  if (!isValidDateString(v)) return '実在する正しい日付（8桁）を入力してください';
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
                    icon: Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
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
                  child: Text(widget.editItem != null ? '日記を更新する' : '日記を保存する', style: const TextStyle(fontSize: 16)),
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
      final dataMap = {
        'athlete_id': widget.athleteId,
        'date': formattedDate,
        'content': _contentController.text,
        'reflection': _reflectionController.text,
        'rating': rating,
      };

      if (widget.editItem != null) {
        await supabase.from('practice_diaries').update(dataMap).eq('id', widget.editItem!['id']);
      } else {
        await supabase.from('practice_diaries').insert(dataMap);
      }

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