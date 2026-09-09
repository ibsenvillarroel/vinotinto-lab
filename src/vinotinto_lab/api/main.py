from __future__ import annotations

import pandas as pd

from fastapi import FastAPI, HTTPException, Query

from vinotinto_lab.analytics.similarity.player_similarity import (
    AmbiguousPlayerError,
    PlayerClubMismatchError,
    PlayerNotFoundError,
    PlayerNotEligibleForSimilarityError,
)

from vinotinto_lab.analytics.similarity.player_similarity_v2 import (
    find_similar_players_v2,
)

from vinotinto_lab.analytics.players.player_profile import (
    resolve_player_profile,
)

from vinotinto_lab.analytics.players.player_explorer import (
    list_players,
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

    except PlayerNotFoundError as exc:
        raise HTTPException(
            status_code=404,
            detail=str(exc),
        ) from exc

    except (
        AmbiguousPlayerError,
        PlayerClubMismatchError,
    ) as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    except RuntimeError as exc:
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        ) from exc

    except PlayerNotEligibleForSimilarityError as exc:
        raise HTTPException(
            status_code=422,
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

@app.get("/players/{player_name}")
def player_profile(
    player_name: str,
    club: str | None = Query(
        default=None,
    ),
) -> dict:

    try:
        player = resolve_player_profile(
            player_name=player_name,
            club=club,
        )

    except PlayerNotFoundError as exc:
        raise HTTPException(
            status_code=404,
            detail=str(exc),
        ) from exc

    except (
        AmbiguousPlayerError,
        PlayerClubMismatchError,
    ) as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    return {
        "identity": {
            "canonical_player_key":
                player["canonical_player_key"],

            "source_player_key":
                player["source_player_key"],

            "name":
                player["player_name"],

            "nation":
                player["nation_raw"],

            "nation_country_code":
                player["nation_country_code"],

            "nation_fifa_code":
                player["nation_fifa_code"],

            "age":
                (
                    int(player["age"])
                    if pd.notna(player["age"])
                    else None
                ),

            "born_year":
                (
                    int(player["born_year"])
                    if pd.notna(player["born_year"])
                    else None
                ),
        },

        "season": {
            "season":
                int(player["season"]),

            "label":
                player["season_label"],

            "primary_club":
                player["primary_squad_name"],

            "primary_competition":
                player["primary_competition_name"],

            "clubs":
                player["squad_names"],

            "competitions":
                player["competition_names"],

            "stint_count":
                int(player["stint_count"]),
        },

        "role": {
            "position":
                player["position_raw"],

            "position_group":
                player["position_group"],
        },

        "usage": {
            "appearances":
                int(player["appearances"]),

            "starts":
                int(player["starts"]),

            "minutes":
                int(player["minutes"]),
        },

        "production": {
            "goals":
                int(player["goals"]),

            "assists":
                int(player["assists"]),

            "goal_contributions":
                int(player["goal_contributions"]),

            "non_penalty_goals":
                int(player["non_penalty_goals"]),

            "penalties_scored":
                int(player["penalties_scored"]),

            "penalties_attempted":
                int(player["penalties_attempted"]),

            "shots":
                int(player["shots"]),

            "shots_on_target":
                int(player["shots_on_target"]),
        },

        "other_stats": {
            "crosses":
                int(player["crosses"]),

            "tackles_won":
                int(player["tackles_won"]),

            "interceptions":
                int(player["interceptions"]),

            "fouls_drawn":
                int(player["fouls_drawn"]),

            "fouls_committed":
                int(player["fouls_committed"]),

            "offsides":
                int(player["offsides"]),

            "yellow_cards":
                int(player["yellow_cards"]),

            "red_cards":
                int(player["red_cards"]),
        },

        "per90": {
            "non_penalty_goals":
                float(
                    player["non_penalty_goals_per90"]
                ),

            "assists":
                float(player["assists_per90"]),

            "shots":
                float(player["shots_per90"]),

            "shots_on_target":
                float(
                    player["shots_on_target_per90"]
                ),

            "crosses":
                float(player["crosses_per90"]),

            "fouls_drawn":
                float(player["fouls_drawn_per90"]),

            "tackles_won":
                float(player["tackles_won_per90"]),

            "interceptions":
                float(player["interceptions_per90"]),

            "fouls_committed":
                float(
                    player["fouls_committed_per90"]
                ),

            "offsides":
                float(player["offsides_per90"]),
        },

        "data_quality": {
            "similarity_eligible":
                bool(
                    player["is_similarity_eligible"]
                ),

            "sample_quality":
                player["sample_quality"],
        },
    }

@app.get("/players")
def players_explorer(
    search: str | None = Query(
        default=None,
    ),
    competition: str | None = Query(
        default=None,
    ),
    club: str | None = Query(
        default=None,
    ),
    position_group: str | None = Query(
        default=None,
    ),
    min_minutes: int | None = Query(
        default=None,
        ge=0,
    ),
    similarity_eligible: bool | None = Query(
        default=None,
    ),
    limit: int = Query(
        default=25,
        ge=1,
        le=100,
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
) -> dict:

    return list_players(
        search=search,
        competition=competition,
        club=club,
        position_group=position_group,
        min_minutes=min_minutes,
        similarity_eligible=similarity_eligible,
        limit=limit,
        offset=offset,
    )