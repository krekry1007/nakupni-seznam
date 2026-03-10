import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NakupniSeznamApp());
}

class NakupniSeznamApp extends StatelessWidget {
  const NakupniSeznamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chytrý nákup',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SeznamObrazovka(),
    );
  }
}

class SeznamObrazovka extends StatefulWidget {
  const SeznamObrazovka({super.key});

  @override
  State<SeznamObrazovka> createState() => _SeznamObrazovkaState();
}

class _SeznamObrazovkaState extends State<SeznamObrazovka> {
  // Propojení s kolekcí 'nakupy' v databázi Firestore
  final CollectionReference _nakupy = FirebaseFirestore.instance.collection('nakupy');
  final TextEditingController _textController = TextEditingController();

  // Funkce pro přidání položky
  Future<void> _pridejPolozku() async {
    final String nazev = _textController.text.trim();
    if (nazev.isEmpty) return; 
    
    await _nakupy.add({
      'nazev': nazev,
      'koupeno': false,
      'cas_pridani': FieldValue.serverTimestamp(), 
    });
    
    _textController.clear(); 
  }

  // Funkce pro odškrtnutí
  Future<void> _zmenStav(String idDokumentu, bool aktualniStav) async {
    await _nakupy.doc(idDokumentu).update({'koupeno': !aktualniStav});
  }

  // Funkce pro smazání
  Future<void> _smazPolozku(String idDokumentu) async {
    await _nakupy.doc(idDokumentu).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rodinný nákupní seznam', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [
          // Ovládací prvky pro zadávání dat
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Co je potřeba koupit?',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_cart),
                    ),
                    onSubmitted: (_) => _pridejPolozku(),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _pridejPolozku,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          
          // Zobrazení dat v reálném čase pomocí ListView
          Expanded(
            child: StreamBuilder(
              stream: _nakupy.orderBy('cas_pridani', descending: true).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Zatím tu nic není. Přidej první položku!', style: TextStyle(fontSize: 16)));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final dokument = snapshot.data!.docs[index];
                    final String id = dokument.id;
                    final String nazev = dokument['nazev'];
                    final bool koupeno = dokument['koupeno'];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: koupeno ? 0 : 2, // Pokud je koupeno, karta "splaskne"
                      color: koupeno ? Colors.grey.shade200 : Colors.white,
                      child: ListTile(
                        leading: Checkbox(
                          value: koupeno,
                          onChanged: (hodnota) => _zmenStav(id, koupeno),
                        ),
                        title: Text(
                          nazev,
                          style: TextStyle(
                            fontSize: 18,
                            decoration: koupeno ? TextDecoration.lineThrough : null,
                            color: koupeno ? Colors.grey : Colors.black,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _smazPolozku(id),
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
    );
  }
}