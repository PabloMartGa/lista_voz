import 'package:flutter_test/flutter_test.dart';
import 'package:lista_voz/comandos.dart';

void main() {
  group('interpretarComando', () {
    test('no distingue mayúsculas ni tildes', () {
      expect(interpretarComando('Añade'), Comando.anadir);
      expect(interpretarComando('anade'), Comando.anadir);
      expect(interpretarComando('AÑADIR'), Comando.anadir);
      expect(interpretarComando('CUÁNTOS'), Comando.leer);
    });

    test('acepta los sinónimos de añadir', () {
      for (final palabra in ['añadir', 'añade', 'nuevo', 'crear']) {
        expect(interpretarComando(palabra), Comando.anadir, reason: palabra);
      }
    });

    test('acepta los sinónimos de borrar', () {
      for (final palabra in ['borrar', 'borra', 'eliminar', 'quitar']) {
        expect(interpretarComando(palabra), Comando.borrar, reason: palabra);
      }
    });

    test('acepta los sinónimos de leer', () {
      for (final palabra in ['leer', 'lee', 'cuántos', 'lista']) {
        expect(interpretarComando(palabra), Comando.leer, reason: palabra);
      }
    });

    test('acepta los sinónimos de ayuda', () {
      expect(interpretarComando('ayuda'), Comando.ayuda);
      expect(interpretarComando('comandos'), Comando.ayuda);
    });

    test('reconoce la orden dentro de una frase', () {
      expect(interpretarComando('por favor añade uno'), Comando.anadir);
      expect(interpretarComando('quiero que quita el último'), Comando.borrar);
      expect(interpretarComando('dime cuántos hay'), Comando.leer);
    });

    test('ignora los signos de puntuación', () {
      expect(interpretarComando('¡Borra!'), Comando.borrar);
      expect(interpretarComando('ayuda...'), Comando.ayuda);
    });

    test('lo que no es una orden es desconocido', () {
      expect(interpretarComando('hola'), Comando.desconocido);
      expect(interpretarComando('qué tiempo hace'), Comando.desconocido);
    });

    test('no confunde palabras parecidas con órdenes', () {
      expect(interpretarComando('listado'), Comando.desconocido);
      expect(interpretarComando('nuevamente'), Comando.desconocido);
    });

    test('el texto vacío o en blanco es desconocido', () {
      expect(interpretarComando(''), Comando.desconocido);
      expect(interpretarComando('   '), Comando.desconocido);
    });
  });
}
