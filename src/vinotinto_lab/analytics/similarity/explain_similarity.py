from __future__ import annotations

import argparse

import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler

from vinotinto_lab.analytics.similarity.player_similarity import (
    FEATURES,
    find_similar_players,
    load_players,
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


def get_canonical_row(
    cohort: pd.DataFrame,
    canonical_player_key: str,
) -> pd.Series:

    matches = cohort[
        cohort["canonical_player_key"]
        == canonical_player_key
    ]

    if len(matches) != 1:
        raise RuntimeError(
            "Expected exactly one canonical player "
            f"for key {canonical_player_key}, "
            f"found {len(matches)}."
        )

    return matches.iloc[0]


def explain_similarity(
    player_name: str,
    club: str | None = None,
    rank: int = 1,
) -> tuple[
    pd.Series,
    pd.Series,
    pd.DataFrame,
]:

    if rank < 1:
        raise ValueError(
            "Rank must be 1 or greater."
        )

    target, results = find_similar_players(
        player_name=player_name,
        club=club,
        limit=rank,
    )

    if len(results) < rank:
        raise ValueError(
            f"Only {len(results)} similar players "
            f"were available."
        )

    candidate = results.iloc[rank - 1]

    players = load_players()

    cohort = build_standardized_cohort(
        players=players,
        position_group=target["position_group"],
    )

    target_row = get_canonical_row(
        cohort,
        target["canonical_player_key"],
    )

    candidate_row = get_canonical_row(
        cohort,
        candidate["canonical_player_key"],
    )

    target_vector = np.array(
        [
            float(target_row[f"_z_{feature}"])
            for feature in FEATURES
        ]
    )

    candidate_vector = np.array(
        [
            float(candidate_row[f"_z_{feature}"])
            for feature in FEATURES
        ]
    )

    denominator = (
        np.linalg.norm(target_vector)
        * np.linalg.norm(candidate_vector)
    )

    if denominator == 0:
        raise RuntimeError(
            "Cannot explain cosine similarity "
            "for a zero-length standardized vector."
        )

    contributions = (
        target_vector
        * candidate_vector
        / denominator
    )

    differences = np.abs(
        target_vector - candidate_vector
    )

    rows = []

    for index, feature in enumerate(FEATURES):

        target_z = target_vector[index]
        candidate_z = candidate_vector[index]

        if target_z > 0 and candidate_z > 0:
            direction = "both above cohort avg"

        elif target_z < 0 and candidate_z < 0:
            direction = "both below cohort avg"

        else:
            direction = "opposite sides of avg"

        rows.append(
            {
                "feature": feature,
                "label": FEATURE_LABELS[feature],
                "target_z": target_z,
                "candidate_z": candidate_z,
                "z_gap": differences[index],
                "cosine_contribution": contributions[index],
                "direction": direction,
            }
        )

    explanation = pd.DataFrame(rows)

    return (
        target_row,
        candidate_row,
        explanation,
    )


def print_explanation(
    target: pd.Series,
    candidate: pd.Series,
    explanation: pd.DataFrame,
) -> None:

    similarity = explanation[
        "cosine_contribution"
    ].sum()

    print()
    print(
        "VINOTINTO LAB — "
        "SIMILARITY EXPLAINABILITY V1.2"
    )

    print("=" * 80)

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
        f"Cosine similarity: "
        f"{similarity * 100:.2f}%"
    )

    print()

    print("STRONGEST ALIGNED DIMENSIONS")
    print("-" * 80)

    aligned = (
        explanation
        .sort_values(
            "cosine_contribution",
            ascending=False,
        )
        .head(5)
    )

    for row in aligned.itertuples():

        print(
            f"{row.label:<28} "
            f"target z={row.target_z:>6.2f}  "
            f"candidate z={row.candidate_z:>6.2f}  "
            f"contribution={row.cosine_contribution:>7.3f}  "
            f"{row.direction}"
        )

    print()
    print("LARGEST PROFILE DIFFERENCES")
    print("-" * 80)

    differences = (
        explanation
        .sort_values(
            "z_gap",
            ascending=False,
        )
        .head(5)
    )

    for row in differences.itertuples():

        print(
            f"{row.label:<28} "
            f"target z={row.target_z:>6.2f}  "
            f"candidate z={row.candidate_z:>6.2f}  "
            f"gap={row.z_gap:>6.2f}"
        )

    print()
    print(
        "z-score interpretation: "
        "0 = cohort average; positive = above average; "
        "negative = below average."
    )

    print(
        "Cosine contributions sum to the reported "
        "cosine similarity."
    )


def main() -> None:

    parser = argparse.ArgumentParser(
        description=(
            "Explain Vinotinto Lab player "
            "similarity results."
        )
    )

    parser.add_argument(
        "player_name",
        help="Exact player name.",
    )

    parser.add_argument(
        "--club",
        default=None,
        help="Primary club for name disambiguation.",
    )

    parser.add_argument(
        "--rank",
        type=int,
        default=1,
        help=(
            "Rank of the similar player "
            "to explain. Default: 1."
        ),
    )

    args = parser.parse_args()

    target, candidate, explanation = (
        explain_similarity(
            player_name=args.player_name,
            club=args.club,
            rank=args.rank,
        )
    )

    print_explanation(
        target=target,
        candidate=candidate,
        explanation=explanation,
    )


if __name__ == "__main__":
    main()