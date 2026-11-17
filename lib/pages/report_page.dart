import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final tituloController = TextEditingController();
  final descripcionController = TextEditingController();

  // Ahora manejamos objetos completos: { id_categoria: int, nombre: String }
  List<Map<String, dynamic>> _categorias = [];
  int? _categoriaSeleccionadaId;
  bool _cargandoCategorias = true;

  bool _isLoading = false;
  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  // ---------------------------------------------------------------------
  // Ubicación prellenada desde el mapa (cuando el usuario tocó un punto
  // o vino desde el botón "Nuevo Reporte" ya con su posición actual).
  // Si no llegan argumentos, se sigue pidiendo el GPS como antes.
  // ---------------------------------------------------------------------
  double? _latPredefinida;
  double? _lngPredefinida;
  bool _usarUbicacionPredefinida = false;
  bool _argumentosLeidos = false;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argumentosLeidos) {
      _argumentosLeidos = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final lat = args['latitud'];
        final lng = args['longitud'];
        if (lat != null && lng != null) {
          setState(() {
            _latPredefinida = double.tryParse(lat.toString());
            _lngPredefinida = double.tryParse(lng.toString());
            _usarUbicacionPredefinida = _latPredefinida != null && _lngPredefinida != null;
          });
        }
      }
    }
  }

  Future<void> _cargarCategorias() async {
    try {
      final categoriasData = await ApiService.getCategorias();
      if (mounted) {
        setState(() {
          _categorias = categoriasData.map<Map<String, dynamic>>((cat) {
            return {
              'id_categoria': cat['id_categoria'] ?? 0,
              'nombre': cat['nombre'] ?? 'Sin nombre',
            };
          }).toList();
          _cargandoCategorias = false;
          if (_categorias.isNotEmpty) {
            _categoriaSeleccionadaId = _categorias.first['id_categoria'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoCategorias = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar categorías')),
        );
      }
    }
  }

  Future<void> _seleccionarImagen() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Cámara'), onTap: () => _pick(ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galería'), onTap: () => _pick(ImageSource.gallery)),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(ImageSource source) async {
    Navigator.pop(context);
    final XFile? foto = await _picker.pickImage(source: source, imageQuality: 70);
    if (foto != null) setState(() => _imagenSeleccionada = File(foto.path));
  }

  // ---------------------------------------------------------------------
  // Verifica servicio de ubicación + permiso, pidiendo consentimiento
  // si aún no se ha dado. Devuelve la posición o null si no se pudo obtener.
  // ---------------------------------------------------------------------
  Future<Position?> _obtenerUbicacionConPermiso() async {
    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      if (mounted) {
        _mostrarDialogoUbicacion(
          titulo: 'Ubicación desactivada',
          mensaje: 'Activa el GPS de tu dispositivo para poder reportar tu ubicación.',
          textoBoton: 'Abrir ajustes',
          onPressed: () => Geolocator.openLocationSettings(),
        );
      }
      return null;
    }

    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      // Aquí el sistema operativo muestra el diálogo nativo de consentimiento
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Necesitamos tu ubicación para crear el reporte')),
          );
        }
        return null;
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      if (mounted) {
        _mostrarDialogoUbicacion(
          titulo: 'Permiso bloqueado',
          mensaje: 'Activa el permiso de ubicación desde los ajustes de la app para poder reportar.',
          textoBoton: 'Abrir ajustes de la app',
          onPressed: () => Geolocator.openAppSettings(),
        );
      }
      return null;
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  void _mostrarDialogoUbicacion({
    required String titulo,
    required String mensaje,
    required String textoBoton,
    required VoidCallback onPressed,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onPressed();
            },
            child: Text(textoBoton),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarReporte() async {
    if (ApiService.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para reportar')),
      );
      return;
    }

    if (tituloController.text.trim().isEmpty || descripcionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos')));
      return;
    }

    if (_categoriaSeleccionadaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una categoría')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      double latitud;
      double longitud;

      // Si el usuario tocó un punto en el mapa (o vino con su posición
      // ya lista) y no pidió cambiarla, usamos esas coordenadas directo,
      // sin volver a pedir el GPS.
      if (_usarUbicacionPredefinida && _latPredefinida != null && _lngPredefinida != null) {
        latitud = _latPredefinida!;
        longitud = _lngPredefinida!;
      } else {
        final position = await _obtenerUbicacionConPermiso();
        if (position == null) {
          // Ya se mostró el diálogo/mensaje correspondiente
          setState(() => _isLoading = false);
          return;
        }
        latitud = position.latitude;
        longitud = position.longitude;
      }

      final respuesta = await ApiService.crearReporte(
        titulo: tituloController.text.trim(),
        descripcion: descripcionController.text.trim(),
        idCategoria: _categoriaSeleccionadaId.toString(), // El API espera String (luego lo convierte)
        latitud: latitud,
        longitud: longitud,
        direccion: '', // Opcional: podrías obtenerla con geocoding
        imagen: _imagenSeleccionada,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(respuesta['mensaje'] ?? 'Reporte enviado')),
        );

        // Si esta página fue abierta como push (desde el mapa), hacemos pop
        // y avisamos con "true" para que el mapa refresque el heatmap.
        // Si es una pestaña del IndexedStack, no se hace pop, solo limpiamos el formulario.
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          // Limpiar formulario
          tituloController.clear();
          descripcionController.clear();
          setState(() => _imagenSeleccionada = null);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------
  // Tarjeta que muestra qué ubicación se va a usar para el reporte,
  // con opción de cambiar a la ubicación GPS actual.
  // ---------------------------------------------------------------------
  Widget _buildUbicacionInfo() {
    const primaryColor = Color.fromRGBO(23, 76, 40, 1);

    if (_latPredefinida == null || _lngPredefinida == null) {
      // No llegaron coordenadas del mapa: se usará el GPS al enviar,
      // igual que antes.
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.my_location, color: primaryColor, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Se usará tu ubicación GPS actual al enviar el reporte.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _usarUbicacionPredefinida ? Icons.location_on : Icons.my_location,
                color: primaryColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _usarUbicacionPredefinida
                      ? 'Se reportará en el punto que seleccionaste en el mapa.'
                      : 'Se usará tu ubicación GPS actual al enviar el reporte.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          if (_usarUbicacionPredefinida)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _usarUbicacionPredefinida = false),
                child: const Text('Usar mi ubicación actual en su lugar'),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _usarUbicacionPredefinida = true),
                child: const Text('Usar el punto que seleccioné en el mapa'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(23, 76, 40, 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Reporte'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUbicacionInfo(),
              const SizedBox(height: 16),

              // Dropdown de categorías cargado desde la API
              _cargandoCategorias
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<int>(
                value: _categoriaSeleccionadaId,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categorias.map((cat) {
                  return DropdownMenuItem<int>(
                    value: cat['id_categoria'],
                    child: Text(cat['nombre']),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _categoriaSeleccionadaId = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tituloController,
                decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              // Previsualización de imagen
              _imagenSeleccionada != null
                  ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_imagenSeleccionada!, height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                      onPressed: () => setState(() => _imagenSeleccionada = null),
                    ),
                  ),
                ],
              )
                  : OutlinedButton.icon(
                onPressed: _seleccionarImagen,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Agregar Evidencia'),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _enviarReporte,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enviar Reporte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
