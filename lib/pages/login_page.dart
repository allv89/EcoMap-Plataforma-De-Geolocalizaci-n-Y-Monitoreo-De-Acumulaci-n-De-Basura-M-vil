import 'package:flutter/material.dart';
import 'api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final correoController = TextEditingController();
  final passController = TextEditingController();
  bool _isLoading = false;

  // ──── Inicio de sesión normal ────
  Future<void> _iniciarSesion() async {
    final correo = correoController.text.trim();
    final password = passController.text.trim();

    if (correo.isEmpty || password.isEmpty) {
      _mostrarMensaje("Por favor, ingresa tu correo y contraseña");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resultado = await ApiService.login(correo, password);
      // resultado esperado: { token: "...", usuario: { nombre, apellido, ... } }
      final usuario = resultado['usuario'] ?? resultado;
      final nombre = usuario['nombre'] ?? 'Usuario';
      _mostrarMensaje("¡Bienvenido, $nombre!");

      // Opcional: aquí podrías guardar el token en SharedPreferences
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.setString('token', resultado['token']);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──── Recuperación de contraseña ────
  Future<void> _mostrarDialogoRecuperacion() async {
    final correoRec = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: correoRec,
          decoration: const InputDecoration(hintText: 'Ingresa tu correo electrónico'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final correo = correoRec.text.trim();
              if (correo.isEmpty) {
                _mostrarMensaje('Por favor ingresa un correo');
                return;
              }
              try {
                await ApiService.solicitarRecuperacion(correo);
                if (mounted) {
                  Navigator.pop(context);
                  _mostrarMensaje('Se ha enviado un enlace de recuperación a tu correo');
                }
              } catch (e) {
                _mostrarMensaje(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Image.asset('assets/Logo.png', width: 50, height: 50),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Eco',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: Color.fromRGBO(23, 76, 40, 1)),
                    ),
                    TextSpan(
                      text: 'Map',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color.fromRGBO(23, 76, 40, 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Campos de texto
                      _buildTextField(correoController, "tu@email.com", Icons.email_outlined),
                      const SizedBox(height: 15),
                      _buildTextField(passController, "Contraseña", Icons.lock_outline, isPassword: true),
                      const SizedBox(height: 20),
                      // Botón Iniciar sesión
                      ElevatedButton(
                        onPressed: _isLoading ? null : _iniciarSesion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E5534),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Iniciar sesión", style: TextStyle(fontSize: 16)),
                      ),
                      TextButton(
                        onPressed: _mostrarDialogoRecuperacion,
                        child: const Text("¿Olvidaste tu contraseña?", style: TextStyle(color: Color(0xFF1E5534))),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("¿No tienes cuenta? "),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: const Text("Registrarse", style: TextStyle(color: Color(0xFF1E5534), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                child: const Text("Continuar como invitado", style: TextStyle(decoration: TextDecoration.underline, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }
}