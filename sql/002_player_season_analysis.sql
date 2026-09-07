CREATE OR REPLACE VIEW vw_player_season_analysis AS
SELECT
    p.id AS player_id,
    p.api_football_id,
    p.name AS player_name,
    p.nationality,

    t.id AS team_id,
    t.name AS team_name,

    c.id AS competition_id,
    c.name AS competition_name,
    c.country AS competition_country,

    pss.season,
    pss.position,
    pss.appearances,
    pss.starts,
    pss.minutes,
    pss.rating,

    pss.goals,
    pss.assists,
    pss.penalties_scored,
    pss.penalties_missed,

    pss.shots_total,
    pss.shots_on,

    pss.passes_total,
    pss.passes_key,

    pss.duels_total,
    pss.duels_won,

    pss.dribbles_attempts,
    pss.dribbles_success,

    /* Producción ofensiva */
    ROUND(
        pss.goals * 90.0 / NULLIF(pss.minutes, 0),
        2
    ) AS goals_per_90,

    ROUND(
        pss.assists * 90.0 / NULLIF(pss.minutes, 0),
        2
    ) AS assists_per_90,

    (COALESCE(pss.goals, 0) + COALESCE(pss.assists, 0))
        AS goal_contributions,

    ROUND(
        (COALESCE(pss.goals, 0) + COALESCE(pss.assists, 0))
        * 90.0 / NULLIF(pss.minutes, 0),
        2
    ) AS goal_contributions_per_90,

    /* Remate */
    ROUND(
        pss.shots_total * 90.0 / NULLIF(pss.minutes, 0),
        2
    ) AS shots_per_90,

    ROUND(
        pss.shots_on * 90.0 / NULLIF(pss.minutes, 0),
        2
    ) AS shots_on_per_90,

    ROUND(
        pss.shots_on * 100.0 / NULLIF(pss.shots_total, 0),
        2
    ) AS shots_on_pct,

    ROUND(
        pss.goals * 100.0 / NULLIF(pss.shots_total, 0),
        2
    ) AS goal_conversion_pct,

    ROUND(
        pss.minutes * 1.0 / NULLIF(pss.goals, 0),
        2
    ) AS minutes_per_goal,

    /* Sin penaltis */
    (
        COALESCE(pss.goals, 0)
        - COALESCE(pss.penalties_scored, 0)
    ) AS non_penalty_goals,

    ROUND(
        (
            COALESCE(pss.goals, 0)
            - COALESCE(pss.penalties_scored, 0)
        ) * 90.0 / NULLIF(pss.minutes, 0),
        2
    ) AS non_penalty_goals_per_90,

    /* Creación */
    ROUND(
        pss.passes_key * 90.0 / NULLIF(pss.minutes, 0),
        2
    ) AS key_passes_per_90,

    /* Regate */
    ROUND(
        pss.dribbles_success * 100.0
        / NULLIF(pss.dribbles_attempts, 0),
        2
    ) AS dribble_success_pct,

    /* Duelos */
    ROUND(
        pss.duels_won * 100.0
        / NULLIF(pss.duels_total, 0),
        2
    ) AS duels_won_pct

FROM player_season_stat pss
JOIN player p
    ON p.id = pss.player_id
JOIN team t
    ON t.id = pss.team_id
JOIN competition c
    ON c.id = pss.competition_id;