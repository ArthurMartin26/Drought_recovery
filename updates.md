# Project Status: Drought Shock Construction (Work in Progress)

## recent update 

Baseline standardisation can be numerically unstable when baseline rainfall variability is near zero for particular grid‑cell × calendar‑month combinations. We therefore apply a two‑stage stabilisation rule: baselines with effectively zero variance are excluded from shock classification, and remaining low‑variance baselines are stabilised using a lower‑bound on the standard deviation based on the empirical distribution. This prevents implausible z‑scores while preserving genuine drought variation.

## Overview

This repository contains work towards constructing a regional, grid‑cell–level dataset of drought shocks for Sub‑Saharan Africa, with a focus on Nigeria. The ultimate goal of the project is to study and predict regional post‑shock adjustment and recovery dynamics using satellite data and machine learning methods.

Work to date has focused on defining and operationalising drought shocks in a way that is conceptually appropriate for recovery analysis. This process surfaced several important issues, which are documented here.

---

## Data Inputs

The core input dataset is a monthly rainfall panel at 10km spatial resolution, with one row per grid cell per month. Each observation includes:

- grid cell identifier  
- year and month  
- monthly rainfall (mm)  
- grid cell centroid coordinates  

The panel spans approximately 2000–2024 and is treated as the canonical rainfall input for drought construction.

---

## Conceptual Definition of Drought (Agreed)

A drought is defined as a **finite rainfall shock**, not a persistent climatic state.

Specifically, a drought should:

- represent a temporary excursion away from normal rainfall conditions  
- have a clear start and end  
- persist long enough to matter economically  
- allow for a post‑shock recovery phase  

Long‑run aridification or permanent regime shifts are explicitly **not** treated as droughts, as they do not admit a meaningful recovery dynamic.

---

## Chosen Drought Detection Strategy

The agreed conceptual strategy for detecting drought shocks is:

- use multi‑month accumulated rainfall rather than single‑month deviations  
- focus on 3‑month accumulated rainfall as a baseline shock measure  
- standardise accumulated rainfall relative to a baseline climatology  
- use entry and exit thresholds (hysteresis) so that droughts begin under severe stress and end only after recovery  
- construct drought events as contiguous blocks of drought months  

This approach is intended to produce episodic, finite drought shocks suitable for analysing recovery trajectories.

---

## Implementation Status

Multiple drought construction scripts have been developed and tested. These scripts successfully:

- compute rolling multi‑month rainfall aggregates  
- standardise rainfall relative to a baseline  
- classify drought states using entry and exit thresholds  
- assign drought indicators at the month level  

However, **event construction remains unresolved**.

Specifically, issues were identified where:

- drought events were incorrectly formed from non‑contiguous months  
- event start and end dates spanned long calendar periods while reported durations were short  
- event identifiers appeared on months that were not in drought state  
- some event definitions violated the intended “shock” interpretation  

These problems indicate that the current event‑building logic does not yet fully enforce calendar contiguity and temporal coherence.

As a result, **no drought event table should currently be treated as final or correct**.

---

## Current Decision

At this point, coding has been paused deliberately.

Before further implementation, the drought event logic needs to be re‑designed and validated carefully to ensure that:

- each drought event consists of strictly consecutive calendar months  
- event duration matches the calendar span exactly  
- event identifiers only appear on drought months  
- no event spans implausibly long periods  

This redesign will be done incrementally and validated against individual grid‑cell time series before scaling up.

---

## What Is Reliable at This Stage

- the rainfall panel itself  
- rolling rainfall aggregates  
- baseline climatology calculations  
- month‑level drought state indicators (conceptually)  

---

## What Is Not Yet Reliable

- drought event identifiers  
- event start and end dates  
- event durations  
- any downstream analysis using event‑level data  

---

## Next Steps (Planned)

- redesign drought event construction with explicit calendar contiguity checks  
- validate drought events visually and numerically on a small number of cells  
- only then regenerate a full event‑level dataset  
- proceed to recovery and adjustment analysis once drought shocks are well‑defined  

---

## Summary

Significant progress has been made on data preparation and on clarifying the correct conceptual definition of drought shocks for this project. However, drought event construction is still under active development and should be treated as unfinished.

This README reflects the current, honest state of the project to avoid over‑claiming or accidental misuse of intermediate outputs.
