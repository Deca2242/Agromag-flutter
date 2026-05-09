# app

Aplicación móvil Flutter para la gestión de cultivos y alertas agrícolas en el departamento del Magdalena, Colombia. Funciona offline con SQLite y se sincroniza con un backend Spring Boot mediante Supabase Auth.

## Requisitos previos

- Flutter SDK >= 3.11
- Dart SDK >= 3.11
- Android SDK o Xcode (para iOS)
- Proyecto activo en [Supabase](https://supabase.com)
- Backend Spring Boot (`agromag/`) corriendo localmente o en un servidor

## Configuración inicial

### 1. Clonar el repositorio

```bash
git clone <url-del-repo>
cd app
```

### 2. Crear el archivo de entorno

```bash
cp .env.example .env
```

Edita `.env` con tus valores reales:

```
SUPABASE_URL=https://tu-proyecto-ref.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...   # Project Settings → API → anon public
API_BASE_URL=http://10.0.2.2:8080  # ver nota abajo
```

> **`API_BASE_URL` según entorno:**
> | Entorno | Valor |
> |---------|-------|
> | Emulador Android | `http://10.0.2.2:8080` |
> | Simulador iOS | `http://localhost:8080` |
> | Dispositivo físico (misma red Wi-Fi) | `http://<IP_LAN_PC>:8080` |
>
> Para conocer tu IP LAN en Linux: `ip route get 1 | awk '{print $7; exit}'`

### 3. Instalar dependencias

```bash
flutter pub get
```

### 4. Ejecutar la app

```bash
flutter run
```

## Supabase — configuración requerida

- **Authentication → Providers → Email:** activado con "Confirm email" ON.
- **Authentication → URL Configuration → Redirect URLs:** añadir al menos un placeholder (ej. `https://agromagdalena.app/confirmed`).
- Credenciales en **Project Settings → API**.

## Backend Spring (`agromag/`)

El backend valida JWTs de Supabase como OAuth2 Resource Server. Antes de arrancar la app, asegúrate de que Spring esté corriendo con la variable de entorno `SUPABASE_PROJECT_REF` apuntando a tu proyecto Supabase.

## Estructura del proyecto

```
lib/
  core/
    config/env.dart          # Lectura de variables .env
    network/                 # Dio + AuthInterceptor + excepciones
    router/                  # GoRouter con redirect de sesión
    theme/                   # Colores y tema Material 3
    widgets/                 # Widgets compartidos
  data/
    repositories/            # AuthRepository, ProfileRepository
    services/                # LocalDb (SQLite), ProfileApi, ProfileLocalDao
    mock/                    # Datos de ejemplo para cultivos y alertas
  domain/
    models/                  # Profile, Municipality, AppRole
  features/
    auth/                    # Login, registro, recuperar contraseña
    home/                    # Pantalla principal
    crops/                   # Listado y detalle de cultivos
    alerts/                  # Alertas
    profile/                 # Perfil de usuario y cerrar sesión
    assistant/               # Asistente IA (en desarrollo)
    splash/                  # Pantalla de carga inicial
```

## Secretos — qué NO versionar

| Archivo | Motivo |
|---------|--------|
| `.env` | Contiene `SUPABASE_ANON_KEY` y URLs sensibles |
| `android/local.properties` | Ruta al SDK local de cada máquina |
| `key.properties`, `*.jks`, `*.keystore` | Firma de release |

El archivo `.env` ya está en `.gitignore`. Usa `.env.example` como referencia para nuevos clones.
