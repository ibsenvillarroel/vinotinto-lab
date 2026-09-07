BEGIN;

CREATE OR REPLACE VIEW vw_player_season_canonical AS
WITH ranked_stints AS (
    SELECT
        s.*,

        ROW_NUMBER() OVER (
            PARTITION BY
                s.source_player_key,
                s.season
            ORDER BY
                s.minutes DESC NULLS LAST,
                s.id
        ) AS stint_rank

    FROM stg_kaggle_player_season s
),

primary_stint AS (
    SELECT
        source_player_key,
        season,

        player_name,
        nation_raw,
        nation_country_code,
        nation_fifa_code,

        position_raw,

        squad_name AS primary_squad_name,
        competition_name AS primary_competition_name

    FROM ranked_stints
    WHERE stint_rank = 1
),

aggregated AS (
    SELECT
        source_player_key,
        season,

        MAX(season_label) AS season_label,

        MAX(age) AS age,
        MAX(born_year) AS born_year,

        COUNT(*) AS stint_count,

        STRING_AGG(
            DISTINCT squad_name,
            ' | '
            ORDER BY squad_name
        ) AS squad_names,

        STRING_AGG(
            DISTINCT competition_name,
            ' | '
            ORDER BY competition_name
        ) AS competition_names,

        SUM(COALESCE(appearances, 0)) AS appearances,
        SUM(COALESCE(starts, 0)) AS starts,
        SUM(COALESCE(minutes, 0)) AS minutes,

        SUM(COALESCE(goals, 0)) AS goals,
        SUM(COALESCE(assists, 0)) AS assists,
        SUM(COALESCE(goal_contributions, 0))
            AS goal_contributions,

        SUM(COALESCE(non_penalty_goals, 0))
            AS non_penalty_goals,

        SUM(COALESCE(penalties_scored, 0))
            AS penalties_scored,

        SUM(COALESCE(penalties_attempted, 0))
            AS penalties_attempted,

        SUM(COALESCE(shots, 0)) AS shots,
        SUM(COALESCE(shots_on_target, 0))
            AS shots_on_target,

        SUM(COALESCE(crosses, 0)) AS crosses,
        SUM(COALESCE(tackles_won, 0)) AS tackles_won,
        SUM(COALESCE(interceptions, 0)) AS interceptions,
        SUM(COALESCE(fouls_drawn, 0)) AS fouls_drawn,
        SUM(COALESCE(fouls_committed, 0)) AS fouls_committed,
        SUM(COALESCE(offsides, 0)) AS offsides,

        SUM(COALESCE(yellow_cards, 0)) AS yellow_cards,
        SUM(COALESCE(red_cards, 0)) AS red_cards

    FROM stg_kaggle_player_season

    GROUP BY
        source_player_key,
        season
)

SELECT
    a.source_player_key,
    a.season,
    a.season_label,

    p.player_name,

    p.nation_raw,
    p.nation_country_code,
    p.nation_fifa_code,

    p.position_raw,

    CASE
        WHEN p.position_raw IN ('MF,FW', 'FW,MF')
            THEN 'FW_MF'

        WHEN p.position_raw IN ('DF,MF', 'MF,DF')
            THEN 'DF_MF'

        WHEN p.position_raw IN ('DF,FW', 'FW,DF')
            THEN 'DF_FW'

        WHEN p.position_raw = 'FW'
            THEN 'FW'

        WHEN p.position_raw = 'MF'
            THEN 'MF'

        WHEN p.position_raw = 'DF'
            THEN 'DF'

        WHEN p.position_raw = 'GK'
            THEN 'GK'

        ELSE 'UNKNOWN'
    END AS position_group,

    p.primary_squad_name,
    p.primary_competition_name,

    a.squad_names,
    a.competition_names,

    a.stint_count,

    a.age,
    a.born_year,

    a.appearances,
    a.starts,
    a.minutes,

    a.goals,
    a.assists,
    a.goal_contributions,
    a.non_penalty_goals,
    a.penalties_scored,
    a.penalties_attempted,

    a.shots,
    a.shots_on_target,

    a.crosses,
    a.tackles_won,
    a.interceptions,
    a.fouls_drawn,
    a.fouls_committed,
    a.offsides,

    a.yellow_cards,
    a.red_cards,

    CASE
        WHEN a.minutes >= 900
             AND p.position_raw <> 'GK'
        THEN TRUE
        ELSE FALSE
    END AS is_similarity_eligible,

    CASE
        WHEN a.minutes >= 1800 THEN 'HIGH'
        WHEN a.minutes >= 900 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS sample_quality,

    ROUND(
        a.non_penalty_goals::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS non_penalty_goals_per90,

    ROUND(
        a.assists::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS assists_per90,

    ROUND(
        a.shots::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS shots_per90,

    ROUND(
        a.shots_on_target::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS shots_on_target_per90,

    ROUND(
        a.crosses::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS crosses_per90,

    ROUND(
        a.fouls_drawn::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS fouls_drawn_per90,

    ROUND(
        a.tackles_won::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS tackles_won_per90,

    ROUND(
        a.interceptions::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS interceptions_per90,

    ROUND(
        a.fouls_committed::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS fouls_committed_per90,

    ROUND(
        a.offsides::numeric
        * 90
        / NULLIF(a.minutes, 0),
        4
    ) AS offsides_per90

FROM aggregated a

JOIN primary_stint p
    ON p.source_player_key = a.source_player_key
   AND p.season = a.season;

COMMENT ON VIEW vw_player_season_canonical IS
'Canonical player-season layer. Aggregates multiple club stints into one seasonal player record and recomputes per-90 metrics from aggregated totals.';

COMMIT;