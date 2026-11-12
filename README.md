# UNICEF BiH DI | Minimal synthetic model (v0.3)

**Purpose:** provide a small, transparent, synthetic dataset and a base-R scenario model with institution-level fixed costs, workforce-readiness and placement-matching proxies (M3) for the UNICEF BiH deinstitutionalisation economic assessment.  **Nothing in `baseline.csv`, `flows.csv`, `scenarios.csv` or `settings.csv` is an observation from Bosnia and Herzegovina.**

The example represents **one hypothetical local service network**, NOT BiH overall and NOT any identifiable institution or child. It contains 200 children at the opening of a hypothetical 2025 base year: 100 institutional (I), 50 foster (F), 35 kinship (K), 15 community/small-group (G). `HOME` and `EXIT` are external statuses, not additional resident care populations.

## Run

From the repository root, with base R (no dependencies):

```bash
Rscript R/run_model.R
```

Produces `outputs/stocks.csv`, `outputs/realised_flows.csv`, `outputs/institution_units.csv`, `outputs/annual_results.csv`, and `outputs/scenario_summary.csv`. If an expected stock exceeds capacity, v0.1 **stops** instead of assigning a child to an unsuitable placement. Counts are **expected values**, potentially fractional, not simulated individual records. This is a deterministic accounting prototype, **not an empirically calibrated forecast**.

## Inputs

| File | Meaning | Status |
|---|---|---|
| `data/baseline.csv` | Starting care populations, capacity, unit costs and fixed costs | All synthetic estimates |
| `data/flows.csv` | Reference annual flows for 2025, scaled against populations in future years | All assumptions |
| `data/scenarios.csv` | Four scenarios: S0 BAU, S1 phased without closure, S1 with closure, S1 with closure and matching constraint | All assumptions |
| `data/settings.csv` | Base year, horizon, discount rate, prevention volumes/unit cost | All assumptions |
| `data/institutions.csv` | One five-unit synthetic institution: costs, FTE assumptions, closure/staff adjustment lead time, avoidable share | All assumptions |
| `data/evidence.csv` | Published reference figures with URL, year, and limitations | Context ONLY: not copied into model inputs |

Model costs: institutional fixed cost **2.3 million BAM/year** plus **10,500 BAM per child-year**, foster **10,800 BAM/child-year**, kinship **7,200 BAM/child-year**, G **25,000 BAM/child-year** + **100,000 BAM fixed**, prevention **900 BAM/family/year**. These are illustrations, not sourced national unit-cost estimates. BAU has no additional reforms; phased DI assumes annual cumulative reduction of institutional admissions (5 percentage points per model year, capped at 100%), increased transitions out of institutions (7% multiplier growth per year), modest capacity expansion, and **100,000 BAM/year** transition investments. The admission and prevention assumptions are *not* presented as estimated causal effects.

### Published points of reference (not interchangeable)

- **E1 UNICEF 2024:** reports **1,857** children in residential care for BiH. The reference period and category scope need verification before use as a 2025 national baseline. https://www.unicef.org/eca/reports/keeping-families-together-europe
- **E2 KJU Bjelave, 2024 financial plan:** **3,803,851 BAM** planned overall budget; describes average **85** children and **75** employees, but the organisation also operates multiple locations and programmes. Thus dividing its full budget by 85 does **not** yield a comparable institutional unit cost. https://cdn.dombjelave.ba/storage/2025/07/15/finansijski-plan-kju-dom-za-djecu-bez-roditeljskog-staranja-za-2024-godinu.pdf
- **E3 Sarajevo foster allowance, reported 2026:** **717.30 BAM per month** for traditional fostering (payment only). The synthetic F unit cost of 900 BAM/month *adds unverified service/support costs* and is not presented as an official national rate. https://faktor.ba/bosna-i-hercegovina/aktuelno/otvorena-srca-sigurni-domovi-kako-postati-hranitelj-u-sarajevu/256572
- **E4 UNICEF BiH 2025 Situation Analysis:** documents fragmented definitions and limited cross-jurisdiction comparability. https://www.unicef.org/bih/en/reports/situation-analysis-position-children-and-adolescents-bosnia-and-herzegovina

## Model boundaries and next data requests

1. **M1:** validate true counts, admission/exit events, cross-care transitions (2024–2026), and available capacity from providers and social work centres.
2. **M2:** collect actual current expenditure broken down by personnel, services and infrastructure; identify what is fixed or avoidable. Finance transfers should not be added twice.
3. **M3:** map actual facilities, staff, units, closure feasibility and safe placement constraints. The v0.3 illustration releases only the **avoidable share** of unit fixed costs after closure, subject to staffing readiness and a minimum adjustment lag. Additional care capacity is governed by the existing scenario inputs. The general `annual_transition_investment_bam` must be kept distinct from institution-specific closure costs.
4. **M4:** review and validate the policy pathways with UNICEF, including prevention, the availability/appropriateness of care, transitions, and staffing.
5. **M5:** not yet monetised. The output is a **10-year fiscal cost comparison**, not a full CBA. No long-term child benefit has been invented.

Costs are stated in **constant 2025 BAM**, with zero inflation (illustrative) and an assumed **3.5% discount rate**. This rate is not claimed as the approved BiH or UNICEF discounting standard. Children cannot be equated with a fungible resource: capacity and safe, appropriate care are prerequisites to transitions.

**QA status:** all CSVs were syntax and accounting checked via a Python mirror because R was unavailable in the authoring environment. The included R script should be run in R/RStudio or GitHub Actions before reliance on numerical results.


## Institution cost and closure module (M3, updated v0.3)

The **same child flows** are simulated under `S1_PHASED` (no restructuring)
and `S1_PHASED_RESTRUCT` (allow unit closures). Differences in their costs
come from unit-level fixed-cost reductions, retained expenses and one-off
closure costs. The fourth `S1_RESTRUCT_MATCH75` scenario deliberately
introduces a separate, illustrative matching constraint. `S0_BAU` is unchanged.

**Synthetic institution assumptions:** one provider (`INST_SYN_01`), five
25-place units (=125 places), annual central overhead **800,000 BAM**, unit-level
fixed cost **300,000 BAM per active unit**, and a one-off **150,000 BAM per
unit closed**. The total starting fixed cost is 800,000 + 5 × 300,000 =
**2,300,000 BAM/year**, deliberately matching the original
`baseline.csv` institutional fixed cost. Variable care costs remain
**10,500 BAM per child-year**. Every monetary value is an unsupported
illustrative assumption, not an observation or an estimate of an actual provider.

**Rules (v0.3):** one unit may close at **year-end** only if remaining units
can accommodate the closing institutional population, staffing can be reassigned,
and eligibility has held for `max(closure_lag_years, staff_adjustment_lag_years)`
consecutive years. No more than one unit closes per year; at least one remains
operational; reopening is not modelled. One-off closure expenditure is incurred **in the year of closure**;
the 300,000 BAM recurring unit-cost saving starts **the following year**.
Institutional central overhead continues throughout. No staff, individual
child suitability or geographic matching is yet explicitly modelled.

**Cost identity (v0.3):**
`institutional care cost = child-years × variable cost + central overhead
+ active units × unit fixed cost
+ closed units × (1 − avoidable share) × unit fixed cost`.
`total system cost = care cost + prevention + general transition investment
+ unit closure cost + system overhead`.

**Check outputs:** `outputs/institution_units.csv` records the number of
units before/after each year, operational capacity, closures and cost
components. `outputs/annual_results.csv` includes
`institution_fixed_cost_bam`, `institution_variable_cost_bam`,
`institution_restructuring_cost_bam` and `units_closed`. Run:

```bash
Rscript R/run_model.R
Rscript R/test_model.R
```

The tests check identical child trajectories for the unrestricted S1 scenarios,
cost identities, non-negative stocks, aggregate capacity, staffing-readiness
constraints, lead times, and matching constraints. **This remains an accounting demonstration, not
a real-world institutional transformation policy or a BiH impact estimate.**

## v0.3: staffing readiness and placement suitability

The model now adds two independent feasibility mechanisms:

1. **Workforce readiness:** central staffing of **12 FTE**, **8 FTE per active
   unit**, and at most **8 FTE/year** available for redeployment/reassignment.
   Closing one unit requires this capacity and a **two-year consecutive
   staffing adjustment / preparation period**. This is a synthetic planning
   constraint, not an observed staffing policy. The model tracks staff still
   assigned to the institution and the FTE that must be reassigned when a unit
   closes. Staff are not treated as unemployed and direct payroll savings are
   **not** calculated independently of unit fixed costs.
2. **Placement suitability proxy:** the fraction of proposed transitions
   **from institutional care (I) to foster (F), kinship (K) and community/
   small-group (G)** that can proceed. Default = **1.00** in S0 and the
   two original S1 scenarios; `S1_RESTRUCT_MATCH75` uses **0.75** as a
   sensitivity case. Unmatched transitions are **deferred**, leaving the
   projected child in the original care setting, **not** routed to another
   form of care. This fraction is **not** a case-level suitability assessment,
   and does not verify individual child needs, sibling groups or local service
   matching. Physical capacity is checked separately; the model stops rather
   than reallocating children when capacity is exceeded.

The cost calculation assumes **65% of each closed unit's fixed cost is
avoidable**, while the remaining **35% is retained** as a continuing
system-level expenditure. This prevents automatic full payroll savings, but
the avoidable share is not empirically calibrated and does not establish the
true fiscal impact of staff redeployment. One-off unit closures still cost
**150,000 BAM**. The closure lag extends the period of parallel financing.

Outputs include `staff_fte_start`, `staff_fte_end`,
`staff_redeployed_fte`, `closure_wait_years`,
`deferred_suitability_events`, `planned_events` and the additional retained
cost component. These are **expected counts**; no individual records exist.

### Latest synthetic scenario results (Python accounting cross-check)

| Scenario | NPV of incremental fiscal costs (2025 BAM) |
|---|---:|
| S0_BAU | 0 |
| S1_PHASED | -129,778 |
| S1_PHASED_RESTRUCT | -1,309,110 |
| S1_RESTRUCT_MATCH75 | -908,810 |

The first unit closes at the end of **2026** in the unrestricted restructuring
scenario, with a second closure at the end of **2033**. In the matching-constrained
scenario closures occur at the end of **2028** and **2034**. The expected R
results should be confirmed using `Rscript R/test_model.R`; R could not be
executed in the author's environment. These figures are **not BiH forecasts
or estimates of child outcomes**.
