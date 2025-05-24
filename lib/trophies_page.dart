import 'package:airplan/services/api_config.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TrophiesPage extends StatefulWidget {
  final String username;

  const TrophiesPage({super.key, required this.username});

  @override
  State<TrophiesPage> createState() => _TrophiesPageState();
}

class _TrophiesPageState extends State<TrophiesPage> {
  late Future<List<Map<String, dynamic>>> _trophiesFuture;

  @override
  void initState() {
    super.initState();
    _trophiesFuture = _fetchTrophies();
  }

  Future<List<Map<String, dynamic>>> _fetchTrophies() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig().buildUrl('api/trofeus/${widget.username}')),
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load trophies');
      }
    } catch (e) {
      debugPrint('Error fetching trophies: $e');
      throw Exception('Error fetching trophies');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Trofeos')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _trophiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tienes trofeos aún.'));
          }

          final trophies = snapshot.data!;
          return ListView.builder(
            itemCount: trophies.length,
            itemBuilder: (context, index) {
              final trophy = trophies[index]['trofeu'];
              final obtained = trophies[index]['obtingut'] as bool;
              final obtainedDate = trophies[index]['dataObtencio'];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trophy Image or Black Circle
                      Container(
                        width: 60, // Size of the square frame
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8), // Rounded corners
                          image: trophy['imatge'] != null
                              ? DecorationImage(
                            image: NetworkImage(trophy['imatge']),
                            fit: BoxFit.cover, // Adjust the image to fit the frame
                          )
                              : null,
                        ),
                        child: Stack(
                          children: [
                            if (!obtained) // If the trophy is not obtained
                              Container(
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(0, 0, 0, 0.5), // Dark overlay
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            if (!obtained) // Lock icon overlay
                              const Center(
                                child: Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            if (trophy['imatge'] == null) // Fallback for missing image
                              const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Trophy Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trophy['nom'] ?? 'Sin nombre',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              trophy['descripcio'] ?? 'Sin descripción',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            if (obtainedDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Obtenido: ${DateTime.parse(obtainedDate).toLocal()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Experience and Tick
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${trophy['experiencia']} XP',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (obtained)
                            const Icon(Icons.check_circle, color: Colors.green),
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
    );
  }
}