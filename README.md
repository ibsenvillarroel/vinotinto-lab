# Vinotinto Lab DB v0.1

Base PostgreSQL mínima para comenzar a construir el dataset analítico de Vinotinto Lab a partir de API-Football.

## Qué incluye

- `data_source`: catálogo de proveedores de datos.
- `competition`: ligas/copas.
- `competition_season`: temporada y `coverage` devuelto por API-Football.
- `team`: equipos/selecciones.
- `player`: maestro de jugadores.
- `player_season_stat`: estadísticas acumuladas jugador-equipo-competición-temporada.
- `raw_api_data`: copia del JSON original recibido del proveedor.

## 1. Preparar variables

En PowerShell, desde esta carpeta:

```powershell
Copy-Item .env.example .env
```

## 2. Levantar PostgreSQL

```powershell
docker compose up -d
```

El script `sql/001_init.sql` se ejecuta automáticamente la primera vez que se crea el volumen.

## 3. Comprobar el contenedor

```powershell
docker compose ps
```

## Conexión local

- Host: `localhost`
- Port: `5433`
- Database: `vinotinto_lab`
- User: `vinotinto`
- Password: `vinotinto_lab_dev`

Cadena de conexión:

```text
postgresql://vinotinto:vinotinto_lab_dev@localhost:5433/vinotinto_lab
```

## 4. Verificar tablas

```powershell
docker exec -it vinotinto-lab-postgres psql -U vinotinto -d vinotinto_lab -c "\dt"
```

## 5. Verificar fuente inicial

```powershell
docker exec -it vinotinto-lab-postgres psql -U vinotinto -d vinotinto_lab -c "SELECT * FROM data_source;"
```

## Reinicio completo de desarrollo

**Esto elimina todos los datos locales de esta BD.**

```powershell
docker compose down -v
docker compose up -d
```

## Próximo paso

Construir un importador que consulte API-Football y cargue:

1. LaLiga 2025/26 + coverage.
2. Real Madrid.
3. Kylian Mbappé.
4. Sus estadísticas de LaLiga 2025/26.
5. El JSON original en `raw_api_data`.
