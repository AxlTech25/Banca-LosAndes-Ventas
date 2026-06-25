# Scripts de prueba — Banco_DBAndes

Proyecto Supabase: **Banco_DBAndes** (`offfufngzzbefvdvbdtr`)

## Orden de ejecución

| Orden | Archivo | Qué hace |
|-------|---------|----------|
| 1 | `seed_test_users.sql` | Auth + asesores (todos los perfiles) |
| 2 | `../seed_demo.sql` | Flujo completo del operador **104592** |
| 3 | `seed_operator_2_data.sql` | Operadores **105001** y datos extra **105002** |
| 4 | `verify_test_setup.sql` | Comprobación |

Contraseña común: **`Demo2026!`**

## Usuarios

| Código | Perfil | Uso en la app |
|--------|--------|----------------|
| **104592** | Operador | Cartera completa, mora, solicitudes SOL-DEMO |
| 105001 | Operador | Segundo asesor — supervisión M11 |
| 105002 | Operador | Tercer asesor — supervisión M11 |
| 201001 | Super operador | Menú comité en campo |
| **301001** | Supervisor | Reportes + monitor en mapa |
| 901001 | Administrador | Menú admin |

## Flujo recomendado de prueba

1. **104592** → cartera (3 clientes), campañas, mora Carlos, solicitudes en todos los estados.
2. **301001** → monitor de cobertura (3 operadores) y productividad mensual.
3. **201001** / **901001** → validar menú por rol.

Si **104592** ya existía en Auth con otro UUID, ejecuta `link_auth_by_email.sql`.

## Login falla con "codigo o contrasena incorrectos"

**Causa común:** usuarios creados por SQL con campos `NULL` en `auth.users` (GoTrue no puede leerlos).

1. Ejecuta **`fix_auth_sql_users.sql`** en SQL Editor (ya aplicado en Banco_DBAndes).
2. Verifica `.env` → `SUPABASE_URL=https://offfufngzzbefvdvbdtr.supabase.co`
3. Reinicia la app (`flutter run`).
4. **104592** → usa la contraseña que definiste en Dashboard.
5. **Resto** → contraseña `Demo2026!`

## Cartera vacía al iniciar sesión

**Causa común:** los datos demo usan `current_date` de Supabase, pero la app filtraba por la fecha del dispositivo.

1. Reinicia la app (`flutter run`) — ahora consulta la fecha del servidor.
2. Si sigue vacía, ejecuta **`refresh_cartera_hoy.sql`** en SQL Editor.
3. Operadores con cartera demo: **104592** (3), **105001** (2), **105002** (2).
4. **201001** (super operador) no tiene cartera demo; usa **104592** para probar cartera.
