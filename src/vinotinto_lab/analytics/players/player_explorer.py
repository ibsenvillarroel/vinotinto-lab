from __future__ import annotations

from typing import Any

from psycopg.rows import dict_row

from vinotinto_lab.database.connection import get_connection


def list_players(
    *,
    search: str | None = None,
    competition: str | None = None,
    club: str | None = None,
    position_group: str | None = None,
    min_minutes: int | None = None,
    similarity_eligible: bool | None = None,
    limit: int = 25,
    offset: int = 0,
) -> dict[str, Any]:

    where_clauses: list[str] = []
    params: list[Any] = []

    if search:
        where_clauses.append(
            "player_name ILIKE %s"
        )
        params.append(f"%{search.strip()}%")

    if competition:
        where_clauses.append(
            "LOWER(primary_competition_name) = LOWER(%s)"
        )
        params.append(competition.strip())

    if club:
        where_clauses.append(
            "LOWER(primary_squad_name) = LOWER(%s)"
        )
        params.append(club.strip())

    if position_group:
        where_clauses.append(
            "UPPER(position_group) = UPPER(%s)"
        )
        params.append(position_group.strip())

    if min_minutes is not None:
        where_clauses.append(
            "minutes >= %s"
        )
        params.append(min_minutes)

    if similarity_eligible is not None:
        where_clauses.append(
            "is_similarity_eligible = %s"
        )
        params.append(similarity_eligible)

    where_sql = ""

    if where_clauses:
        where_sql = (
            "WHERE "
            + " AND ".join(where_clauses)
        )

    count_query = f"""
        SELECT COUNT(*) AS total
        FROM vw_player_season_canonical
        {where_sql};
    """

    data_query = f"""
        SELECT
            canonical_player_key,
            player_name,
            primary_squad_name,
            primary_competition_name,
            position_raw,
            position_group,
            age,
            minutes,
            goals,
            assists,
            stint_count,
            is_similarity_eligible,
            sample_quality
        FROM vw_player_season_canonical
        {where_sql}
        ORDER BY
            minutes DESC,
            player_name ASC
        LIMIT %s
        OFFSET %s;
    """

    with get_connection() as connection:
        with connection.cursor(
            row_factory=dict_row
        ) as cursor:

            cursor.execute(
                count_query,
                params,
            )

            total = int(
                cursor.fetchone()["total"]
            )

            cursor.execute(
                data_query,
                [
                    *params,
                    limit,
                    offset,
                ],
            )

            rows = cursor.fetchall()

    players = []

    for row in rows:
        players.append(
            {
                "canonical_player_key":
                    row["canonical_player_key"],

                "name":
                    row["player_name"],

                "club":
                    row["primary_squad_name"],

                "competition":
                    row["primary_competition_name"],

                "position":
                    row["position_raw"],

                "position_group":
                    row["position_group"],

                "age":
                    (
                        int(row["age"])
                        if row["age"] is not None
                        else None
                    ),

                "minutes":
                    int(row["minutes"]),

                "goals":
                    int(row["goals"]),

                "assists":
                    int(row["assists"]),

                "stint_count":
                    int(row["stint_count"]),

                "similarity_eligible":
                    bool(
                        row[
                            "is_similarity_eligible"
                        ]
                    ),

                "sample_quality":
                    row["sample_quality"],
            }
        )

    return {
        "total": total,
        "limit": limit,
        "offset": offset,
        "players": players,
    }