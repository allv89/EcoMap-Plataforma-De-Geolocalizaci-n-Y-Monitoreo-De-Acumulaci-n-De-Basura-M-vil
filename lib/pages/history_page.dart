import 'package:flutter/material.dart';
import 'api_service.dart'; // 👇 Asegúrate de que la ruta sea correcta

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<dynamic> _reportes = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Idealmente, este endpoint debería consultar tu vista 'vw_reportes_completos'
      final data = await ApiService.getMisReportes();
      if (mounted) {
        setState(() {
          _reportes = data;
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

  // Método auxiliar para dar color según el ENUM 'estado' de tu base de datos
  Color _getColorPorEstado(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'resuelto':
        return Colors.green;
      case 'en proceso':
        return Colors.orange;
      case 'pendiente':
      default:
        return Colors.redAccent;
    }
  }

  // Método auxiliar para el ícono.
  // Nota: Si tu tabla 'categorias' trae el nombre de la categoría, este método lo evalúa.
  IconData _getIconoPorCategoria(String? categoria) {
    if (categoria == null) return Icons.eco;
    if (categoria.toLowerCase().contains('basura')) return Icons.delete_outline;
    if (categoria.toLowerCase().contains('agua')) return Icons.water_drop_outlined;
    if (categoria.toLowerCase().contains('árbol') || categoria.toLowerCase().contains('arbol')) return Icons.park_outlined;
    return Icons.report_problem_outlined;
  }

  // Método auxiliar para limpiar el DATETIME de la base de datos
  String _formatearFecha(String? fechaStr) {
    if (fechaStr == null) return 'Fecha desconocida';
    try {
      final date = DateTime.parse(fechaStr);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      return fechaStr; // Devuelve el texto original si falla el parseo
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromRGBO(23, 76, 40, 1);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mis Reportes'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(primaryColor),
    );
  }

  Widget _buildBody(Color primaryColor) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_outlined, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargarHistorial,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: const Text('Reintentar conexión', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    if (_reportes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargarHistorial,
        color: primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aún no has realizado ningún reporte.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarHistorial,
      color: primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _reportes.length,
        itemBuilder: (context, index) {
          final reporte = _reportes[index];

          // Match exacto con las columnas de tu DB / Vistas
          final idReporte = reporte['id_reporte'];
          final titulo = reporte['titulo'] ?? 'Reporte sin título';
          final estado = reporte['estado'] ?? 'Pendiente';
          // Asumiendo que tu vista trae el nombre de la categoría, no solo el id_categoria
          final categoria = reporte['categoria'] ?? 'General';
          final fechaStr = reporte['fecha_reporte'];

          final fechaFormateada = _formatearFecha(fechaStr);

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: _getColorPorEstado(estado).withOpacity(0.1),
                child: Icon(
                  _getIconoPorCategoria(categoria),
                  color: _getColorPorEstado(estado),
                ),
              ),
              title: Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Estado: $estado • $fechaFormateada'),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                // Listo para conectar con la pantalla de detalles usando el id_reporte
                /* Navigator.pushNamed(
                  context,
                  '/detalle_reporte',
                  arguments: idReporte,
                ); */
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Abriendo detalles del reporte #$idReporte...')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}