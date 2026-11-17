import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String _nombreCompleto = '';
  String _correo = '';
  String _nivel = 'Nivel 1';
  int _puntos = 0;
  int _reportes = 0;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final datos = await ApiService.getPerfil();

      if (mounted) {
        setState(() {
          final nombre = datos['nombre'] ?? '';
          final apellido = datos['apellido'] ?? '';
          _nombreCompleto = '$nombre $apellido'.trim();
          _correo = datos['correo'] ?? 'usuario@ecomap.com';
          _nivel = datos['nivel'] ?? 'Nivel 1';
          _puntos = datos['puntos'] ?? 0;
          _reportes = datos['reportes_realizados'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
      if (mounted) {
        setState(() {
          _nombreCompleto = 'Usuario EcoMap';
          _correo = 'usuario@ecomap.com';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('token');
    ApiService.token = null;

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(23, 76, 40, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: primaryColor,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              _nombreCompleto.isNotEmpty ? _nombreCompleto : 'Usuario EcoMap',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              _correo,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Divider(height: 40),

            // Nivel y puntos
            ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              title: const Text('Nivel y Puntos'),
              subtitle: Text('Nivel actual: $_nivel'),
              trailing: Chip(
                label: Text('$_puntos pts',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: primaryColor,
              ),
              onTap: () {
                // Navegar a estadísticas más detalladas si se desea
              },
            ),

            // Reportes realizados
            ListTile(
              leading: const Icon(Icons.assignment, color: Colors.blueGrey),
              title: const Text('Reportes realizados'),
              trailing: Text(
                '$_reportes',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // Configuración
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Configuración'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),

            const Spacer(),

            // Botón de Cerrar Sesión
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _cerrarSesion,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar Sesión', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}