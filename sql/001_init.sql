BEGIN;

CREATE TABLE data_source (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(50) NOT NULL UNIQUE,
    name            VARCHAR(120) NOT NULL,
    base_url        TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE competition (
    id                  BIGSERIAL PRIMARY KEY,
    api_football_id     INTEGER UNIQUE,
    name                VARCHAR(160) NOT NULL,
    country             VARCHAR(120),
    type                VARCHAR(30),
    logo_url            TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE competition_season (
    id                  BIGSERIAL PRIMARY KEY,
    competition_id      BIGINT NOT NULL REFERENCES competition(id) ON DELETE CASCADE,
    season              INTEGER NOT NULL,
    start_date          DATE,
    end_date            DATE,
    is_current          BOOLEAN NOT NULL DEFAULT FALSE,
    coverage            JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_competition_season UNIQUE (competition_id, season)
);

CREATE TABLE team (
    id                  BIGSERIAL PRIMARY KEY,
    api_football_id     INTEGER NOT NULL UNIQUE,
    name                VARCHAR(160) NOT NULL,
    code                VARCHAR(20),
    country             VARCHAR(120),
    founded             INTEGER,
    is_national         BOOLEAN,
    logo_url            TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE player (
    id                  BIGSERIAL PRIMARY KEY,
    api_football_id     INTEGER NOT NULL UNIQUE,
    name                VARCHAR(160) NOT NULL,
    firstname           VARCHAR(120),
    lastname            VARCHAR(120),
    birth_date          DATE,
    birth_place         VARCHAR(160),
    birth_country       VARCHAR(120),
    nationality         VARCHAR(120),
    height_cm           SMALLINT,
    weight_kg           SMALLINT,
    photo_url           TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE player_season_stat (
    id                      BIGSERIAL PRIMARY KEY,
    player_id               BIGINT NOT NULL REFERENCES player(id) ON DELETE CASCADE,
    competition_id          BIGINT NOT NULL REFERENCES competition(id) ON DELETE CASCADE,
    team_id                 BIGINT NOT NULL REFERENCES team(id) ON DELETE CASCADE,
    source_id               BIGINT NOT NULL REFERENCES data_source(id),
    season                  INTEGER NOT NULL,

    position                VARCHAR(60),
    shirt_number            INTEGER,
    appearances             INTEGER,
    starts                  INTEGER,
    minutes                 INTEGER,
    rating                  NUMERIC(5,2),

    substitutes_in          INTEGER,
    substitutes_out         INTEGER,
    substitutes_bench       INTEGER,

    shots_total             INTEGER,
    shots_on                INTEGER,

    goals                   INTEGER,
    goals_conceded          INTEGER,
    assists                 INTEGER,
    saves                   INTEGER,

    passes_total            INTEGER,
    passes_key              INTEGER,
    pass_accuracy_pct       NUMERIC(5,2),

    tackles_total           INTEGER,
    blocks                  INTEGER,
    interceptions           INTEGER,

    duels_total             INTEGER,
    duels_won               INTEGER,

    dribbles_attempts       INTEGER,
    dribbles_success        INTEGER,
    dribbles_past           INTEGER,

    fouls_drawn             INTEGER,
    fouls_committed         INTEGER,

    cards_yellow            INTEGER,
    cards_yellow_red        INTEGER,
    cards_red               INTEGER,

    penalties_won           INTEGER,
    penalties_committed     INTEGER,
    penalties_scored        INTEGER,
    penalties_missed        INTEGER,
    penalties_saved         INTEGER,

    fetched_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_player_season_stat
      UNIQUE (player_id, competition_id, team_id, season, source_id)
);

CREATE TABLE raw_api_data (
    id                  BIGSERIAL PRIMARY KEY,
    source_id           BIGINT NOT NULL REFERENCES data_source(id),
    endpoint            VARCHAR(160) NOT NULL,
    request_params      JSONB,
    entity_type         VARCHAR(50),
    entity_api_id       INTEGER,
    season              INTEGER,
    payload             JSONB NOT NULL,
    fetched_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_player_name ON player (name);
CREATE INDEX ix_player_nationality ON player (nationality);
CREATE INDEX ix_team_name ON team (name);
CREATE INDEX ix_competition_name ON competition (name);
CREATE INDEX ix_player_season_stat_player_season ON player_season_stat (player_id, season);
CREATE INDEX ix_player_season_stat_competition_season ON player_season_stat (competition_id, season);
CREATE INDEX ix_raw_api_data_lookup ON raw_api_data (entity_type, entity_api_id, season, fetched_at DESC);

INSERT INTO data_source (code, name, base_url)
VALUES ('API_FOOTBALL', 'API-Football', 'https://v3.football.api-sports.io')
ON CONFLICT (code) DO NOTHING;

COMMIT;
