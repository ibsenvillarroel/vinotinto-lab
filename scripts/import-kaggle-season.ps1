param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,

    [int]$Season = 2025,

    [string]$SeasonLabel = '2025/26',

    [string]$CsvName = 'players_data-2025_2026.csv'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Require-DockerContainer {
    $running = docker inspect -f '{{.State.Running}}' vinotinto-lab-postgres 2>$null
    if ($LASTEXITCODE -ne 0 -or $running.Trim() -ne 'true') {
        throw 'El contenedor vinotinto-lab-postgres no esta ejecutandose. Inicia Docker y ejecuta: docker compose up -d'
    }
}

function Parse-NullableInt {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $n = 0
    if ([int]::TryParse(([string]$Value).Trim(), [ref]$n)) { return $n }
    $d = 0.0
    if ([double]::TryParse(([string]$Value).Trim(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) {
        return [int][math]::Truncate($d)
    }
    return $null
}

function Parse-NullableDecimal {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $text = ([string]$Value).Trim().Replace('%','')
    if ($text.StartsWith('+')) { $text = $text.Substring(1) }
    $d = 0.0
    if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) {
        # Export-Csv usa la cultura regional de Windows para convertir numeros a texto.
        # En configuraciones con coma decimal (ej. es-VE), 27.2 terminaria como 27,2 y
        # PostgreSQL COPY espera punto decimal. Devolvemos texto invariant para evitarlo.
        return $d.ToString('0.################', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return $null
}

function Get-Sha256Hex {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Normalize-JsonObject {
    param($Row)
    $ordered = [ordered]@{}
    foreach ($prop in $Row.PSObject.Properties) {
        if ([string]::IsNullOrEmpty([string]$prop.Value)) {
            $ordered[$prop.Name] = $null
        }
        else {
            $ordered[$prop.Name] = $prop.Value
        }
    }
    return $ordered
}

function Split-FirstToken {
    param($Value)
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return @('', '')
    }
    $parts = $text -split '\s+', 2
    if ($parts.Count -eq 1) { return @($parts[0], '') }
    return @($parts[0], $parts[1])
}

$ZipPath = (Resolve-Path $ZipPath).Path
Require-DockerContainer

$projectRoot = (Get-Location).Path
$tmpRoot = Join-Path $projectRoot 'data\tmp\kaggle_import'
$extractDir = Join-Path $tmpRoot 'extract'
$preparedCsv = Join-Path $tmpRoot 'kaggle_staging_prepared.csv'

if (Test-Path $tmpRoot) {
    Remove-Item $tmpRoot -Recurse -Force
}
New-Item -ItemType Directory -Force $extractDir | Out-Null

Write-Host "Extrayendo: $ZipPath"
Expand-Archive -Path $ZipPath -DestinationPath $extractDir -Force

$csvPath = Join-Path $extractDir $CsvName
if (-not (Test-Path $csvPath)) {
    $available = (Get-ChildItem $extractDir -File | Select-Object -ExpandProperty Name) -join ', '
    throw "No se encontro '$CsvName' dentro del ZIP. Archivos disponibles: $available"
}

Write-Host "Leyendo: $CsvName"
$rows = @(Import-Csv -Path $csvPath -Encoding UTF8)
if ($rows.Count -eq 0) {
    throw 'El CSV no contiene filas.'
}

$requiredColumns = @('Rk','Player','Nation','Pos','Squad','Comp','Age','Born','MP','Starts','Min','90s','Gls','Ast','G+A','G-PK','PK','PKatt','CrdY','CrdR','G+A-PK','Sh','SoT','SoT%','Sh/90','SoT/90','G/Sh','G/SoT','Crs','TklW','Int','Fld','Fls','Off','2CrdY','OG')
$actualColumns = @($rows[0].PSObject.Properties.Name)
$missing = @($requiredColumns | Where-Object { $_ -notin $actualColumns })
if ($missing.Count -gt 0) {
    throw "El CSV no tiene las columnas esperadas: $($missing -join ', ')"
}

$fileHash = (Get-FileHash -Path $csvPath -Algorithm SHA256).Hash.ToLowerInvariant()
$sourceFileName = [System.IO.Path]::GetFileName($csvPath)

# Crea o reutiliza el lote. La misma version del archivo (mismo SHA256) reutiliza el batch.
$batchSql = @"
WITH src AS (
    SELECT id AS source_id FROM data_source WHERE code = 'KAGGLE_FBREF'
), upsert AS (
    INSERT INTO kaggle_import_batch (
        source_id, season, season_label, source_filename, file_sha256, row_count, imported_at, updated_at
    )
    SELECT source_id, $Season, '$($SeasonLabel.Replace("'", "''"))', '$($sourceFileName.Replace("'", "''"))', '$fileHash', $($rows.Count), NOW(), NOW()
    FROM src
    ON CONFLICT (source_id, file_sha256) DO UPDATE SET
        season = EXCLUDED.season,
        season_label = EXCLUDED.season_label,
        source_filename = EXCLUDED.source_filename,
        row_count = EXCLUDED.row_count,
        imported_at = NOW(),
        updated_at = NOW()
    RETURNING id
)
SELECT id FROM upsert;
"@

$batchOutput = docker exec vinotinto-lab-postgres psql -Atq -v ON_ERROR_STOP=1 -U vinotinto -d vinotinto_lab -c $batchSql
if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear/reutilizar el lote de importacion.' }
$batchId = ($batchOutput | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
if (-not $batchId) { throw "No se pudo determinar batch_id. Salida: $($batchOutput -join ' | ')" }

$sourceIdOutput = docker exec vinotinto-lab-postgres psql -Atq -v ON_ERROR_STOP=1 -U vinotinto -d vinotinto_lab -c "SELECT id FROM data_source WHERE code='KAGGLE_FBREF';"
if ($LASTEXITCODE -ne 0) { throw 'No se pudo obtener source_id de KAGGLE_FBREF.' }
$sourceId = ($sourceIdOutput | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
if (-not $sourceId) { throw 'No existe la fuente KAGGLE_FBREF. Ejecuta primero sql/003_kaggle_staging.sql.' }

Write-Host "Preparando $($rows.Count) filas para PostgreSQL..."
$prepared = New-Object System.Collections.Generic.List[object]
$rowNumber = 0

foreach ($row in $rows) {
    $rowNumber++

    $nationParts = Split-FirstToken $row.Nation
    $compParts = Split-FirstToken $row.Comp
    $sourcePlayerKey = Get-Sha256Hex ("{0}|{1}|{2}" -f $row.Player, $row.Born, $row.Nation)
    $payload = (Normalize-JsonObject $row | ConvertTo-Json -Depth 8 -Compress)

    $prepared.Add([pscustomobject][ordered]@{
        batch_id                    = [int64]$batchId
        source_id                   = [int64]$sourceId
        source_row_number           = $rowNumber
        source_rank                 = Parse-NullableInt $row.Rk
        source_player_key           = $sourcePlayerKey
        player_name                 = $row.Player
        nation_raw                  = $row.Nation
        nation_country_code         = $nationParts[0]
        nation_fifa_code            = $nationParts[1]
        position_raw                = $row.Pos
        squad_name                  = $row.Squad
        competition_raw             = $row.Comp
        competition_source_code     = $compParts[0]
        competition_name            = $compParts[1]
        season                      = $Season
        season_label                = $SeasonLabel
        age                         = Parse-NullableDecimal $row.Age
        born_year                   = Parse-NullableInt $row.Born
        appearances                 = Parse-NullableInt $row.MP
        starts                      = Parse-NullableInt $row.Starts
        minutes                     = Parse-NullableInt $row.Min
        nineties                    = Parse-NullableDecimal $row.'90s'
        goals                       = Parse-NullableInt $row.Gls
        assists                     = Parse-NullableInt $row.Ast
        goal_contributions          = Parse-NullableInt $row.'G+A'
        non_penalty_goals           = Parse-NullableInt $row.'G-PK'
        penalties_scored            = Parse-NullableInt $row.PK
        penalties_attempted         = Parse-NullableInt $row.PKatt
        yellow_cards                = Parse-NullableInt $row.CrdY
        red_cards                   = Parse-NullableInt $row.CrdR
        non_penalty_ga_per90        = Parse-NullableDecimal $row.'G+A-PK'
        shots                       = Parse-NullableInt $row.Sh
        shots_on_target             = Parse-NullableInt $row.SoT
        shots_on_target_pct         = Parse-NullableDecimal $row.'SoT%'
        shots_per90                 = Parse-NullableDecimal $row.'Sh/90'
        shots_on_target_per90       = Parse-NullableDecimal $row.'SoT/90'
        goals_per_shot              = Parse-NullableDecimal $row.'G/Sh'
        goals_per_shot_on_target    = Parse-NullableDecimal $row.'G/SoT'
        crosses                     = Parse-NullableInt $row.Crs
        tackles_won                 = Parse-NullableInt $row.TklW
        interceptions               = Parse-NullableInt $row.Int
        fouls_drawn                 = Parse-NullableInt $row.Fld
        fouls_committed             = Parse-NullableInt $row.Fls
        offsides                    = Parse-NullableInt $row.Off
        second_yellow_cards         = Parse-NullableInt $row.'2CrdY'
        own_goals                   = Parse-NullableInt $row.OG
        minutes_per_appearance      = Parse-NullableDecimal $row.'Mn/MP'
        minutes_pct                 = Parse-NullableDecimal $row.'Min%'
        minutes_per_start           = Parse-NullableDecimal $row.'Mn/Start'
        complete_matches            = Parse-NullableInt $row.Compl
        sub_appearances             = Parse-NullableInt $row.Subs
        minutes_per_sub             = Parse-NullableDecimal $row.'Mn/Sub'
        unused_sub                  = Parse-NullableInt $row.unSub
        points_per_match            = Parse-NullableDecimal $row.PPM
        on_goals                    = Parse-NullableInt $row.onG
        on_goals_against            = Parse-NullableInt $row.onGA
        plus_minus                  = Parse-NullableDecimal $row.'+/-'
        plus_minus_per90            = Parse-NullableDecimal $row.'+/-90'
        on_off_per90                = Parse-NullableDecimal $row.'On-Off'
        goals_against               = Parse-NullableInt $row.GA
        goals_against_per90         = Parse-NullableDecimal $row.GA90
        shots_on_target_against     = Parse-NullableInt $row.SoTA
        saves                       = Parse-NullableInt $row.Saves
        save_pct                    = Parse-NullableDecimal $row.'Save%'
        wins                        = Parse-NullableInt $row.W
        draws                       = Parse-NullableInt $row.D
        losses                      = Parse-NullableInt $row.L
        clean_sheets                = Parse-NullableInt $row.CS
        clean_sheet_pct             = Parse-NullableDecimal $row.'CS%'
        keeper_penalty_attempts     = Parse-NullableInt $row.PKatt_stats_keeper
        keeper_penalties_allowed    = Parse-NullableInt $row.PKA
        keeper_penalties_saved      = Parse-NullableInt $row.PKsv
        keeper_penalties_missed     = Parse-NullableInt $row.PKm
        payload                     = $payload
    })
}

$prepared | Export-Csv -Path $preparedCsv -NoTypeInformation -Encoding UTF8

$containerCsv = "/tmp/kaggle_staging_$batchId.csv"
docker cp $preparedCsv "vinotinto-lab-postgres:$containerCsv" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Fallo docker cp del CSV preparado.' }

# Hace la importacion idempotente para este batch.
$deleteSql = "DELETE FROM stg_kaggle_player_season WHERE batch_id = $batchId;"
docker exec vinotinto-lab-postgres psql -v ON_ERROR_STOP=1 -U vinotinto -d vinotinto_lab -c $deleteSql | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron limpiar filas previas del batch.' }

$columns = @(
    'batch_id','source_id','source_row_number','source_rank','source_player_key',
    'player_name','nation_raw','nation_country_code','nation_fifa_code','position_raw','squad_name',
    'competition_raw','competition_source_code','competition_name','season','season_label','age','born_year',
    'appearances','starts','minutes','nineties','goals','assists','goal_contributions','non_penalty_goals',
    'penalties_scored','penalties_attempted','yellow_cards','red_cards','non_penalty_ga_per90',
    'shots','shots_on_target','shots_on_target_pct','shots_per90','shots_on_target_per90','goals_per_shot','goals_per_shot_on_target',
    'crosses','tackles_won','interceptions','fouls_drawn','fouls_committed','offsides','second_yellow_cards','own_goals',
    'minutes_per_appearance','minutes_pct','minutes_per_start','complete_matches','sub_appearances','minutes_per_sub','unused_sub',
    'points_per_match','on_goals','on_goals_against','plus_minus','plus_minus_per90','on_off_per90',
    'goals_against','goals_against_per90','shots_on_target_against','saves','save_pct','wins','draws','losses','clean_sheets','clean_sheet_pct',
    'keeper_penalty_attempts','keeper_penalties_allowed','keeper_penalties_saved','keeper_penalties_missed','payload'
) -join ','

$copySql = "\copy stg_kaggle_player_season ($columns) FROM '$containerCsv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', NULL '')"
docker exec vinotinto-lab-postgres psql -v ON_ERROR_STOP=1 -U vinotinto -d vinotinto_lab -c $copySql
if ($LASTEXITCODE -ne 0) { throw 'Fallo el COPY hacia stg_kaggle_player_season.' }

docker exec vinotinto-lab-postgres rm -f $containerCsv | Out-Null

$summarySql = @"
SELECT competition_name, COUNT(*) AS rows
FROM stg_kaggle_player_season
WHERE batch_id = $batchId
GROUP BY competition_name
ORDER BY competition_name;
"@

Write-Host ''
Write-Host 'Importacion completada.' -ForegroundColor Green
Write-Host "Batch ID: $batchId"
Write-Host "SHA256: $fileHash"
Write-Host "Filas esperadas: $($rows.Count)"
Write-Host ''
docker exec vinotinto-lab-postgres psql -U vinotinto -d vinotinto_lab -c $summarySql

$countSql = "SELECT COUNT(*) FROM stg_kaggle_player_season WHERE batch_id = $batchId;"
$countOutput = docker exec vinotinto-lab-postgres psql -Atq -U vinotinto -d vinotinto_lab -c $countSql
$loadedCount = ($countOutput | Where-Object { $_ -match '^\d+$' } | Select-Object -First 1)
Write-Host "Total cargado: $loadedCount"

if ([int]$loadedCount -ne $rows.Count) {
    throw "La cantidad cargada ($loadedCount) no coincide con el CSV ($($rows.Count))."
}

Write-Host ''
Write-Host 'OK: Kaggle 2025/26 cargado en staging.' -ForegroundColor Green
