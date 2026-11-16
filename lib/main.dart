import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CycleStore.instance.init();
  runApp(const MyCycleApp());
}

const rose = Color(0xFFB85D7B);
const roseDark = Color(0xFF573847);
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
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const CycleHomePage()));
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: rose)));
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.asset('assets/mycycle_icon.png', width: 84, height: 84)), const SizedBox(height: 18), const Text('MyCycle', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF573847))), const SizedBox(height: 8), Text(setup ? 'Créez votre code PIN personnel' : 'Entrez votre code PIN', style: const TextStyle(color: Colors.black54)), const SizedBox(height: 24), SizedBox(width: 230, child: TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: '••••', counterText: '4 à 6 chiffres'))), if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)), const SizedBox(height: 12), FilledButton(style: FilledButton.styleFrom(backgroundColor: rose, minimumSize: const Size(220, 48)), onPressed: _submit, child: Text(setup ? 'Créer mon code' : 'Déverrouiller'))])))));
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


class CycleHomePage extends StatefulWidget {
  const CycleHomePage({super.key});
  @override
  State<CycleHomePage> createState() => _CycleHomePageState();
}

class _CycleHomePageState extends State<CycleHomePage> {
  List<Map<String, Object?>> _periods = [];
  SharedPreferences? _prefs;
  bool _busy = true;
  bool _reminderOn = true;
  bool _consent = false;
  int _cycleLength = 28;
  int _bleedLength = 5;
  int _leadDays = 2;
  int _tab = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateUtils.dateOnly(DateTime.now());
  final _phone = TextEditingController();

  static const _months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
  static const _weekdays = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim'];

  DateTime get _today => DateUtils.dateOnly(DateTime.now());
  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  String _iso(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  DateTime _date(Map<String,Object?> row, String key) => DateTime.parse(row[key] as String);
  String _label(DateTime d, {bool year = false}) => '${d.day} ${_months[d.month-1]}${year ? ' ${d.year}' : ''}';
  DateTime? get _lastStart => _periods.isEmpty ? null : _date(_periods.first,'start_date');

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = await CycleStore.instance.all();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _periods = rows;
      _cycleLength = prefs.getInt('cycle_length') ?? 28;
      _bleedLength = prefs.getInt('period_length') ?? 5;
      _reminderOn = prefs.getBool('whatsapp_enabled') ?? true;
      _consent = prefs.getBool('whatsapp_consent') ?? false;
      _leadDays = prefs.getInt('whatsapp_lead_days') ?? 2;
      _phone.text = prefs.getString('whatsapp_phone') ?? '';
      _busy = false;
    });
  }

  Future<void> _reload() async {
    final rows = await CycleStore.instance.all();
    if (mounted) setState(() => _periods = rows);
  }

  int get _average {
    if (_periods.length < 2) return _cycleLength;
    final dates = _periods.map((r) => _date(r,'start_date')).toList();
    final gaps = <int>[];
    for (var i=0; i<dates.length-1 && i<5; i++) {
      final gap = dates[i].difference(dates[i+1]).inDays;
      if (gap >= 15 && gap <= 60) gaps.add(gap);
    }
    if (gaps.isEmpty) return _cycleLength;
    return (gaps.reduce((a,b)=>a+b)/gaps.length).round().clamp(15,60).toInt();
  }

  DateTime? get _nextStart {
    if (_lastStart == null) return null;
    var next = _lastStart!.add(Duration(days:_average));
    while (!next.isAfter(_today)) { next = next.add(Duration(days:_average)); }
    return next;
  }

  DateTime? get _cycleStart => _nextStart?.subtract(Duration(days:_average));
  DateTime? get _ovulation => _nextStart?.subtract(const Duration(days:14));
  int get _cycleDay => _cycleStart == null ? 1 : _today.difference(_cycleStart!).inDays+1;

  CyclePhase _phase(DateTime input) {
    final date = _day(input);
    for (final row in _periods) {
      final start = _date(row,'start_date');
      final end = row['end_date'] == null ? start.add(Duration(days:_bleedLength-1)) : _date(row,'end_date');
      if (!date.isBefore(start) && !date.isAfter(end)) return CyclePhase.period;
    }
    final anchor = _cycleStart ?? _lastStart;
    if (anchor == null) return CyclePhase.follicular;
    final day = ((date.difference(anchor).inDays % _average)+_average)%_average;
    final ovDay = _average-14;
    if (day < _bleedLength) return CyclePhase.period;
    if (day == ovDay) return CyclePhase.ovulation;
    if (day >= ovDay-5 && day <= ovDay+1) return CyclePhase.fertile;
    if (day < ovDay-5) return CyclePhase.follicular;
    return CyclePhase.luteal;
  }

  Color _phaseColor(CyclePhase p) => switch(p) {
    CyclePhase.period => const Color(0xFFF4CDD7),
    CyclePhase.follicular => const Color(0xFFE0EEE6),
    CyclePhase.fertile => const Color(0xFFDDECEF),
    CyclePhase.ovulation => const Color(0xFFDCC9EF),
    CyclePhase.luteal => const Color(0xFFF2E5D5),
  };
  Color _phaseInk(CyclePhase p) => switch(p) {
    CyclePhase.period => const Color(0xFF87495B),
    CyclePhase.follicular => const Color(0xFF527564),
    CyclePhase.fertile => const Color(0xFF4F7880),
    CyclePhase.ovulation => const Color(0xFF694A89),
    CyclePhase.luteal => const Color(0xFF796346),
  };
  String _phaseName(CyclePhase p) => switch(p) {
    CyclePhase.period => 'Menstruations',
    CyclePhase.follicular => 'Phase folliculaire',
    CyclePhase.fertile => 'Fenêtre fertile estimée',
    CyclePhase.ovulation => 'Ovulation estimée',
    CyclePhase.luteal => 'Phase lutéale',
  };
  String _phaseHelp(CyclePhase p) => switch(p) {
    CyclePhase.period => 'Les règles correspondent à l’élimination de la muqueuse utérine.',
    CyclePhase.follicular => 'Après les règles, le corps prépare un follicule et un ovule.',
    CyclePhase.fertile => 'La fenêtre fertile est estimée; les dates réelles peuvent varier.',
    CyclePhase.ovulation => 'Jour d’ovulation calculé, sans confirmation biologique.',
    CyclePhase.luteal => 'Période après l’ovulation estimée, jusqu’aux prochaines règles.',
  };

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _phone.dispose(); super.dispose(); }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text),behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    if (_busy) return const Scaffold(body: Center(child:CircularProgressIndicator(color:rose)));
    final pages = [_home(),_calendar(),_history(),_reminders(),_settings()];
    return Scaffold(
      appBar: AppBar(
        title: Row(children:[
          ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.asset('assets/mycycle_icon.png',width:32,height:32)),
          const SizedBox(width:10), const Text('MyCycle',style:TextStyle(fontWeight:FontWeight.bold))
        ]),
        actions:[IconButton(tooltip:'Verrouiller',onPressed:()=>Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(_)=>const PinGate())),icon:const Icon(Icons.lock_outline))],
      ),
      body:SafeArea(child:IndexedStack(index:_tab,children:pages)),
      bottomNavigationBar:NavigationBar(
        selectedIndex:_tab,
        onDestinationSelected:(i)=>setState(()=>_tab=i),
        destinations:const[
          NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Accueil'),
          NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Calendrier'),
          NavigationDestination(icon:Icon(Icons.history),label:'Historique'),
          NavigationDestination(icon:Icon(Icons.chat_bubble_outline),selectedIcon:Icon(Icons.chat_bubble),label:'WhatsApp'),
          NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'Réglages'),
        ],
      ),
    );
  }

  Widget _disclaimer() => Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:const Color(0xFFFFF4E7),borderRadius:BorderRadius.circular(15)),
    child:const Text('Les dates de fertilité et d’ovulation sont des estimations, peuvent varier d’un cycle à l’autre et ne doivent pas être utilisées comme contraception ni comme diagnostic médical.',style:TextStyle(fontSize:12,color:Color(0xFF725A3D))),
  );

  Widget _home() {
    final next=_nextStart; final ov=_ovulation;
    return ListView(padding:const EdgeInsets.fromLTRB(18,10,18,24),children:[
      Container(
        padding:const EdgeInsets.all(22),
        decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFFFF4F6),Color(0xFFF5E0E6)]),borderRadius:BorderRadius.circular(24)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('VOTRE CYCLE, EN DOUCEUR',style:TextStyle(color:rose,fontSize:11,fontWeight:FontWeight.bold,letterSpacing:1.2)),
          const SizedBox(height:9),
          Text(_lastStart==null?'À l’écoute de votre rythme':'Jour $_cycleDay du cycle',style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold,color:Color(0xFF573847))),
          const SizedBox(height:8),
          Text(next==null?'Enregistrez le premier jour de vos règles pour commencer.':'Prochaines règles estimées autour du ${_label(next)}.',style:const TextStyle(color:Color(0xFF765765))),
          if(next!=null) Padding(padding:const EdgeInsets.only(top:8),child:Text('Durée moyenne du cycle : $_average jours',style:const TextStyle(color:Color(0xFF765765),fontWeight:FontWeight.w600))),
        ]),
      ),
      const SizedBox(height:14),
      Row(children:[
        Expanded(child:_metric('Prochaines règles',next==null?'À calculer':_label(next),Icons.water_drop_outlined,paleRose)),
        const SizedBox(width:10),
        Expanded(child:_metric('Ovulation estimée',ov==null?'À calculer':_label(ov),Icons.auto_awesome_outlined,const Color(0xFFECE3F5))),
      ]),
      const SizedBox(height:14),
      _legend(),
      const SizedBox(height:12),
      _disclaimer(),
      const SizedBox(height:14),
      FilledButton.icon(onPressed:_addPeriod,icon:const Icon(Icons.add),label:const Text('Enregistrer mes règles'),style:FilledButton.styleFrom(backgroundColor:rose,minimumSize:const Size.fromHeight(50))),
    ]);
  }

  Widget _metric(String title,String value,IconData icon,Color tint)=>Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    CircleAvatar(backgroundColor:tint,foregroundColor:roseDark,child:Icon(icon)),
    const SizedBox(height:10),Text(title,style:const TextStyle(fontSize:12,color:Colors.black54)),const SizedBox(height:4),Text(value,style:const TextStyle(fontWeight:FontWeight.bold,color:roseDark)),
  ])));

  Widget _legend()=>Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Les phases du cycle',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold,color:roseDark)),
    const SizedBox(height:10),
    ...CyclePhase.values.map((p)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[
      Container(width:12,height:12,decoration:BoxDecoration(color:_phaseColor(p),borderRadius:BorderRadius.circular(4))),
      const SizedBox(width:10),Expanded(child:Text(_phaseName(p),style:const TextStyle(fontSize:13))),
      if(p==CyclePhase.ovulation)const Text('estimée',style:TextStyle(color:Colors.black45,fontSize:11)),
    ]))),
  ])));

  Widget _calendar()=>ListView(padding:const EdgeInsets.fromLTRB(14,8,14,22),children:[
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
      Row(children:[
        IconButton(onPressed:()=>setState(()=>_month=DateTime(_month.year,_month.month-1)),icon:const Icon(Icons.chevron_left)),
        Expanded(child:Text('${_months[_month.month-1]} ${_month.year}',textAlign:TextAlign.center,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold,color:roseDark))),
        IconButton(onPressed:()=>setState(()=>_month=DateTime(_month.year,_month.month+1)),icon:const Icon(Icons.chevron_right)),
      ]),
      Row(children:_weekdays.map((w)=>Expanded(child:Center(child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(w,style:const TextStyle(fontSize:11,color:Colors.black45)))))).toList()),
      Builder(builder:(context){
        final first=DateTime(_month.year,_month.month,1); final offset=first.weekday-1; final count=DateUtils.getDaysInMonth(_month.year,_month.month); final rows=((offset+count)/7).ceil();
        return GridView.builder(
          shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:rows*7,
          gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,crossAxisSpacing:4,mainAxisSpacing:5),
          itemBuilder:(context,i){
            final date=DateTime(_month.year,_month.month,i-offset+1); final inMonth=date.month==_month.month; final phase=_phase(date); final selected=DateUtils.isSameDay(date,_selected); final today=DateUtils.isSameDay(date,_today);
            return InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>setState(() {_selected=date;_month=DateTime(date.year,date.month);}),child:Container(
              decoration:BoxDecoration(color:inMonth?_phaseColor(phase):Colors.transparent,borderRadius:BorderRadius.circular(12),border:Border.all(color:selected?rose:today?const Color(0xFFDA9CAA):Colors.transparent,width:selected?2:1)),
              alignment:Alignment.center,child:Text('${date.day}',style:TextStyle(color:inMonth?_phaseInk(phase):Colors.black26,fontWeight:selected||phase==CyclePhase.ovulation?FontWeight.bold:FontWeight.normal)),
            ));
          },
        );
      }),
    ]))),
    const SizedBox(height:10),
    Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:4,height:58,decoration:BoxDecoration(color:_phaseInk(_phase(_selected)),borderRadius:BorderRadius.circular(4))),
      const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${_label(_selected,year:true)} · ${_phaseName(_phase(_selected))}',style:const TextStyle(fontWeight:FontWeight.bold,color:roseDark)),
        const SizedBox(height:5),Text(_phaseHelp(_phase(_selected)),style:const TextStyle(fontSize:13,color:Colors.black54)),
      ])),
    ]))),
    const SizedBox(height:10),_legend(),const SizedBox(height:10),_disclaimer(),
  ]);

  Widget _history()=>RefreshIndicator(color:rose,onRefresh:_reload,child:ListView(padding:const EdgeInsets.fromLTRB(14,8,14,22),children:[
    Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Historique des règles',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:roseDark)),
      const SizedBox(height:5),const Text('Modifiez les dates de début et de fin selon vos besoins.',style:TextStyle(fontSize:13,color:Colors.black54)),
      const SizedBox(height:12),FilledButton.icon(onPressed:_addPeriod,icon:const Icon(Icons.add),label:const Text('Ajouter une période'),style:FilledButton.styleFrom(backgroundColor:rose)),
    ]))),
    if(_periods.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Aucune période enregistrée pour le moment.')))
    else ..._periods.map((row){
      final start=_date(row,'start_date'); final end=row['end_date']==null?null:_date(row,'end_date');
      return Card(child:ListTile(
        leading:const CircleAvatar(backgroundColor:paleRose,child:Icon(Icons.water_drop,color:rose)),
        title:Text('Début : ${_label(start,year:true)}'),
        subtitle:Text(end==null?'Fin non renseignée':'Fin : ${_label(end,year:true)}'),
        trailing:IconButton(tooltip:'Modifier les dates',icon:const Icon(Icons.edit_calendar,color:rose),onPressed:()=>_editPeriod(row)),
      ));
    }),
    const SizedBox(height:10),_disclaimer(),
  ]));

  Future<PeriodDates?> _editDialog({DateTime? startValue,DateTime? endValue}) async {
    var start=_day(startValue??_today); DateTime? end=endValue==null?null:_day(endValue); String? error;
    return showDialog<PeriodDates>(context:context,builder:(dialog)=>StatefulBuilder(builder:(context,setDialog)=>AlertDialog(
      title:Text(startValue==null?'Ajouter une période':'Modifier la période'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        ListTile(title:const Text('Premier jour'),subtitle:Text(_label(start,year:true)),trailing:const Icon(Icons.calendar_month,color:rose),onTap:()async{
          final value=await showDatePicker(context:dialog,initialDate:start,firstDate:DateTime(2015),lastDate:_today,helpText:'Premier jour des règles');
          if(value!=null)setDialog(() { start=_day(value); if(end!=null&&end!.isBefore(start)) end=start; });
        }),
        ListTile(title:const Text('Dernier jour'),subtitle:Text(end==null?'Non renseigné':_label(end!,year:true)),trailing:const Icon(Icons.calendar_month,color:rose),onTap:()async{
          final value=await showDatePicker(context:dialog,initialDate:end??start,firstDate:start,lastDate:_today,helpText:'Dernier jour des règles');
          if(value!=null)setDialog(()=>end=_day(value));
        }),
        Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>setDialog(()=>end=null),child:const Text('Effacer la fin'))),
        if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Annuler')),
        FilledButton(onPressed:(){
          if(end!=null&&end!.isBefore(start)){setDialog(()=>error='La fin doit suivre le début.');return;}
          Navigator.pop(dialog,PeriodDates(start,end));
        },child:const Text('Enregistrer')),
      ],
    )));
  }

  Future<void> _addPeriod() async {
    final value=await _editDialog(); if(value==null||!mounted)return;
    if(_periods.any((r)=>_iso(_date(r,'start_date'))==_iso(value.start))){_toast('Une période existe déjà à cette date.');return;}
    await CycleStore.instance.add(value.start,value.end); await _reload(); if(mounted)_toast('Période ajoutée.');
  }

  Future<void> _editPeriod(Map<String,Object?> row) async {
    final value=await _editDialog(startValue:_date(row,'start_date'),endValue:row['end_date']==null?null:_date(row,'end_date'));
    if(value==null||!mounted)return; final id=row['id'] as int;
    if(_periods.any((r)=>r['id']!=id&&_iso(_date(r,'start_date'))==_iso(value.start))){_toast('Une autre période commence à cette date.');return;}
    await CycleStore.instance._db!.update('periods',{'start_date':_iso(value.start),'end_date':value.end==null?null:_iso(value.end!)},where:'id = ?',whereArgs:[id]);
    await _reload(); if(mounted)_toast('Dates mises à jour.');
  }

  String get _messageText {
    final next=_nextStart;
    final day=next?.subtract(Duration(days:_leadDays));
    final date=day==null?'bientôt':'${_label(day)}';
    return 'Bonjour 🌷 Petit rappel tout doux : vos prochaines règles sont estimées autour du $date. Cette prévision est indicative. Prenez soin de vous ✨';
  }

  Future<void> _openWhatsApp() async {
    if(!_reminderOn){_toast('Activez d’abord la préférence de rappel.');return;}
    if(!_consent){_toast('Votre consentement est nécessaire avant d’ouvrir WhatsApp.');return;}
    final phone=_phone.text.replaceAll(RegExp(r'\D'),'');
    if(phone.length<8){_toast('Saisissez un numéro valide avec son indicatif.');return;}
    final uri=Uri.https('wa.me','/$phone',{'text':_messageText});
    final opened=await launchUrl(uri,mode:LaunchMode.externalApplication);
    if(!mounted)return; if(!opened)_toast('WhatsApp n’a pas pu être ouvert.');
  }

  Widget _reminders()=>ListView(padding:const EdgeInsets.fromLTRB(14,8,14,22),children:[
    Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Rappel WhatsApp',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:roseDark)),
      const SizedBox(height:5),const Text('Préparez un message que vous pourrez relire dans WhatsApp.',style:TextStyle(color:Colors.black54,fontSize:13)),
      SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,activeColor:rose,title:const Text('Préférence de rappel activée'),subtitle:const Text('Activée par défaut. Aucun envoi automatique n’est programmé.'),value:_reminderOn,onChanged:(v)async{setState(()=>_reminderOn=v);await _prefs?.setBool('whatsapp_enabled',v);}),
      TextField(controller:_phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Numéro WhatsApp avec indicatif',hintText:'+212 6 00 00 00 00',prefixIcon:Icon(Icons.phone_outlined)),onChanged:(v)=>_prefs?.setString('whatsapp_phone',v)),
      const SizedBox(height:12),
      DropdownButtonFormField<int>(value:_leadDays,decoration:const InputDecoration(labelText:'Moment du rappel'),items:const[
        DropdownMenuItem(value:2,child:Text('2 jours avant la date estimée')),
        DropdownMenuItem(value:1,child:Text('1 jour avant la date estimée')),
        DropdownMenuItem(value:0,child:Text('Le jour estimé')),
      ],onChanged:(v)async{if(v!=null){setState(()=>_leadDays=v);await _prefs?.setInt('whatsapp_lead_days',v);}}),
      const SizedBox(height:8),
      CheckboxListTile(value:_consent,contentPadding:EdgeInsets.zero,controlAffinity:ListTileControlAffinity.leading,activeColor:rose,title:const Text('Je consens à ouvrir WhatsApp avec ce numéro et ce texte prérempli.',style:TextStyle(fontSize:13)),subtitle:const Text('Vous relisez le message et confirmez vous-même tout envoi.',style:TextStyle(fontSize:12)),onChanged:(v)async{setState(()=>_consent=v??false);await _prefs?.setBool('whatsapp_consent',_consent);}),
      FilledButton.icon(onPressed:_openWhatsApp,icon:const Icon(Icons.open_in_new),label:const Text('Préparer le message dans WhatsApp'),style:FilledButton.styleFrom(backgroundColor:rose,minimumSize:const Size.fromHeight(49))),
    ]))),
    Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Aperçu du message',style:TextStyle(fontWeight:FontWeight.bold,color:roseDark)),const SizedBox(height:10),
      Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFFF2F0EB),borderRadius:BorderRadius.circular(14)),child:Text(_messageText)),
      const SizedBox(height:8),const Text('Prototype uniquement : MyCycle n’envoie aucun message. WhatsApp s’ouvre avec le texte prérempli; vous choisissez ensuite de le modifier ou de confirmer son envoi.',style:TextStyle(fontSize:12,color:Colors.black54)),
    ]))),
    _disclaimer(),
  ]);

  Widget _settings()=>ListView(padding:const EdgeInsets.fromLTRB(14,8,14,22),children:[
    Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Paramètres',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:roseDark)),const SizedBox(height:6),const Text('Utilisée tant que peu de cycles sont enregistrés.',style:TextStyle(fontSize:12,color:Colors.black54)),const SizedBox(height:14),
      DropdownButtonFormField<int>(value:_cycleLength,decoration:const InputDecoration(labelText:'Durée de cycle par défaut'),items:[for(var d=21;d<=40;d++)DropdownMenuItem(value:d,child:Text('$d jours'))],onChanged:(v)async{if(v!=null){setState(()=>_cycleLength=v);await _prefs?.setInt('cycle_length',v);}}),
      const SizedBox(height:12),
      DropdownButtonFormField<int>(value:_bleedLength,decoration:const InputDecoration(labelText:'Durée habituelle des règles'),items:[for(var d=2;d<=10;d++)DropdownMenuItem(value:d,child:Text('$d jours'))],onChanged:(v)async{if(v!=null){setState(()=>_bleedLength=v);await _prefs?.setInt('period_length',v);}}),
      const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.lock_outline,color:rose),title:Text('Verrouillage PIN'),subtitle:Text('Votre code protège l’accès à l’application.')),
    ]))),
    Card(child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Données et confidentialité',style:TextStyle(fontWeight:FontWeight.bold,color:roseDark)),
      const SizedBox(height:7),const Text('Les dates de cycle, préférences et le numéro sont conservés localement sur cet appareil. MyCycle ne les synchronise pas vers un serveur.',style:TextStyle(fontSize:13,color:Colors.black54)),
    ]))),
    _disclaimer(),
  ]);
}

enum CyclePhase { period, follicular, fertile, ovulation, luteal }
class PeriodDates {
  const PeriodDates(this.start,this.end);
  final DateTime start;
  final DateTime? end;
}
