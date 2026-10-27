# Inklet

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Italiano](README.it.md)

Sitio web: [getinklet.app](https://getinklet.app)

**Turn rough thoughts into clear text.**

**Inklet** es un asistente de escritura para macOS que convierte lo que escribes, pegas o dices en un texto claro, sin salir de la app que ya estás usando.

Abre el popover de escritura con el atajo global y escribe, pega o dicta en el mismo borrador de origen editable. El dictado en tiempo real se queda dentro del Asistente de escritura, así que puedes revisar la transcripción antes de decidir si transformarla o insertarla. En Macs con Apple silicon, las instalaciones nuevas reconocen la voz en tu Mac, de modo que tu voz nunca sale de él.

> Este documento es una traducción de [README.md](README.md), en inglés. Si hay diferencias, prevalece la versión en inglés.

## Instalación

GitHub Releases es el único canal de distribución oficial de Inklet. Descarga el DMG más reciente, firmado y notarizado, desde [GitHub Releases](https://github.com/wanming/Inklet/releases), ábrelo y copia Inklet en `/Applications`.

También puedes usar el script de instalación de abajo. El script descarga el DMG y la suma de comprobación más recientes de GitHub Releases, verifica la estructura del DMG, la suma de comprobación, la aceptación de Gatekeeper, el identificador del paquete, el Hardened Runtime, los entitlements efectivos y la firma de la app, y después copia Inklet en `/Applications`.

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

## Actualizaciones

Inklet usa GitHub Releases como única fuente de actualizaciones. Las versiones de producción consultan en GitHub los metadatos públicos de la última versión estable aproximadamente una vez cada 24 horas. Solo se anuncia una actualización cuando esa versión ya tiene un `Inklet.dmg` subido; **Ver en GitHub** abre la página exacta de esa versión. Inklet nunca descarga ni instala actualizaciones automáticamente.

Usa **Buscar actualizaciones…** en el menú de la app para comprobarlo manualmente, tanto en la app de producción como en Inklet Local. Inklet Local nunca programa comprobaciones automáticas. Los fallos de las comprobaciones automáticas no se muestran, mientras que una comprobación manual ofrece **Reintentar**. Si Inklet está ocupado con la escritura, el dictado, las acciones de selección, una migración, una ventana modal o un menú abierto, el aviso automático de actualización espera a que la app esté inactiva.

Después de actualizar, el primer inicio de la nueva versión muestra una vez una breve ventana de **Novedades**, cuando Inklet está inactivo y sin quitarle el foco a la app que estás usando. No aparece en una instalación nueva ni mientras está abierta la guía de bienvenida. **Historial de cambios**, en el menú de la barra de menús, muestra todas las versiones y resalta la que estás usando.

## Configuración inicial

1. Abre Inklet desde la carpeta Aplicaciones. Para una compilación desde el código fuente, ejecuta `scripts/run-local-app.sh` desde la raíz del repositorio y usa `/Applications/Inklet Local.app`.
2. Haz clic en el icono de Inklet en la barra de menús y abre **Ajustes**.
3. Concede el permiso de Accesibilidad cuando macOS lo pida. Inklet usa este único permiso genérico para leer selecciones, ejecutar el método alternativo de copia configurado, devolver el foco a la app anterior y pegar los resultados confirmados. Inklet permanece en segundo plano mientras Ajustes del Sistema está abierto y vuelve a los ajustes **General** cuando lo cierras.
4. En una instalación nueva, y una vez después de actualizar a esta versión, una guía de bienvenida te lleva por el idioma de la interfaz (las instalaciones nuevas siguen el idioma del sistema), Accesibilidad, el modelo de escritura, el micrófono para el Dictado en tiempo real y los atajos para abrir Inklet y dictar, y al final presenta la barra que aparece junto al texto seleccionado. Para recorrerla de nuevo cuando quieras, elige **Guía de bienvenida** en el menú de la barra de menús; cada paso parte de tus ajustes actuales. En Apple silicon sugiere **Integrado** con el modelo recomendado y lo descarga en segundo plano si lo mantienes; el popover de escritura muestra el progreso y funciona sin conexión cuando termina. Para usar un proveedor en la nube, elígelo en **Modelos de IA** e introduce su clave de API. Con OpenAI, la opción predeterminada en Macs Intel, una sola clave cubre la escritura, el dictado en tiempo real, la traducción de la selección y la pronunciación. Con cualquier otro proveedor, la escritura y la traducción de la selección usan ese proveedor, mientras que el dictado y la pronunciación, cuando eliges OpenAI para ellos, siguen necesitando una clave de API de OpenAI en la tarjeta Claves de API de esa misma página. Para ejecutar la escritura y la traducción en tu Mac sin ninguna clave, elige **Integrado** y descarga un modelo, o elige **Ollama** o **LM Studio** si ya usas alguno de ellos (consulta [Modelos locales](#modelos-locales)).
5. Configura el **Asistente de escritura** con el modelo, el atajo de escritura, los ajustes de generación y los modos de prompt que quieras usar. **Dictado en tiempo real** tiene su propia página en Ajustes: actívalo o desactívalo, elige **En este Mac** u **OpenAI** para el reconocimiento de voz y elige el atajo de mantener pulsado y el micrófono. En Apple silicon, las instalaciones nuevas usan **En este Mac** y la guía de bienvenida descarga su modelo de voz cuando activas el dictado ahí; las configuraciones existentes siguen con OpenAI hasta que cambies. Con OpenAI, **Dictado avanzado** solo expone el modelo de recuperación; el endpoint de recuperación no se puede editar. Inklet fija el modelo en tiempo real.
6. Opcional: configura el **Asistente de selección** con un idioma de traducción, el modo de **Selección forzada**, la voz y la velocidad de la pronunciación con IA, y escucha una muestra de la voz en Ajustes.
7. Concede el permiso de Micrófono la primera vez que mantengas pulsado el atajo de Dictado de forma válida. Abrir Inklet, visitar Ajustes o pulsar el atajo de Dictado fuera del editor de origen activo no lo solicita.

## Uso diario

Flujo de texto:

1. Pon el foco en cualquier campo de texto de otra app.
2. Pulsa `Option+Space`.
3. Busca un modo de prompt por coincidencia aproximada (por ejemplo, `res` puede encontrar `Resumir`), usa `Up` / `Down` para resaltarlo y pulsa `Tab` o `Enter` para confirmar el modo.
4. Escribe o pega el texto en bruto.
5. Pulsa `Enter` para transformarlo. El resultado aparece a medida que se genera; pulsa `Escape` para detenerlo.
6. Pulsa `Enter` de nuevo para insertar el resultado, o pulsa `Shift+Command+C` (o haz clic en el botón de copiar del resultado) para copiarlo.

Flujo de dictado:

1. **Abre el Asistente de escritura** con `Option+Space`.
2. **Confirma un modo de prompt**. El dictado no está disponible en el selector de modos ni en el editor de resultados.
3. **Pon el cursor en el borrador de origen o selecciona el texto que quieras reemplazar.** El dictado se inserta en el cursor o reemplaza la selección.
4. **Mantén pulsado el atajo de Dictado configurado** (Option derecha por defecto) y habla con normalidad mientras el borrador se actualiza en su sitio. Una pulsación breve no hace nada. Si falla la conexión en tiempo real, sigue manteniendo pulsado y hablando mientras Inklet guarda una grabación temporal de recuperación.
5. **Suelta para finalizar** la transcripción. Con **En este Mac**, la recuperación transcribe la grabación en tu Mac. Con OpenAI, si hace falta recuperar, Inklet envía una sola solicitud a `https://api.openai.com/v1/audio/transcriptions` con la misma clave de API de OpenAI que usa el dictado en tiempo real. La grabación temporal permanece en local hasta que la solicitud alternativa empieza de verdad, se sube como máximo una vez y se elimina al terminar la sesión.
6. Revisa y edita el borrador dictado. El dictado por sí solo no ejecuta el modo de prompt ni inserta texto en otra app.
7. **Pulsa Return solo cuando estés listo** para ejecutar el modo de prompt confirmado; vuelve a pulsar Return solo cuando quieras insertar el resultado.

El atajo de Dictado solo funciona en el editor de origen y solo se mantiene pulsado. Puedes cambiar su tecla modificadora a Command derecha, Option izquierda o Command izquierda, o desactivar el dictado por completo, en **Ajustes** → **Dictado en tiempo real**. Escape, perder el foco, cerrar el popover o abrir otra sesión de origen cancela el dictado y restaura el borrador original.

## Qué hace

- Se abre con un atajo global de macOS. El predeterminado es `Option+Space`.
- Transmite el dictado en tiempo real al editor de origen activo del Asistente de escritura mientras mantienes pulsado un atajo de tecla modificadora. El predeterminado es Option derecha.
- Muestra las acciones de selección cuando seleccionas texto en otra app del Mac y haces una breve pausa, con lectura de la selección al estilo de EasyDict, traducción rápida, un prompt de **Traducir** personalizable, pronunciación con IA, resultados de traducción redimensionables que recuerdan su último tamaño y una caché local de 7 días para traducciones repetidas.
- Ignora el texto seleccionado de más de 1500 caracteres para evitar activaciones accidentales al seleccionar una página entera.
- Reproduce directamente el texto seleccionado y, desde el resultado de la traducción, puede reproducir tanto el original como la traducción.
- Te permite elegir qué botones muestra el menú de selección y en qué orden, en **Ajustes** › **Asistente de selección** › **Botones del menú**. **Traducir**, **Pronunciar** y cualquier modo de prompt pueden ser un botón; se muestran hasta cuatro a la vez y el resto va en **Más**. Un botón de modo de prompt ejecuta ese modo sobre el texto seleccionado y muestra el resultado en el panel con controles para copiar y reproducir.
- Transforma texto con modos de prompt integrados:
  - To Simple and Correct English (en tu idioma de escritura, que eliges en Ajustes › General; inglés por defecto)
  - Summarize (en tu idioma de traducción, que por defecto sigue el idioma de la interfaz)
  - To Spanish, To Japanese, etc. (traduce a tu idioma de traducción; con una sola palabra muestra su significado, pronunciación y frases de ejemplo)
  - Voice Cleanup
  - Los nombres de los modos integrados quedan en inglés en todos los idiomas de la interfaz, para que las mismas letras los encuentren; muestran tus idiomas hasta que los renombres.
- Muestra el resultado en el popover a medida que se genera y después lo inserta en la app que tenía el foco o lo copia con el botón de copiar del resultado.
- Usa una única vía de selección independiente de la app y basada primero en Accesibilidad. Las acciones de selección automáticas piden primero la selección a la Accesibilidad de macOS y solo usan el método alternativo de portapapeles temporal configurado cuando la **Selección forzada** lo permite. Cada lectura queda ligada al proceso de origen capturado y se cancela si ese proceso termina o pierde el foco.
- Mantiene desactivado por defecto el `Command+C` simulado. La copia desde el menú sigue siendo el método alternativo seguro de **Selección forzada**; puedes activar explícitamente la copia simulada como alternativa avanzada para apps sin un menú Copiar utilizable, pero puede interferir con juegos, escritorios remotos o máquinas virtuales.
- Serializa las lecturas temporales del portapapeles y restaura la instantánea anterior solo mientras la misma lectura siga siendo la dueña del resultado de copia observado; el contenido más reciente del portapapeles prevalece. El disparador de doble copia es pasivo: usa la copia que ya hizo el usuario sin emitir otra copia sintética ni restaurar datos más antiguos del portapapeles. El clic derecho sigue siendo nativo y nunca inicia una lectura de la selección.
- No usa código de selección específico de navegadores ni solicita permisos de Automatización para navegadores. Chrome, Safari, Edge y las apps nativas usan la misma vía genérica.
- Te permite editar los modos de prompt, el proveedor, el modelo, el endpoint personalizado compatible con OpenAI, el tiempo de espera, el atajo de escritura, el atajo de mantener pulsado para el Dictado, el micrófono, el modelo de recuperación, el idioma de traducción de la selección, el prompt de **Traducir** de la selección, los botones del menú de selección, el modo de **Selección forzada**, el permiso de copia simulada, y la voz y la velocidad de la pronunciación con IA.
- Muestra un **Historial** local de los resultados correctos de escritura y de selección, con las entradas duplicadas consecutivas agrupadas, el texto de origen y del resultado seleccionable, un control para copiar el resultado y una acción para borrarlo todo. Las entradas de Voice antiguas siguen siendo legibles.
- Escribe y traduce con OpenAI, Anthropic, Google Gemini, DeepSeek, Alibaba Qwen, Moonshot Kimi, Zhipu GLM, MiniMax, SiliconFlow, Volcengine Ark, Tencent Hunyuan, Baichuan, 01.AI Yi, xAI, Groq, Mistral, OpenRouter, Perplexity, Together AI, Cerebras o cualquier endpoint personalizado compatible con OpenAI, como un servidor de modelos local. La pronunciación usa el motor elegido en Texto a voz, en Modelos de IA: la voz del sistema de macOS (la predeterminada en instalaciones nuevas, sin conexión y gratis) u OpenAI. El dictado usa el motor de reconocimiento de voz elegido en **Dictado en tiempo real**.
- Ejecuta la escritura y la traducción en tu Mac con el motor integrado (Qwen3.5 4B o Gemma 4 E4B, descargados una sola vez desde Hugging Face) o con un servidor local de Ollama o LM Studio. No hace falta clave de API y el texto se queda en tu Mac.
- Ofrece la interfaz de la app en inglés, chino simplificado, chino tradicional, japonés, coreano, español, francés, alemán, portugués e italiano.
- Adapta los menús de selección compactos y los controles con poco espacio de los ajustes y la escritura a las etiquetas traducidas; al cambiar de idioma se actualiza la interfaz abierta y se conserva el contenido que estás escribiendo.

## Estado actual

Inklet es un MVP en fase temprana. El repositorio incluye actualmente:

- Un Swift Package para la app de macOS y el motor de escritura principal.
- Una app de barra de menús con un popover de escritura y una ventana de ajustes.
- Adaptadores de proveedores y almacenamiento de la configuración.
- Pruebas unitarias del comportamiento principal.
- Notas de pruebas manuales en [docs/manual-test-checklist.md](docs/manual-test-checklist.md).

## Requisitos

- macOS 14 o posterior.
- Toolchain de Swift 6.
- Se recomienda Xcode completo para la compatibilidad con XCTest.
- Permiso de Accesibilidad para Inklet, necesario para la lectura genérica de la selección, el método alternativo de copia configurado, devolver el foco a la app anterior y pegar el resultado generado.
- Permiso de Micrófono para el dictado en tiempo real mientras se mantiene pulsado el atajo.
- Una clave de API de OpenAI u otro proveedor compatible, o un modelo local. La pronunciación y el dictado solo requieren una clave de API de OpenAI cuando usan OpenAI.

## Modelos locales

Inklet puede escribir y traducir con un modelo que se ejecuta en tu Mac, de modo que tu texto nunca sale de él y no necesitas clave de API.

- **Integrado** (solo Apple silicon y opción predeterminada en instalaciones nuevas): elige **Integrado** como proveedor, escoge un modelo y haz clic en **Descargar**. Gemma 4 E4B (unos 4,6 GB) es el predeterminado en Macs con 16 GB de memoria o más; Qwen3.5 4B (unos 2,7 GB) es el recomendado para 8 GB. En una instalación nueva lo descarga la guía de bienvenida y, mientras se descarga un modelo, el popover de escritura muestra el progreso, con un botón **Descargar** si el modelo aún no está. Las descargas se reanudan tras una interrupción y se verifican con un SHA-256 fijado antes de usarse. Cuando abres el popover de escritura con **Integrado** seleccionado, Inklet inicia su servidor llama.cpp incluido solo en la dirección de loopback y carga el modelo, así que suele estar listo cuando envías el texto. En Macs con 24 GB de memoria o más, el modelo permanece cargado y solo se libera cuando macOS se queda corto de memoria; en Macs más pequeños, el servidor lo libera tras cinco minutos de inactividad.
- **Dictado en este Mac** (solo Apple silicon y opción predeterminada en instalaciones nuevas): el Dictado en tiempo real reconoce la voz con Qwen3-ASR 0.6B (alrededor de 1 GB), que entiende 30 idiomas y chino mezclado con inglés. Funciona con el mismo motor llama.cpp incluido, en un servidor aparte, vuelve a transcribir lo que dices aproximadamente cada 0,6 segundos mientras hablas y fija cada frase en una pausa. En Macs con 16 GB de memoria o más, el modelo de voz permanece cargado mientras el dictado está activado; en Macs más pequeños se carga al abrir el popover de escritura y se libera tras cinco minutos de inactividad. Desactivar el dictado, o elegir OpenAI, lo detiene. Cuando Inklet o macOS usan chino tradicional, el dictado en chino se escribe con caracteres tradicionales.
- **Ollama**: instala [Ollama](https://ollama.com), ejecuta `ollama pull qwen3.5:4b` y elige **Ollama**. Inklet muestra los modelos que Ollama tiene descargados.
- **LM Studio**: inicia el servidor local de LM Studio en el puerto 1234, carga un modelo y elige **LM Studio**.

Los proveedores locales tienen al menos 120 segundos por solicitud para que la primera solicitud pueda cargar el modelo. Inklet pide a los servidores locales que se salten el "razonamiento" para que los modelos de razonamiento pequeños respondan directamente. Las compilaciones desde el código fuente compilan el motor integrado con `scripts/build-llama-server.sh`, que necesita `cmake`; si falta, la app sigue funcionando y la opción **Integrado** explica que el motor no está incluido.

## Compilar y ejecutar

Antes de cada compilación del paquete de la app, aumenta tanto `INKLET_VERSION` como `INKLET_BUILD_NUMBER` en el archivo `VERSION` de la raíz. Normalmente se incrementa la versión de parche; usa incrementos menores o mayores para cambios más grandes. El número de compilación debe seguir siendo un entero positivo mayor que cualquier número de compilación usado antes, también entre versiones comerciales. Revisa la última `main`, las etiquetas de Git, todas las versiones de GitHub (incluidos los borradores) y los worktrees activos antes de elegirlo. Inklet usa solo este número de compilación para decidir si una actualización es más reciente.

Ejecuta las compilaciones remotas del DMG en GitHub solo desde `main`, después de fusionar y subir los cambios previstos y el `VERSION` actualizado. Lanza `build-dmg.yml` con `--ref main`.

Para una versión oficial, verifica que la compilación se completó y los archivos finales, sustituye la descripción provisional por los cambios en chino y en inglés desde la última versión estable publicada y publícala como la última versión estable. Un borrador ya verificado puede publicarse sin recompilar ni cambiar su versión.

El flujo de trabajo del DMG comprueba antes de compilar si hay números de compilación reutilizados o más bajos; no incrementa ninguno de los dos valores automáticamente. Consulta [release version checks](scripts/README.md#release-version-checks) para la validación manual. Cambiar la versión de una app empaquetada requiere recompilar, firmar, notarizar y regenerar las sumas de comprobación; cambiar solo el título de la versión o el nombre del archivo no actualiza la app.

Desde la raíz del repositorio:

```bash
swift build
scripts/run-local-app.sh
```

Usa `scripts/run-local-app.sh` para las pruebas manuales habituales desde cualquier worktree. Instala y abre la identidad estable `/Applications/Inklet Local.app`, de modo que la confianza de Accesibilidad y del llavero de macOS se pueda reutilizar entre compilaciones.

Ejecutar las pruebas:

```bash
swift test
```

Si las pruebas fallan porque `XCTest` no está disponible, instala la app completa de Xcode en lugar de solo las Command Line Tools.

Comprueba todos los idiomas de la interfaz con `scripts/check-localization.sh`. Añade `--snapshots` para generar una galería HTML local de capturas sintéticas de la interfaz nativa en `.build/localization-audit/`; el comando imprime su ruta. Los pull requests y los pushes a `main` ejecutan automáticamente todas las pruebas unitarias y las comprobaciones de localización. Consulta [localization audit](docs/localization-audit.md) para ver la cobertura y las comprobaciones manuales pendientes.

## Atajos de teclado

- `Option+Space`: abre el popover de escritura.
- `Right Option`: mantenlo pulsado para dictar mientras el editor de origen del Asistente de escritura está activo. Cambia la tecla modificadora o desactiva el dictado en **Ajustes** → **Dictado en tiempo real**; una pulsación breve no hace nada.
- `Up` / `Down` en el lanzador de modos: mueve el resaltado por los modos de prompt ordenados por coincidencia aproximada.
- `Tab`, `Return` o `Enter` del teclado numérico en el lanzador de modos: confirma el modo de prompt resaltado y pone el foco en el editor de origen. Return sigue sirviendo para confirmar texto o un candidato del método de entrada durante la composición; Return con Command, Shift, Option o Control no confirma un modo.
- `Enter` en el editor: transforma el texto de origen, inserta un resultado generado por el modo actual o vuelve a generar con el modo recién confirmado un resultado obsoleto de un modo anterior.
- `Command+Enter`: inserta el texto original sin llamar al modelo.
- `Shift+Command+C`: copia el resultado visible sin cerrar el popover.
- `Command+Up` / `Command+Down`: recorre los modos de prompt visibles.
- Mantener pulsada solo `Command`: muestra todos los atajos en la barra de acciones. Normalmente la barra solo muestra la pista de dictado y el botón principal; todos los atajos funcionan igual.
- `Escape`: retrocede un nivel con cada pulsación, del resultado al editor de origen, luego al lanzador de modos y después cierra el popover. Durante la transformación, detiene la generación, descarta el resultado parcial y se queda en el editor.
- `Command+,`: abre Ajustes mientras Inklet está activo.

La búsqueda no distingue mayúsculas ni diacríticos y admite coincidencias de caracteres en orden. Las coincidencias exactas y de prefijo reciben el mayor impulso; las coincidencias consecutivas, al inicio de palabra, más tempranas y más compactas suelen quedar más arriba.

Cuando se abre el lanzador de modos, el último modo de prompt confirmado aparece resaltado si sigue visible. Un clic resalta un modo; un doble clic lo confirma. Volver al lanzador conserva el borrador y el resultado actuales.

## Estructura del repositorio

```text
Sources/InkletApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/InkletCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/InkletCoreTests/   unit tests for core behavior
docs/                    QA manual y política de privacidad
```

## Notas de desarrollo

- Mantén el comportamiento de los proveedores cubierto por pruebas unitarias específicas.
- Usa [docs/manual-test-checklist.md](docs/manual-test-checklist.md) antes de publicar cambios visibles para el usuario.
- Usa `scripts/run-local-app.sh` en lugar de un ejecutable de SwiftPM o `open dist/...` para las pruebas manuales habituales, de modo que los permisos locales de Accesibilidad y del llavero sigan ligados a una única identidad estable de la app.
- Trata con cuidado los flujos del portapapeles y de Accesibilidad; son centrales en la experiencia de la app.
- El proyecto sigue en fase de MVP, así que el README debe reflejar el código y no planes futuros.

## Almacenamiento local y actualizaciones

Las versiones de producción y las de QA local usan almacenamiento separado por paquete y no comparten ajustes, Historial, caché de traducciones, diagnósticos ni credenciales del llavero:

- Application Support de producción: `~/Library/Application Support/com.tomwan.inklet/`
- Application Support local: `~/Library/Application Support/com.tomwan.inklet.local/`
- Preferencias de producción: `~/Library/Preferences/com.tomwan.inklet.plist`
- Preferencias locales: `~/Library/Preferences/com.tomwan.inklet.local.plist`
- Claves de API de los proveedores: `api-keys.json` en la carpeta de Application Support correspondiente, legible solo por tu cuenta de usuario y excluido de las copias de seguridad de Time Machine
- Servicios del llavero usados por versiones anteriores: `Inklet.ProviderAPIKey` (producción) e `Inklet.Local.ProviderAPIKey` (local)

Las versiones anteriores guardaban las claves de API en el llavero. La primera vez que se necesita una clave, Inklet la copia del llavero a `api-keys.json` y deja el elemento del llavero en su sitio, para que volver a una versión anterior la siga encontrando. Cambiar o borrar una clave en Ajustes elimina la copia del llavero.

En el primer inicio tras actualizar desde la antigua versión con sandbox, Inklet copia automáticamente las preferencias antiguas reconocidas, las claves de API de los proveedores al servicio del llavero correspondiente y el Historial al almacenamiento del paquete actual. No borra ni modifica el origen antiguo, así que los datos antiguos siguen disponibles para revertir o recuperar. La caché de traducciones, que es desechable, no se migra.

Si macOS bloquea el acceso automático al contenedor antiguo correspondiente, Ajustes mantiene disponible la acción **Importar datos…**. La importación asistida valida la carpeta `Data` antigua exacta del paquete de producción o local en ejecución, la lee solo mientras el permiso actual del panel de archivos sea válido y no guarda un marcador de acceso persistente.

## Privacidad

- Inklet envía las solicitudes de escritura y de traducción de la selección al proveedor que elijas en Ajustes, usando la clave de API de ese proveedor. Con la voz del sistema de macOS, la pronunciación lee el texto en tu Mac; solo usa OpenAI, con tu clave de API de OpenAI, cuando eliges OpenAI para texto a voz. El dictado solo usa OpenAI cuando lo eliges como motor de reconocimiento de voz.
- Con el reconocimiento de voz **En este Mac**, el audio del dictado y su grabación de recuperación los procesa un servidor en tu Mac y nunca salen de él.
- Con el reconocimiento de voz de OpenAI, mientras mantienes pulsado el atajo de Dictado, el audio del micrófono activo se transmite directamente a la transcripción de OpenAI Realtime. Inklet también guarda una grabación local temporal de recuperación. Permanece en local hasta que la solicitud alternativa empieza de verdad, se sube como máximo una vez a `https://api.openai.com/v1/audio/transcriptions` usando la misma clave de API de OpenAI que usa el dictado en tiempo real, y se elimina en cualquier forma de finalizar la sesión.
- Tus claves de API se guardan localmente en tu Mac, una por proveedor.
- Con los proveedores **Integrado**, Ollama o LM Studio, las solicitudes de escritura y traducción solo van a un servidor en tu Mac. Descargar un modelo integrado envía una solicitud a Hugging Face para el archivo elegido; no incluye tu texto, audio, claves de API ni ajustes.
- Inklet usa el permiso de Accesibilidad para la lectura genérica de la selección, el método alternativo de copia configurado, devolver el foco a la app anterior y pegar texto.
- Inklet usa el permiso de Micrófono solo durante una pulsación válida del Dictado en el editor de origen activo del Asistente de escritura. Al terminar el dictado queda un borrador editable y no se inserta nada en otra app.
- Inklet usa temporalmente el portapapeles para insertar y para las lecturas alternativas de **Selección forzada** configuradas. Una lectura de **Selección forzada** solo restaura el portapapeles anterior si el valor copiado temporalmente por Inklet sigue siendo el actual, y no sobrescribe un cambio externo posterior del portapapeles.
- Inklet guarda localmente en el Historial el texto de origen y el resultado de las acciones de escritura y selección correctas hasta que lo borres en Ajustes, y omite las entradas duplicadas consecutivas. Un borrador dictado sin procesar no crea ninguna entrada en el Historial; las entradas de Voice antiguas siguen siendo legibles en local.
- Las acciones de selección capturan la app de origen y la ubicación de la selección, validan ese origen antes y durante la lectura y usan Accesibilidad para leer su selección actual. Si Accesibilidad no devuelve el texto seleccionado, el modo de **Selección forzada** configurado puede invocar brevemente Copiar del menú y leer el texto resultante del portapapeles mediante la transacción protegida descrita arriba. El `Command+C` simulado está desactivado por defecto y solo se ejecuta tras activarlo explícitamente como opción avanzada. Puedes desactivar la **Selección forzada** en Ajustes. Esta vía no envía Apple Events dirigidos a navegadores ni solicita permisos de Automatización para navegadores. Pulsar `Command+C` dos veces seguidas tras seleccionar texto lee explícitamente la copia que ya hiciste. Inklet no guarda el texto que solo se ha seleccionado, a menos que una acción correcta quede registrada en el Historial local.
- El Asistente de selección guarda en caché local durante 7 días los resultados de traducción correctos, con claves de caché cifradas con hash, para acelerar las traducciones repetidas.
- La traducción del Asistente de selección envía el texto seleccionado y tus instrucciones personalizadas de **Traducir** al proveedor elegido cuando no hay una traducción en la caché local; un botón de modo de prompt envía el texto seleccionado y el prompt de ese modo al proveedor elegido; la pronunciación envía el texto seleccionado a OpenAI solo cuando OpenAI es el motor de texto a voz.
- Inklet obtiene el catálogo público de modelos de `models.dev` como máximo una vez al día. Esta solicitud no incluye tu texto, audio, claves de API ni ajustes de la app.
- No envíes texto ni audio privados a OpenAI ni al proveedor elegido a menos que confíes en sus políticas de tratamiento de datos.

## Comentarios

Elige **Enviar comentarios…** en el menú de Inklet de la barra de menús, o [abre un issue](https://github.com/wanming/Inklet/issues/new/choose). Los informes de errores y las ideas de funciones son bienvenidos; nunca pegues claves de API ni texto privado en un issue.

## Contribuir

Consulta [CONTRIBUTING.md](CONTRIBUTING.md).

## Seguridad

Consulta [SECURITY.md](SECURITY.md) para informar de vulnerabilidades y para las pautas sobre datos sensibles.

## Licencia

Inklet se publica bajo la [MIT License](LICENSE).
Los avisos de terceros se encuentran en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
