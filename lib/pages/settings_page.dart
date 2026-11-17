import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificacionesEnabled = true;
  bool _modoOscuro = false;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificacionesEnabled = prefs.getBool('notificaciones') ?? true;
      _modoOscuro = prefs.getBool('modo_oscuro') ?? false;
    });
  }

  Future<void> _cambiarNotificaciones(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificaciones', valor);
    setState(() => _notificacionesEnabled = valor);
  }

  Future<void> _cambiarModoOscuro(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modo_oscuro', valor);
    setState(() => _modoOscuro = valor);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modo oscuro actualizado. Reinicia la app para aplicar todos los cambios.')),
      );
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

  Future<void> _contactarSoporte() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'soporte@ecomap.com',
      query: 'subject=Soporte Técnico - EcoMap App',
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        throw 'No se pudo abrir el correo';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay una app de correo configurada en este dispositivo')),
        );
      }
    }
  }

  void _mostrarAcercaDe() {
    showAboutDialog(
      context: context,
      applicationName: 'EcoMap',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset('assets/Logo.png', width: 50, height: 50),
      children: const [
        Text(
          'EcoMap es una plataforma comunitaria para reportar y visualizar problemas ambientales en tu ciudad.',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(23, 76, 40, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Preferencias de Cuenta", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
          ),
          SwitchListTile(
            title: const Text("Notificaciones push"),
            subtitle: const Text("Recibe alertas de reportes cerca de ti"),
            value: _notificacionesEnabled,
            activeColor: primaryColor,
            onChanged: _cambiarNotificaciones,
          ),
          SwitchListTile(
            title: const Text("Modo Oscuro"),
            subtitle: const Text("Cambia la apariencia de la aplicación"),
            value: _modoOscuro,
            activeColor: primaryColor,
            onChanged: _cambiarModoOscuro,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Información y Soporte", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
          ),
          ListTile(leading: const Icon(Icons.info_outline), title: const Text("Acerca de EcoMap"), onTap: _mostrarAcercaDe),
          ListTile(leading: const Icon(Icons.description_outlined), title: const Text("Términos y Condiciones"), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Términos y condiciones próximamente')))),
          ListTile(leading: const Icon(Icons.email_outlined), title: const Text("Contactar Soporte"), onTap: _contactarSoporte),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red)), onTap: _cerrarSesion),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16), child: Text("EcoMap v1.0.0", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}