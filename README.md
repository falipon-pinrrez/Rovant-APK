# Rovant – navegación con reportes de voz

App tipo Waze en Flutter donde todas las alertas se pueden grabar con audio.
Usa la guía de color de los mockups: tema oscuro dorado y tema claro azul.

## Qué hace

| Pantalla | Funciones |
|---|---|
| **Inicio** | Onboarding con logo, 3 beneficios, "Comenzar" (pide permiso de ubicación) |
| **Mapa / navegación** | Mapa OpenStreetMap (oscuro o claro), tu personaje como marcador, velocímetro, buscador "¿A dónde vas?", mantener presionado para elegir destino, ruta con instrucciones de giro habladas, ETA y km restantes, recálculo si te sales de la ruta |
| **Alertas con audio** | Al acercarte a un reporte (200–1500 m, configurable), Rovant lo anuncia en voz alta y reproduce el audio grabado por quien lo reportó |
| **Reportar** | Accidente, tráfico, policía, obstáculo, foto, audio, con foto (cámara o galería), audio y detalles opcionales. Toma la dirección automáticamente |
| **Grabar audio rápido** | Botón verde de micrófono: graba hasta 60 s y publica en tu ubicación |
| **Reportes** | Lista con filtros por categoría |
| **Detalle** | Reproductor (play/pausa, ±10 s, barra), foto, compartir, ver en mapa, eliminar |
| **Configuración** | Personaje, nombre, notificaciones, tema, alertas con audio, voz de navegación, distancia de alerta, ayuda, términos |

## Compilar el APK

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.27 o superior y Android Studio (SDK de Android).

**Windows:** clic derecho en `crear_proyecto.ps1` → *Ejecutar con PowerShell*.
**Mac / Linux:** `bash crear_proyecto.sh`

El script crea la carpeta `rovant_app` al lado de esta, copia el código, pone los permisos, genera el ícono y compila.
El APK queda en `rovant_app/build/app/outputs/flutter-apk/app-release.apk`.

Para probar en tu teléfono con cable USB: `cd rovant_app` y luego `flutter run`.

Si `flutter pub get` reporta un conflicto de versiones, ejecuta `flutter pub upgrade` y vuelve a compilar.

## Personajes

Los avatares salen de `assets/personajes/`. Cualquier PNG/JPG/WEBP que pongas ahí aparece en
*Configuración → Elige tu personaje* (vuelve a compilar después de agregar imágenes).
Por defecto trae 4 carritos originales.

> Si usas personajes de una franquicia (p. ej. Halo), ten en cuenta que son propiedad de su dueño:
> para publicar la app (sobre todo en Play Store o con fines comerciales) necesitas su permiso.

## Estructura

```
lib/
  main.dart                 arranque, temas, providers
  theme.dart                tokens de color (guía RutaSegura/Rovant)
  models/reporte.dart       categorías (color, ícono, frase de voz) y reporte
  data/stores.dart          ajustes y reportes (guardados en el teléfono)
  services/servicios.dart   voz (TTS + audios), rutas OSRM, búsqueda y direcciones (Nominatim), personajes
  widgets/comunes.dart      botones, íconos de categoría, avatar, onda de audio
  screens/                  inicio, mapa, reportes, detalle, nuevo reporte, grabar, configuración
```

## Siguiente paso: reportes compartidos entre usuarios

Hoy los reportes se guardan en cada teléfono, más unos reportes de ejemplo en Bogotá.
Para que todos los conductores vean los audios de los demás, conecta `ReportesStore` a un backend:

1. Crea un proyecto en Firebase y agrega `firebase_core`, `cloud_firestore` y `firebase_storage`.
2. En `agregar()`: sube el audio/foto a Storage, guarda el reporte (con las URLs) en Firestore.
3. En `load()`: escucha la colección `reportes` de las últimas 24 h (`snapshots()`) en vez de SharedPreferences.
4. En `Voz.alerta` usa `UrlSource(url)` en lugar de `DeviceFileSource` para los audios remotos.

## Servicios externos (gratis, sin API key)

- Mapas: teselas de CARTO sobre datos de © OpenStreetMap.
- Rutas: servidor público de demostración de OSRM. Para producción monta tu propio OSRM o usa GraphHopper o Mapbox.
- Búsqueda y direcciones: Nominatim (máximo 1 petición por segundo).

## Publicar en Play Store

El APK de `flutter build apk` se firma con la llave de depuración, lo cual sirve para instalarlo directamente.
Para Play Store crea una llave de firma (https://docs.flutter.dev/deployment/android#sign-the-app)
y compila con `flutter build appbundle`.
