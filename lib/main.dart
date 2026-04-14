import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ChytrAplikace());
}

class ChytrAplikace extends StatefulWidget {
  const ChytrAplikace({super.key});

  @override
  State<ChytrAplikace> createState() => _ChytrAplikaceState();
}

class _ChytrAplikaceState extends State<ChytrAplikace> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _mainColor = Colors.deepPurple;

  void zmenVzhled(ThemeMode mode, Color color) {
    setState(() {
      _themeMode = mode;
      _mainColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rodinný Organizér',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _mainColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _mainColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: AuthGate(zmenVzhled: zmenVzhled),
    );
  }
}

class AuthGate extends StatelessWidget {
  final Function(ThemeMode, Color) zmenVzhled;
  const AuthGate({super.key, required this.zmenVzhled});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoginObrazovka();
        return HlavniObrazovka(zmenVzhled: zmenVzhled);
      },
    );
  }
}

class LoginObrazovka extends StatefulWidget {
  const LoginObrazovka({super.key});
  @override
  State<LoginObrazovka> createState() => _LoginObrazovkaState();
}

class _LoginObrazovkaState extends State<LoginObrazovka> {
  Future<void> _prihlasitGooglem() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      UserCredential kredit = await FirebaseAuth.instance.signInWithPopup(
        googleProvider,
      );
      if (kredit.user != null) {
        await FirebaseFirestore.instance
            .collection('uzivatele')
            .doc(kredit.user!.uid)
            .set({
              'email': kredit.user!.email,
              'jmeno': kredit.user!.displayName,
              'posledni_prihlaseni': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chyba: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_available,
                size: 100,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 30),
              const Text(
                'Nákupy, Úkoly & Nápady',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _prihlasitGooglem,
                icon: const Icon(Icons.login),
                label: const Text(
                  'Přihlásit se přes Google',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum Zobrazeni {
  nakupy,
  skupinovyChat,
  podporaChat,
  adminSeznamPodpory,
  adminChatSDetail,
}

class HlavniObrazovka extends StatefulWidget {
  final Function(ThemeMode, Color) zmenVzhled;
  const HlavniObrazovka({super.key, required this.zmenVzhled});

  @override
  State<HlavniObrazovka> createState() => _HlavniObrazovkaState();
}

class _HlavniObrazovkaState extends State<HlavniObrazovka> {
  final User _uzivatel = FirebaseAuth.instance.currentUser!;

  final List<String> _adminEmaily = ['admin@tvojeapka.cz'];
  bool get _jeAdmin => _adminEmaily.contains(_uzivatel.email);

  Zobrazeni _aktualniZobrazeni = Zobrazeni.nakupy;
  String _vybranyFiltr = 'Vše';

  final _nazevController = TextEditingController();
  final _mnozstviController = TextEditingController();
  final _emailPozvankyController = TextEditingController();
  final _nazevSeznamuController = TextEditingController();
  final _chatZpravaController = TextEditingController();
  final _kodSeznamuController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  DateTime? _vybraneDatum;

  String _vybranaKategorie = 'Jídlo';
  final List<String> _kategorie = [
    'Jídlo',
    'Drogerie',
    'Domácnost',
    'Nápady / Výlety',
    'Ostatní',
  ];

  String? _aktivniSeznamId;
  String _aktivniSeznamNazev = 'Načítám...';
  bool _nacitaSe = true;
  String? _adminVybranyChatUid;
  String? _adminVybranyChatEmail;

  final List<Color> _paletaBarev = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _nactiUzivatelskyProfil();
    _zkontrolujVytvorZakladniSeznam().then((_) {
      _zkontrolujDeepLink();
    });
    _zkontrolujPozvanky();
  }

  @override
  void dispose() {
    _chatFocusNode.dispose();
    super.dispose();
  }

  Future<void> _zkontrolujDeepLink() async {
    final uri = Uri.base;
    if (uri.queryParameters.containsKey('join')) {
      String kodKeSpojeni = uri.queryParameters['join']!;
      var doc = await FirebaseFirestore.instance
          .collection('seznamy')
          .doc(kodKeSpojeni)
          .get();
      if (doc.exists) {
        await FirebaseFirestore.instance
            .collection('seznamy')
            .doc(kodKeSpojeni)
            .update({
              'clenove': FieldValue.arrayUnion([_uzivatel.uid]),
            });
        if (mounted) {
          setState(() {
            _aktivniSeznamId = kodKeSpojeni;
            _aktivniSeznamNazev = doc['nazev'];
            _aktualniZobrazeni = Zobrazeni.nakupy;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Úspěšně připojeno přes sdílený odkaz! ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _nactiUzivatelskyProfil() async {
    var doc = await FirebaseFirestore.instance
        .collection('uzivatele')
        .doc(_uzivatel.uid)
        .get();
    if (doc.exists && doc.data()!.containsKey('barva')) {
      widget.zmenVzhled(ThemeMode.system, Color(doc['barva']));
    }
  }

  void _ulozAZmenBarvu(Color barva) {
    widget.zmenVzhled(ThemeMode.system, barva);
    FirebaseFirestore.instance
        .collection('uzivatele')
        .doc(_uzivatel.uid)
        .update({'barva': barva.value});
    Navigator.pop(context);
  }

  Future<void> _zkontrolujVytvorZakladniSeznam() async {
    var existujici = await FirebaseFirestore.instance
        .collection('seznamy')
        .where('clenove', arrayContains: _uzivatel.uid)
        .limit(1)
        .get();
    if (existujici.docs.isEmpty) {
      var novyRef = await FirebaseFirestore.instance.collection('seznamy').add({
        'nazev': 'Můj osobní seznam',
        'vlastnik': _uzivatel.uid,
        'clenove': [_uzivatel.uid],
        'cas': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _aktivniSeznamId = novyRef.id;
        _aktivniSeznamNazev = 'Můj osobní seznam';
        _nacitaSe = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _aktivniSeznamId = existujici.docs.first.id;
        _aktivniSeznamNazev = existujici.docs.first['nazev'];
        _nacitaSe = false;
      });
    }
  }

  Future<void> _smazatSeznam(String seznamId, String nazev) async {
    bool? potvrdit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smazat seznam?'),
        content: Text('Opravdu chceš smazat "$nazev"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    if (potvrdit == true) {
      await FirebaseFirestore.instance
          .collection('seznamy')
          .doc(seznamId)
          .delete();
      if (_aktivniSeznamId == seznamId) {
        setState(() {
          _nacitaSe = true;
        });
        await _zkontrolujVytvorZakladniSeznam();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seznam byl smazán.')));
    }
  }

  Future<void> _opustitSeznam(String seznamId, String nazev) async {
    bool? potvrdit = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opustit seznam?'),
        content: Text('Opravdu chceš odejít ze seznamu "$nazev"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Odejít'),
          ),
        ],
      ),
    );
    if (potvrdit == true) {
      await FirebaseFirestore.instance
          .collection('seznamy')
          .doc(seznamId)
          .update({
            'clenove': FieldValue.arrayRemove([_uzivatel.uid]),
          });
      if (_aktivniSeznamId == seznamId) {
        setState(() {
          _nacitaSe = true;
        });
        await _zkontrolujVytvorZakladniSeznam();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Opustil jsi seznam.')));
    }
  }

  Future<void> _ulozitNeboUpravitPolozku({String? docId}) async {
    String zadanyText = _nazevController.text.trim();
    String zadaneMnozstvi = _mnozstviController.text.trim();
    if (zadanyText.isEmpty || _aktivniSeznamId == null) return;

    Map<String, dynamic> data = {
      'nazev': zadanyText,
      'mnozstvi': zadaneMnozstvi,
      'kategorie': _vybranaKategorie,
      'termin': _vybraneDatum?.toIso8601String(),
    };

    if (docId == null) {
      data['koupeno'] = false;
      data['cas_pridani'] = FieldValue.serverTimestamp();
      data['seznam_id'] = _aktivniSeznamId;
      data['historie_cen'] = [];
      await FirebaseFirestore.instance.collection('nakupy').add(data);
    } else {
      await FirebaseFirestore.instance
          .collection('nakupy')
          .doc(docId)
          .update(data);
    }

    _nazevController.clear();
    _mnozstviController.clear();
    _vybraneDatum = null;
    if (!mounted) return;
    Navigator.pop(context);
  }

  // --- LOGIKA CHATŮ ---
  Future<void> _odeslatZpravu(
    String kolekcePath,
    String docId,
    bool jePodpora,
  ) async {
    String textZpravy = _chatZpravaController.text.trim();
    if (textZpravy.isEmpty) {
      _chatFocusNode.requestFocus();
      return;
    }
    _chatZpravaController.clear();

    String odesilatel =
        (_jeAdmin &&
            jePodpora &&
            _aktualniZobrazeni == Zobrazeni.adminChatSDetail)
        ? 'ADMIN'
        : _uzivatel.email!;

    await FirebaseFirestore.instance
        .collection(kolekcePath)
        .doc(docId)
        .collection('zpravy')
        .add({
          'text': textZpravy,
          'odesilatel': odesilatel,
          'cas': FieldValue.serverTimestamp(),
          'precteno': false,
        });

    if (jePodpora) {
      await FirebaseFirestore.instance.collection(kolekcePath).doc(docId).set({
        'email': _jeAdmin ? _adminVybranyChatEmail : _uzivatel.email,
        'posledni_zprava': textZpravy,
        'cas_posledni': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    _chatFocusNode.requestFocus();

    if (jePodpora && odesilatel != 'ADMIN') {
      if (textZpravy.toLowerCase().contains('káv') ||
          textZpravy.toLowerCase().contains('kav')) {
        _zpracujSifrovanyPozadavek(docId, 'kava', 100);
      } else if (textZpravy.toLowerCase().contains('cukr')) {
        _zpracujSifrovanyPozadavek(docId, 'cukr', 100);
      }
    }
  }

  Future<void> _zpracujSifrovanyPozadavek(
    String ciloveUid,
    String produkt,
    int pozadovaneMnozstvi,
  ) async {
    final tajnyKlic = enc.Key.fromUtf8('TADY_BY_BYL_MUJ_TAJNY_KLIC_32ZNK');
    final iv = enc.IV.fromUtf8('TADY_BY_BYL_MUJ_IV');
    try {
      final encrypter = enc.Encrypter(enc.AES(tajnyKlic));
      final surovadata = '{"kava": 500, "cukr": 1000}';
      final zasifrovanoVpameti = encrypter.encrypt(surovadata, iv: iv);
      final desifrovanyText = encrypter.decrypt(zasifrovanoVpameti, iv: iv);
      Map<String, dynamic> skladovaData = json.decode(desifrovanyText);
      int naSklade = skladovaData[produkt] ?? 0;
      String odpoved = (naSklade >= pozadovaneMnozstvi)
          ? 'SYSTÉM: Máme dostatek položky "$produkt". Dešifrován zůstatek: $naSklade g.'
          : 'SYSTÉM: Nedostatek zásob pro "$produkt".';
      await FirebaseFirestore.instance
          .collection('podpora_chaty')
          .doc(ciloveUid)
          .collection('zpravy')
          .add({
            'text': odpoved,
            'odesilatel': 'SYSTÉM',
            'cas': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _oznacitZpravyZaPrectene(
    String kolekcePath,
    String docId,
  ) async {
    var neptectene = await FirebaseFirestore.instance
        .collection(kolekcePath)
        .doc(docId)
        .collection('zpravy')
        .where('precteno', isEqualTo: false)
        .where('odesilatel', isNotEqualTo: _uzivatel.email)
        .get();
    for (var doc in neptectene.docs) {
      doc.reference.update({'precteno': true});
    }
  }

  // --- STATISTIKY ÚTRAT ---
  void _ukazStatistiky() async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    var nakupyData = await FirebaseFirestore.instance
        .collection('nakupy')
        .where('seznam_id', isEqualTo: _aktivniSeznamId)
        .where('koupeno', isEqualTo: true)
        .get();
    Navigator.pop(context);

    Map<String, double> utratyDleKategorie = {};
    double celkovaUtrata = 0;

    for (var doc in nakupyData.docs) {
      Map<String, dynamic> data = doc.data();
      if (data.containsKey('cena_celkem') && data['cena_celkem'] != null) {
        double cena = double.parse(data['cena_celkem'].toString());
        String kat = data['kategorie'] ?? 'Ostatní';
        utratyDleKategorie[kat] = (utratyDleKategorie[kat] ?? 0) + cena;
        celkovaUtrata += cena;
      }
    }

    if (celkovaUtrata == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zatím nejsou zaznamenány žádné útraty.')),
      );
      return;
    }

    List<PieChartSectionData> kolace = [];
    int colorIndex = 0;
    utratyDleKategorie.forEach((kat, cena) {
      kolace.add(
        PieChartSectionData(
          color: _paletaBarev[colorIndex % _paletaBarev.length],
          value: cena,
          title: '${(cena / celkovaUtrata * 100).toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Celková útrata: ${celkovaUtrata.toStringAsFixed(0)} Kč'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: Column(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(sections: kolace, centerSpaceRadius: 40),
                ),
              ),
              const SizedBox(height: 10),
              ...utratyDleKategorie.keys
                  .map(
                    (kat) => Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          color:
                              _paletaBarev[utratyDleKategorie.keys
                                      .toList()
                                      .indexOf(kat) %
                                  _paletaBarev.length],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$kat: ${utratyDleKategorie[kat]!.toStringAsFixed(0)} Kč',
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  void _ukazGrafCen(String nazevPolozky, List<dynamic> historieCen) {
    if (historieCen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zatím nemáme uloženy žádné ceny.')),
      );
      return;
    }
    List<FlSpot> bodyGrafu = [];
    for (int i = 0; i < historieCen.length; i++)
      bodyGrafu.add(
        FlSpot(i.toDouble(), double.parse(historieCen[i].toString())),
      );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vývoj ceny:\n$nazevPolozky'),
        content: SizedBox(
          height: 300,
          width: 300,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d), width: 1),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: bodyGrafu,
                  isCurved: true,
                  color: Colors.deepPurple,
                  barWidth: 4,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  // --- VYKRESLOVÁNÍ PODLE REŽIMU ---
  Widget _vykresliChatBox(String kolekcePath, String docId, bool jePodpora) {
    if (jePodpora && _jeAdmin) _oznacitZpravyZaPrectene(kolekcePath, docId);

    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection(kolekcePath)
                .doc(docId)
                .collection('zpravy')
                .orderBy('cas', descending: true)
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty)
                return const Center(
                  child: Text(
                    'Napiš první zprávu...',
                    style: TextStyle(color: Colors.grey),
                  ),
                );

              return ListView.builder(
                reverse: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  bool jeMoje =
                      data['odesilatel'] == _uzivatel.email ||
                      (data['odesilatel'] == 'ADMIN' && _jeAdmin && jePodpora);
                  bool precteno = data['precteno'] ?? false;

                  return Align(
                    alignment: jeMoje
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 12,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: jeMoje
                            ? Colors.green[800]
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!jeMoje)
                            Text(
                              data['odesilatel'],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                data['text'],
                                style: TextStyle(
                                  color: jeMoje
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (jeMoje)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    precteno ? Icons.done_all : Icons.check,
                                    size: 14,
                                    color: precteno ? Colors.blue : Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatZpravaController,
                  focusNode: _chatFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Napiš zprávu...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) =>
                      _odeslatZpravu(kolekcePath, docId, jePodpora),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.green),
                onPressed: () => _odeslatZpravu(kolekcePath, docId, jePodpora),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vykresliAdminPrehled() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('podpora_chaty')
          .orderBy('cas_posledni', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text('Zatím žádné konverzace.'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chatData = snapshot.data!.docs[index];
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.support_agent, color: Colors.white),
              ),
              title: Text(chatData['email'] ?? 'Neznámý'),
              subtitle: Text(
                chatData['posledni_zprava'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                setState(() {
                  _adminVybranyChatUid = chatData.id;
                  _adminVybranyChatEmail = chatData['email'];
                  _aktualniZobrazeni = Zobrazeni.adminChatSDetail;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _vykresliNakupy() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['Vše', 'Chybí', 'Hotovo'].map((filtr) {
              return ChoiceChip(
                label: Text(filtr),
                selected: _vybranyFiltr == filtr,
                onSelected: (bool selected) =>
                    setState(() => _vybranyFiltr = filtr),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('nakupy')
                .where('seznam_id', isEqualTo: _aktivniSeznamId)
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const Center(
                  child: Text('Zatím tu nic není. Otevři formulář plusem.'),
                );

              var dokumenty = snapshot.data!.docs.toList();

              if (_vybranyFiltr == 'Chybí')
                dokumenty = dokumenty
                    .where(
                      (d) =>
                          (d.data() as Map<String, dynamic>)['koupeno'] ==
                          false,
                    )
                    .toList();
              if (_vybranyFiltr == 'Hotovo')
                dokumenty = dokumenty
                    .where(
                      (d) =>
                          (d.data() as Map<String, dynamic>)['koupeno'] == true,
                    )
                    .toList();

              Map<String, List<QueryDocumentSnapshot>> seskupeno = {};
              for (var dok in dokumenty) {
                String kat =
                    (dok.data() as Map<String, dynamic>)['kategorie'] ??
                    'Ostatní';
                if (!seskupeno.containsKey(kat)) seskupeno[kat] = [];
                seskupeno[kat]!.add(dok);
              }

              return ListView(
                children: seskupeno.keys.map((kategorie) {
                  seskupeno[kategorie]!.sort((a, b) {
                    var dataA = a.data() as Map<String, dynamic>;
                    var dataB = b.data() as Map<String, dynamic>;

                    bool kA = dataA['koupeno'] ?? false;
                    bool kB = dataB['koupeno'] ?? false;

                    if (kA && !kB) return 1;
                    if (!kA && kB) return -1;

                    var dA = dataA['termin'];
                    var dB = dataB['termin'];
                    if (dA == null && dB == null) return 0;
                    if (dA == null) return 1;
                    if (dB == null) return -1;
                    return DateTime.parse(dA).compareTo(DateTime.parse(dB));
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          top: 16,
                          bottom: 8,
                        ),
                        child: Text(
                          kategorie.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ...seskupeno[kategorie]!
                          .map((dok) => _vykresliJednuPolozku(dok, kategorie))
                          .toList(),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- OPRAVA ROZLOŽENÍ POLOŽKY PRO MOBILY ---
  Widget _vykresliJednuPolozku(QueryDocumentSnapshot dok, String kategorie) {
    final data = dok.data() as Map<String, dynamic>;
    final koupeno = data['koupeno'] ?? false;
    final nazev = data['nazev'] ?? 'Neznámá položka';
    final mnozstvi = data.containsKey('mnozstvi') ? data['mnozstvi'] : '';
    List<dynamic> historieCen = data.containsKey('historie_cen')
        ? data['historie_cen']
        : [];

    DateTime? termin;
    bool jeZpozdenoNeboDnes = false;
    if (data.containsKey('termin') && data['termin'] != null) {
      termin = DateTime.tryParse(data['termin']);
      if (termin != null && termin.difference(DateTime.now()).inHours <= 24)
        jeZpozdenoNeboDnes = true;
    }

    final zobrazenyNazev =
        (mnozstvi != null && mnozstvi.toString().trim().isNotEmpty)
        ? '$nazev ($mnozstvi)'
        : nazev;
    final textCeny = data.containsKey('cena_na_osobu')
        ? 'Rozpočítáno: ${data['cena_na_osobu']} Kč/os'
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: koupeno
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: (!koupeno && jeZpozdenoNeboDnes)
              ? Colors.red
              : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: koupeno
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    kategorie == 'Nápady / Výlety'
                        ? Icons.lightbulb
                        : _ziskejIkonu(kategorie),
                    color: koupeno
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zobrazenyNazev,
                        style: TextStyle(
                          decoration: koupeno
                              ? TextDecoration.lineThrough
                              : null,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (termin != null)
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 14,
                              color: (!koupeno && jeZpozdenoNeboDnes)
                                  ? Colors.red
                                  : Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${termin.day}.${termin.month}.${termin.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: (!koupeno && jeZpozdenoNeboDnes)
                                    ? Colors.red
                                    : Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      if (textCeny.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            textCeny,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    kategorie,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    if (kategorie != 'Nápady / Výlety')
                      IconButton(
                        icon: const Icon(Icons.show_chart, color: Colors.blue),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _ukazGrafCen(nazev, historieCen),
                      ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _zobrazFormular(
                        docIdKUprave: dok.id,
                        puvodniData: data,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: koupeno,
                        onChanged: (val) async {
                          if (val == true) {
                            TextEditingController cenaController =
                                TextEditingController();
                            TextEditingController osobController =
                                TextEditingController(text: '1');
                            await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Útrata a rozpočítání'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: cenaController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Kolik to stálo celkem?',
                                        suffixText: 'Kč',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: osobController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Mezi kolik osob se to dělí?',
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      FirebaseFirestore.instance
                                          .collection('nakupy')
                                          .doc(dok.id)
                                          .update({'koupeno': true});
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Přeskočit'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (cenaController.text.isNotEmpty) {
                                        double celkem =
                                            double.tryParse(
                                              cenaController.text.replaceAll(
                                                ',',
                                                '.',
                                              ),
                                            ) ??
                                            0;
                                        int osob =
                                            int.tryParse(osobController.text) ??
                                            1;
                                        double naOsobu = osob > 0
                                            ? celkem / osob
                                            : celkem;
                                        double jednotkovaCena = celkem;
                                        if (mnozstvi.toString().isNotEmpty) {
                                          RegExp regExp = RegExp(
                                            r'(\d+([.,]\d+)?)',
                                          );
                                          var match = regExp.firstMatch(
                                            mnozstvi.toString(),
                                          );
                                          if (match != null) {
                                            double mnozstviNum =
                                                double.tryParse(
                                                  match
                                                      .group(0)!
                                                      .replaceAll(',', '.'),
                                                ) ??
                                                1.0;
                                            if (mnozstviNum > 0)
                                              jednotkovaCena =
                                                  celkem / mnozstviNum;
                                          }
                                        }
                                        FirebaseFirestore.instance
                                            .collection('nakupy')
                                            .doc(dok.id)
                                            .update({
                                              'koupeno': true,
                                              'cena_celkem': celkem,
                                              'cena_na_osobu': double.parse(
                                                naOsobu.toStringAsFixed(2),
                                              ),
                                              'historie_cen':
                                                  FieldValue.arrayUnion([
                                                    double.parse(
                                                      (jednotkovaCena)
                                                          .toStringAsFixed(2),
                                                    ),
                                                  ]),
                                            });
                                      }
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Uložit a spočítat'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            FirebaseFirestore.instance
                                .collection('nakupy')
                                .doc(dok.id)
                                .update({
                                  'koupeno': false,
                                  'cena_celkem': FieldValue.delete(),
                                  'cena_na_osobu': FieldValue.delete(),
                                });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => FirebaseFirestore.instance
                          .collection('nakupy')
                          .doc(dok.id)
                          .delete(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _zkontrolujPozvanky() {
    FirebaseFirestore.instance
        .collection('pozvanky')
        .where('pro_email', isEqualTo: _uzivatel.email)
        .where('stav', isEqualTo: 'ceka')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty && mounted) {
            var pozvanka = snapshot.docs.first;
            _ukazUpozorneniNaPozvanku(
              pozvanka.id,
              pozvanka['od_jmena'],
              pozvanka['seznam_id'],
              pozvanka['seznam_nazev'],
            );
          }
        });
  }

  void _ukazUpozorneniNaPozvanku(
    String pozvankaId,
    String odKoho,
    String seznamId,
    String nazevSeznamu,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Nová pozvánka! 💌'),
        content: Text(
          '$odKoho tě zve do skupiny "$nazevSeznamu". Chceš se připojit?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('pozvanky')
                  .doc(pozvankaId)
                  .update({'stav': 'odmitnuto'});
              Navigator.pop(context);
            },
            child: const Text('Odmítnout', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('seznamy')
                  .doc(seznamId)
                  .update({
                    'clenove': FieldValue.arrayUnion([_uzivatel.uid]),
                  });
              await FirebaseFirestore.instance
                  .collection('pozvanky')
                  .doc(pozvankaId)
                  .update({'stav': 'prijato'});
              if (!mounted) return;
              setState(() {
                _aktivniSeznamId = seznamId;
                _aktivniSeznamNazev = nazevSeznamu;
                _aktualniZobrazeni = Zobrazeni.nakupy;
              });
              Navigator.pop(context);
            },
            child: const Text('Přijmout'),
          ),
        ],
      ),
    );
  }

  void _zobrazFormular({
    String? docIdKUprave,
    Map<String, dynamic>? puvodniData,
  }) {
    if (puvodniData != null) {
      _nazevController.text = puvodniData['nazev'] ?? '';
      _mnozstviController.text = puvodniData['mnozstvi'] ?? '';
      _vybranaKategorie = puvodniData['kategorie'] ?? 'Ostatní';
      _vybraneDatum = puvodniData['termin'] != null
          ? DateTime.tryParse(puvodniData['termin'])
          : null;
    } else {
      _nazevController.clear();
      _mnozstviController.clear();
      _vybraneDatum = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nazevController,
                decoration: const InputDecoration(
                  labelText: 'Název položky nebo Nápad...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mnozstviController,
                decoration: const InputDecoration(
                  labelText: 'Množství / Detail (nepovinné)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _vybranaKategorie,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Kategorie',
                ),
                items: _kategorie
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (val) =>
                    setModalState(() => _vybranaKategorie = val!),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _vybraneDatum == null
                      ? 'Přidat termín (nepovinné)'
                      : 'Termín: ${_vybraneDatum!.day}.${_vybraneDatum!.month}.${_vybraneDatum!.year}',
                ),
                onPressed: () async {
                  DateTime? vybrano = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (vybrano != null) {
                    setModalState(() {
                      _vybraneDatum = vybrano;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _ulozitNeboUpravitPolozku(docId: docIdKUprave),
                child: Text(
                  docIdKUprave == null ? 'Přidat do seznamu' : 'Uložit změny',
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _ukazQRCode() {
    String odkazProSdleni = '${Uri.base.origin}/?join=$_aktivniSeznamId';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sdílet přes QR kód'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Naskenujte kód foťákem v mobilu. Aplikace se sama otevře a přidá vás.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              width: 200,
              child: QrImageView(
                data: odkazProSdleni,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  void _dialogPozvatEmailem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poslat e-mailovou pozvánku'),
        content: TextField(
          controller: _emailPozvankyController,
          decoration: const InputDecoration(labelText: 'E-mail uživatele'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_emailPozvankyController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('pozvanky').add({
                  'od_jmena': _uzivatel.displayName ?? _uzivatel.email,
                  'od_uid': _uzivatel.uid,
                  'pro_email': _emailPozvankyController.text.trim(),
                  'seznam_id': _aktivniSeznamId,
                  'seznam_nazev': _aktivniSeznamNazev,
                  'stav': 'ceka',
                  'cas': FieldValue.serverTimestamp(),
                });
                _emailPozvankyController.clear();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Odeslat'),
          ),
        ],
      ),
    );
  }

  void _ukazVyberBarvy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vyber si barvu aplikace'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _paletaBarev
              .map(
                (barva) => GestureDetector(
                  onTap: () => _ulozAZmenBarvu(barva),
                  child: CircleAvatar(backgroundColor: barva, radius: 22),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  IconData _ziskejIkonu(String kat) {
    switch (kat) {
      case 'Jídlo':
        return Icons.fastfood;
      case 'Drogerie':
        return Icons.clean_hands;
      case 'Domácnost':
        return Icons.home;
      default:
        return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_nacitaSe)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    String nadpisAppBar = _aktivniSeznamNazev;
    if (_aktualniZobrazeni == Zobrazeni.podporaChat)
      nadpisAppBar = 'Podpora: Kontakt na správce';
    if (_aktualniZobrazeni == Zobrazeni.skupinovyChat)
      nadpisAppBar = 'Skupinový chat';
    if (_aktualniZobrazeni == Zobrazeni.adminSeznamPodpory)
      nadpisAppBar = 'Admin Panel';
    if (_aktualniZobrazeni == Zobrazeni.adminChatSDetail)
      nadpisAppBar = 'Chat: $_adminVybranyChatEmail';

    Color textListy = (_aktualniZobrazeni != Zobrazeni.nakupy)
        ? Colors.white
        : Theme.of(context).colorScheme.onPrimaryContainer;

    return Scaffold(
      appBar: AppBar(
        title: Text(nadpisAppBar, style: TextStyle(color: textListy)),
        backgroundColor: (_aktualniZobrazeni != Zobrazeni.nakupy)
            ? Colors.black87
            : Theme.of(context).colorScheme.inversePrimary,
        iconTheme: IconThemeData(color: textListy),
        actions: _aktualniZobrazeni == Zobrazeni.nakupy
            ? [
                IconButton(
                  icon: Icon(Icons.person_add, color: textListy),
                  tooltip: 'Pozvat přes e-mail',
                  onPressed: _dialogPozvatEmailem,
                ),
                IconButton(
                  icon: Icon(Icons.qr_code, color: textListy),
                  tooltip: 'Sdílet odkazem (QR)',
                  onPressed: _ukazQRCode,
                ),
                IconButton(
                  icon: Icon(Icons.chat, color: textListy),
                  tooltip: 'Skupinový chat',
                  onPressed: () => setState(
                    () => _aktualniZobrazeni = Zobrazeni.skupinovyChat,
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.close, color: textListy),
                  onPressed: () =>
                      setState(() => _aktualniZobrazeni = Zobrazeni.nakupy),
                ),
              ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_uzivatel.displayName ?? 'Uživatel'),
              accountEmail: Text(_uzivatel.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundImage: _uzivatel.photoURL != null
                    ? NetworkImage(_uzivatel.photoURL!)
                    : null,
                child: _uzivatel.photoURL == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Tvé Okruhy:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('seznamy')
                        .where('clenove', arrayContains: _uzivatel.uid)
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      var seznamyDocs = snapshot.data!.docs.toList();

                      // TŘÍDĚNÍ: Oblíbené půjdou vždy nahoru!
                      seznamyDocs.sort((a, b) {
                        bool aFav =
                            (a.data() as Map<String, dynamic>)['oblibene']
                                ?.contains(_uzivatel.uid) ??
                            false;
                        bool bFav =
                            (b.data() as Map<String, dynamic>)['oblibene']
                                ?.contains(_uzivatel.uid) ??
                            false;
                        if (aFav && !bFav) return -1;
                        if (!aFav && bFav) return 1;
                        return (a.data() as Map<String, dynamic>)['nazev']
                            .toString()
                            .compareTo(
                              (b.data() as Map<String, dynamic>)['nazev']
                                  .toString(),
                            );
                      });

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: seznamyDocs.length,
                        itemBuilder: (context, index) {
                          var doc = seznamyDocs[index];
                          bool jeAktivni =
                              (doc.id == _aktivniSeznamId &&
                              _aktualniZobrazeni == Zobrazeni.nakupy);
                          bool jsemVlastnik = doc['vlastnik'] == _uzivatel.uid;
                          bool jeOblibeny =
                              (doc.data() as Map<String, dynamic>)['oblibene']
                                  ?.contains(_uzivatel.uid) ??
                              false;

                          return ListTile(
                            leading: Icon(
                              jeOblibeny ? Icons.star : Icons.list_alt,
                              color: jeOblibeny
                                  ? Colors.amber
                                  : (jeAktivni
                                        ? Theme.of(context).colorScheme.primary
                                        : null),
                            ),
                            title: Text(
                              doc['nazev'],
                              style: TextStyle(
                                fontWeight: jeAktivni
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            tileColor: jeAktivni
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1)
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Tlačítko pro přidání do oblíbených
                                IconButton(
                                  icon: Icon(
                                    jeOblibeny ? Icons.star : Icons.star_border,
                                    color: jeOblibeny
                                        ? Colors.amber
                                        : Colors.grey,
                                  ),
                                  onPressed: () {
                                    if (jeOblibeny) {
                                      FirebaseFirestore.instance
                                          .collection('seznamy')
                                          .doc(doc.id)
                                          .update({
                                            'oblibene': FieldValue.arrayRemove([
                                              _uzivatel.uid,
                                            ]),
                                          });
                                    } else {
                                      FirebaseFirestore.instance
                                          .collection('seznamy')
                                          .doc(doc.id)
                                          .update({
                                            'oblibene': FieldValue.arrayUnion([
                                              _uzivatel.uid,
                                            ]),
                                          });
                                    }
                                  },
                                ),
                                jsemVlastnik
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _smazatSeznam(doc.id, doc['nazev']);
                                        },
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.exit_to_app,
                                          color: Colors.orange,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _opustitSeznam(doc.id, doc['nazev']);
                                        },
                                      ),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _aktivniSeznamId = doc.id;
                                _aktivniSeznamNazev = doc['nazev'];
                                _aktualniZobrazeni = Zobrazeni.nakupy;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                  ),
                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.pie_chart, color: Colors.orange),
                    title: const Text(
                      'Statistiky útrat',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _ukazStatistiky();
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.support_agent,
                      color: Colors.black,
                    ),
                    title: const Text(
                      'Podpora / Kontakt na správce',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    tileColor: _aktualniZobrazeni == Zobrazeni.podporaChat
                        ? Colors.grey[300]
                        : null,
                    onTap: () {
                      setState(() {
                        _aktualniZobrazeni = Zobrazeni.podporaChat;
                      });
                      Navigator.pop(context);
                    },
                  ),

                  if (_jeAdmin)
                    ListTile(
                      leading: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.red,
                      ),
                      title: const Text(
                        'Admin Panel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      tileColor:
                          (_aktualniZobrazeni == Zobrazeni.adminSeznamPodpory ||
                              _aktualniZobrazeni == Zobrazeni.adminChatSDetail)
                          ? Colors.red[100]
                          : null,
                      onTap: () {
                        setState(() {
                          _aktualniZobrazeni = Zobrazeni.adminSeznamPodpory;
                        });
                        Navigator.pop(context);
                      },
                    ),

                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.green,
                    ),
                    title: const Text('Vytvořit seznam'),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Nový seznam'),
                          content: TextField(
                            controller: _nazevSeznamuController,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Zrušit'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                if (_nazevSeznamuController.text
                                    .trim()
                                    .isNotEmpty) {
                                  var novyRef = await FirebaseFirestore.instance
                                      .collection('seznamy')
                                      .add({
                                        'nazev': _nazevSeznamuController.text
                                            .trim(),
                                        'vlastnik': _uzivatel.uid,
                                        'clenove': [_uzivatel.uid],
                                        'cas': FieldValue.serverTimestamp(),
                                      });
                                  setState(() {
                                    _aktivniSeznamId = novyRef.id;
                                    _aktivniSeznamNazev =
                                        _nazevSeznamuController.text.trim();
                                    _aktualniZobrazeni = Zobrazeni.nakupy;
                                  });
                                  _nazevSeznamuController.clear();
                                  if (context.mounted) Navigator.pop(context);
                                }
                              },
                              child: const Text('Vytvořit'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.palette, color: Colors.blue),
                    title: const Text('Změnit barvu aplikace'),
                    onTap: () {
                      Navigator.pop(context);
                      _ukazVyberBarvy();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.dark_mode),
                    title: const Text('Přepnout téma'),
                    onTap: () {
                      widget.zmenVzhled(
                        Theme.of(context).brightness == Brightness.dark
                            ? ThemeMode.light
                            : ThemeMode.dark,
                        Theme.of(context).colorScheme.primary,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Odhlásit se',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => FirebaseAuth.instance.signOut(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),

      body: _aktualniZobrazeni == Zobrazeni.nakupy
          ? _vykresliNakupy()
          : (_aktualniZobrazeni == Zobrazeni.skupinovyChat
                ? _vykresliChatBox('seznamy', '$_aktivniSeznamId', false)
                : (_aktualniZobrazeni == Zobrazeni.podporaChat
                      ? _vykresliChatBox('podpora_chaty', _uzivatel.uid, true)
                      : (_aktualniZobrazeni == Zobrazeni.adminSeznamPodpory
                            ? _vykresliAdminPrehled()
                            : _vykresliChatBox(
                                'podpora_chaty',
                                _adminVybranyChatUid!,
                                true,
                              )))),

      floatingActionButton: _aktualniZobrazeni == Zobrazeni.nakupy
          ? FloatingActionButton(
              onPressed: () => _zobrazFormular(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
