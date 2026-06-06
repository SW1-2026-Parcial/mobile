import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/repositories/documento_repository.dart';
import '../../../domain/models/documento_model.dart';

/// Pantalla de documentos asociados a un trámite.
class DocumentosScreen extends StatefulWidget {
  final String tramiteId;
  final String? ticketNumber;

  const DocumentosScreen({
    super.key,
    required this.tramiteId,
    this.ticketNumber,
  });

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final DocumentoRepository _repo = DocumentoRepository();
  List<DocumentoModel> _documentos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
  }

  Future<void> _cargarDocumentos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _documentos = await _repo.getByTramiteId(widget.tramiteId);
    } catch (e) {
      _error = 'Error al cargar documentos';
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _subirDesdeGaleria() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      await _subirArchivo(File(image.path), image.name);
    }
  }

  Future<void> _subirDesdeCamara() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image != null) {
      await _subirArchivo(File(image.path), image.name);
    }
  }

  Future<void> _subirDesdeArchivos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'xlsx', 'png', 'jpg', 'jpeg'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      await _subirArchivo(file, result.files.single.name);
    }
  }

  Future<void> _subirArchivo(File file, String nombre) async {
    try {
      setState(() => _loading = true);
      await _repo.upload(
        tramiteId: widget.tramiteId,
        file: file,
        nombre: nombre,
      );
      await _cargarDocumentos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento subido correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _loading = false);
    }
  }

  void _mostrarOpcionesSubida() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF3F51B5)),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _subirDesdeCamara();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF3F51B5)),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                _subirDesdeGaleria();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFF3F51B5)),
              title: const Text('Archivo (PDF, Word, Excel)'),
              onTap: () {
                Navigator.pop(context);
                _subirDesdeArchivos();
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ticketNumber != null
              ? 'Docs — ${widget.ticketNumber}'
              : 'Documentos',
        ),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarOpcionesSubida,
        backgroundColor: const Color(0xFF3F51B5),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade600)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _cargarDocumentos,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_documentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Sin documentos',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Presiona + para subir uno',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDocumentos,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _documentos.length,
        separatorBuilder: (_c, _i) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final doc = _documentos[index];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade100,
                child: Icon(
                  _iconForExtension(doc.extension),
                  color: const Color(0xFF3F51B5),
                ),
              ),
              title: Text(
                doc.nombre,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${doc.sizeFormatted} • ${doc.extension.toUpperCase()}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Text(
                doc.extension.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
