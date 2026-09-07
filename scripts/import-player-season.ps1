param(
    [Parameter(Mandatory = $true)]
    [string]$Search,

    [Parameter(Mandatory = $true)]
    [int]$League,

    [Parameter(Mandatory = $true)]
    [int]$Season
)

$ErrorActionPreference = 'Stop'

function Get-EnvValue {
    param([string]$Name)

    $line = Get-Content .env | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $line) {
        throw "No se encontro $Name en .env"
    }

    return ($line -replace "^$([regex]::Escape($Name))=", '').Trim()
}

function SqlText {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'NULL' }
    return "'" + ([string]$Value).Replace("'", "''") + "'"
}

function SqlInt {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'NULL' }
    return ([int64]$Value).ToString([System.Globalization.CultureInfo]::InvariantCulture)
}

function SqlDecimal {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'NULL' }
    $number = [decimal]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture)
    return $number.ToString([System.Globalization.CultureInfo]::InvariantCulture)
}

function FirstInteger {
    param($Value)
    if ($null -eq $Value) { return $null }
    $match = [regex]::Match([string]$Value, '\d+')
    if (-not $match.Success) { return $null }
    return [int]$match.Value
}

$apiKey = Get-EnvValue 'API_FOOTBALL_KEY'
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'API_FOOTBALL_KEY esta vacio en .env'
}

$encodedSearch = [uri]::EscapeDataString($Search)
$url = "https://v3.football.api-sports.io/players?search=$encodedSearch&league=$League&season=$Season"
$headers = @{ 'x-apisports-key' = $apiKey }

Write-Host "Consultando API-Football: $Search | league=$League | season=$Season"
$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

if ($response.errors -and $response.errors.PSObject.Properties.Count -gt 0) {
    $errorJson = $response.errors | ConvertTo-Json -Depth 10 -Compress
    throw "API-Football devolvio errores: $errorJson"
}

$entries = @($response.response)
if ($entries.Count -eq 0) {
    throw "No se encontraron jugadores para '$Search' en league=$League season=$Season"
}

$entry = $entries | Where-Object { $_.player.name -like "*$Search*" } | Select-Object -First 1
if (-not $entry) { $entry = $entries[0] }

$player = $entry.player
$statsList = @($entry.statistics) | Where-Object { $_.league.id -eq $League -and $_.league.season -eq $Season }
if ($statsList.Count -eq 0) {
    throw 'Se encontro el jugador, pero no estadisticas para la liga/temporada solicitada.'
}

New-Item -ItemType Directory -Force data\raw | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$rawPath = ".\data\raw\player_$($player.id)_league_${League}_season_${Season}_$timestamp.json"
$rawJsonPretty = $response | ConvertTo-Json -Depth 30
$rawJsonPretty | Set-Content -Path $rawPath -Encoding UTF8

$rawJson = $response | ConvertTo-Json -Depth 30 -Compress
$rawJsonSql = $rawJson.Replace("'", "''")
$requestParams = (@{ search = $Search; league = $League; season = $Season } | ConvertTo-Json -Compress).Replace("'", "''")

$heightCm = FirstInteger $player.height
$weightKg = FirstInteger $player.weight

$sql = @"
BEGIN;

INSERT INTO player (
    api_football_id, name, firstname, lastname,
    birth_date, birth_place, birth_country, nationality,
    height_cm, weight_kg, photo_url, updated_at
)
VALUES (
    $(SqlInt $player.id), $(SqlText $player.name), $(SqlText $player.firstname), $(SqlText $player.lastname),
    $(SqlText $player.birth.date), $(SqlText $player.birth.place), $(SqlText $player.birth.country), $(SqlText $player.nationality),
    $(SqlInt $heightCm), $(SqlInt $weightKg), $(SqlText $player.photo), NOW()
)
ON CONFLICT (api_football_id) DO UPDATE SET
    name = EXCLUDED.name,
    firstname = EXCLUDED.firstname,
    lastname = EXCLUDED.lastname,
    birth_date = EXCLUDED.birth_date,
    birth_place = EXCLUDED.birth_place,
    birth_country = EXCLUDED.birth_country,
    nationality = EXCLUDED.nationality,
    height_cm = EXCLUDED.height_cm,
    weight_kg = EXCLUDED.weight_kg,
    photo_url = EXCLUDED.photo_url,
    updated_at = NOW();
"@

foreach ($stat in $statsList) {
    $sql += @"

INSERT INTO competition (
    api_football_id, name, country, logo_url, updated_at
)
VALUES (
    $(SqlInt $stat.league.id), $(SqlText $stat.league.name), $(SqlText $stat.league.country), $(SqlText $stat.league.logo), NOW()
)
ON CONFLICT (api_football_id) DO UPDATE SET
    name = EXCLUDED.name,
    country = EXCLUDED.country,
    logo_url = EXCLUDED.logo_url,
    updated_at = NOW();

INSERT INTO competition_season (competition_id, season, updated_at)
VALUES (
    (SELECT id FROM competition WHERE api_football_id = $(SqlInt $stat.league.id)),
    $(SqlInt $stat.league.season),
    NOW()
)
ON CONFLICT (competition_id, season) DO UPDATE SET
    updated_at = NOW();

INSERT INTO team (
    api_football_id, name, logo_url, updated_at
)
VALUES (
    $(SqlInt $stat.team.id), $(SqlText $stat.team.name), $(SqlText $stat.team.logo), NOW()
)
ON CONFLICT (api_football_id) DO UPDATE SET
    name = EXCLUDED.name,
    logo_url = EXCLUDED.logo_url,
    updated_at = NOW();

INSERT INTO player_season_stat (
    player_id, competition_id, team_id, source_id, season,
    position, shirt_number, appearances, starts, minutes, rating,
    substitutes_in, substitutes_out, substitutes_bench,
    shots_total, shots_on,
    goals, goals_conceded, assists, saves,
    passes_total, passes_key, pass_accuracy_pct,
    tackles_total, blocks, interceptions,
    duels_total, duels_won,
    dribbles_attempts, dribbles_success, dribbles_past,
    fouls_drawn, fouls_committed,
    cards_yellow, cards_yellow_red, cards_red,
    penalties_won, penalties_committed, penalties_scored, penalties_missed, penalties_saved,
    fetched_at, updated_at
)
VALUES (
    (SELECT id FROM player WHERE api_football_id = $(SqlInt $player.id)),
    (SELECT id FROM competition WHERE api_football_id = $(SqlInt $stat.league.id)),
    (SELECT id FROM team WHERE api_football_id = $(SqlInt $stat.team.id)),
    (SELECT id FROM data_source WHERE code = 'API_FOOTBALL'),
    $(SqlInt $stat.league.season),
    $(SqlText $stat.games.position), $(SqlInt $stat.games.number), $(SqlInt $stat.games.appearences), $(SqlInt $stat.games.lineups), $(SqlInt $stat.games.minutes), $(SqlDecimal $stat.games.rating),
    $(SqlInt $stat.substitutes.in), $(SqlInt $stat.substitutes.out), $(SqlInt $stat.substitutes.bench),
    $(SqlInt $stat.shots.total), $(SqlInt $stat.shots.on),
    $(SqlInt $stat.goals.total), $(SqlInt $stat.goals.conceded), $(SqlInt $stat.goals.assists), $(SqlInt $stat.goals.saves),
    $(SqlInt $stat.passes.total), $(SqlInt $stat.passes.key), $(SqlDecimal $stat.passes.accuracy),
    $(SqlInt $stat.tackles.total), $(SqlInt $stat.tackles.blocks), $(SqlInt $stat.tackles.interceptions),
    $(SqlInt $stat.duels.total), $(SqlInt $stat.duels.won),
    $(SqlInt $stat.dribbles.attempts), $(SqlInt $stat.dribbles.success), $(SqlInt $stat.dribbles.past),
    $(SqlInt $stat.fouls.drawn), $(SqlInt $stat.fouls.committed),
    $(SqlInt $stat.cards.yellow), $(SqlInt $stat.cards.yellowred), $(SqlInt $stat.cards.red),
    $(SqlInt $stat.penalty.won), $(SqlInt $stat.penalty.commited), $(SqlInt $stat.penalty.scored), $(SqlInt $stat.penalty.missed), $(SqlInt $stat.penalty.saved),
    NOW(), NOW()
)
ON CONFLICT (player_id, competition_id, team_id, season, source_id) DO UPDATE SET
    position = EXCLUDED.position,
    shirt_number = EXCLUDED.shirt_number,
    appearances = EXCLUDED.appearances,
    starts = EXCLUDED.starts,
    minutes = EXCLUDED.minutes,
    rating = EXCLUDED.rating,
    substitutes_in = EXCLUDED.substitutes_in,
    substitutes_out = EXCLUDED.substitutes_out,
    substitutes_bench = EXCLUDED.substitutes_bench,
    shots_total = EXCLUDED.shots_total,
    shots_on = EXCLUDED.shots_on,
    goals = EXCLUDED.goals,
    goals_conceded = EXCLUDED.goals_conceded,
    assists = EXCLUDED.assists,
    saves = EXCLUDED.saves,
    passes_total = EXCLUDED.passes_total,
    passes_key = EXCLUDED.passes_key,
    pass_accuracy_pct = EXCLUDED.pass_accuracy_pct,
    tackles_total = EXCLUDED.tackles_total,
    blocks = EXCLUDED.blocks,
    interceptions = EXCLUDED.interceptions,
    duels_total = EXCLUDED.duels_total,
    duels_won = EXCLUDED.duels_won,
    dribbles_attempts = EXCLUDED.dribbles_attempts,
    dribbles_success = EXCLUDED.dribbles_success,
    dribbles_past = EXCLUDED.dribbles_past,
    fouls_drawn = EXCLUDED.fouls_drawn,
    fouls_committed = EXCLUDED.fouls_committed,
    cards_yellow = EXCLUDED.cards_yellow,
    cards_yellow_red = EXCLUDED.cards_yellow_red,
    cards_red = EXCLUDED.cards_red,
    penalties_won = EXCLUDED.penalties_won,
    penalties_committed = EXCLUDED.penalties_committed,
    penalties_scored = EXCLUDED.penalties_scored,
    penalties_missed = EXCLUDED.penalties_missed,
    penalties_saved = EXCLUDED.penalties_saved,
    fetched_at = NOW(),
    updated_at = NOW();
"@
}

$sql += @"

INSERT INTO raw_api_data (
    source_id, endpoint, request_params, entity_type, entity_api_id, season, payload, fetched_at
)
VALUES (
    (SELECT id FROM data_source WHERE code = 'API_FOOTBALL'),
    '/players',
    '$requestParams'::jsonb,
    'player',
    $(SqlInt $player.id),
    $Season,
    '$rawJsonSql'::jsonb,
    NOW()
);

COMMIT;
"@

New-Item -ItemType Directory -Force data\tmp | Out-Null
$sqlPath = ".\data\tmp\import_player_$($player.id)_${League}_${Season}_$timestamp.sql"
$sql | Set-Content -Path $sqlPath -Encoding UTF8

$containerSqlPath = "/tmp/import_player_$($player.id)_${League}_${Season}_$timestamp.sql"

docker cp $sqlPath "vinotinto-lab-postgres:$containerSqlPath" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Fallo docker cp del SQL temporal.' }

docker exec vinotinto-lab-postgres psql -v ON_ERROR_STOP=1 -U vinotinto -d vinotinto_lab -f $containerSqlPath
if ($LASTEXITCODE -ne 0) { throw 'Fallo la carga en PostgreSQL.' }

docker exec vinotinto-lab-postgres rm -f $containerSqlPath | Out-Null

Write-Host ''
Write-Host "OK: $($player.name) importado correctamente." -ForegroundColor Green
Write-Host "JSON crudo: $rawPath"
Write-Host ''
Write-Host 'Resumen guardado:'
foreach ($stat in $statsList) {
    Write-Host "- $($stat.team.name) | $($stat.league.name) $($stat.league.season) | PJ=$($stat.games.appearences) | MIN=$($stat.games.minutes) | G=$($stat.goals.total) | A=$($stat.goals.assists)"
}
