# Vinotinto Lab V3 — Player Intelligence Feature Target

## 1. Objective

Player Intelligence V3 will extend the V2 statistical player profile into a richer football intelligence model.

The purpose of this document is to define the target feature space before selecting or integrating new data sources.

The guiding principle is:

> Data sources must be selected because they provide information required by the analytical model, not simply because the data is available.

V2 remains the baseline and must continue to be reproducible while V3 is developed.

---

## 2. Current V2 Baseline

Player Intelligence V2 currently uses ten per-90 features:

- non_penalty_goals_per90
- assists_per90
- shots_per90
- shots_on_target_per90
- crosses_per90
- fouls_drawn_per90
- tackles_won_per90
- interceptions_per90
- fouls_committed_per90
- offsides_per90

Current similarity architecture:

Canonical Player-Season
→ Position Cohort
→ StandardScaler
→ Euclidean Distance

Eligibility currently requires:

- minimum 900 minutes

V2 provides:

- canonical player-season records
- transfer-stint aggregation
- identity resolution
- player profiles
- player explorer
- similarity
- Euclidean explainability
- REST API
- automated integration tests

V3 must improve this baseline rather than replace it without evidence.

---

## 3. Target Feature Families

### 3.1 Finishing

Target metrics:

- goals
- non-penalty goals
- xG
- non-penalty xG
- shots
- shots on target
- shot accuracy
- goals per shot
- goals minus xG
- touches or shots inside penalty area

Purpose:

Measure finishing volume, shot quality and finishing efficiency.

Priority:

HIGH

---

### 3.2 Chance Creation

Target metrics:

- assists
- xA
- key passes
- passes leading to shots
- shot-creating actions
- goal-creating actions
- crosses
- crosses into penalty area

Purpose:

Separate pure finishing profiles from players responsible for creating opportunities.

Priority:

HIGH

---

### 3.3 Ball Progression

Target metrics:

- progressive passes
- progressive carries
- passes into final third
- passes into penalty area
- carries into final third
- carries into penalty area

Purpose:

Measure how players advance possession rather than only measuring final output.

Priority:

HIGH

---

### 3.4 Possession and 1v1 Ability

Target metrics:

- carries
- attempted take-ons
- successful take-ons
- take-on success rate
- touches
- touches in attacking third
- touches in penalty area
- dispossessions
- miscontrols

Purpose:

Identify ball-dominant profiles, dribblers and players capable of generating progression individually.

Priority:

HIGH

---

### 3.5 Passing Profile

Target metrics:

- passes attempted
- passes completed
- completion percentage
- short passes
- medium passes
- long passes
- progressive passes
- switches
- through balls

Purpose:

Distinguish possession-oriented, progressive and direct passing profiles.

Priority:

HIGH for midfielders
MEDIUM for forwards and defenders

---

### 3.6 Defensive Activity

Target metrics:

- tackles attempted
- tackles won
- interceptions
- recoveries
- blocks
- clearances
- pressures
- successful pressures
- aerial duels
- ground duels
- duel success rate

Purpose:

Create meaningful defensive and midfield profiles rather than relying on a small number of defensive statistics.

Priority:

HIGH

---

### 3.7 Discipline and Physical Interaction

Target metrics:

- fouls committed
- fouls drawn
- yellow cards
- red cards
- aerial duels
- duels won
- duels lost

Purpose:

Provide additional context about player involvement and physical profile.

Priority:

MEDIUM

---

## 4. Player Context

Player statistics must be accompanied by contextual information.

Target dimensions:

- canonical player identity
- full name
- date of birth
- age
- nationality
- primary position
- secondary positions
- club
- league
- season
- appearances
- starts
- minutes
- transfer history
- previous clubs
- market value
- contract information where appropriate and available

These dimensions are not necessarily similarity features.

They are primarily used for:

- filtering
- identity resolution
- contextual analysis
- player discovery
- future product features

---

## 5. Cross-Source Identity Requirements

V3 should move from source-specific identity resolution toward a canonical multi-source player model.

Conceptual architecture:

player_master
    |
    +-- Kaggle identity
    +-- Transfermarkt identity
    +-- API-Football identity
    +-- future source identities

Target requirements:

- stable internal canonical_player_id
- source name
- source player id
- source URL or key when available
- confidence of identity match
- explicit overrides for ambiguous cases
- auditability of manual resolutions

Name matching alone must not be treated as sufficient identity evidence.

---

## 6. Role-Aware Intelligence

V2 compares players by broad position groups.

V3 should eventually support richer football roles.

Potential examples:

### Forwards

- poacher
- target forward
- mobile striker
- wide forward
- inside forward
- creator-forward

### Midfielders

- defensive midfielder
- ball-winning midfielder
- deep-lying playmaker
- box-to-box midfielder
- attacking midfielder
- advanced creator

### Defenders

- ball-playing centre-back
- stopper
- attacking full-back
- defensive full-back
- wing-back

These labels must not initially be hardcoded as truth.

They should eventually emerge from:

- richer features
- clustering
- dimensionality reduction
- football interpretation

---

## 7. Goalkeeper Intelligence

Goalkeepers are currently excluded from V2 similarity.

V3 should evaluate a dedicated goalkeeper feature space instead of mixing goalkeepers with outfield players.

Potential target metrics:

- save percentage
- goals conceded
- post-shot expected goals
- crosses stopped
- defensive actions outside penalty area
- launch percentage
- passing metrics
- clean sheets

Goalkeeper modeling should remain independent from outfield similarity.

---

## 8. Data Quality Requirements

A feature should not automatically enter the production model because it exists.

Each candidate feature should be evaluated for:

- coverage
- missing values
- consistency
- reproducibility
- season availability
- league availability
- source stability
- semantic definition
- duplicate information
- outliers
- sample-size sensitivity

Per-90 transformations must continue to be calculated only after player-season aggregation when appropriate.

---

## 9. Source Evaluation Requirements

Every candidate data source should be assessed against:

- available competitions
- available seasons
- player coverage
- metric coverage
- player identifiers
- historical availability
- update frequency
- reproducibility
- automation capability
- rate limits
- licensing / usage constraints
- cost
- integration complexity

Potential sources currently under consideration:

- existing Kaggle datasets
- Transfermarkt-derived work
- API-Football
- additional advanced-stat sources
- future sports-data APIs

No source is considered selected simply because it appears in this list.

---

## 10. Modeling Principles

V3 should preserve the engineering lessons learned during V2.

### Baseline first

Similarity V2 remains the benchmark.

### Compare empirically

New feature spaces should be compared against V2 using representative players.

### Explainability

Similarity results should remain explainable at feature level.

### Position and role awareness

Players should not be compared across incompatible football contexts.

### Avoid artificial similarity percentages

Distance or similarity metrics should preserve their statistical meaning unless a calibrated interpretation is developed.

### Experiments are not production models

PCA, clustering and role-specific feature sets should remain experimental until validated.

---

## 11. Evaluation Players

A stable group of representative players should be used to evaluate V3 against V2.

Initial candidates:

- Kylian Mbappé
- Lamine Yamal
- Vinícius Júnior
- Harry Kane
- Robert Lewandowski
- Pedri
- Frenkie de Jong
- Vitinha

The evaluation set should include:

- forwards
- hybrid FW/MF players
- midfielders
- transferred players
- identity-resolution edge cases

---

## 12. V3 Success Criteria

Player Intelligence V3 should not be considered successful merely because more features are available.

V3 should demonstrate that richer data enables at least some of the following:

- more football-coherent nearest neighbours
- clearer distinction between tactical profiles
- meaningful player archetypes
- stronger position-specific models
- better explainability
- richer Player Profile responses
- more useful Player Explorer filtering
- reproducible multi-source data integration

The final decision to replace or extend the V2 similarity model must be evidence-based.

---

## 13. Non-Goals for the First V3 Phase

The first V3 phase will not prioritize:

- match prediction
- bookmaker odds
- prediction markets
- QuinielaManía integration
- cloud deployment
- MLflow
- Airflow
- complex frontend development

Those capabilities remain part of the broader Vinotinto Lab roadmap.

The immediate focus is:

Data Enrichment
→ Multi-source Identity
→ Advanced Player Features
→ Role-Aware Player Intelligence
