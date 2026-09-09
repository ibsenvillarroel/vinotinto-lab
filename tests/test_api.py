from fastapi.testclient import TestClient

from vinotinto_lab.api.main import app


client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")

    assert response.status_code == 200

    assert response.json() == {
        "status": "ok",
        "service": "vinotinto-lab-api",
    }


def test_mbappe_similarity_limit_5() -> None:
    response = client.get(
        "/players/Kylian Mbappé/similar",
        params={
            "limit": 5,
        },
    )

    assert response.status_code == 200

    payload = response.json()

    assert payload["model"]["version"] == "2.0"
    assert payload["model"]["metric"] == "euclidean"

    assert payload["player"]["name"] == "Kylian Mbappé"
    assert payload["player"]["club"] == "Real Madrid"
    assert payload["player"]["position_group"] == "FW"

    assert len(
        payload["similar_players"]
    ) == 5

    first = payload["similar_players"][0]

    assert first["rank"] == 1
    assert first["name"] == "Dušan Vlahović"
    assert first["club"] == "Juventus"

    distances = [
        player["distance"]
        for player in payload["similar_players"]
    ]

    assert distances == sorted(distances)


def test_ambiguous_vitinha_requires_club() -> None:
    response = client.get(
        "/players/Vitinha/similar",
        params={
            "limit": 5,
        },
    )

    assert response.status_code == 400

    detail = response.json()["detail"]

    assert "Multiple canonical players" in detail
    assert "Genoa" in detail
    assert "Paris Saint-Germain" in detail


def test_vitinha_psg_disambiguation() -> None:
    response = client.get(
        "/players/Vitinha/similar",
        params={
            "club": "Paris Saint-Germain",
            "limit": 5,
        },
    )

    assert response.status_code == 200

    player = response.json()["player"]

    assert player["canonical_player_key"] == (
        "KAGGLE:VITINHA:PSG:2000:POR"
    )

    assert player["name"] == "Vitinha"
    assert player["club"] == "Paris Saint-Germain"
    assert player["competition"] == "Ligue 1"
    assert player["position_group"] == "MF"


def test_limit_validation() -> None:
    response = client.get(
        "/players/Kylian Mbappé/similar",
        params={
            "limit": 0,
        },
    )

    assert response.status_code == 422