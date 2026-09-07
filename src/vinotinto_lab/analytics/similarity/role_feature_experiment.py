from __future__ import annotations

import argparse

import pandas as pd
from sklearn.metrics.pairwise import euclidean_distances
from sklearn.preprocessing import StandardScaler

from vinotinto_lab.analytics.similarity.player_similarity import (
    FEATURES,
    load_players,
    resolve_target_player,
)


ROLE_FEATURES = {
    "FW": [
        "non_penalty_goals_per90",
        "assists_per90",
        "shots_per90",
        "shots_on_target_per90",
        "fouls_drawn_per90",
        "offsides_per90",
    ],

    "FW_MF": [
        "non_penalty_goals_per90",
        "assists_per90",
        "shots_per90",
        "shots_on_target_per90",
        "crosses_per90",
        "fouls_drawn_per90",
    ],

    "MF": [
        "assists_per90",
        "shots_per90",
        "crosses_per90",
        "fouls_drawn_per90",
        "tackles_won_per90",
        "interceptions_per90",
    ],

    "DF_MF": [
        "assists_per90",
        "crosses_per90",
        "fouls_drawn_per90",
        "tackles_won_per90",
        "interceptions_per90",
        "fouls_committed_per90",
    ],

    "DF": [
        "crosses_per90",
        "fouls_drawn_per90",
        "tackles_won_per90",
        "interceptions_per90",
        "fouls_committed_per90",
    ],
}


def rank_players(
    cohort: pd.DataFrame,
    target: pd.Series,
    features: list[str],
) -> pd.DataFrame:

    matrix = (
        cohort[features]
        .astype(float)
        .to_numpy()
    )

    scaler = StandardScaler()
    standardized = scaler.fit_transform(matrix)

    target_indexes = cohort.index[
        cohort["canonical_player_key"].eq(
            target["canonical_player_key"]
        )
    ].tolist()

    if len(target_indexes) != 1:
        raise RuntimeError(
            "Expected exactly one target inside cohort."
        )

    target_index = target_indexes[0]

    distances = euclidean_distances(
        standardized[target_index:target_index + 1],
        standardized,
    )[0]

    result = cohort.copy()
    result["distance"] = distances

    return (
        result[
            result["canonical_player_key"]
            != target["canonical_player_key"]
        ]
        .sort_values("distance")
        .reset_index(drop=True)
    )


def print_ranking(
    title: str,
    ranking: pd.DataFrame,
    limit: int,
) -> None:

    print()
    print(title)
    print("-" * 78)

    for rank, row in enumerate(
        ranking.head(limit).itertuples(),
        start=1,
    ):
        print(
            f"{rank:>2}. "
            f"{row.player_name:<25} "
            f"{row.primary_squad_name:<20} "
            f"{row.primary_competition_name:<16} "
            f"{row.distance:>6.3f}"
        )


def main() -> None:

    parser = argparse.ArgumentParser()

    parser.add_argument("player_name")
    parser.add_argument("--club", default=None)
    parser.add_argument("--limit", type=int, default=10)

    args = parser.parse_args()

    players = load_players()

    target = resolve_target_player(
        players,
        args.player_name,
        args.club,
    )

    position_group = target["position_group"]

    cohort = (
        players[
            players["position_group"] == position_group
        ]
        .copy()
        .reset_index(drop=True)
    )

    role_features = ROLE_FEATURES.get(
        position_group
    )

    if role_features is None:
        raise ValueError(
            f"No role feature set defined for "
            f"{position_group}."
        )

    baseline = rank_players(
        cohort,
        target,
        FEATURES,
    )

    role_aware = rank_players(
        cohort,
        target,
        role_features,
    )

    print()
    print(
        "VINOTINTO LAB — "
        "ROLE FEATURE EXPERIMENT"
    )
    print("=" * 78)

    print()
    print(
        f"{target['player_name']} | "
        f"{target['primary_squad_name']} | "
        f"{position_group}"
    )

    print()
    print("ROLE FEATURES")

    for feature in role_features:
        print(f" - {feature}")

    print_ranking(
        "BASELINE — 10 FEATURES",
        baseline,
        args.limit,
    )

    print_ranking(
        "ROLE-AWARE FEATURE SET",
        role_aware,
        args.limit,
    )

    baseline_top = set(
        baseline.head(args.limit)[
            "canonical_player_key"
        ]
    )

    role_top = set(
        role_aware.head(args.limit)[
            "canonical_player_key"
        ]
    )

    overlap = len(
        baseline_top & role_top
    )

    print()
    print(
        f"Top-{args.limit} overlap: "
        f"{overlap}/{args.limit}"
    )


if __name__ == "__main__":
    main()