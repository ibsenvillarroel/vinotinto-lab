from __future__ import annotations

from fastapi import FastAPI, HTTPException, Query

from vinotinto_lab.analytics.similarity.player_similarity_v2 import (
    find_similar_players_v2,
)


app = FastAPI(
    title="Vinotinto Lab API",
    description=(
        "Sports Intelligence API for player analytics "
        "and machine-learning services."
    ),
    version="0.1.0",
)


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "service": "vinotinto-lab-api",
    }


@app.get("/players/{player_name}/similar")
def similar_players(
    player_name: str,
    limit: int = Query(
        default=10,
        ge=1,
        le=50,
    ),
    club: str | None = Query(
        default=None,
    ),
) -> dict:

    try:
        target, results = find_similar_players_v2(
            player_name=player_name,
            limit=limit,
            club=club,
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    except RuntimeError as exc:
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        ) from exc

    similar = []

    for rank, row in enumerate(
        results.itertuples(),
        start=1,
    ):

        similar.append(
            {
                "rank": rank,
                "canonical_player_key":
                    row.canonical_player_key,
                "name":
                    row.player_name,
                "club":
                    row.primary_squad_name,
                "competition":
                    row.primary_competition_name,
                "position":
                    row.position_raw,
                "position_group":
                    row.position_group,
                "minutes":
                    int(row.minutes),
                "stint_count":
                    int(row.stint_count),
                "distance":
                    round(
                        float(row.distance),
                        4,
                    ),
            }
        )

    return {
        "model": {
            "name": "player-similarity",
            "version": "2.0",
            "metric": "euclidean",
            "preprocessing": "standard_scaler",
        },

        "player": {
            "canonical_player_key":
                target["canonical_player_key"],
            "name":
                target["player_name"],
            "club":
                target["primary_squad_name"],
            "competition":
                target["primary_competition_name"],
            "position":
                target["position_raw"],
            "position_group":
                target["position_group"],
            "minutes":
                int(target["minutes"]),
            "stint_count":
                int(target["stint_count"]),
        },

        "similar_players": similar,
    }