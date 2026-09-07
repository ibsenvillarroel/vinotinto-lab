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
            id,
            player_name,
            squad_name,
            competition_name,
            position_raw,
            position_group,
            role_family,
            minutes,
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
        FROM vw_player_intelligence_base
        WHERE is_similarity_eligible = TRUE
          AND position_group <> 'GK'
        ORDER BY player_name;
    """

    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()

    return pd.DataFrame(rows)


def find_similar_players(
    player_name: str,
    limit: int = 10,
) -> tuple[pd.Series, pd.DataFrame]:

    players = load_players()

    if players.empty:
        raise RuntimeError(
            "No eligible players were returned from PostgreSQL."
        )

    normalized_name = player_name.strip().casefold()

    matches = players[
        players["player_name"]
        .astype(str)
        .str.casefold()
        .eq(normalized_name)
    ]

    if matches.empty:
        suggestions = players[
            players["player_name"]
            .astype(str)
            .str.casefold()
            .str.contains(normalized_name, regex=False)
        ]

        if not suggestions.empty:
            names = ", ".join(
                suggestions["player_name"]
                .drop_duplicates()
                .head(10)
                .tolist()
            )

            raise ValueError(
                f'Player "{player_name}" was not found exactly. '
                f"Possible matches: {names}"
            )

        raise ValueError(
            f'Player "{player_name}" was not found.'
        )

    # Si existieran varias filas con el mismo nombre,
    # usamos inicialmente la que tenga más minutos.
    target = (
        matches
        .sort_values("minutes", ascending=False)
        .iloc[0]
    )

    position_group = target["position_group"]

    cohort = players[
        players["position_group"] == position_group
    ].copy()

    cohort.reset_index(drop=True, inplace=True)

    if len(cohort) < 3:
        raise RuntimeError(
            f"Not enough eligible players in cohort {position_group}."
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
        cohort["id"].eq(target["id"])
    ].tolist()

    if not target_indexes:
        raise RuntimeError(
            "Target player was not found inside its comparison cohort."
        )

    target_index = target_indexes[0]

    similarities = cosine_similarity(
        standardized_matrix[target_index:target_index + 1],
        standardized_matrix,
    )[0]

    cohort["similarity"] = similarities

    results = (
        cohort[
            cohort["id"] != target["id"]
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
    print("VINOTINTO LAB — PLAYER SIMILARITY BASELINE V1")
    print("=" * 65)

    print()
    print("PLAYER")
    print(
        f"{target['player_name']} | "
        f"{target['squad_name']} | "
        f"{target['competition_name']}"
    )

    print(
        f"Position: {target['position_raw']} "
        f"→ cohort {target['position_group']}"
    )

    print(
        f"Minutes: {int(target['minutes'])}"
    )

    print()
    print("MOST SIMILAR PLAYERS")
    print("-" * 65)

    for rank, (_, row) in enumerate(
        results.iterrows(),
        start=1,
    ):
        similarity_pct = float(
            row["similarity"]
        ) * 100

        print(
            f"{rank:>2}. "
            f"{row['player_name']:<25} "
            f"{row['squad_name']:<18} "
            f"{row['competition_name']:<16} "
            f"{similarity_pct:>7.2f}%"
        )

    print()
    print(
        "Method: StandardScaler + cosine similarity "
        "within the same position cohort."
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Vinotinto Lab Player Similarity Baseline V1"
        )
    )

    parser.add_argument(
        "player_name",
        help="Exact player name.",
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
    )

    print_results(
        target,
        results,
    )


if __name__ == "__main__":
    main()