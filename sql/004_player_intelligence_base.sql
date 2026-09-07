BEGIN;

CREATE OR REPLACE VIEW vw_player_intelligence_base AS
WITH normalized AS (
    SELECT
        s.id,
        s.batch_id,
        s.source_id,
        s.source_player_key,

        s.player_name,
        s.nation_raw,
        s.nation_country_code,
        s.nation_fifa_code,

        s.position_raw,

        CASE
            WHEN s.position_raw IN ('MF,FW', 'FW,MF') THEN 'FW_MF'
            WHEN s.position_raw IN ('DF,MF', 'MF,DF') THEN 'DF_MF'
            WHEN s.position_raw IN ('DF,FW', 'FW,DF') THEN 'DF_FW'
            WHEN s.position_raw = 'FW' THEN 'FW'
            WHEN s.position_raw = 'MF' THEN 'MF'
            WHEN s.position_raw = 'DF' THEN 'DF'
            WHEN s.position_raw = 'GK' THEN 'GK'
            ELSE 'UNKNOWN'
        END AS position_group,

        s.squad_name,
        s.competition_name,
        s.season,
        s.season_label,

        s.age,
        s.born_year,

        s.appearances,
        s.starts,
        s.minutes,
        s.nineties,

        s.goals,
        s.assists,
        s.goal_contributions,
        s.non_penalty_goals,
        s.penalties_scored,
        s.penalties_attempted,

        s.yellow_cards,
        s.red_cards,

        s.shots,
        s.shots_on_target,
        s.shots_on_target_pct,
        s.shots_per90,
        s.shots_on_target_per90,
        s.goals_per_shot,
        s.goals_per_shot_on_target,

        s.crosses,
        s.tackles_won,
        s.interceptions,
        s.fouls_drawn,
        s.fouls_committed,
        s.offsides,

        s.minutes_per_appearance,
        s.minutes_pct,
        s.minutes_per_start,
        s.complete_matches,
        s.sub_appearances,
        s.minutes_per_sub,

        s.points_per_match,
        s.plus_minus,
        s.plus_minus_per90,
        s.on_off_per90,

        s.goals_against,
        s.goals_against_per90,
        s.shots_on_target_against,
        s.saves,
        s.save_pct,
        s.wins,
        s.draws,
        s.losses,
        s.clean_sheets,
        s.clean_sheet_pct,

        s.keeper_penalty_attempts,
        s.keeper_penalties_allowed,
        s.keeper_penalties_saved,
        s.keeper_penalties_missed,

        s.imported_at

    FROM stg_kaggle_player_season s
)

SELECT
    n.*,

    /* =========================================================
       ROLE / COMPARISON COHORT
       ========================================================= */

    CASE
        WHEN n.position_group = 'GK' THEN 'GOALKEEPER'
        WHEN n.position_group = 'DF' THEN 'DEFENDER'
        WHEN n.position_group = 'DF_MF' THEN 'DEFENSIVE_HYBRID'
        WHEN n.position_group = 'MF' THEN 'MIDFIELDER'
        WHEN n.position_group = 'FW_MF' THEN 'ATTACKING_HYBRID'
        WHEN n.position_group = 'FW' THEN 'FORWARD'
        WHEN n.position_group = 'DF_FW' THEN 'OTHER_HYBRID'
        ELSE 'UNKNOWN'
    END AS role_family,

    /*
       900 minutos será inicialmente nuestro umbral
       mínimo para incluir a un jugador en cálculos
       de similitud.
    */
    CASE
        WHEN COALESCE(n.minutes, 0) >= 900
             AND n.position_group <> 'UNKNOWN'
        THEN TRUE
        ELSE FALSE
    END AS is_similarity_eligible,

    CASE
        WHEN COALESCE(n.minutes, 0) >= 1800 THEN 'HIGH'
        WHEN COALESCE(n.minutes, 0) >= 900 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS sample_quality,

    /* =========================================================
       ATTACKING PRODUCTION / 90
       ========================================================= */

    ROUND(
        COALESCE(n.goals, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS goals_per90,

    ROUND(
        COALESCE(n.assists, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS assists_per90,

    ROUND(
        COALESCE(n.goal_contributions, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS goal_contributions_per90,

    ROUND(
        COALESCE(n.non_penalty_goals, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS non_penalty_goals_per90,

    /* =========================================================
       GENERAL PLAY / 90
       ========================================================= */

    ROUND(
        COALESCE(n.crosses, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS crosses_per90,

    ROUND(
        COALESCE(n.tackles_won, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS tackles_won_per90,

    ROUND(
        COALESCE(n.interceptions, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS interceptions_per90,

    ROUND(
        COALESCE(n.fouls_drawn, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS fouls_drawn_per90,

    ROUND(
        COALESCE(n.fouls_committed, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS fouls_committed_per90,

    ROUND(
        COALESCE(n.offsides, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS offsides_per90,

    ROUND(
        COALESCE(n.yellow_cards, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS yellow_cards_per90,

    ROUND(
        COALESCE(n.red_cards, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS red_cards_per90,

    /* =========================================================
       GOALKEEPER METRICS / 90
       ========================================================= */

    ROUND(
        COALESCE(n.saves, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS saves_per90,

    ROUND(
        COALESCE(n.shots_on_target_against, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS shots_on_target_against_per90,

    ROUND(
        COALESCE(n.clean_sheets, 0)::numeric
        * 90
        / NULLIF(n.minutes, 0),
        4
    ) AS clean_sheets_per90

FROM normalized n;

COMMENT ON VIEW vw_player_intelligence_base IS
'Normalized analytical base for Vinotinto Lab Player Intelligence. Includes position cohorts, sample eligibility and per-90 metrics.';

COMMIT;