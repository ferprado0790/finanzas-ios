# 📱 Finanz iOS — app nativa (SwiftUI)

App **nativa de iOS** generada a partir de `finanzas-app` (React) y conectada al
mismo backend, `finanzas-backend` (Spring Boot). No es un WebView: es SwiftUI
puro, con `async/await`, Swift Charts y el JWT guardado en el Keychain.

| Capa | Tecnología |
|------|-----------|
| UI | SwiftUI (iOS 17+), Swift Charts |
| Estado | Observation (`@Observable`) |
| Red | `URLSession` + `async/await` |
| Sesión | JWT en Keychain + `ASWebAuthenticationSession` para OAuth2 |
| Backend | `finanzas-backend` (sin cambios de código) |

---

## Requisitos

- macOS con **Xcode 16 o superior** (el proyecto usa carpetas sincronizadas).
- iOS 17.0 o superior (simulador o dispositivo).
- El backend `finanzas-backend` en marcha, con su PostgreSQL.

---

## Arranque rápido

### 1. Levanta el backend

```bash
cd ../finanzas-backend
export JWT_SECRET=c2VjcmV0S2V5Rm9yRmluYW56QXBwU3VwZXJTZWN1cmVKV1QyMDI1
export DB_PASSWORD=tu-password
mvn spring-boot:run
```

Escucha en el puerto **8090** (`application.yml`), así que la API queda en
`http://localhost:8090/api`.

**No hay que configurar nada más.** El backend ya distingue el origen del login:
la app llama a `/api/oauth2/authorization/{proveedor}?client=mobile` y el
servidor redirige a `finanz://auth`, mientras que la web sigue yendo a
`app.frontend-url`. Los destinos móviles se pueden cambiar con las variables
`MOBILE_OAUTH_URL` y `MOBILE_RESET_URL`.

### 2. Abre y ejecuta la app

```bash
open Finanz.xcodeproj
```

Elige un simulador de iPhone y pulsa ⌘R.

> Si tu Xcode es anterior a la versión 16, regenera el proyecto con XcodeGen:
> `brew install xcodegen && cd IOS && xcodegen generate`.

### 3. A qué backend apunta

Por defecto, al servidor público: **`https://finanz.kerbero.uk/api`**. Funciona
igual en el simulador, en un iPhone por Wi-Fi y con datos móviles.

Solo hay que cambiarlo para desarrollar contra un backend local:

| Dónde ejecutas | URL base |
|---|---|
| Producción (por defecto) | `https://finanz.kerbero.uk/api` |
| Simulador, backend en el mismo Mac | `http://localhost:8090/api` |
| iPhone físico en la misma Wi-Fi | `http://192.168.x.x:8090/api` (IP del Mac) |

La URL se cambia **sin recompilar**: icono ⚙️ en la pantalla de login, o
Inicio → menú de perfil → Ajustes → Servidor. Si escribes solo el host se le
añade `/api`, y se asume `https` salvo que sea una dirección local.

> **HTTP y App Transport Security**: el `Info.plist` ya no lleva excepciones,
> así que iOS **exige TLS**. Para apuntar a un backend local sin certificado hay
> que añadir de vuelta `NSAppTransportSecurity` → `NSAllowsLocalNetworking`
> (está comentado en el propio archivo).

---

## Equivalencia de pantallas

| Web (`finanzas-app`) | iOS |
|---|---|
| `LoginPage.jsx` | `Features/Auth/LoginView.swift` |
| `ForgotPasswordPage.jsx` | `Features/Auth/ForgotPasswordView.swift` |
| `ResetPasswordPage.jsx` | `Features/Auth/ResetPasswordView.swift` |
| `Dashboard.jsx` | `Features/Dashboard/DashboardView.swift` |
| `IncomePage.jsx` | `Features/Income/IncomeView.swift` |
| `ExpensePage.jsx` | `Features/Expenses/ExpenseView.swift` |
| `ShoppingListPage.jsx` | `Features/Shopping/ShoppingListView.swift` |
| `AnalysisPage.jsx` | `Features/Analysis/AnalysisView.swift` |
| `ReportPage.jsx` | `Features/Reports/ReportView.swift` |
| `BudgetCheckPage.jsx` | `Features/Budget/BudgetCheckView.swift` |
| `services/authService.js` | `Services/AuthService.swift` |
| `services/apiService.js` | `Services/FinanceServices.swift` |
| `context/AuthContext.js` | `Session/SessionStore.swift` |

La barra inferior de la web tiene 6 pestañas. En iOS se dejan **5** (convención
del sistema): Inicio, Ingresos, Gastos, Compras y Aprobar. **Análisis** e
**Informes** se abren desde los accesos rápidos de Inicio, igual que ya hacía la
web con Análisis.

---

## Endpoints consumidos

Todos los de `finanzas-backend`, sin excepción:

- `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`,
  `PATCH /api/auth/me`, `POST /api/auth/forgot-password`, `POST /api/auth/reset-password`
- `GET /api/oauth2/authorization/{google|github}`
- `GET|POST|PUT|DELETE /api/jobs`
- `GET|POST|PUT|DELETE /api/incomes`
- `GET|POST|PUT|DELETE /api/expenses`, `GET /api/expenses/by-category`
- `GET /api/budget/summary`, `POST /api/budget/check-expense`,
  `GET /api/budget/trend`, `GET|POST /api/budget/limits`, `GET /api/budget/report`
- `GET|POST|PUT|DELETE /api/shopping-list`, `PATCH /api/shopping-list/{id}/toggle`

---

## Deep links

El esquema `finanz://` está declarado en `Config/Info.plist`:

| URL | Efecto |
|---|---|
| `finanz://auth?token=<jwt>` | Cierra el flujo OAuth2 e inicia sesión |
| `finanz://reset?token=<token>` | Abre la pantalla de nueva contraseña |

El correo de recuperación que envía el backend incluye los dos enlaces: el botón
principal abre la web y, debajo, «Ábrelo en la app» abre `finanz://reset`.

Prueba manual en el simulador:

```bash
xcrun simctl openurl booted "finanz://reset?token=abc123"
```

---

## Estructura

```
IOS/
├── Finanz.xcodeproj/          # Proyecto (carpetas sincronizadas de Xcode 16)
├── project.yml                # Alternativa: regenerar con XcodeGen
├── Config/Info.plist          # Bundle id, esquema finanz://, ATS
└── Finanz/
    ├── App/                   # FinanzApp, RootView, MainTabView
    ├── Core/                  # APIClient, APIError, TokenStore (Keychain),
    │                          # Theme, Formatters, Catalogs, AppConfig
    ├── Models/                # Espejo exacto de los DTO de Java
    ├── Services/              # AuthService + servicios por dominio
    ├── Session/               # SessionStore (@Observable)
    ├── Components/            # Card, ProgressBar, MonthSelector, chips…
    ├── Features/              # Una carpeta por pantalla (vista + view model)
    └── Resources/             # Assets.xcassets (icono y color de acento)
```

Al usar carpetas sincronizadas, **cualquier archivo `.swift` que añadas dentro
de `Finanz/` entra solo en el target**: no hay que tocar el `.xcodeproj`.

---

## Decisiones que se apartan de la web

Son intencionadas; se listan para que no sorprendan:

1. **Sin datos de demo.** La web rellenaba con datos falsos cuando el backend
   fallaba. Aquí se muestra un aviso con botón de reintentar: en una app
   instalada, un balance inventado es peligroso.
2. **Importes con `Decimal`,** no con `Double`, para evitar errores de redondeo.
3. **JWT en Keychain,** no en `localStorage`.
4. **Periodos de referencia de «¿Puedo gastarlo?» recalculados** con `Calendar`
   (últimos 3 / 6 / 12 meses). El cálculo de la web se salía de rango en enero
   y febrero.
5. **`ReportPage` corregido:** la web leía `cat.percentage` y `t.label`, pero el
   backend envía `pct` y `month`. En iOS se usan los nombres reales, así que el
   informe muestra los porcentajes y las etiquetas de mes correctamente.
6. **Edición de ingresos y gastos**, que la web no ofrecía aunque el backend ya
   exponía `PUT /api/incomes/{id}` y `PUT /api/expenses/{id}`.

---

## Antes de publicar en la App Store

- Cambia `PRODUCT_BUNDLE_IDENTIFIER` (`com.finanz.app`) por el tuyo y asigna tu
  equipo de firma en Xcode → Signing & Capabilities.
- Sirve el backend por **HTTPS** y elimina las excepciones de
  `NSAppTransportSecurity` en `Config/Info.plist`.
- Sustituye `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` por
  el icono definitivo (1024×1024, sin canal alfa).
