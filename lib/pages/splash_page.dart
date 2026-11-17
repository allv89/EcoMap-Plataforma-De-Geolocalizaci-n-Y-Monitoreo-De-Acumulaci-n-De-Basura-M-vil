import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- Nuevo import

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Espera 2 segundos para mostrar el logo y la animación
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // --- VERIFICACIÓN DE SESIÓN LOCAL ---
    // Consultamos la memoria del teléfono
    final prefs = await SharedPreferences.getInstance();

    // Buscamos si existe la variable 'isLoggedIn'. Si no existe, devuelve false por defecto.
    final estaLogueado = prefs.getBool('isLoggedIn') ?? false;

    if (estaLogueado) {
      // Si el usuario ya había iniciado sesión antes, va directo al HomePage (tu mapa)
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Si es su primera vez o cerró sesión, va al Login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Utilizamos el color verde de tu tema
      backgroundColor: const Color.fromRGBO(23, 76, 40, 1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Opcional: Si quieres usar tu propio logo en lugar del ícono
            // Image.asset('assets/Logo.png', width: 100, height: 100, color: Colors.white),
            const Icon(Icons.eco, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              'EcoMap',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}