/// Órdenes de voz que entiende la aplicación.
enum Comando { anadir, borrar, leer, ayuda, desconocido }

/// Palabra (ya normalizada: minúsculas y sin tildes) -> orden.
const Map<String, Comando> _sinonimos = {
  // añadir
  'anadir': Comando.anadir,
  'anade': Comando.anadir,
  'nuevo': Comando.anadir,
  'crear': Comando.anadir,
  // borrar
  'borrar': Comando.borrar,
  'borra': Comando.borrar,
  'eliminar': Comando.borrar,
  'quitar': Comando.borrar,
  // leer
  'leer': Comando.leer,
  'lee': Comando.leer,
  'cuantos': Comando.leer,
  'lista': Comando.leer,
  // ayuda
  'ayuda': Comando.ayuda,
  'comandos': Comando.ayuda,
};

/// Pasa a minúsculas y quita tildes y diéresis (la «ñ» pasa a «n»), de modo
/// que «Añade», «anade» y «AÑADE» den el mismo texto.
String normalizar(String texto) {
  const origen = 'áàäâéèëêíìïîóòöôúùüûñ';
  const destino = 'aaaaeeeeiiiioooouuuun';
  final buffer = StringBuffer();
  for (final rune in texto.toLowerCase().runes) {
    final caracter = String.fromCharCode(rune);
    final i = origen.indexOf(caracter);
    buffer.write(i >= 0 ? destino[i] : caracter);
  }
  return buffer.toString();
}

/// Interpreta lo que ha dicho el usuario.
///
/// Reconoce la orden aunque vaya dentro de una frase («por favor añade uno»).
/// Si hay varias palabras de orden, gana la primera que se pronuncia.
/// Cualquier otra cosa, o el texto vacío, es [Comando.desconocido].
Comando interpretarComando(String texto) {
  final palabras = normalizar(texto)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((palabra) => palabra.isNotEmpty);
  for (final palabra in palabras) {
    final comando = _sinonimos[palabra];
    if (comando != null) return comando;
  }
  return Comando.desconocido;
}
