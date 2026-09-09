# \# Vinotinto Lab

#

# \*\*Sports Data, Analytics and Machine Learning Platform\*\*

#

# Vinotinto Lab is a sports intelligence project designed to explore how data engineering, analytics and machine learning can be used to understand football players, compare playing profiles and eventually generate predictive services for real sports products.

#

# The project is being developed as a production-oriented portfolio platform rather than as a collection of isolated notebooks.

#

# Current release: \*\*Player Intelligence V2\*\*

#

# \---

#

# \## Overview

#

# Vinotinto Lab combines:

#

# \- sports data ingestion

# \- PostgreSQL analytical modeling

# \- canonical player identity resolution

# \- player-season aggregation

# \- transfer-stint handling

# \- player profile analytics

# \- player similarity modeling

# \- model explainability

# \- REST APIs with FastAPI

# \- Dockerized execution

# \- automated integration tests

#

# The longer-term architecture is designed so that Vinotinto Lab can act as the analytical and machine-learning layer behind products such as \*\*QuinielaManía\*\*.

#

# ```text

# Sports Data Sources

# &#x20;       │

# &#x20;       ▼

# Data Platform

# &#x20;       │

# &#x20;       ├── ingestion

# &#x20;       ├── data quality

# &#x20;       ├── identity resolution

# &#x20;       └── analytical models

# &#x20;       │

# &#x20;       ▼

# Vinotinto Lab

# &#x20;       │

# &#x20;       ├── Player Intelligence

# &#x20;       ├── Similarity Models

# &#x20;       ├── Match Prediction

# &#x20;       └── Sports Analytics

# &#x20;       │

# &#x20;       ▼

# REST / ML APIs

# &#x20;       │

# &#x20;       ▼

# Sports Products

# &#x20;       └── QuinielaManía



Player Intelligence V2



Version 2 focuses on building a reliable player intelligence foundation before introducing more advanced machine-learning models.



The current implementation provides:



canonical player-season records

identity resolution

transfer aggregation

player profiles

player explorer API

similarity eligibility rules

position-based comparison cohorts

standardized Euclidean player similarity

similarity explainability

automated API tests

Technology Stack

Data

PostgreSQL 16

SQL

Kaggle football datasets

API-Football experiments

Analytics / Machine Learning

Python 3.12

pandas

scikit-learn

NumPy-compatible analytical workflows

Backend

FastAPI

Uvicorn

psycopg

Infrastructure

Docker

Docker Compose

Testing

pytest

FastAPI TestClient

Data Architecture



The project currently uses PostgreSQL as the analytical source of truth.



Important data layers include:



Raw / Staging

│

├── raw\_api\_data

├── stg\_kaggle\_player\_season

└── API-Football data

&#x20;       │

&#x20;       ▼

Identity Resolution

&#x20;       │

&#x20;       └── vw\_kaggle\_player\_identity\_resolved

&#x20;       │

&#x20;       ▼

Canonical Player-Season

&#x20;       │

&#x20;       └── vw\_player\_season\_canonical

&#x20;       │

&#x20;       ├── Player Profiles

&#x20;       ├── Player Explorer

&#x20;       └── Similarity Engine



The current Kaggle dataset contains players from:



La Liga

Premier League

Bundesliga

Serie A

Ligue 1



The staging dataset contains approximately 2,800 raw player-season rows.



After transfer aggregation and identity resolution, the analytical layer contains approximately 2,691 canonical player-season records.



Canonical Player Identity



Player identity became an important data-quality problem during development.



Initially, source player identities were derived using combinations of:



player name

birth year

nationality



This produced a real collision involving two Portuguese players named Vitinha, both born in 2000:



Vitinha

├── Paris Saint-Germain

│   └── MF

│

└── Genoa

&#x20;   └── FW,MF



The original identity logic incorrectly treated them as the same person.



Vinotinto Lab therefore introduced an identity-resolution layer with explicit canonical player keys.



Example:



KAGGLE:VITINHA:PSG:2000:POR



KAGGLE:VITINHA:GENOA:2000:POR



This allows downstream analytics to operate on canonical identities rather than relying blindly on source identifiers.



Transfer-Stint Aggregation



Players can appear multiple times in a season when they change clubs.



The canonical player-season model aggregates those stints into a single seasonal analytical record while preserving:



primary club

all clubs

primary competition

all competitions

stint count

total minutes

counting statistics



Per-90 metrics are recomputed after aggregation.



This prevents transferred players from being incorrectly treated as independent observations.



Player Profiles



The Player Profile service exposes the complete canonical player population.



Unlike the similarity model, the profile API does not require a player to have a minimum number of minutes.



Example:



GET /players/Kylian%20Mbapp%C3%A9



The response includes:



identity

nationality

age

season

club

competition

role

appearances

starts

minutes

goals

assists

shots

defensive actions

disciplinary statistics

per-90 metrics

data-quality information



Example structure:



{

&#x20; "identity": {

&#x20;   "name": "Kylian Mbappé",

&#x20;   "nation\_fifa\_code": "FRA"

&#x20; },

&#x20; "season": {

&#x20;   "primary\_club": "Real Madrid",

&#x20;   "primary\_competition": "La Liga"

&#x20; },

&#x20; "role": {

&#x20;   "position": "FW",

&#x20;   "position\_group": "FW"

&#x20; },

&#x20; "usage": {

&#x20;   "minutes": 2599

&#x20; },

&#x20; "production": {

&#x20;   "goals": 25,

&#x20;   "assists": 5

&#x20; },

&#x20; "data\_quality": {

&#x20;   "similarity\_eligible": true,

&#x20;   "sample\_quality": "HIGH"

&#x20; }

}

Player Explorer



V2 introduces a searchable player discovery API:



GET /players



Supported filters include:



search

competition

club

position\_group

min\_minutes

similarity\_eligible

limit

offset



Examples:



GET /players?search=Vini

GET /players?competition=La%20Liga\&position\_group=FW

GET /players?club=Barcelona

GET /players?similarity\_eligible=true\&min\_minutes=900



Responses include:



{

&#x20; "total": 100,

&#x20; "limit": 25,

&#x20; "offset": 0,

&#x20; "players": \[]

}



This endpoint is intended to become the backend foundation for a future visual Player Explorer.



Player Similarity

V1 — Cosine Similarity



The first similarity model used:



position-based cohorts

StandardScaler

cosine similarity



The original feature space included ten available per-90 metrics:



non\_penalty\_goals\_per90

assists\_per90

shots\_per90

shots\_on\_target\_per90

crosses\_per90

fouls\_drawn\_per90

tackles\_won\_per90

interceptions\_per90

fouls\_committed\_per90

offsides\_per90



Initial results were reasonable for some players.



For example, Dušan Vlahović appeared as the closest player to Kylian Mbappé.



However, explainability analysis uncovered an important weakness.



Players such as:



Lamine Yamal ↔ Harry Kane



Vinícius Júnior ↔ Harry Kane



sometimes received unexpectedly high cosine similarity.



Why Cosine Similarity Was Not Selected



Cosine similarity measures the direction of standardized vectors more strongly than their absolute distance.



Two players can therefore receive a high similarity score when their metrics move in similar directions even when their actual statistical magnitudes are substantially different.



To investigate this behavior, Vinotinto Lab compared:



Cosine similarity

Euclidean distance

Manhattan distance



A representative result:



Lamine Yamal ↔ Harry Kane



Cosine rank:

5



Euclidean rank:

63



Manhattan rank:

52



Another example:



Vinícius Júnior ↔ Harry Kane



Cosine rank:

2



Euclidean rank:

205



This experiment showed that standardized Euclidean distance better represented the concept of statistical proximity intended by the project.



V2 Similarity Model



The official V2 model therefore uses:



Canonical Player-Season

&#x20;       │

&#x20;       ▼

Position Cohort

&#x20;       │

&#x20;       ▼

10 per-90 features

&#x20;       │

&#x20;       ▼

StandardScaler

&#x20;       │

&#x20;       ▼

Euclidean Distance



Interpretation:



lower distance = more statistically similar



The system intentionally does not convert Euclidean distance into an arbitrary percentage score.



Example Results

Kylian Mbappé



Representative V2 nearest neighbors include:



Dušan Vlahović

Donyell Malen

Robert Lewandowski

Cheikh Dieng

Nicolas Jackson

Lamine Yamal



Representative results include:



Endrick

Marcus Rashford

Said El Mala

Tiago Tomás

Deniz Undav

Raphinha

Vinícius Júnior

Pedri



Representative results include:



Frenkie de Jong

Devyne Rensch

Vitinha

Caner İlkhan

Boubacar Kamara

Position Cohorts



Players are compared only against compatible position groups.



Current cohorts include:



FW

MF

DF

FW\_MF

DF\_MF

DF\_FW

GK



Goalkeepers are currently excluded from the similarity model.



Similarity Eligibility



Player profiles and similarity modeling intentionally use different populations.



Canonical Player Population

&#x20;       │

&#x20;       ├── Player Profile

&#x20;       │      all canonical players

&#x20;       │

&#x20;       └── Similarity Engine

&#x20;              eligible players only



A player currently requires at least:



900 minutes



to participate in similarity analysis.



For example, a player with 800 minutes can still have a valid player profile but is not considered statistically reliable enough for the similarity model.



API behavior therefore distinguishes between:



404

Player does not exist



422

Player exists but is not eligible

for similarity analysis



This prevents insufficient sample size from being incorrectly interpreted as missing data.



Similarity Explainability



Vinotinto Lab also includes explainability utilities for understanding why two players are considered similar.



For Euclidean distance, the system can inspect the squared contribution of every standardized feature to the total distance.



Example analyses showed that similarity relationships can be influenced heavily by metrics such as:



offsides

shots on target

fouls drawn

crosses

assists

tackles



This diagnostic layer is used to evaluate whether similarity results are statistically and football-wise reasonable.



Role-Specific Feature Experiment



V2 also tested role-aware feature subsets.



Example experimental feature groups included:



FW

non-penalty goals

assists

shots

shots on target

fouls drawn

offsides

FW / MF

non-penalty goals

assists

shots

shots on target

crosses

fouls drawn

MF

assists

shots

crosses

fouls drawn

tackles won

interceptions



The experiment produced promising results for attacking players.



However, it was not promoted to the official model.



The current dataset does not contain enough advanced football features to define reliable role-aware profiles, particularly for midfielders.



Important missing dimensions include:



xG

xA

key passes

progressive passes

progressive carries

shot-creating actions

dribble quality

duel profiles

chance creation



For that reason, official V2 remains the standardized 10-feature Euclidean model.



REST API



Vinotinto Lab exposes its analytical services through FastAPI.



Current endpoints:



GET /health



GET /players



GET /players/{player\_name}



GET /players/{player\_name}/similar



Interactive documentation is available through FastAPI Swagger:



http://localhost:8000/docs

Similarity Example

GET /players/Kylian%20Mbapp%C3%A9/similar?limit=5



The API returns:



target player

similarity model metadata

position cohort

nearest players

Euclidean distance

API Error Semantics



The API uses domain-aware HTTP responses.



200

Successful request



400

Ambiguous identity or invalid club disambiguation



404

Player does not exist



422

Player exists but is not eligible for similarity

or request validation failed



500

Unexpected internal analytical error

Automated Testing



V2 includes Dockerized integration tests covering:



health endpoint

player similarity

result limits

canonical identity ambiguity

club disambiguation

missing players

player profiles

similarity eligibility

Player Explorer

filtering

pagination

validation



Current V2 regression suite:



16 tests passed



Run:



docker compose --profile test run --rm test

Running the Project

Requirements

Docker Desktop

Docker Compose

Git



A local Python installation is not required for the analytical runtime.



Environment Configuration



Create:



.env



based on:



.env.example



Sensitive credentials such as API keys must never be committed.



Start PostgreSQL

docker compose up -d postgres

Start the API

docker compose up -d api



Check:



docker compose ps



Health check:



Invoke-RestMethod http://localhost:8000/health

Restart the API After Source Changes



The project intentionally runs Uvicorn without automatic reload inside Docker because Windows bind mounts caused file-watcher I/O instability.



After changing Python source code:



docker compose restart api

Database SQL Layers



The SQL implementation is versioned incrementally.



001\_init.sql



002\_player\_season\_analysis.sql



003\_kaggle\_staging.sql



004\_player\_intelligence\_base.sql



005\_player\_season\_canonical.sql



006\_player\_identity\_resolution.sql



007\_player\_season\_canonical\_identity\_resolved.sql



These scripts represent the evolution from raw data structures toward the canonical Player Intelligence model.



Project Structure

vinotinto\_lab\_db\_v0\_1/

│

├── Dockerfile

├── docker-compose.yml

├── pyproject.toml

├── README.md

│

├── sql/

│   ├── 001\_init.sql

│   ├── 002\_player\_season\_analysis.sql

│   ├── 003\_kaggle\_staging.sql

│   ├── 004\_player\_intelligence\_base.sql

│   ├── 005\_player\_season\_canonical.sql

│   ├── 006\_player\_identity\_resolution.sql

│   └── 007\_player\_season\_canonical\_identity\_resolved.sql

│

├── scripts/

│   ├── import-player-season.ps1

│   └── import-kaggle-season.ps1

│

├── src/

│   └── vinotinto\_lab/

│       ├── api/

│       │   └── main.py

│       │

│       ├── database/

│       │   └── connection.py

│       │

│       └── analytics/

│           ├── players/

│           │   ├── player\_profile.py

│           │   └── player\_explorer.py

│           │

│           └── similarity/

│               ├── player\_similarity.py

│               ├── player\_similarity\_v2.py

│               ├── explain\_similarity.py

│               ├── explain\_euclidean.py

│               ├── compare\_metrics.py

│               └── role\_feature\_experiment.py

│

└── tests/

&#x20;   └── test\_api.py

Data Sources



Current work uses football datasets imported from Kaggle and experimental API-Football ingestion.



Raw datasets are intentionally excluded from the Git repository.



API credentials are also excluded.



Current Limitations



Player Intelligence V2 intentionally has several limitations.



Feature richness



The current dataset lacks several advanced football metrics required for deeper role modeling.



Single-season focus



The current analytical implementation focuses primarily on the 2025/26 European league dataset.



Similarity is statistical, not semantic



Euclidean proximity identifies players with similar available statistical profiles.



It does not claim that two players:



have identical tactical roles

have identical technical quality

have equal market value

would perform equally in another team

Goalkeepers



Goalkeeper-specific similarity is not implemented yet.



Source identity



Identity resolution currently includes explicit correction mechanisms but has not yet evolved into a generalized multi-source entity-resolution system.



Future Work



Future Vinotinto Lab versions may introduce:



Data Enrichment

Transfermarkt integration

richer event/statistical sources

advanced player metrics

market value

transfer history

Player Intelligence V3

role-aware feature engineering

advanced attacking profiles

advanced midfield profiles

defensive profiles

goalkeeper models

dimensionality reduction

clustering

player archetypes

Match Intelligence

match prediction

expected outcomes

probability calibration

model evaluation

ML Engineering

MLflow

experiment tracking

model registry

scheduled pipelines

Prefect / Airflow

CI/CD

Product Integration

Vinotinto Lab APIs consumed by QuinielaManía

prediction services

sports insights

recommendation features

Cloud

AWS or GCP deployment

managed PostgreSQL

container orchestration

production observability

Engineering Principles



Vinotinto Lab follows several principles:



Data quality before modeling.

Canonical identity before aggregation.

Explain models instead of trusting rankings blindly.

Compare modeling alternatives empirically.

Separate experiments from production decisions.

Expose analytical capabilities through reusable APIs.

Test behavior before adding new features.

Build toward integration with real sports products.



The objective is not simply:



"I trained a model."



The objective is:



I built it, tested it, explained it, exposed it through an API and designed it to integrate with a real sports product.



Status



Player Intelligence V2 — Feature Complete



Current status:



Data foundation                  ✅

Canonical player-season          ✅

Transfer aggregation             ✅

Identity resolution              ✅

Player profiles                  ✅

Player Explorer                  ✅



Similarity V1 experimentation    ✅

Metric comparison                ✅

Similarity V2                    ✅

Euclidean explainability         ✅

Role-feature experiment          ✅



FastAPI                          ✅

Docker                           ✅

Swagger                          ✅

Automated regression tests       ✅



Next major milestone:



Vinotinto Lab V3 — Advanced Player Intelligence and Data Enrichment





\## Después de guardar el README



No hagamos todavía el merge. Primero validamos el cierre documental:



```powershell

git diff --check
