from __future__ import annotations

import pandas as pd
from psycopg.rows import dict_row

from vinotinto_lab.analytics.similarity.player_similarity import (
    AmbiguousPlayerError,
    PlayerClubMismatchError,
    PlayerNotFoundError,
)
from vinotinto_lab.database.connection import get_connection


def load_player_profiles() -> pd.DataFrame:
    query = """
        SELECT
            canonical_player_key,
            source_player_key,

            season,
            season_label,

            player_name,

            nation_raw,
            nation_country_code,
            nation_fifa_code,

            position_raw,
            position_group,

            primary_squad_name,
            primary_competition_name,

            squad_names,
            competition_names,

            stint_count,

            age,
            born_year,

            appearances,
            starts,
            minutes,

            goals,
            assists,
            goal_contributions,
            non_penalty_goals,

            penalties_scored,
            penalties_attempted,

            shots,
            shots_on_target,

            crosses,
            tackles_won,
            interceptions,

            fouls_drawn,
            fouls_committed,
            offsides,

            yellow_cards,
            red_cards,

            is_similarity_eligible,
            sample_quality,

            non_penalty_goals_per90,
            assists_per90,
            shots_per90,
            shots_on_target_per90,
            crosses_per90,
            fouls_drawn_per90,
            tackles_won_per90,
            interceptions_per90,
            fouls_committed_per90,
            offsides_per90

        FROM vw_player_season_canonical

        ORDER BY player_name;
    """

    with get_connection() as connection:
        with connection.cursor(
            row_factory=dict_row
        ) as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()

    return pd.DataFrame(rows)


def resolve_player_profile(
    player_name: str,
    club: str | None = None,
) -> pd.Series:

    players = load_player_profiles()

    normalized_name = (
        player_name
        .strip()
        .casefold()
    )

    matches = players[
        players["player_name"]
        .astype(str)
        .str.casefold()
        .eq(normalized_name)
    ].copy()

    if matches.empty:
        suggestions = players[
            players["player_name"]
            .astype(str)
            .str.casefold()
            .str.contains(
                normalized_name,
                regex=False,
            )
        ]

        if not suggestions.empty:
            suggestions = (
                suggestions[
                    [
                        "player_name",
                        "primary_squad_name",
                        "primary_competition_name",
                    ]
                ]
                .drop_duplicates()
                .head(10)
            )

            text = "; ".join(
                f"{row.player_name} "
                f"({row.primary_squad_name}, "
                f"{row.primary_competition_name})"
                for row in suggestions.itertuples()
            )

            raise PlayerNotFoundError(
                f'Player "{player_name}" was not found exactly. '
                f"Possible matches: {text}"
            )

        raise PlayerNotFoundError(
            f'Player "{player_name}" was not found.'
        )

    if club:
        normalized_club = (
            club
            .strip()
            .casefold()
        )

        matches = matches[
            matches["primary_squad_name"]
            .astype(str)
            .str.casefold()
            .eq(normalized_club)
        ]

        if matches.empty:
            raise PlayerClubMismatchError(
                f'Player "{player_name}" was found, '
                f'but not with primary club "{club}".'
            )

    if len(matches) > 1:
        candidates = "; ".join(
            f"{row.player_name} — "
            f"{row.primary_squad_name} — "
            f"{row.primary_competition_name} — "
            f"{row.position_raw} — "
            f"{int(row.minutes)} min"
            for row in matches.itertuples()
        )

        raise AmbiguousPlayerError(
            f'Multiple canonical players match "{player_name}". '
            f"Specify the club parameter. "
            f"Candidates: {candidates}"
        )

    return matches.iloc[0]