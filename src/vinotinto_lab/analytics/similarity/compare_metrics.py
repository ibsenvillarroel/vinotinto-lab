from __future__ import annotations

import argparse

import pandas as pd
from sklearn.metrics.pairwise import (
    cosine_similarity,
    euclidean_distances,
    manhattan_distances,
)
from sklearn.preprocessing import StandardScaler

from vinotinto_lab.analytics.similarity.player_similarity import (
    FEATURES,
    load_players,
    resolve_target_player,
)


def prepare_cohort(
    player_name: str,
    club: str | None = None,
) -> tuple[pd.Series, pd.DataFrame]:

    players = load_players()

    target = resolve_target_player(
        players=players,
        player_name=player_name,
        club=club,
    )

    cohort = players[
        players["position_group"]
        == target["position_group"]
    ].copy()

    cohort.reset_index(drop=True, inplace=True)

    missing = cohort[FEATURES].isna().sum()

    if missing.any():
        raise RuntimeError(
            f"Missing values: "
            f"{missing[missing > 0].to_dict()}"
        )

    return target, cohort


def calculate_metrics(
    target: pd.Series,
    cohort: pd.DataFrame,
) -> pd.DataFrame:

    matrix = (
        cohort[FEATURES]
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
            "Expected exactly one target "
            "inside the cohort."
        )

    target_index = target_indexes[0]

    target_vector = standardized[
        target_index:target_index + 1
    ]

    result = cohort.copy()

    result["cosine"] = cosine_similarity(
        target_vector,
        standardized,
    )[0]

    result["euclidean"] = euclidean_distances(
        target_vector,
        standardized,
    )[0]

    result["manhattan"] = manhattan_distances(
        target_vector,
        standardized,
    )[0]

    result = result[
        result["canonical_player_key"]
        != target["canonical_player_key"]
    ].copy()

    return result


def print_top(
    data: pd.DataFrame,
    metric: str,
    limit: int,
) -> None:

    ascending = metric != "cosine"

    ranked = (
        data
        .sort_values(
            metric,
            ascending=ascending,
        )
        .head(limit)
    )

    print()
    print(metric.upper())
    print("-" * 78)

    for rank, row in enumerate(
        ranked.itertuples(),
        start=1,
    ):

        value = getattr(row, metric)

        if metric == "cosine":
            metric_value = f"{value * 100:7.2f}%"
        else:
            metric_value = f"{value:7.3f}"

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
            f"{metric_value}"
            f"{transfer_marker}"
        )


def print_specific_ranks(
    data: pd.DataFrame,
    candidate_name: str,
) -> None:

    matches = data[
        data["player_name"]
        .astype(str)
        .str.casefold()
        .eq(candidate_name.strip().casefold())
    ].copy()

    if matches.empty:
        print()
        print(
            f'Candidate "{candidate_name}" '
            "was not found in this cohort."
        )
        return

    cosine_ranked = (
        data
        .sort_values(
            "cosine",
            ascending=False,
        )
        .reset_index(drop=True)
    )

    euclidean_ranked = (
        data
        .sort_values(
            "euclidean",
            ascending=True,
        )
        .reset_index(drop=True)
    )

    manhattan_ranked = (
        data
        .sort_values(
            "manhattan",
            ascending=True,
        )
        .reset_index(drop=True)
    )

    candidate_key = matches.iloc[0][
        "canonical_player_key"
    ]

    def get_rank(
        ranked: pd.DataFrame,
    ) -> int:

        indexes = ranked.index[
            ranked["canonical_player_key"]
            == candidate_key
        ].tolist()

        return indexes[0] + 1

    row = matches.iloc[0]

    print()
    print("CANDIDATE DIAGNOSTIC")
    print("-" * 78)

    print(
        f"{row['player_name']} | "
        f"{row['primary_squad_name']}"
    )

    print(
        f"Cosine:     rank "
        f"{get_rank(cosine_ranked):>3} | "
        f"{float(row['cosine']) * 100:.2f}%"
    )

    print(
        f"Euclidean:  rank "
        f"{get_rank(euclidean_ranked):>3} | "
        f"distance {float(row['euclidean']):.3f}"
    )

    print(
        f"Manhattan:  rank "
        f"{get_rank(manhattan_ranked):>3} | "
        f"distance {float(row['manhattan']):.3f}"
    )


def main() -> None:

    parser = argparse.ArgumentParser(
        description=(
            "Compare similarity metrics for "
            "Vinotinto Lab."
        )
    )

    parser.add_argument(
        "player_name",
    )

    parser.add_argument(
        "--club",
        default=None,
    )

    parser.add_argument(
        "--candidate",
        default=None,
        help=(
            "Optional player whose rank "
            "should be compared across metrics."
        ),
    )

    parser.add_argument(
        "--limit",
        type=int,
        default=10,
    )

    args = parser.parse_args()

    target, cohort = prepare_cohort(
        player_name=args.player_name,
        club=args.club,
    )

    results = calculate_metrics(
        target=target,
        cohort=cohort,
    )

    print()
    print(
        "VINOTINTO LAB — "
        "SIMILARITY METRIC EXPERIMENT"
    )

    print("=" * 78)

    print()
    print(
        f"{target['player_name']} | "
        f"{target['primary_squad_name']} | "
        f"{target['position_group']}"
    )

    print(
        f"Cohort size: {len(cohort)}"
    )

    print_top(
        results,
        "cosine",
        args.limit,
    )

    print_top(
        results,
        "euclidean",
        args.limit,
    )

    print_top(
        results,
        "manhattan",
        args.limit,
    )

    if args.candidate:
        print_specific_ranks(
            results,
            args.candidate,
        )


if __name__ == "__main__":
    main()