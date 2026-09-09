from __future__ import annotations

import argparse

import pandas as pd
from sklearn.metrics.pairwise import euclidean_distances
from sklearn.preprocessing import StandardScaler

from vinotinto_lab.analytics.players.player_profile import (
    resolve_player_profile,
)

from vinotinto_lab.analytics.similarity.player_similarity import (
    FEATURES,
    PlayerNotEligibleForSimilarityError,
    load_players,
)


def find_similar_players_v2(
    player_name: str,
    limit: int = 10,
    club: str | None = None,
) -> tuple[pd.Series, pd.DataFrame]:

    # Resolve against the complete canonical player population.
    # This allows us to distinguish:
    # - player does not exist
    # - player exists but is not eligible for similarity
    target = resolve_player_profile(
        player_name=player_name,
        club=club,
    )

    if not bool(target["is_similarity_eligible"]):
        raise PlayerNotEligibleForSimilarityError(
            f'Player "{target["player_name"]}" exists, '
            f'but is not eligible for similarity analysis. '
            f'Current minutes: {int(target["minutes"])}. '
            f'Minimum required: 900.'
        )

    # Similarity population contains only eligible players.
    players = load_players()

    if players.empty:
        raise RuntimeError(
            "No eligible players were returned from PostgreSQL."
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

    if len(target_indexes) != 1:
        raise RuntimeError(
            "Expected exactly one target player "
            "inside its canonical comparison cohort."
        )

    target_index = target_indexes[0]

    distances = euclidean_distances(
        standardized_matrix[
            target_index:target_index + 1
        ],
        standardized_matrix,
    )[0]

    cohort["distance"] = distances

    results = (
        cohort[
            cohort["canonical_player_key"]
            != target["canonical_player_key"]
        ]
        .sort_values(
            "distance",
            ascending=True,
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
        "PLAYER SIMILARITY V2.0"
    )

    print("=" * 80)

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
    print("-" * 80)

    for rank, row in enumerate(
        results.itertuples(),
        start=1,
    ):

        transfer_marker = (
            f" [{int(row.stint_count)} stints]"
            if int(row.stint_count) > 1
            else ""
        )

        print(
            f"{rank:>2}. "
            f"{row.player_name:<25} "
            f"{row.primary_squad_name:<20} "
            f"{row.primary_competition_name:<16} "
            f"distance={float(row.distance):>6.3f}"
            f"{transfer_marker}"
        )

    print()
    print(
        "Method: canonical player-season data + "
        "StandardScaler + Euclidean distance "
        "within the same position cohort."
    )

    print(
        "Interpretation: lower distance = "
        "more statistically similar."
    )


def main() -> None:

    parser = argparse.ArgumentParser(
        description=(
            "Vinotinto Lab Player Similarity V2.0 "
            "using standardized Euclidean distance."
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

    target, results = find_similar_players_v2(
        player_name=args.player_name,
        limit=args.limit,
        club=args.club,
    )

    print_results(
        target=target,
        results=results,
    )


if __name__ == "__main__":
    main()