import 'package:flutter/material.dart';
import 'api_service.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  List<dynamic> _usuarios = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _cargarRanking();
  }

  Future<void> _cargarRanking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await ApiService.getRanking(); // Devuelve lista de usuarios (vw_top_usuarios)

      if (mounted) {
        setState(() {
          _usuarios = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(23, 76, 40, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking de Usuarios'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildContenido(primaryColor),
    );
  }

  Widget _buildContenido(Color primaryColor) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargarRanking,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                child: const Text('Reintentar'),
              )
            ],
          ),
        ),
      );
    }

    if (_usuarios.isEmpty) {
      return const Center(
        child: Text(
          'No hay usuarios registrados aún.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _usuarios.length,
      itemBuilder: (context, index) {
        final usuario = _usuarios[index];
        return _buildUsuarioTile(index, usuario, primaryColor);
      },
    );
  }

  Widget _buildUsuarioTile(int index, dynamic usuario, Color color) {
    final nombre = usuario['nombre'] ?? '';
    final apellido = usuario['apellido'] ?? '';
    final nombreCompleto = '$nombre $apellido'.trim();
    final puntos = usuario['puntos'] ?? 0;
    final nivel = usuario['nivel'] ?? 'Nivel 1';
    final reportes = usuario['reportes_realizados'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: index < 3 ? Colors.amber.withOpacity(0.3) : Colors.green.withOpacity(0.2),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: index < 3 ? Colors.amber.shade800 : color,
            ),
          ),
        ),
        title: Text(
          nombreCompleto.isNotEmpty ? nombreCompleto : 'Usuario ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$nivel • $reportes reportes'),
        trailing: Text(
          '$puntos pts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: puntos > 100 ? Colors.green : Colors.grey,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}