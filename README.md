# 88 Editor (macOS)

**88 Editor** es una aplicación nativa para macOS desarrollada en **Swift** y **SwiftUI**, diseñada con un enfoque minimalista, de alto rendimiento y con una estética sobria y neutra en **Modo Oscuro por defecto** siguiendo las directrices de interfaz humana (*Human Interface Guidelines*) de Apple.

La app está concebida para la edición de video ágil y fluida, optimizada para aprovechar la eficiencia térmica y los decodificadores de hardware de los procesadores Apple Silicon (especialmente en **MacBook Air M1/M2/M3/M4**), sin requerir ventiladores activos y minimizando el impacto en la batería.

---

## 1. Stack Técnico y Arquitectura

* **Lenguaje & Plataforma:** Swift 5.9+ / Swift 6, macOS 13+ (Ventura, Sonoma, Sequoia).
* **Apariencia:** Modo Oscuro nativo forzado por defecto (`NSAppearance(named: .darkAqua)` y `.preferredColorScheme(.dark)`).
* **Frameworks Centrales:**
  * `SwiftUI`: Interfaz reactiva declarativa, vistas de paneles y hojas modales nativas.
  * `AVFoundation`: Motor de composición temporal (`AVMutableComposition`), capas de decodificación acelerada (`AVPlayerLayer`) y control de audio (`AVMutableAudioMix`).
  * `Combine` & Concurrencia Estructurada (`async/await`, `@MainActor`).
  * `AppKit`: Integración de bajo nivel para `NSEvent.addLocalMonitorForEvents`, `NSFontManager`, `NSOpenPanel`, `NSSavePanel` y gestión de cursores.
* **Gestión de Medios por Referencia:** 
  * **Sin duplicación:** La app jamás copia ni importa archivos pesados al almacenamiento de la aplicación.
  * **Persistencia Segura:** Utiliza `Security-Scoped Bookmarks` para conservar el acceso de lectura y reproducción a rutas locales arbitrarias del Finder entre sesiones.
* **Arquitectura:** **MVVM** con desacoplamiento estricto.

---

## 2. Atajos de Teclado Profesionales

Gestionados a nivel de ventana mediante `KeyboardManager` (con protección inteligente para no interceptar cuando estás escribiendo en un campo de texto):

| Atajo | Acción |
| :--- | :--- |
| **Delete / Backspace** | **Eliminar el clip seleccionado** |
| **Supr (Fn + Delete)** | **Eliminar el clip seleccionado** |
| **Barra Espaciadora** (`Space`) | Reproducir / Pausar reproducción |
| **⌘ + B** (o tecla **B** / **C**) | Dividir (*Split*) el clip seleccionado en la posición del playhead |
| **Flecha Izquierda** (`←`) | Retroceder 1 fotograma (Frame Step Back) |
| **Flecha Derecha** (`→`) | Avanzar 1 fotograma (Frame Step Forward) |
| **⇧ + Flecha Izquierda** (`⇧←`) | Retroceder 1 segundo (salto rápido) |
| **⇧ + Flecha Derecha** (`⇧→`) | Avanzar 1 segundo (salto rápido) |
| **Flecha Arriba** (`↑`) | Saltar al corte o inicio de clip anterior |
| **Flecha Abajo** (`↓`) | Saltar al corte o fin de clip siguiente |
| **⌘ + ←** (o tecla **Home**) | Ir al inicio absoluto de la línea de tiempo (`00:00:00:00`) |
| **⌘ + →** (o tecla **End**) | Ir al final absoluto de la línea de tiempo |
| **J** | Retroceder reproducción / shuttle |
| **K** | Pausar reproducción |
| **L** | Reproducir hacia adelante |
| **M** | Silenciar (*Mute*) / Desilenciar el clip seleccionado |
| **Escape** (o **⌘ + D**) | Deseleccionar clip actual |
| **⌘ + =** (o **⌘ + +**) | Aumentar zoom del visor / canvas |
| **⌘ + -** | Reducir zoom del visor / canvas |
| **⌘ + 0** | Restablecer zoom al 100% (Ajustar al visor) |
| **⌘ + 1** | Alternar / Ocultar barra lateral izquierda (Media Pool) |
| **⌘ + 2** | Alternar / Ocultar barra lateral derecha (Inspector) |
| **⌘ + I** | Importar medios desde Finder (`NSOpenPanel`) |
| **⌘ + S** | Guardar proyecto en formato `.88proj` (JSON) |
| **⌘ + N** | Crear nuevo proyecto (Modal con preset por defecto *Personalizado*) |
| **⌘ + O** | Abrir proyecto `.88proj` existente |

---

## 3. Estructura de la Interfaz

```
+-----------------------------------------------------------------------------------+
|  [⌘1]  88 [Nombre de Proyecto ●]   |  [⌘N] [⌘O] [⌘S] [⌘I] [⌘B]  |             [⌘2] |
+-----------------------------------------------------------------------------------+
|  SIDEBAR IZQUIERDO   |                CANVAS CENTRAL                |  SIDEBAR DERECHO   |
|  (Media Pool)        |  (Previsualización AVPlayerLayer)            |  (Inspector)       |
|                      |                                              |                    |
|  - Drop Zone Finder  |  - Zoom por Trackpad (Pinch-to-zoom)         |  - Transformación  |
|  - Grilla / Lista    |  - Atajos ⌘+, ⌘-, ⌘0, doble clic para reset  |    (X, Y, Escala,  |
|  - Metadatos         |  - Pan / Arrastre en zoom                    |     Rotación)      |
|  - Referencias puras |  - Escala: 100% / 50% Proxy (Apple Silicon)  |  - Opacidad (0-100)|
|                      |  - Timecode SMPTE y transporte               |  - Volumen (0-100) |
|                      |                                              |  - NSFontManager   |
+-----------------------------------------------------------------------------------+
|  DIVISOR INTERACTIVO REDIMENSIONABLE (Arrastrar ↕ para ajustar altura de timeline)|
+-----------------------------------------------------------------------------------+
|  PANEL INFERIOR: LÍNEA DE TIEMPO RESPONSIVA (Ancho 100% sin cortes)               |
|  - Estado vacío elegante si no hay archivos: "Arrastra archivos aquí"             |
|  - Pistas independientes V1, V2, A1 con Badges compactos                          |
|  - Recorte de extremos In / Out con cursor horizontal                             |
|  - Playhead interactivo sincronizado en tiempo real                               |
+-----------------------------------------------------------------------------------+
```

---

## 4. Compilación y Ejecución

```bash
# Compilar el binario
swift build

# Ejecutar la app
swift run 88Editor
```
