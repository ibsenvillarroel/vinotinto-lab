BEGIN;

CREATE TABLE IF NOT EXISTS player_identity_override (
    id BIGSERIAL PRIMARY KEY,

    source_player_key VARCHAR(64) NOT NULL,
    season INTEGER NOT NULL,

    squad_name VARCHAR(255) NOT NULL,
    competition_name VARCHAR(255) NOT NULL,

    canonical_player_key VARCHAR(128) NOT NULL,
    canonical_player_name VARCHAR(255) NOT NULL,

    resolution_reason TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_player_identity_override
        UNIQUE (
            source_player_key,
            season,
            squad_name,
            competition_name
        )
);


/*
    Known identity collision:

    Two different Portuguese players named Vitinha,
    both born in 2000, are represented by the same
    source_player_key because the source only contains
    birth year rather than full birth date.

    Genoa:
      Vitinha — forward

    Paris Saint-Germain:
      Vitinha — midfielder
*/

INSERT INTO player_identity_override (
    source_player_key,
    season,
    squad_name,
    competition_name,
    canonical_player_key,
    canonical_player_name,
    resolution_reason
)
SELECT
    s.source_player_key,
    s.season,
    s.squad_name,
    s.competition_name,

    CASE
        WHEN s.squad_name = 'Genoa'
            THEN 'KAGGLE:VITINHA:GENOA:2000:POR'

        WHEN s.squad_name = 'Paris Saint-Germain'
            THEN 'KAGGLE:VITINHA:PSG:2000:POR'
    END,

    s.player_name,

    'Manual resolution of same-name/same-birth-year/same-nation identity collision'

FROM stg_kaggle_player_season s

WHERE s.player_name = 'Vitinha'
  AND s.born_year = 2000
  AND s.nation_fifa_code = 'POR'
  AND s.squad_name IN (
      'Genoa',
      'Paris Saint-Germain'
  )

ON CONFLICT (
    source_player_key,
    season,
    squad_name,
    competition_name
)
DO UPDATE SET
    canonical_player_key =
        EXCLUDED.canonical_player_key,

    canonical_player_name =
        EXCLUDED.canonical_player_name,

    resolution_reason =
        EXCLUDED.resolution_reason,

    updated_at = NOW();


CREATE OR REPLACE VIEW vw_kaggle_player_identity_resolved AS
SELECT
    s.*,

    COALESCE(
        o.canonical_player_key,
        s.source_player_key
    ) AS canonical_player_key,

    COALESCE(
        o.canonical_player_name,
        s.player_name
    ) AS canonical_player_name,

    CASE
        WHEN o.id IS NOT NULL
            THEN TRUE
        ELSE FALSE
    END AS identity_overridden

FROM stg_kaggle_player_season s

LEFT JOIN player_identity_override o
    ON o.source_player_key = s.source_player_key
   AND o.season = s.season
   AND o.squad_name = s.squad_name
   AND o.competition_name = s.competition_name;


COMMENT ON TABLE player_identity_override IS
'Manual identity-resolution layer for ambiguous source player keys. Preserves source data while allowing distinct real-world players to receive separate canonical identities.';

COMMENT ON VIEW vw_kaggle_player_identity_resolved IS
'Kaggle staging data enriched with canonical player identity after explicit identity-resolution overrides.';

COMMIT;