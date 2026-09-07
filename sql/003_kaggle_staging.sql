BEGIN;

INSERT INTO data_source (code, name, base_url)
VALUES (
    'KAGGLE_FBREF',
    'Kaggle - Football Players Stats (FBref-derived)',
    NULL
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    updated_at = NOW();

CREATE TABLE IF NOT EXISTS kaggle_import_batch (
    id              BIGSERIAL PRIMARY KEY,
    source_id       BIGINT NOT NULL REFERENCES data_source(id),
    season          INTEGER NOT NULL,
    season_label    VARCHAR(20) NOT NULL,
    source_filename TEXT NOT NULL,
    file_sha256     VARCHAR(64) NOT NULL,
    row_count       INTEGER,
    imported_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_kaggle_import_batch UNIQUE (source_id, file_sha256)
);

CREATE TABLE IF NOT EXISTS stg_kaggle_player_season (
    id                          BIGSERIAL PRIMARY KEY,
    batch_id                    BIGINT NOT NULL REFERENCES kaggle_import_batch(id) ON DELETE CASCADE,
    source_id                   BIGINT NOT NULL REFERENCES data_source(id),
    source_row_number           INTEGER NOT NULL,
    source_rank                 INTEGER,
    source_player_key           VARCHAR(64) NOT NULL,

    player_name                 VARCHAR(180) NOT NULL,
    nation_raw                  VARCHAR(80),
    nation_country_code         VARCHAR(12),
    nation_fifa_code            VARCHAR(12),
    position_raw                VARCHAR(40),
    squad_name                  VARCHAR(180) NOT NULL,
    competition_raw             VARCHAR(180) NOT NULL,
    competition_source_code     VARCHAR(20),
    competition_name            VARCHAR(160) NOT NULL,
    season                      INTEGER NOT NULL,
    season_label                VARCHAR(20) NOT NULL,
    age                         NUMERIC(5,2),
    born_year                   INTEGER,

    appearances                 INTEGER,
    starts                      INTEGER,
    minutes                     INTEGER,
    nineties                    NUMERIC(8,2),
    goals                       INTEGER,
    assists                     INTEGER,
    goal_contributions          INTEGER,
    non_penalty_goals           INTEGER,
    penalties_scored            INTEGER,
    penalties_attempted         INTEGER,
    yellow_cards                INTEGER,
    red_cards                   INTEGER,
    non_penalty_ga_per90        NUMERIC(8,4),

    shots                       INTEGER,
    shots_on_target             INTEGER,
    shots_on_target_pct         NUMERIC(8,3),
    shots_per90                 NUMERIC(8,3),
    shots_on_target_per90       NUMERIC(8,3),
    goals_per_shot              NUMERIC(8,4),
    goals_per_shot_on_target    NUMERIC(8,4),

    crosses                     INTEGER,
    tackles_won                 INTEGER,
    interceptions               INTEGER,
    fouls_drawn                 INTEGER,
    fouls_committed             INTEGER,
    offsides                    INTEGER,
    second_yellow_cards         INTEGER,
    own_goals                   INTEGER,

    minutes_per_appearance      NUMERIC(8,2),
    minutes_pct                 NUMERIC(8,3),
    minutes_per_start           NUMERIC(8,2),
    complete_matches            INTEGER,
    sub_appearances             INTEGER,
    minutes_per_sub             NUMERIC(8,2),
    unused_sub                  INTEGER,
    points_per_match            NUMERIC(8,3),
    on_goals                    INTEGER,
    on_goals_against            INTEGER,
    plus_minus                  NUMERIC(8,2),
    plus_minus_per90            NUMERIC(8,3),
    on_off_per90                NUMERIC(8,3),

    goals_against               INTEGER,
    goals_against_per90         NUMERIC(8,3),
    shots_on_target_against     INTEGER,
    saves                       INTEGER,
    save_pct                    NUMERIC(8,3),
    wins                        INTEGER,
    draws                       INTEGER,
    losses                      INTEGER,
    clean_sheets                INTEGER,
    clean_sheet_pct             NUMERIC(8,3),
    keeper_penalty_attempts     INTEGER,
    keeper_penalties_allowed    INTEGER,
    keeper_penalties_saved      INTEGER,
    keeper_penalties_missed     INTEGER,

    payload                     JSONB NOT NULL,
    imported_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_stg_kaggle_batch_row UNIQUE (batch_id, source_row_number)
);

CREATE INDEX IF NOT EXISTS ix_stg_kaggle_player_name
    ON stg_kaggle_player_season (player_name);

CREATE INDEX IF NOT EXISTS ix_stg_kaggle_source_player_key
    ON stg_kaggle_player_season (source_player_key);

CREATE INDEX IF NOT EXISTS ix_stg_kaggle_competition_season
    ON stg_kaggle_player_season (competition_name, season);

CREATE INDEX IF NOT EXISTS ix_stg_kaggle_squad_season
    ON stg_kaggle_player_season (squad_name, season);

CREATE INDEX IF NOT EXISTS ix_stg_kaggle_position
    ON stg_kaggle_player_season (position_raw);

COMMIT;
