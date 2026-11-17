import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://e654-181-197-127-209.ngrok-free.app/api';

  // Token JWT después del login
  static String? token;

  // ─────────────────────────────────────────────────
  // AUTENTICACIÓN
  // ─────────────────────────────────────────────────

  /// Login normal con correo y contraseña.
  /// El backend debe ejecutar el procedimiento sp_login y devolver un JWT.
  static Future<Map<String, dynamic>> login(String correo, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      token = data['token'];
      return data; // esperamos { token: "jwt...", usuario: {...} }
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? 'Credenciales incorrectas');
    }
  }

  /// Registro de nuevo usuario.
  /// Se envía nombre, apellido, correo y password.
  /// El backend debe ejecutar sp_registrar_usuario.
  static Future<Map<String, dynamic>> register(
      String nombre, String apellido, String correo, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'apellido': apellido,
        'correo': correo,
        'password': password, // El backend hashea antes de insertar
        'tipo_cuenta': 'normal',
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? 'Error al registrar');
    }
  }

  /// Login con Google. Envía idToken al backend.
  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      token = data['token'];
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? 'Error al autenticar con Google');
    }
  }

  /// Solicitar recuperación de contraseña (envía token al correo).
  static Future<void> solicitarRecuperacion(String correo) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/recuperar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo}),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? 'Error al solicitar recuperación');
    }
  }

  // ─────────────────────────────────────────────────
  // REPORTES
  // ─────────────────────────────────────────────────

  /// Crear un nuevo reporte (con o sin foto).
  /// Coincide con el procedimiento sp_crear_reporte.
  static Future<Map<String, dynamic>> crearReporte({
    required String titulo,
    required String descripcion,
    required String idCategoria,
    required double latitud,
    required double longitud,
    String direccion = '',  // puede venir de geocodificación inversa
    File? imagen,
  }) async {
    final uri = Uri.parse('$baseUrl/reportes');
    final request = http.MultipartRequest('POST', uri);

    // Headers
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Campos de texto
    request.fields['titulo'] = titulo;
    request.fields['descripcion'] = descripcion;
    request.fields['id_categoria'] = idCategoria;
    request.fields['latitud'] = latitud.toString();
    request.fields['longitud'] = longitud.toString();
    request.fields['direccion'] = direccion;

    // Imagen opcional
    if (imagen != null) {
      request.files.add(await http.MultipartFile.fromPath('foto', imagen.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final jsonResponse = jsonDecode(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonResponse;
    } else {
      throw Exception(jsonResponse['mensaje'] ?? 'Error al crear el reporte');
    }
  }

  /// Obtener los reportes del usuario autenticado.
  /// El backend debe llamar a sp_obtener_reportes_usuario (usa token para obtener id_usuario).
  static Future<List<dynamic>> getMisReportes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reportes/mis-reportes'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // El backend puede devolver { reportes: [...] } o directamente una lista
      return data['reportes'] ?? data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['mensaje'] ?? 'Error al cargar el historial');
    }
  }

  /// Obtener todas las ubicaciones para el mapa (lat, lng, peso).
  /// Solo incluye reportes activos (no resueltos).
  static Future<List<dynamic>> getUbicacionesReportes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reportes/ubicaciones'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar las ubicaciones para el mapa');
    }
  }

  /// Todos los reportes activos (no resueltos), con conteo de votos.
  /// Útil para construir listados o clustering personalizado en el cliente.
  static Future<List<dynamic>> getReportesActivos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reportes/activos'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar los reportes activos');
    }
  }

  /// Reportes activos dentro de un radio (km) alrededor de un punto.
  /// Se usa para mostrar qué reportes componen un "sitio" del mapa.
  static Future<List<dynamic>> getReportesCercanos(
      double lat,
      double lng, {
        double radioKm = 0.2,
      }) async {
    final uri = Uri.parse('$baseUrl/reportes/cercanos').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radio_km': radioKm.toString(),
      },
    );

    final response = await http.get(uri, headers: {'Content-Type': 'application/json'});

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar los reportes cercanos');
    }
  }

  /// Votar sobre un reporte puntual, estilo Waze.
  /// tipo = 'confirmar' (sigue sucio, se puede votar desde cualquier lugar)
  ///      o 'limpiar' (ya está limpio; el backend EXIGE que lat/lng estén
  ///      físicamente cerca del reporte, o rechaza el voto con 403).
  /// Al alcanzar el número necesario de confirmaciones de 'limpiar',
  /// el backend marca el reporte como Resuelto y lo quita del mapa.
  static Future<Map<String, dynamic>> votarReporte(
      dynamic idReporte,
      String tipo,
      double lat,
      double lng,
      ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reportes/$idReporte/votar'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'tipo': tipo, 'latitud': lat, 'longitud': lng}),
    );

    final jsonResponse = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonResponse;
    } else {
      throw Exception(jsonResponse['mensaje'] ?? 'Error al votar en el reporte');
    }
  }

  // ─────────────────────────────────────────────────
  // PERFIL Y ESTADÍSTICAS
  // ─────────────────────────────────────────────────

  /// Obtener perfil del usuario autenticado (datos + estadísticas).
  /// El backend debe unir USUARIOS y ESTADISTICAS.
  static Future<Map<String, dynamic>> getPerfil() async {
    final response = await http.get(
      Uri.parse('$baseUrl/perfil'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar el perfil');
    }
  }

  /// Obtener ranking de usuarios (puntos, nivel, reportes).
  /// El backend usa la vista vw_top_usuarios o sp_ranking.
  static Future<List<dynamic>> getRanking() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ranking'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : data['ranking'];
    } else {
      throw Exception('Error al cargar el ranking');
    }
  }

  /// Tendencia de limpieza (datos históricos).
  /// Necesita implementación personalizada en el backend.
  static Future<List<double>> getTendenciaLimpieza() async {
    final response = await http.get(
      Uri.parse('$baseUrl/estadisticas/tendencia'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return List<double>.from(jsonDecode(response.body));
    }
    // valores por defecto para evitar errores en la UI
    return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  }

  /// Obtener todos los "sitios" con sus puntuaciones.
  /// Ya NO son zonas fijas: se calculan dinámicamente agrupando los
  /// reportes activos por cercanía, en cualquier parte del mapa.
  static Future<List<dynamic>> getZonas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/zonas'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar zonas');
    }
  }

  /// Ranking de sitios (dinámico, calculado igual que getZonas()).
  static Future<List<dynamic>> getRankingZonas() async {
    final response = await http.get(
      Uri.parse('$baseUrl/zonas/ranking'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar ranking de zonas');
    }
  }

  // ─────────────────────────────────────────────────
  // CATEGORÍAS
  // ─────────────────────────────────────────────────

  /// Obtener la lista de categorías de la tabla CATEGORIAS.
  static Future<List<dynamic>> getCategorias() async {
    final response = await http.get(
      Uri.parse('$baseUrl/categorias'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is List ? data : data['categorias'];
    } else {
      throw Exception('Error al cargar las categorías');
    }
  }
}
