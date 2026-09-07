from __future__ import annotations

import argparse

import pandas as pd
from psycopg.rows import dict_row
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.preprocessing import StandardScaler

from vinotinto_lab.database.connection import get_connection


FEATURES = [
    "non_penalty_goals_per90",
    "assists_per90",
    "shots_per90",
    "shots_on_target_per90",
    "crosses_per90",
    "fouls_drawn_per90",
    "tackles_won_per90",
    "interceptions_per90",
    "fouls_committed_per90",
    "offsides_per90",
]


def load_players() -> pd.DataFrame:
    query = """
        SELECT
            canonical_player_key,
            source_player_key,

            player_name,

            primary_squad_name,
            primary_competition_name,

            squad_names,
            competition_names,

            position_raw,
            position_group,

            minutes,
            stint_count,

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

        WHERE is_similarity_eligible = TRUE
          AND position_group <> 'GK'

        ORDER BY player_name;
    """

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()

    return pd.DataFrame(rows)


def resolve_target_player(
    players: pd.DataFrame,
    player_name: str,
    club: str | None = None,
) -> pd.Series:

    normalized_name = player_name.strip().casefold()

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
            .str.contains(normalized_name, regex=False)
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

            raise ValueError(
                f'Player "{player_name}" was not found exactly. '
                f"Possible matches: {text}"
            )

        raise ValueError(
            f'Player "{player_name}" was not found.'
        )

    if club:
        normalized_club = club.strip().casefold()

        matches = matches[
            matches["primary_squad_name"]
            .astype(str)
            .str.casefold()
            .eq(normalized_club)
        ]

        if matches.empty:
            raise ValueError(
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

        raise ValueError(
            f'Multiple canonical players match "{player_name}". '
            f"Use --club to disambiguate. "
            f"Candidates: {candidates}"
        )

    return matches.iloc[0]


def find_similar_players(
    player_name: str,
    limit: int = 10,
    club: str | None = None,
) -> tuple[pd.Series, pd.DataFrame]:

    players = load_players()

    if players.empty:
        raise RuntimeError(
            "No eligible players were returned from PostgreSQL."
        )

    target = resolve_target_player(
        players=players,
        player_name=player_name,
        club=club,
    )

    position_group = target["position_group"]

    cohort = players[
        players["position_group"] == position_group
    ].copy()

    cohort.reset_index(drop=True, inplace=True)

    if len(cohort) < 3:
        raise RuntimeError(
            f"Not enough eligible players in cohort "
            f"{position_group}."
        )

    missing_values = cohort[FEATURES].isna().sum()

    if missing_values.any():
        missing = missing_values[
            missing_values > 0
        ].to_dict()

        raise RuntimeError(
            f"Missing feature values detected: {missing}"
        )

    feature_matrix = (
        cohort[FEATURES]
        .astype(float)
        .to_numpy()
    )

    scaler = StandardScaler()

    standardized_matrix = scaler.fit_transform(
        feature_matrix
    )

    target_indexes = cohort.index[
        cohort["canonical_player_key"].eq(
            target["canonical_player_key"]
        )
    ].tolist()

    if not target_indexes:
        raise RuntimeError(
            "Target player was not found inside "
            "its comparison cohort."
        )

    target_index = target_indexes[0]

    similarities = cosine_similarity(
        standardized_matrix[
            target_index:target_index + 1
        ],
        standardized_matrix,
    )[0]

    cohort["similarity"] = similarities

    results = (
        cohort[
            cohort["canonical_player_key"]
            != target["canonical_player_key"]
        ]
        .sort_values(
            "similarity",
            ascending=False,
        )
        .head(limit)
        .copy()
    )

    return target, results


def print_results(
    target: pd.Series,
    results: pd.DataFrame,
) -> None:

    print()
    print(
        "VINOTINTO LAB — "
        "PLAYER SIMILARITY CANONICAL V1.1"
    )
    print("=" * 78)

    print()
    print("PLAYER")

    print(
        f"{target['player_name']} | "
        f"{target['primary_squad_name']} | "
        f"{target['primary_competition_name']}"
    )

    print(
        f"Position: {target['position_raw']} "
        f"→ cohort {target['position_group']}"
    )

    print(
        f"Minutes: {int(target['minutes'])} | "
        f"Stints: {int(target['stint_count'])}"
    )

    if int(target["stint_count"]) > 1:
        print(
            f"Season clubs: {target['squad_names']}"
        )

    print()
    print("MOST SIMILAR PLAYERS")
    print("-" * 78)

    for rank, (_, row) in enumerate(
        results.iterrows(),
        start=1,
    ):
        similarity_pct = (
            float(row["similarity"]) * 100
        )

        transfer_marker = (
            f" [{int(row['stint_count'])} stints]"
            if int(row["stint_count"]) > 1
            else ""
        )

        print(
            f"{rank:>2}. "
            f"{row['player_name']:<25} "
            f"{row['primary_squad_name']:<20} "
            f"{row['primary_competition_name']:<16} "
            f"{similarity_pct:>7.2f}%"
            f"{transfer_marker}"
        )

    print()
    print(
        "Method: canonical player-season data + "
        "StandardScaler + cosine similarity "
        "within the same position cohort."
    )


def main() -> None:

    parser = argparse.ArgumentParser(
        description=(
            "Vinotinto Lab Player Similarity "
            "Canonical Baseline V1.1"
        )
    )

    parser.add_argument(
        "player_name",
        help="Exact player name.",
    )

    parser.add_argument(
        "--club",
        default=None,
        help=(
            "Primary club used to disambiguate "
            "players with identical names."
        ),
    )

    parser.add_argument(
        "--limit",
        type=int,
        default=10,
        help="Number of similar players to return.",
    )

    args = parser.parse_args()

    target, results = find_similar_players(
        player_name=args.player_name,
        limit=args.limit,
        club=args.club,
    )

    print_results(
        target,
        results,
    )


if __name__ == "__main__":
    main()