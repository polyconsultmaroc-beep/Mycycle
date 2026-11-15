import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CycleStore.instance.init();
  runApp(const MyCycleApp());
}

const rose = Color(0xFFB85D7B);
const paleRose = Color(0xFFF8E9EE);

class MyCycleApp extends StatelessWidget {
  const MyCycleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MyCycle', debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: rose, surface: const Color(0xFFFFFBFC)), scaffoldBackgroundColor: const Color(0xFFFFF8FA), appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFFF8FA), foregroundColor: Color(0xFF573847)), cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFF1DDE4)))), inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        home: const PinGate(),
      );
}

class PinGate extends StatefulWidget { const PinGate({super.key}); @override State<PinGate> createState() => _PinGateState(); }
class _PinGateState extends State<PinGate> {
  final pin = TextEditingController();
  final secure = const FlutterSecureStorage();
  bool setup = false; bool loading = true; String error = '';
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async { final saved = await secure.read(key: 'pin_hash'); if (!mounted) return; setState(() { setup = saved == null; loading = false; }); }
  String _hash(String value, String salt) => sha256.convert(utf8.encode('$salt:$value')).toString();
  Future<void> _submit() async {
    final value = pin.text;
    if (!RegExp(r'^\d{4,6}$').hasMatch(value)) { setState(() => error = 'Saisissez un code de 4 à 6 chiffres.'); return; }
    if (setup) {
      final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
      final saltText = base64Encode(salt);
      await secure.write(key: 'pin_salt', value: saltText);
      await secure.write(key: 'pin_hash', value: _hash(value, saltText));
    } else {
      final salt = await secure.read(key: 'pin_salt') ?? '';
      final saved = await secure.read(key: 'pin_hash');
      if (saved != _hash(value, salt)) { setState(() => error = 'Code PIN incorrect.'); pin.clear(); return; }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: rose)));
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 76, height: 76, decoration: const BoxDecoration(color: paleRose, shape: BoxShape.circle), child: const Icon(Icons.favorite, color: rose, size: 38)), const SizedBox(height: 18), const Text('MyCycle', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF573847))), const SizedBox(height: 8), Text(setup ? 'Créez votre code PIN personnel' : 'Entrez votre code PIN', style: const TextStyle(color: Colors.black54)), const SizedBox(height: 24), SizedBox(width: 230, child: TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: '••••', counterText: '4 à 6 chiffres'))), if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)), const SizedBox(height: 12), FilledButton(style: FilledButton.styleFrom(backgroundColor: rose, minimumSize: const Size(220, 48)), onPressed: _submit, child: Text(setup ? 'Créer mon code' : 'Déverrouiller'))]))));
  }
}

class CycleStore {
  CycleStore._(); static final instance = CycleStore._(); Database? _db;
  Future<void> init() async { final dbPath = await getDatabasesPath(); _db = await openDatabase(p.join(dbPath, 'mycycle.db'), version: 1, onCreate: (db, version) async { await db.execute('CREATE TABLE periods(id INTEGER PRIMARY KEY AUTOINCREMENT, start_date TEXT NOT NULL, end_date TEXT)'); }); }
  Future<List<Map<String, Object?>>> all() async => (await _db!.query('periods', orderBy: 'start_date DESC'));
  Future<void> add(DateTime start, DateTime? end) async { await _db!.insert('periods', {'start_date': _date(start), 'end_date': end == null ? null : _date(end)}); }
  Future<void> updateEnd(int id, DateTime end) async { await _db!.update('periods', {'end_date': _date(end)}, where: 'id = ?', whereArgs: [id]); }
  static String _date(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}

class HomePage extends StatefulWidget { const HomePage({super.key}); @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  List<Map<String, Object?>> periods = []; bool busy = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final data = await CycleStore.instance.all(); if (mounted) setState(() { periods = data; busy = false; }); }
  DateTime? get lastStart => periods.isEmpty ? null : DateTime.parse(periods.first['start_date'] as String);
  int get averageCycle { if (periods.length < 2) return 28; final dates = periods.map((e) => DateTime.parse(e['start_date'] as String)).toList(); final gaps = <int>[]; for (var i=0; i<dates.length-1 && i<5; i++) { final gap = dates[i].difference(dates[i+1]).inDays; if (gap >= 15 && gap <= 60) gaps.add(gap); } if (gaps.isEmpty) return 28; return (gaps.reduce((a,b)=>a+b)/gaps.length).round(); }
  String get nextLabel { if (lastStart == null) return 'Ajoutez vos dernières règles'; final next = lastStart!.add(Duration(days: averageCycle)); final diff = next.difference(DateTime.now()).inDays; return diff >= 0 ? 'Prochaines règles estimées dans $diff jour${diff == 1 ? '' : 's'}' : 'Date estimée dépassée — enregistrez vos règles si elles ont commencé'; }
  Future<void> _addPeriod() async { final start = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime.now(), helpText: 'Premier jour des règles'); if (start == null || !mounted) return; final end = await showDatePicker(context: context, initialDate: start, firstDate: start, lastDate: DateTime.now(), helpText: 'Dernier jour des règles (facultatif)'); await CycleStore.instance.add(start, end); await _load(); }
  Future<void> _finish(Map<String,Object?> row) async { final start = DateTime.parse(row['start_date'] as String); final end = await showDatePicker(context: context, initialDate: DateTime.now().isBefore(start) ? start : DateTime.now(), firstDate: start, lastDate: DateTime.now(), helpText: 'Dernier jour des règles'); if (end != null) { await CycleStore.instance.updateEnd(row['id'] as int, end); await _load(); } }
  String fmt(String value) { final d = DateTime.parse(value); return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'; }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('MyCycle', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(tooltip: 'Verrouiller', onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PinGate())), icon: const Icon(Icons.lock_outline))]), body: busy ? const Center(child: CircularProgressIndicator(color: rose)) : RefreshIndicator(color: rose, onRefresh: _load, child: ListView(padding: const EdgeInsets.all(18), children: [Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: paleRose, borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Votre cycle', style: TextStyle(color: Color(0xFF765765))), const SizedBox(height: 8), Text(lastStart == null ? 'Bienvenue' : 'Jour ${DateTime.now().difference(lastStart!).inDays + 1}', style: const TextStyle(fontSize: 29, fontWeight: FontWeight.bold, color: Color(0xFF573847))), const SizedBox(height: 8), Text(nextLabel, style: const TextStyle(color: Color(0xFF765765))), const SizedBox(height: 10), Text(periods.length < 3 ? 'Prévision indicative : basée sur une moyenne standard tant que peu de cycles sont enregistrés.' : 'Prévision indicative basée sur vos derniers cycles.', style: const TextStyle(fontSize: 11, color: Color(0xFF765765)))])), const SizedBox(height: 18), FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: rose, minimumSize: const Size.fromHeight(52)), onPressed: _addPeriod, icon: const Icon(Icons.add), label: const Text('Enregistrer mes règles')), const SizedBox(height: 24), const Text('Historique', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF573847))), const SizedBox(height: 8), if (periods.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Aucun cycle enregistré. Appuyez sur le bouton ci-dessus pour commencer.'))) else ...periods.map((row) => Card(child: ListTile(leading: const CircleAvatar(backgroundColor: paleRose, child: Icon(Icons.water_drop, color: rose)), title: Text('Début : ${fmt(row['start_date'] as String)}'), subtitle: Text(row['end_date'] == null ? 'Fin non renseignée' : 'Fin : ${fmt(row['end_date'] as String)}'), trailing: row['end_date'] == null ? IconButton(tooltip: 'Renseigner la fin', icon: const Icon(Icons.edit_calendar, color: rose), onPressed: () => _finish(row)) : const Icon(Icons.check_circle_outline, color: rose)))), const SizedBox(height: 18), const Text('Les prévisions sont approximatives et ne doivent pas être utilisées comme méthode contraceptive ou diagnostic médical.', style: TextStyle(fontSize: 12, color: Colors.black54))])));
}
