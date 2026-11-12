# UNICEF BiH DI | Minimal synthetic model (v0.2)

**Purpose:** provide a small, transparent, synthetic dataset and a base-R scenario model with a first institution-level cost module (M3) for the UNICEF BiH deinstitutionalisation economic assessment.  **Nothing in `baseline.csv`, `flows.csv`, `scenarios.csv` or `settings.csv` is an observation from Bosnia and Herzegovina.**

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
| `data/scenarios.csv` | Three scenarios: S0 BAU, S1 phased without closure, S1 phased with unit closure | All assumptions |
| `data/settings.csv` | Base year, horizon, discount rate, prevention volumes/unit cost | All assumptions |
| `data/institutions.csv` | Five-unit synthetic institution, central and unit-level fixed costs, closure lag and one-off cost | All assumptions |
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
3. **M3:** map actual facilities, staff, units, closure feasibility and safe placement constraints. The new v0.2 illustration releases *unit-level*, not central, fixed costs only after a unit closes. Additional care capacity is governed by the existing scenario inputs. The general `annual_transition_investment_bam` must be kept distinct from institution-specific closure costs.
4. **M4:** review and validate the policy pathways with UNICEF, including prevention, the availability/appropriateness of care, transitions, and staffing.
5. **M5:** not yet monetised. The output is a **10-year fiscal cost comparison**, not a full CBA. No long-term child benefit has been invented.

Costs are stated in **constant 2025 BAM**, with zero inflation (illustrative) and an assumed **3.5% discount rate**. This rate is not claimed as the approved BiH or UNICEF discounting standard. Children cannot be equated with a fungible resource: capacity and safe, appropriate care are prerequisites to transitions.

**QA status:** all CSVs were syntax and accounting checked via a Python mirror because R was unavailable in the authoring environment. The included R script should be run in R/RStudio or GitHub Actions before reliance on numerical results.


## v0.2: institution cost and closure module (M3)

The **same exact child flows** are simulated under `S1_PHASED` (no restructuring)
and `S1_PHASED_RESTRUCT` (allow unit closures). Differences in their cost
results therefore come **only** from institution-level fixed-cost reductions
and one-off closure costs. `S0_BAU` is unchanged.

**Synthetic institution assumptions:** one provider (`INST_SYN_01`), five
25-place units (=125 places), annual central overhead **800,000 BAM**, unit-level
fixed cost **300,000 BAM per active unit**, and a one-off **150,000 BAM per
unit closed**. The total starting fixed cost is 800,000 + 5 × 300,000 =
**2,300,000 BAM/year**, deliberately matching the original
`baseline.csv` institutional fixed cost. Variable care costs remain
**10,500 BAM per child-year**. Every monetary value is an unsupported
illustrative assumption, not an observation or an estimate of an actual provider.

**Rules:** one unit may close at the **end** of a year when its remaining
units have enough places for the observed end-year synthetic institutional
population. `closure_lag_years = 1` means one eligible year; for a larger
value the model requires consecutive eligible years. No more than one unit
closes per year, at least one unit remains operational, and no reopening
is modelled. One-off closure expenditure is incurred **in the year of closure**;
the 300,000 BAM recurring unit-cost saving starts **the following year**.
Institutional central overhead continues throughout. No staff, individual
child suitability or geographic matching is yet explicitly modelled.

**Cost identity:**
`institutional care cost = child-years × variable cost + central overhead + active units × unit fixed cost`.
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

The test checks identical child trajectories for both S1 scenarios, cost
identities, non-negative stocks, safe aggregate capacity and no closure
when the switch is off. **This remains an accounting demonstration, not
a real-world institutional transformation policy or a BiH impact estimate.**
