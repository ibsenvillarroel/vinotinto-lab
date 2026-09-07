from __future__ import annotations

import argparse

import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler

from vinotinto_lab.analytics.similarity.player_similarity import (
    FEATURES,
    load_players,
    resolve_target_player,
)
from vinotinto_lab.analytics.similarity.player_similarity_v2 import (
    find_similar_players_v2,
)


FEATURE_LABELS = {
    "non_penalty_goals_per90": "Non-penalty goals / 90",
    "assists_per90": "Assists / 90",
    "shots_per90": "Shots / 90",
    "shots_on_target_per90": "Shots on target / 90",
    "crosses_per90": "Crosses / 90",
    "fouls_drawn_per90": "Fouls drawn / 90",
    "tackles_won_per90": "Tackles won / 90",
    "interceptions_per90": "Interceptions / 90",
    "fouls_committed_per90": "Fouls committed / 90",
    "offsides_per90": "Offsides / 90",
}


def build_standardized_cohort(
    players: pd.DataFrame,
    position_group: str,
) -> pd.DataFrame:

    cohort = players[
        players["position_group"] == position_group
    ].copy()

    cohort.reset_index(drop=True, inplace=True)

    missing_values = cohort[FEATURES].isna().sum()

    if missing_values.any():
        missing = missing_values[
            missing_values > 0
        ].to_dict()

        raise RuntimeError(
            f"Missing feature values detected: {missing}"
        )

    matrix = (
        cohort[FEATURES]
        .astype(float)
        .to_numpy()
    )

    scaler = StandardScaler()
    standardized = scaler.fit_transform(matrix)

    for index, feature in enumerate(FEATURES):
        cohort[f"_z_{feature}"] = standardized[:, index]

    return cohort


def get_player_row(
    cohort: pd.DataFrame,
    canonical_player_key: str,
) -> pd.Series:

    matches = cohort[
        cohort["canonical_player_key"]
        == canonical_player_key
    ]

    if len(matches) != 1:
        raise RuntimeError(
            f"Expected exactly one canonical player "
            f"for key {canonical_player_key}; "
            f"found {len(matches)}."
        )

    return matches.iloc[0]


def explain_euclidean(
    player_name: str,
    rank: int = 1,
    club: str | None = None,
) -> tuple[
    pd.Series,
    pd.Series,
    pd.DataFrame,
    float,
]:

    if rank < 1:
        raise ValueError(
            "Rank must be 1 or greater."
        )

    target, results = find_similar_players_v2(
        player_name=player_name,
        club=club,
        limit=rank,
    )

    if len(results) < rank:
        raise ValueError(
            f"Only {len(results)} similar players "
            "were available."
        )

    candidate = results.iloc[rank - 1]

    players = load_players()

    cohort = build_standardized_cohort(
        players=players,
        position_group=target["position_group"],
    )

    target_row = get_player_row(
        cohort,
        target["canonical_player_key"],
    )

    candidate_row = get_player_row(
        cohort,
        candidate["canonical_player_key"],
    )

    rows = []

    total_squared_distance = 0.0

    for feature in FEATURES:

        target_z = float(
            target_row[f"_z_{feature}"]
        )

        candidate_z = float(
            candidate_row[f"_z_{feature}"]
        )

        difference = (
            target_z - candidate_z
        )

        squared_difference = (
            difference ** 2
        )

        total_squared_distance += (
            squared_difference
        )

        rows.append(
            {
                "feature": feature,
                "label": FEATURE_LABELS[feature],
                "target_z": target_z,
                "candidate_z": candidate_z,
                "absolute_gap": abs(difference),
                "squared_contribution": squared_difference,
            }
        )

    explanation = pd.DataFrame(rows)

    distance = np.sqrt(
        total_squared_distance
    )

    explanation[
        "distance_share_pct"
    ] = (
        explanation["squared_contribution"]
        / total_squared_distance
        * 100
        if total_squared_distance > 0
        else 0
    )

    return (
        target_row,
        candidate_row,
        explanation,
        float(distance),
    )


def print_explanation(
    target: pd.Series,
    candidate: pd.Series,
    explanation: pd.DataFrame,
    distance: float,
) -> None:

    print()
    print(
        "VINOTINTO LAB — "
        "EUCLIDEAN EXPLAINABILITY V2.1"
    )

    print("=" * 90)

    print()

    print(
        f"{target['player_name']} "
        f"({target['primary_squad_name']})"
    )

    print("vs")

    print(
        f"{candidate['player_name']} "
        f"({candidate['primary_squad_name']})"
    )

    print()

    print(
        f"Cohort: {target['position_group']}"
    )

    print(
        f"Euclidean distance: {distance:.3f}"
    )

    print()

    print("MOST SIMILAR DIMENSIONS")
    print("-" * 90)

    closest = (
        explanation
        .sort_values(
            "absolute_gap",
            ascending=True,
        )
        .head(5)
    )

    for row in closest.itertuples():

        print(
            f"{row.label:<28} "
            f"target z={row.target_z:>6.2f}  "
            f"candidate z={row.candidate_z:>6.2f}  "
            f"gap={row.absolute_gap:>6.2f}"
        )

    print()

    print("LARGEST DISTANCE CONTRIBUTORS")
    print("-" * 90)

    largest = (
        explanation
        .sort_values(
            "squared_contribution",
            ascending=False,
        )
        .head(5)
    )

    for row in largest.itertuples():

        print(
            f"{row.label:<28} "
            f"target z={row.target_z:>6.2f}  "
            f"candidate z={row.candidate_z:>6.2f}  "
            f"gap={row.absolute_gap:>6.2f}  "
            f"share={row.distance_share_pct:>6.2f}%"
        )

    print()

    print(
        "Interpretation: contributions represent "
        "the share of squared Euclidean distance "
        "generated by each feature."
    )

    print(
        "Lower total distance = more statistically "
        "similar player profiles."
    )


def main() -> None:

    parser = argparse.ArgumentParser(
        description=(
            "Explain Vinotinto Lab V2 "
            "Euclidean player similarity."
        )
    )

    parser.add_argument(
        "player_name",
        help="Exact player name.",
    )

    parser.add_argument(
        "--club",
        default=None,
    )

    parser.add_argument(
        "--rank",
        type=int,
        default=1,
        help=(
            "Rank of the similar player "
            "to explain."
        ),
    )

    args = parser.parse_args()

    (
        target,
        candidate,
        explanation,
        distance,
    ) = explain_euclidean(
        player_name=args.player_name,
        club=args.club,
        rank=args.rank,
    )

    print_explanation(
        target=target,
        candidate=candidate,
        explanation=explanation,
        distance=distance,
    )


if __name__ == "__main__":
    main()