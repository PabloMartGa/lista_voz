import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'comandos.dart';

void main() => runApp(const ListaVozApp());

class ListaVozApp extends StatelessWidget {
  const ListaVozApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista por voz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
      ),
      home: const PantallaLista(),
    );
  }
}

class PantallaLista extends StatefulWidget {
  const PantallaLista({super.key});

  @override
  State<PantallaLista> createState() => _PantallaListaState();
}

class _PantallaListaState extends State<PantallaLista> {
  final SpeechToText _voz = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  /// Los elementos de la lista («Elemento 1», «Elemento 2»...).
  final List<String> _elementos = [];

  // Estado del reconocimiento de voz.
  bool _inicializando = true;
  bool _vozDisponible = false;
  String _motivoNoDisponible = '';
  bool _escuchando = false;

  /// Evita ejecutar dos veces la misma orden (resultado final + error tardío).
  bool _ordenProcesada = true;

  // Lo que se muestra en pantalla.
  String _transcripcion = '';
  String _ultimaOrden = '—';
  String _ultimaRespuesta = '—';

  // Ampliación: idioma de reconocimiento y de respuesta.
  List<LocaleName> _idiomas = [];
  String _idiomaId = 'es_ES';

  @override
  void initState() {
    super.initState();
    _iniciarVoz();
  }

  @override
  void dispose() {
    // Paso 4: liberar recursos.
    unawaited(_voz.cancel());
    unawaited(_tts.stop());
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Inicialización
  // ---------------------------------------------------------------------------

  Future<void> _iniciarVoz() async {
    // Síntesis de voz: si falla, la app sigue funcionando en modo visual.
    try {
      await _tts.setLanguage('es-ES');
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}

    // Reconocimiento de voz.
    var disponible = false;
    try {
      disponible = await _voz.initialize(
        onStatus: _alCambiarEstado,
        onError: _alHaberError,
      );
    } catch (_) {
      disponible = false;
    }

    var motivo = '';
    var idiomas = <LocaleName>[];
    var idiomaId = _idiomaId;

    if (disponible) {
      try {
        idiomas = await _voz.locales();
      } catch (_) {}
      // Si el móvil no ofrece es_ES, usa otra variante del español si existe.
      if (idiomas.isNotEmpty && !idiomas.any((l) => l.localeId == idiomaId)) {
        for (final l in idiomas) {
          if (l.localeId.startsWith('es')) {
            idiomaId = l.localeId;
            break;
          }
        }
      }
    } else {
      var hayPermiso = false;
      try {
        hayPermiso = await _voz.hasPermission;
      } catch (_) {}
      motivo = hayPermiso
          ? 'Este dispositivo no tiene un servicio de reconocimiento de voz '
              'disponible.'
          : 'No has dado permiso para usar el micrófono. Actívalo en los '
              'ajustes del sistema.';
    }

    if (!mounted) return;
    setState(() {
      _inicializando = false;
      _vozDisponible = disponible;
      _motivoNoDisponible = motivo;
      _idiomas = idiomas;
      _idiomaId = idiomaId;
    });
  }

  void _alCambiarEstado(String estado) {
    if (!mounted) return;
    if (estado == 'listening') {
      setState(() => _escuchando = true);
    } else if (estado == 'notListening' || estado == 'done') {
      setState(() => _escuchando = false);
    }
  }

  void _alHaberError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() => _escuchando = false);
    // Si ya se ha procesado una orden, el error es solo un cierre tardío.
    if (_ordenProcesada) return;
    _ordenProcesada = true;
    final sinVoz = error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout';
    _avisar(sinVoz
        ? 'No he oído nada. Pulsa el micrófono e inténtalo de nuevo.'
        : 'Ha fallado el reconocimiento de voz (${error.errorMsg}). '
            'Puedes usar los botones.');
  }

  // ---------------------------------------------------------------------------
  // Escucha
  // ---------------------------------------------------------------------------

  Future<void> _alternarEscucha() async {
    if (_escuchando) {
      await _voz.stop();
      return;
    }
    // Que la app no se oiga a sí misma.
    await _tts.stop();
    _ordenProcesada = false;
    setState(() {
      _transcripcion = '';
      _escuchando = true;
    });
    try {
      await _voz.listen(
        onResult: _alRecibirResultado,
        localeId: _idiomaId,
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _escuchando = false);
      _avisar('No se ha podido empezar a escuchar. Usa los botones.');
    }
  }

  void _alRecibirResultado(SpeechRecognitionResult resultado) {
    if (!mounted) return;
    // Mientras se habla se ve lo que se va reconociendo.
    setState(() => _transcripcion = resultado.recognizedWords);
    if (resultado.finalResult && !_ordenProcesada) {
      _ordenProcesada = true;
      _procesarOrden(resultado.recognizedWords);
    }
  }

  // ---------------------------------------------------------------------------
  // Órdenes (las usan por igual la voz y los botones)
  // ---------------------------------------------------------------------------

  void _procesarOrden(String texto) {
    final oido = texto.trim();
    if (oido.isEmpty) {
      _avisar('No he oído nada. Pulsa el micrófono e inténtalo de nuevo.');
      return;
    }
    final comando = interpretarComando(oido);
    setState(() => _ultimaOrden = _nombreOrden(comando));
    switch (comando) {
      case Comando.anadir:
        _anadir();
      case Comando.borrar:
        _borrar();
      case Comando.leer:
        _leer();
      case Comando.ayuda:
        _ayuda();
      case Comando.desconocido:
        _avisar('No he entendido «$oido». Di «ayuda» para oír las órdenes');
        _decir('No te he entendido. Di ayuda para oír las órdenes.');
    }
  }

  String _nombreOrden(Comando comando) {
    switch (comando) {
      case Comando.anadir:
        return 'añadir';
      case Comando.borrar:
        return 'borrar';
      case Comando.leer:
        return 'leer';
      case Comando.ayuda:
        return 'ayuda';
      case Comando.desconocido:
        return 'no reconocida';
    }
  }

  void _anadir() {
    setState(() => _elementos.add('Elemento ${_elementos.length + 1}'));
    _decir('Añadido el elemento ${_elementos.length}');
  }

  void _borrar() {
    if (_elementos.isEmpty) {
      _decir('La lista está vacía');
      return;
    }
    final numero = _elementos.length;
    setState(() => _elementos.removeLast());
    _decir('Borrado el elemento $numero');
  }

  void _leer() {
    final n = _elementos.length;
    if (n == 0) {
      _decir('La lista está vacía');
    } else if (n == 1) {
      _decir('Hay 1 elemento');
    } else {
      _decir('Hay $n elementos');
    }
  }

  void _ayuda() {
    _decir('Las órdenes son: añadir, para crear un elemento; borrar, para '
        'quitar el último; leer, para saber cuántos hay; y ayuda.');
  }

  /// Muestra la respuesta en pantalla y la dice en voz alta.
  void _decir(String texto) {
    setState(() => _ultimaRespuesta = texto);
    unawaited(_hablar(texto));
  }

  Future<void> _hablar(String texto) async {
    try {
      await _tts.speak(texto);
    } catch (_) {
      // Sin síntesis de voz, la respuesta sigue visible en pantalla.
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Ampliación: cambiar el idioma de reconocimiento y de respuesta.
  Future<void> _cambiarIdioma(String? id) async {
    if (id == null) return;
    setState(() => _idiomaId = id);
    try {
      await _tts.setLanguage(id.replaceAll('_', '-'));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lista controlada por voz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_inicializando && !_vozDisponible) ...[
                _avisoSinVoz(tema),
                const SizedBox(height: 12),
              ],
              if (_vozDisponible && _idiomas.isNotEmpty) ...[
                _selectorIdioma(),
                const SizedBox(height: 12),
              ],
              Expanded(child: _lista(tema)),
              const SizedBox(height: 8),
              _panelEstado(tema),
              const SizedBox(height: 12),
              _botonesTactiles(),
              const SizedBox(height: 16),
              _botonMicrofono(tema),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avisoSinVoz(ThemeData tema) {
    return Card(
      color: tema.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.mic_off, color: tema.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$_motivoNoDisponible\nPuedes seguir usando la lista con los '
                'botones.',
                style: TextStyle(color: tema.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectorIdioma() {
    return DropdownMenu<String>(
      expandedInsets: EdgeInsets.zero,
      menuHeight: 280,
      label: const Text('Idioma de reconocimiento y de respuesta'),
      initialSelection:
          _idiomas.any((l) => l.localeId == _idiomaId) ? _idiomaId : null,
      dropdownMenuEntries: [
        for (final idioma in _idiomas)
          DropdownMenuEntry<String>(value: idioma.localeId, label: idioma.name),
      ],
      onSelected: _cambiarIdioma,
    );
  }

  Widget _lista(ThemeData tema) {
    if (_elementos.isEmpty) {
      return Center(
        child: Text(
          'La lista está vacía.\nDi «añadir» o pulsa el botón Añadir.',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyLarge,
        ),
      );
    }
    return ListView.builder(
      itemCount: _elementos.length,
      itemBuilder: (context, i) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(_elementos[i]),
        ),
      ),
    );
  }

  Widget _panelEstado(ThemeData tema) {
    final transcripcion = _transcripcion.isNotEmpty
        ? '«$_transcripcion»'
        : (_escuchando ? 'Escuchando…' : '—');
    return Card(
      color: tema.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transcripción: $transcripcion'),
            const SizedBox(height: 4),
            Text('Última orden: $_ultimaOrden'),
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text('Respuesta: $_ultimaRespuesta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonesTactiles() {
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: 'Añadir un elemento a la lista',
            child: FilledButton.tonalIcon(
              onPressed: _anadir,
              icon: const Icon(Icons.add),
              label: const Text('Añadir'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Tooltip(
            message: 'Borrar el último elemento',
            child: FilledButton.tonalIcon(
              onPressed: _borrar,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Borrar'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Tooltip(
            message: 'Leer cuántos elementos hay',
            child: FilledButton.tonalIcon(
              onPressed: _leer,
              icon: const Icon(Icons.record_voice_over),
              label: const Text('Leer'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _botonMicrofono(ThemeData tema) {
    final colores = tema.colorScheme;
    final String tooltip;
    final String texto;
    final IconData icono;
    final Color fondo;
    final Color frente;

    if (_inicializando) {
      tooltip = 'Preparando el micrófono';
      texto = 'Preparando el reconocimiento de voz…';
      icono = Icons.mic_none;
      fondo = colores.surfaceContainerHighest;
      frente = colores.onSurfaceVariant;
    } else if (!_vozDisponible) {
      tooltip = 'Micrófono no disponible';
      texto = 'Micrófono desactivado: $_motivoNoDisponible';
      icono = Icons.mic_off;
      fondo = colores.surfaceContainerHighest;
      frente = colores.onSurfaceVariant;
    } else if (_escuchando) {
      tooltip = 'Dejar de escuchar';
      texto = 'Escuchando… di una orden';
      icono = Icons.mic;
      fondo = colores.error;
      frente = colores.onError;
    } else {
      tooltip = 'Pulsa y di una orden';
      texto = 'Pulsa el micrófono y di «añadir», «borrar», «leer» o «ayuda»';
      icono = Icons.mic_none;
      fondo = colores.primary;
      frente = colores.onPrimary;
    }

    return Column(
      children: [
        FloatingActionButton.large(
          heroTag: 'microfono',
          tooltip: tooltip,
          backgroundColor: fondo,
          foregroundColor: frente,
          // Deshabilitado si no hay permiso, servicio o aún se inicializa.
          onPressed: (_vozDisponible && !_inicializando) ? _alternarEscucha : null,
          child: Icon(icono, size: 40),
        ),
        const SizedBox(height: 8),
        Text(texto, textAlign: TextAlign.center),
      ],
    );
  }
}
