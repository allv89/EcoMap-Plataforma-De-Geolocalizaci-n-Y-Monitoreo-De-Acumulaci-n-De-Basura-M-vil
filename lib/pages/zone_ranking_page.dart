import 'package:flutter/material.dart';
import 'api_service.dart';
import 'map_page.dart';
import 'zone_utils.dart';

class ZoneRankingPage extends StatefulWidget {
  const ZoneRankingPage({super.key});

  @override
  State<ZoneRankingPage> createState() => _ZoneRankingPageState();
}

class _ZoneRankingPageState extends State<ZoneRankingPage> {
  static const primaryColor = Color.fromRGBO(23, 76, 40, 1);

  List<dynamic> _zonas = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarRanking();
  }

  Future<void> _cargarRanking() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getRankingZonas();
      if (!mounted) return;
      setState(() => _zonas = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Abre el mapa centrado y con la tarjeta de esa zona ya abierta,
  // igual que cuando tocas un pin directamente en el mapa.
  void _abrirZonaEnMapa(Map<String, dynamic> zona) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(focusZona: zona),
      ),
    );
  }

  Widget _buildMedalla(int index) {
    // Top 3 con medalla de color; el resto con número simple.
    const medallas = [
      Color(0xFFFFD700), // oro
      Color(0xFFC0C0C0), // plata
      Color(0xFFCD7F32), // bronce
    ];

    final esTop3 = index < 3;
    return CircleAvatar(
      backgroundColor: esTop3 ? medallas[index] : Colors.grey[300],
      child: esTop3
          ? const Icon(Icons.emoji_events, color: Colors.black87, size: 20)
          : Text(
        '${index + 1}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking de Zonas'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _cargarRanking,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      )
          : _zonas.isEmpty
          ? const Center(child: Text('Aún no hay zonas registradas'))
          : RefreshIndicator(
        onRefresh: _cargarRanking,
        color: primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _zonas.length,
          itemBuilder: (context, index) {
            final zona =
            _zonas[index] as Map<String, dynamic>;
            final nombre =
                zona['nombre']?.toString() ?? 'Zona sin nombre';
            final puntos =
                int.tryParse(zona['puntuacion'].toString()) ?? 0;
            final color = getZoneColor(puntos);
            final estado = getZoneLabel(puntos);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: color.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: ListTile(
                onTap: () => _abrirZonaEnMapa(zona),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: _buildMedalla(index),
                title: Text(
                  nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold),
                ),
                subtitle: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      estado,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$puntos pts',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Colors.grey, size: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
