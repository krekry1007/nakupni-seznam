import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ChytrAplikace());
}

// ------------------------------------------------------------------
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
      title: 'Super Nákup',
      themeMode: _themeMode,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _mainColor, brightness: Brightness.light), useMaterial3: true),
      darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _mainColor, brightness: Brightness.dark), useMaterial3: true),
      home: HlavniObrazovka(zmenVzhled: zmenVzhled),
    );
  }
}

// ------------------------------------------------------------------
class HlavniObrazovka extends StatefulWidget {
  final Function(ThemeMode, Color) zmenVzhled;
  const HlavniObrazovka({super.key, required this.zmenVzhled});

  @override
  State<HlavniObrazovka> createState() => _HlavniObrazovkaState();
}

class _HlavniObrazovkaState extends State<HlavniObrazovka> {
  final CollectionReference _nakupy = FirebaseFirestore.instance.collection('nakupy');
  
  String _vybranyFiltr = 'Vše'; 
  final _nazevController = TextEditingController();
  String _vybranaKategorie = 'Jídlo';
  final List<String> _kategorie = ['Jídlo', 'Drogerie', 'Domácnost', 'Ostatní'];

  Future<void> _pridejPolozku() async {
    if (_nazevController.text.trim().isEmpty) return;
    await _nakupy.add({
      'nazev': _nazevController.text.trim(),
      'koupeno': false,
      'kategorie': _vybranaKategorie,
      'cas_pridani': FieldValue.serverTimestamp(),
    });
    _nazevController.clear();
    
    if (!mounted) return;
    Navigator.pop(context); 
  }

  void _zobrazFormular() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nazevController, decoration: const InputDecoration(labelText: 'Co chybí?', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _vybranaKategorie, 
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Kategorie'),
                items: _kategorie.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (val) => setModalState(() => _vybranaKategorie = val!),
              ),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: _pridejPolozku, child: const Text('Přidat do seznamu')),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  IconData _ziskejIkonu(String kat) {
    switch (kat) {
      case 'Jídlo': return Icons.fastfood;
      case 'Drogerie': return Icons.clean_hands;
      case 'Domácnost': return Icons.home;
      default: return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Můj nákup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Center(child: Icon(Icons.shopping_cart, color: Colors.white, size: 50)),
            ),
            ListTile(leading: const Icon(Icons.dark_mode), title: const Text('Tmavý režim'), onTap: () => widget.zmenVzhled(ThemeMode.dark, Colors.deepPurple)),
            ListTile(leading: const Icon(Icons.light_mode), title: const Text('Světlý režim'), onTap: () => widget.zmenVzhled(ThemeMode.light, Colors.deepPurple)),
            ListTile(leading: const Icon(Icons.color_lens, color: Colors.green), title: const Text('Zelené téma'), onTap: () => widget.zmenVzhled(ThemeMode.system, Colors.green)),
            ListTile(leading: const Icon(Icons.color_lens, color: Colors.orange), title: const Text('Oranžové téma'), onTap: () => widget.zmenVzhled(ThemeMode.system, Colors.orange)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Vše', 'Chybí', 'Koupeno'].map((filtr) {
                return ChoiceChip(
                  label: Text(filtr),
                  selected: _vybranyFiltr == filtr,
                  onSelected: (bool selected) {
                    setState(() => _vybranyFiltr = filtr);
                  },
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _nakupy.orderBy('cas_pridani', descending: true).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Tady nic není.'));

                var dokumenty = snapshot.data!.docs.toList();
                
                // Opraveno bezpečnostním as Map<String, dynamic>
                if (_vybranyFiltr == 'Chybí') {
                  dokumenty = dokumenty.where((d) => (d.data() as Map<String, dynamic>)['koupeno'] == false).toList();
                }
                if (_vybranyFiltr == 'Koupeno') {
                  dokumenty = dokumenty.where((d) => (d.data() as Map<String, dynamic>)['koupeno'] == true).toList();
                }

                return ListView.builder(
                  itemCount: dokumenty.length,
                  itemBuilder: (context, index) {
                    final dok = dokumenty[index];
                    
                    final data = dok.data() as Map<String, dynamic>;
                    final koupeno = data['koupeno'] ?? false;
                    final nazev = data['nazev'] ?? 'Neznámá položka';
                    final kategorie = data.containsKey('kategorie') ? data['kategorie'] : 'Ostatní';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      color: koupeno ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: koupeno ? Colors.grey : Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(_ziskejIkonu(kategorie), color: koupeno ? Colors.white : Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(nazev, style: TextStyle(decoration: koupeno ? TextDecoration.lineThrough : null)),
                        subtitle: Text(kategorie, style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: koupeno,
                              onChanged: (val) => _nakupy.doc(dok.id).update({'koupeno': val}),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _nakupy.doc(dok.id).delete(), // Tohle položku natrvalo smaže
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _zobrazFormular,
        child: const Icon(Icons.add),
      ),
    );
  }
}