import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'api_service.dart';
import 'zone_utils.dart';

class MapPage extends StatefulWidget {
  /// Zona a la que se debe centrar el mapa al abrir (opcional).
  /// Se usa, por ejemplo, cuando se llega desde el ranking de zonas.
  /// Debe traer al menos 'id' o 'latitud'/'longitud'.
  final Map<String, dynamic>? focusZona;

  const MapPage({super.key, this.focusZona});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  // Ubicación por defecto (David, Chiriquí) mientras se obtiene el GPS real
  LatLng _currentLocation = const LatLng(9.1012, -79.4029);
  double? _currentHeading; // grados 0-360, null si no hay rumbo confiable

  List<WeightedLatLng> _heatMapData = [];
  List<Map<String, dynamic>> _zonas = [];
  bool _isLoadingMapData = true;
  bool _isLoadingLocation = true;

  StreamSubscription<Position>? _positionStream;

  static const primaryColor = Color.fromRGBO(23, 76, 40, 1);

  // Radio (km) que se usa para buscar reportes dentro de un sitio y
  // para decidir si un tap "cae" sobre un sitio existente o es libre.
  static const double _radioBusquedaSitioKm = 0.2;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _cargarDatos();
    _iniciarSeguimientoUbicacion();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // SEGUIMIENTO CONTINUO DE UBICACIÓN
  // Actualiza el marcador en tiempo real y calcula el rumbo (heading)
  // para rotar el cono de dirección, igual que Waze/Google Maps.
  // ---------------------------------------------------------------------
  void _iniciarSeguimientoUbicacion() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // metros mínimos para disparar una actualización
    );
    _positionStream =
        Geolocator.getPositionStream(locationSettings: settings).listen(
              (posicion) {
            if (!mounted) return;
            setState(() {
              _currentLocation = LatLng(posicion.latitude, posicion.longitude);
              // Solo confiamos en el heading si el usuario se está moviendo,
              // porque en reposo el valor suele ser ruido.
              if (posicion.headingAccuracy >= 0 && posicion.speed > 0.3) {
                _currentHeading = posicion.heading;
              }
            });
          },
          onError: (e) => debugPrint("Error en stream de ubicación: $e"),
        );
  }

  // ---------------------------------------------------------------------
  // CARGA DE DATOS (heatmap + sitios dinámicos)
  // ---------------------------------------------------------------------
  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() => _isLoadingMapData = true);

    try {
      final ubicaciones = await ApiService.getUbicacionesReportes();
      // Los "sitios" ya no son zonas fijas: se calculan en el backend
      // agrupando los reportes activos que hay cerca entre sí, sin
      // importar el corregimiento, así que funcionan en todo el mapa.
      final zonas = await ApiService.getZonas();

      if (mounted) {
        setState(() {
          _heatMapData = ubicaciones.map<WeightedLatLng>((p) {
            final lat = double.parse(p['latitud'].toString());
            final lng = double.parse(p['longitud'].toString());
            final peso = p['peso'] != null
                ? double.parse(p['peso'].toString())
                : 1.0;
            return WeightedLatLng(LatLng(lat, lng), peso);
          }).toList();

          _zonas = zonas
              .map<Map<String, dynamic>>((z) => z as Map<String, dynamic>)
              .toList();

          _isLoadingMapData = false;
        });
        _enfocarZonaSiCorresponde();
      }
    } catch (e) {
      debugPrint("Error cargando datos: $e");
      if (mounted) {
        setState(() => _isLoadingMapData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudieron cargar los datos del mapa"),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // UBICACIÓN + PERMISOS (primera obtención)
  // ---------------------------------------------------------------------
  Future<void> _getLocation() async {
    setState(() => _isLoadingLocation = true);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showLocationDialog(
          titulo: "Ubicación desactivada",
          mensaje:
          "Activa el GPS de tu dispositivo para ver tu posición en el mapa.",
          textoBoton: "Abrir ajustes",
          onPressed: () => Geolocator.openLocationSettings(),
        );
      }
      return;
    }

    LocationPermission permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();

      if (permiso == LocationPermission.denied) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Permiso de ubicación denegado"),
            ),
          );
        }
        return;
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showLocationDialog(
          titulo: "Permiso bloqueado",
          mensaje: "Has denegado el permiso de ubicación permanentemente. "
              "Actívalo manualmente desde los ajustes de la app.",
          textoBoton: "Abrir ajustes de la app",
          onPressed: () => Geolocator.openAppSettings(),
        );
      }
      return;
    }

    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(posicion.latitude, posicion.longitude);
          _isLoadingLocation = false;
        });
        _mapController.move(_currentLocation, 15);
      }
    } catch (e) {
      debugPrint("Error obteniendo ubicación: $e");
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _showLocationDialog({
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
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

  // Nota: el color y la etiqueta de estado de zona ahora viven en
  // zone_utils.dart (getZoneColor / getZoneLabel) para que el mapa y el
  // ranking de zonas siempre se vean consistentes entre sí.

  // ---------------------------------------------------------------------
  // ENFOCAR ZONA (cuando se llega desde el ranking u otra pantalla)
  // ---------------------------------------------------------------------
  void _enfocarZonaSiCorresponde() {
    final foco = widget.focusZona;
    if (foco == null) return;

    // Si tenemos el id, buscamos la versión completa del sitio ya cargado.
    Map<String, dynamic> zonaCompleta = foco;
    final id = foco['id_zona'] ?? foco['id'];
    if (id != null) {
      zonaCompleta = _zonas.firstWhere(
            (z) => (z['id_zona'] ?? z['id']).toString() == id.toString(),
        orElse: () => foco,
      );
    }

    double? lat;
    double? lng;
    try {
      lat = double.parse(zonaCompleta['latitud'].toString());
      lng = double.parse(zonaCompleta['longitud'].toString());
    } catch (_) {
      return; // sin coordenadas válidas no podemos centrar el mapa
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(LatLng(lat!, lng!), 16);
      _mostrarInfoZona(zonaCompleta);
    });
  }

  // ---------------------------------------------------------------------
  // DELIMITACIÓN DE SITIO
  // Si el backend envía zona['poligono'] (lista de puntos {lat,lng} o
  // [lat,lng]), se dibuja el contorno real del área. Si no existe (caso
  // normal ahora, ya que los sitios son dinámicos), se usa un círculo
  // aproximado ("la sombra") como respaldo.
  // ---------------------------------------------------------------------
  List<LatLng>? _parsePoligono(Map<String, dynamic> zona) {
    final raw = zona['poligono'];
    if (raw == null || raw is! List || raw.isEmpty) return null;

    try {
      return raw.map<LatLng>((punto) {
        if (punto is Map) {
          final lat = double.parse(punto['lat'].toString());
          final lng = double.parse(punto['lng'].toString());
          return LatLng(lat, lng);
        } else if (punto is List && punto.length >= 2) {
          return LatLng(
            double.parse(punto[0].toString()),
            double.parse(punto[1].toString()),
          );
        }
        throw const FormatException('Formato de punto de polígono inválido');
      }).toList();
    } catch (e) {
      debugPrint("Polígono inválido para zona ${zona['nombre']}: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // VOTAR SOBRE UN REPORTE PUNTUAL (estilo Waze)
  // 'confirmar' = sigue sucio, se puede votar desde cualquier lugar.
  // 'limpiar'   = ya está limpio; el backend EXIGE estar físicamente
  //               cerca (valida distancia con tu GPS actual) y, si se
  //               acumulan suficientes confirmaciones, el reporte se
  //               marca Resuelto y desaparece del mapa automáticamente.
  // ---------------------------------------------------------------------
  Future<void> _votarReporte(dynamic idReporte, String tipo) async {
    if (Navigator.canPop(context)) Navigator.pop(context);

    try {
      final resultado = await ApiService.votarReporte(
        idReporte,
        tipo,
        _currentLocation.latitude,
        _currentLocation.longitude,
      );

      if (!mounted) return;
      final resuelto = resultado['resuelto'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['mensaje']?.toString() ??
              (tipo == 'limpiar'
                  ? "¡Gracias por confirmar!"
                  : "Reporte confirmado.")),
          backgroundColor: resuelto
              ? Colors.green[700]
              : (tipo == 'limpiar' ? Colors.green[700] : Colors.red[700]),
        ),
      );

      _cargarDatos();
    } catch (e) {
      debugPrint("Error votando reporte: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // ---------------------------------------------------------------------
  // TOQUE EN CUALQUIER PUNTO DEL MAPA
  // Permite reportar basura en cualquier lugar, no solo donde ya hay
  // un sitio marcado.
  // ---------------------------------------------------------------------
  void _onMapTap(TapPosition tapPosition, LatLng punto) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "¿Qué quieres hacer en este punto?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final creado = await Navigator.pushNamed(
                    context,
                    '/crear_reporte',
                    arguments: {
                      'latitud': punto.latitude,
                      'longitud': punto.longitude,
                    },
                  );
                  if (creado == true) _cargarDatos();
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text("Reportar basura aquí"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EcoMap - Zonas"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: () => Navigator.pushNamed(context, '/ranking_zonas'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, "/settings"),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 13,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.ecomap",
              ),

              // Mapa de calor
              if (_heatMapData.isNotEmpty)
                HeatMapLayer(
                  heatMapDataSource:
                  InMemoryHeatMapDataSource(data: _heatMapData),
                  heatMapOptions: HeatMapOptions(
                    radius: 35,
                    minOpacity: 0.2,
                    gradient: {
                      0.25: Colors.blue,
                      0.55: Colors.green,
                      0.85: Colors.yellow,
                      1.0: Colors.red,
                    },
                  ),
                ),

              // Delimitación PRECISA (polígono real) cuando el backend la provee
              PolygonLayer(
                polygons: _zonas
                    .map((zona) {
                  final puntos = _parsePoligono(zona);
                  if (puntos == null) return null;
                  final puntuacion =
                  int.parse(zona['puntuacion'].toString());
                  final color = getZoneColor(puntuacion);
                  return Polygon(
                    points: puntos,
                    color: color.withValues(alpha: 0.28),
                    borderColor: color,
                    borderStrokeWidth: 2.5,
                  );
                })
                    .whereType<Polygon>()
                    .toList(),
              ),

              // "Sombra" (círculo) para los sitios dinámicos: aparece en
              // cualquier lugar donde haya reportes activos agrupados,
              // sin necesidad de una zona predefinida.
              CircleLayer(
                circles: _zonas
                    .where((zona) => _parsePoligono(zona) == null)
                    .map((zona) {
                  final lat = double.parse(zona['latitud'].toString());
                  final lng = double.parse(zona['longitud'].toString());
                  final radioKm = double.parse(zona['radio_km'].toString());
                  final puntuacion = int.parse(zona['puntuacion'].toString());
                  final color = getZoneColor(puntuacion);

                  return CircleMarker(
                    point: LatLng(lat, lng),
                    radius: radioKm * 1000,
                    useRadiusInMeter: true,
                    color: color.withValues(alpha: 0.25),
                    borderStrokeWidth: 2,
                    borderColor: color,
                  );
                }).toList(),
              ),

              // Etiquetas con el nombre y estado de cada sitio
              MarkerLayer(
                markers: _zonas.map((zona) {
                  final lat = double.parse(zona['latitud'].toString());
                  final lng = double.parse(zona['longitud'].toString());
                  final nombre = zona['nombre']?.toString() ?? 'Sitio reportado';
                  final puntuacion = int.parse(zona['puntuacion'].toString());
                  final color = getZoneColor(puntuacion);

                  return Marker(
                    point: LatLng(lat, lng),
                    width: 140,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _mostrarInfoZona(zona),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color, width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 5),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    nombre,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            puntuacion.toString(),
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              backgroundColor: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Marcador AVANZADO de ubicación actual (pulso + rumbo)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    child: _CurrentLocationMarker(heading: _currentHeading),
                  ),
                ],
              ),
            ],
          ),

          // Leyenda de colores en la esquina superior izquierda
          const Positioned(
            top: 12,
            left: 12,
            child: _ZoneLegend(),
          ),

          if (_isLoadingMapData || _isLoadingLocation)
            const Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btn_gps",
            backgroundColor: Colors.white,
            foregroundColor: primaryColor,
            mini: true,
            onPressed: _getLocation,
            child: const Icon(Icons.gps_fixed),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "btn_reportar",
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            onPressed: () async {
              final creado = await Navigator.pushNamed(
                context,
                '/crear_reporte',
                arguments: {
                  'latitud': _currentLocation.latitude,
                  'longitud': _currentLocation.longitude,
                },
              );
              if (creado == true) _cargarDatos();
            },
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Nuevo Reporte',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // FICHA DE UN SITIO: trae los reportes reales que lo componen y
  // permite votar en el más cercano, en vez de votar sobre una zona
  // fija abstracta.
  // ---------------------------------------------------------------------
  void _mostrarInfoZona(Map<String, dynamic> zona) async {
    final puntuacion = int.parse(zona['puntuacion'].toString());
    final color = getZoneColor(puntuacion);
    final estado = getZoneLabel(puntuacion);
    final lat = double.parse(zona['latitud'].toString());
    final lng = double.parse(zona['longitud'].toString());
    final radioKm = zona['radio_km'] != null
        ? double.parse(zona['radio_km'].toString())
        : _radioBusquedaSitioKm;

    List<dynamic> reportesCercanos = [];
    try {
      reportesCercanos = await ApiService.getReportesCercanos(
        lat,
        lng,
        radioKm: math.max(radioKm, _radioBusquedaSitioKm),
      );
    } catch (e) {
      debugPrint("Error cargando reportes cercanos: $e");
    }

    // El reporte más cercano a MI ubicación actual es el que se usa
    // para "ya está limpia", porque ese voto exige cercanía real.
    dynamic reporteMasCercanoAMi;
    double? menorDistancia;
    for (final r in reportesCercanos) {
      final d = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        double.parse(r['latitud'].toString()),
        double.parse(r['longitud'].toString()),
      );
      if (menorDistancia == null || d < menorDistancia) {
        menorDistancia = d;
        reporteMasCercanoAMi = r;
      }
    }
    // Para "sigue sucio" alcanza con confirmar el reporte más cercano
    // al centro del sitio (se puede votar desde lejos).
    final reporteParaConfirmar =
    reportesCercanos.isNotEmpty ? reportesCercanos.first : null;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zona['nombre']?.toString() ?? 'Sitio reportado',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("Estado: $estado",
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            Text("Puntuación: $puntuacion"),
            Text("Reportes activos aquí: ${reportesCercanos.length}"),
            const SizedBox(height: 20),
            const Text(
              "¿Cómo está esta zona ahora?",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (reportesCercanos.isEmpty)
              const Text(
                "Ya no hay reportes activos en este punto.",
                style: TextStyle(color: Colors.grey),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        side: BorderSide(color: Colors.red[700]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: reporteParaConfirmar == null
                          ? null
                          : () => _votarReporte(
                          reporteParaConfirmar['id_reporte'], 'confirmar'),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Sigue sucio"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: reporteMasCercanoAMi == null
                          ? null
                          : () => _votarReporte(
                          reporteMasCercanoAMi['id_reporte'], 'limpiar'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Ya está limpia"),
                    ),
                  ),
                ],
              ),
            if (reportesCercanos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "\"Ya está limpia\" solo se acepta si estás físicamente cerca del sitio.",
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// MARCADOR AVANZADO DE UBICACIÓN ACTUAL
// Halo con efecto de pulso (radar) + cono de dirección si hay rumbo (heading)
// ===========================================================================
class _CurrentLocationMarker extends StatefulWidget {
  final double? heading;
  const _CurrentLocationMarker({this.heading});

  @override
  State<_CurrentLocationMarker> createState() =>
      _CurrentLocationMarkerState();
}

class _CurrentLocationMarkerState extends State<_CurrentLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulseValue = _controller.value; // 0..1
        return Stack(
          alignment: Alignment.center,
          children: [
            // Onda de pulso expandiéndose (efecto radar)
            Opacity(
              opacity: (1 - pulseValue).clamp(0.0, 1.0),
              child: Container(
                width: 20 + (pulseValue * 50),
                height: 20 + (pulseValue * 50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withValues(alpha: 0.35),
                ),
              ),
            ),
            // Cono de dirección, solo si conocemos el rumbo
            if (widget.heading != null)
              Transform.rotate(
                angle: widget.heading! * math.pi / 180,
                child: CustomPaint(
                  size: const Size(46, 46),
                  painter: _DirectionConePainter(),
                ),
              ),
            // Halo blanco de fondo
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
            // Punto azul central
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DirectionConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final path = ui.Path()
      ..moveTo(center.dx, center.dy - size.height / 2)
      ..lineTo(center.dx - 9, center.dy - 6)
      ..lineTo(center.dx + 9, center.dy - 6)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===========================================================================
// LEYENDA DE COLORES DE ZONA
// ===========================================================================
class _ZoneLegend extends StatelessWidget {
  const _ZoneLegend();

  @override
  Widget build(BuildContext context) {
    final items = [
      ("Muy sucia", const Color(0xFFD32F2F)),
      ("Sucia", const Color(0xFFF57C00)),
      ("Regular", const Color(0xFFFBC02D)),
      ("Limpia", const Color(0xFF8BC34A)),
      ("Muy limpia", const Color(0xFF2E7D32)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: items
            .map(
              (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: item.$2, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  item.$1,
                  style:
                  const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}
