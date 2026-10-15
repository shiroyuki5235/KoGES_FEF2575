# KoGES repeated low FEF analysis

Release candidate 1.0.0-rc2.2, prepared 15 October 2026.

This repository reconstructs the agreed four-group landmark analysis from an approved local KoGES Ansan–Ansung data release. It consolidates the investigator-run source scripts and adds explicit reproduction gates. It is not yet a statistically validated final release: the consolidated script has been checked with an R grammar parser, but has not been run on participant data in the packaging environment.

Current manuscript scope governs this release: primary four-group Models 1–4 plus exploratory pooled three-group Model 4/5/A/B/C and BMI time effects in Table S4. Original groups, participants and endpoints are preserved. Modules 27–28 reproduce S4 and compare against archived results. Local execution remains required.

## Run

1. Extract the whole repository. Set the RStudio working directory to its root.
2. Use a fresh R session. Install `survival`, `openxlsx`, and `zip` if needed. `splines` ships with R. The archived investigator environment was Windows 11, R 4.6.1, survival 3.8-12; see `reference_results/sessionInfo_original.txt`.
3. Open `R/00_Final_Analysis.R`. The default input is `ASAS01to10_Processed.txt.gz` in the working directory. If absent, select it in the file dialog. If reference/assets folders are absent, a second dialog asks for the extracted package’s `R/00_Final_Analysis.R`. Input encoding is CP949. Run Module 00 through Module 32 sequentially. No earlier scripts, saved R workspace, or `source()` driver are needed.
4. Review the output `Tables/Reproduction_checks.csv`, `Tables/Analysis_status.csv`, figures, and actual `sessionInfo.txt`. Any mismatch must be investigated, never patched by editing expected counts or copying archived results into the generated output.
5. Run `R/01_Capture_Environment.R` in the same session to record dependency versions and an optional actual renv lockfile. This step does not install or update analysis packages.

Outputs are written under ignored `Output_*/Output_<timestamp>_FEF_Final/`, with one XLSX containing separate worksheets for every calculated CSV table, PNG/TIFF at 1200 dpi, vector PDFs, and an aggregate results ZIP. The original Figure 1 and Figure 2 are preserved byte-for-byte. `Figure2_Recomputed_QC` is a fresh rendering for verification, not a replacement for the approved artwork. PDFs do not have a fixed raster dpi.

The calculations use cohort-supplied FEF percent predicted throughout. BEST/PRED reconstruction is an arithmetic audit only. The source equation remains unconfirmed and no new prediction equation is substituted.

## Fixed reference cohorts

| Group | Exposure eligible | Follow-up | Follow-up events | Complete cases | Complete-case events |
|---|---:|---:|---:|---:|---:|
| Never | 2991 | 2832 | 136 | 2808 | 132 |
| Single | 136 | 128 | 46 | 127 | 45 |
| Recurrent | 58 | 54 | 22 | 54 | 22 |
| Frequent | 53 | 46 | 20 | 46 | 20 |

Model 1 uses 3060/224; Models 2–4 use 3035/219. Site is a stratum; ties use Efron. The existing post hoc three-group sensitivity analyses are reproduced separately and never overwrite the primary exposure objects.

Count and effect agreement are necessary checks, but do not prove agreement with an unavailable historical participant-ID manifest. Within this run, ID ordering, joins, complete-case membership, and immutable primary groups are checked explicitly. Keep approved source data and any historical ID/group records privately for investigator verification.

## Data and repository contents

Participant-level data are not included and must be obtained through the applicable KDCA/National Biobank access process. The code exports aggregate results only, not IDs, participant rows or fitted-model RDS objects. `reference_results/` contains previously supplied aggregate estimates used solely as comparison targets. These are not outputs of this new consolidated run.

The package contains no manufactured DOI, no fabricated renv lockfile, no claim of completed original-data execution, and no public upload. Follow `docs/Deposit_Guide_KO.txt` after local verification. Use the version-specific DOI of the exact accepted code release in the paper. The proposed MIT licence covers this code, not restricted KoGES data or third-party software.
