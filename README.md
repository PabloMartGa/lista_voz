# Actividad 1 · Lista controlada por voz

**Módulo:** 0488 Desarrollo de interfaces · 2º DAM · **UT2** Generación de interfaces naturales
**Criterios:** RA2.b (interfaz natural) y RA2.c (reconocimiento de voz)

App Flutter con una lista de elementos que se maneja con la voz: se pulsa el micrófono, se dice una orden y la app la ejecuta y responde en voz alta. Todo lo que se hace con la voz se puede hacer también con botones.

## Puesta en marcha

Este `.zip` contiene el código (`lib/`, `test/`), el `pubspec.yaml` y el `AndroidManifest.xml` ya configurado. Las carpetas de plataforma (Gradle, iOS…) las genera Flutter:

```bash
cd lista_voz
flutter create --project-name lista_voz --platforms=android,ios .
rm -f test/widget_test.dart      # test de ejemplo del generador; no aplica a esta app
flutter pub get
flutter test                      # pruebas unitarias de comandos.dart
flutter run                       # con un móvil Android conectado
```

Paquetes usados: `speech_to_text` y `flutter_tts`.

## Estructura

| Archivo | Contenido |
| --- | --- |
| `lib/comandos.dart` | `enum Comando` y `interpretarComando(String)` en Dart puro: sin mayúsculas ni tildes, sinónimos, orden dentro de una frase, `desconocido` por defecto. |
| `lib/main.dart` | Pantalla principal: `SpeechToText`, `FlutterTts`, lista, panel de transcripción, botones táctiles y micrófono. |
| `test/comandos_test.dart` | 10 pruebas unitarias (mayúsculas/tildes, cada grupo de sinónimos, frases, puntuación, desconocidos, vacío). |
| `android/app/src/main/AndroidManifest.xml` | Permisos de micrófono y consultas a los servicios de voz. |

## Qué cumple cada punto del enunciado

- **Órdenes** (paso 2): `añadir`, `borrar`, `leer`, `ayuda` y sus sinónimos; reconoce la orden dentro de una frase («por favor añade uno»).
- **Voz** (paso 3): `initialize()` guarda si hay reconocimiento; `setLanguage('es-ES')`; `listen()` con `localeId: 'es_ES'` y `listenFor` de 5 s; `onResult` muestra `recognizedWords` mientras se habla y ejecuta la orden cuando `finalResult` es `true`. Respuestas habladas: «Añadido el elemento 3», «Borrado el elemento 3» / «La lista está vacía», «Hay 3 elementos» y la ayuda con la lista de órdenes.
- **Feedback visible**: el micrófono cambia de icono (`mic_none` → `mic`) y de color (primario → rojo) mientras escucha; debajo se ve la transcripción, la última orden y la respuesta (también como texto, para quien no pueda oírla).
- **Orden no entendida**: `SnackBar` con «No he entendido «hola». Di «ayuda» para oír las órdenes».
- **Sin permiso o sin servicio**: el micrófono queda deshabilitado, con un aviso que explica el motivo (permiso denegado o servicio no disponible); los botones siguen funcionando.
- **Alternativa táctil**: botones Añadir, Borrar y Leer que ejecutan las mismas funciones que la voz. Todos los botones, el micrófono incluido, tienen tooltip.
- **Liberar recursos**: `dispose()` cancela el reconocimiento y detiene la síntesis.
- **Ampliación**: un `DropdownMenu` con los idiomas que devuelve `locales()` cambia el idioma de reconocimiento y de respuesta. Las órdenes que interpreta `comandos.dart` están en español, así que con otro idioma habría que añadir sus sinónimos.

## Reflexión

### 1. ¿Reconocimiento en el dispositivo o en un servidor?

✍️ **Mi prueba en modo avión:** _(escribe aquí si la app siguió reconociendo la voz o falló, y con qué mensaje de error)._

Lo habitual en Android es que `speech_to_text` use el reconocedor del sistema (normalmente el de Google). Ese servicio **envía el audio a un servidor** salvo que el usuario haya descargado el paquete de idioma sin conexión; en ese caso reconoce en el dispositivo. Por eso el resultado en modo avión depende del móvil y del idioma descargado: si falla, lo más probable es que fuera reconocimiento en la nube.

Con los criterios de la unidad:

- **Privacidad:** en la nube, el audio (datos personales) sale del móvil y lo trata un tercero; en el dispositivo, no sale. Por eso la app solo pide el permiso cuando se pulsa el micrófono y no guarda ningún audio.
- **Coste:** el reconocimiento en la nube suele ser gratuito para el usuario final, pero no es gratis para quien lo ofrece. Si una app propia usara una API de voz de pago, se facturaría por uso. En el dispositivo no hay coste por petición, pero sí consume CPU y batería, y ocupa espacio del paquete de idioma.
- **Latencia:** en la nube depende de la red, añade retardo y se rompe sin cobertura. En el dispositivo la respuesta es más estable y funciona sin conexión, aunque el modelo local puede ser menos preciso.
- **Plataforma:** depende del sistema operativo y del fabricante. Android delega en el servicio de reconocimiento instalado (por eso las `<queries>` del manifest), iOS usa el reconocedor de Apple (en el dispositivo o en servidores según idioma y versión), y en emuladores o móviles sin servicios de Google puede no haber reconocedor.

### 2. Dos situaciones en las que no se puede usar la voz

1. **Entornos donde no se puede hablar o hay mucho ruido** (biblioteca, reunión, calle con tráfico), o **usuarios con dificultades del habla**: la app ofrece los botones Añadir, Borrar y Leer, que hacen exactamente lo mismo.
2. **Sin permiso de micrófono, sin servicio de reconocimiento o sin conexión** (cuando el reconocedor es de la nube): el micrófono se deshabilita y un texto explica por qué; la app sigue funcionando por completo con botones. Además, toda respuesta hablada se muestra también en pantalla, para quien no pueda oírla (sordera, sin sonido).
