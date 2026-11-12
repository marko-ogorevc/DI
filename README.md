# UNICEF BiH DI | Minimal synthetic data (v0.1)

**Purpose:** provide a small, transparent, synthetic dataset and a first base-R scenario model for the UNICEF BiH deinstitutionalisation economic assessment.  **Nothing in `baseline.csv`, `flows.csv`, `scenarios.csv` or `settings.csv` is an observation from Bosnia and Herzegovina.**

The example represents **one hypothetical local service network**, NOT BiH overall and NOT any identifiable institution or child. It contains 200 children at the opening of a hypothetical 2025 base year: 100 institutional (I), 50 foster (F), 35 kinship (K), 15 community/small-group (G). `HOME` and `EXIT` are external statuses, not additional resident care populations.

## Run

From the repository root, with base R (no dependencies):

```bash
Rscript R/run_model.R
```

Produces `outputs/stocks.csv`, `outputs/realised_flows.csv`, `outputs/annual_results.csv`, and `outputs/scenario_summary.csv`. If an expected stock exceeds capacity, v0.1 **stops** instead of assigning a child to an unsuitable placement. Counts are **expected values**, potentially fractional, not simulated individual records. This is a deterministic accounting prototype, **not an empirically calibrated forecast**.

## Inputs

| File | Meaning | Status |
|---|---|---|
| `data/baseline.csv` | Starting care populations, capacity, unit costs and fixed costs | All synthetic estimates |
| `data/flows.csv` | Reference annual flows for 2025, scaled against populations in future years | All assumptions |
| `data/scenarios.csv` | Two sets of reform parameters: S0 BAU, S1 phased DI | All assumptions |
| `data/settings.csv` | Base year, horizon, discount rate, prevention volumes/unit cost | All assumptions |
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
3. **M3:** map facility-level units and constraints; v0.1 deliberately **does not release institutional fixed costs** as occupancy falls. Opening additional places is represented by scenario capacity; the scenario's `annual_transition_investment_bam` is an aggregate and should not be counted again elsewhere.
4. **M4:** review and validate the policy pathways with UNICEF, including prevention, the availability/appropriateness of care, transitions, and staffing.
5. **M5:** not yet monetised. The output is a **10-year fiscal cost comparison**, not a full CBA. No long-term child benefit has been invented.

Costs are stated in **constant 2025 BAM**, with zero inflation (illustrative) and an assumed **3.5% discount rate**. This rate is not claimed as the approved BiH or UNICEF discounting standard. Children cannot be equated with a fungible resource: capacity and safe, appropriate care are prerequisites to transitions.

**QA status:** all CSVs were syntax and accounting checked via a Python mirror because R was unavailable in the authoring environment. The included R script should be run in R/RStudio or GitHub Actions before reliance on numerical results.
