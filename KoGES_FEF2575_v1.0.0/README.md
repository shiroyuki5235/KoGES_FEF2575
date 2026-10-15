# KoGES repeated low FEF analysis

**Version 1.0.0 · 15 October 2026**

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23383064.svg)](https://doi.org/10.5281/zenodo.23383064)

R analysis code supporting the manuscript:

**“Frequency of low mid-expiratory flow measurements and subsequent airflow obstruction: a Korean longitudinal cohort study.”**

This repository provides the analysis workflow for the KoGES Ansan–Ansung longitudinal cohort. The consolidated script was executed by the investigators using the approved study data, and the reported numerical reproduction checks passed.

## Analysis scope

The analysis uses AS01–AS04 to classify the frequency of low FEF₂₅–₇₅ measurements, with AS04 as the landmark and AS05–AS07 as the outcome follow-up period.

Low FEF₂₅–₇₅ is defined as <65% predicted. The primary exposure groups are:

- **Never:** no low measurements.
- **Single:** one low measurement.
- **Recurrent:** two low measurements.
- **Frequent/Persistent:** three or four low measurements.

Included analyses:

- Participant selection and descriptive statistics.
- Site-stratified Cox models 1–4.
- Kaplan–Meier estimates and incidence summaries.
- Confirmation-based outcomes and alternative exposure thresholds.
- Natural-spline adjustment and specified time-varying effects.
- Exploratory historical-spirometry adjustment, including Models 5/A/B/C and BMI time effects reported in Table S4.
- Interval-censored accelerated failure-time models.

Exploratory three-group analyses combine the Recurrent and Frequent/Persistent groups into a Repeated group. These analyses are performed separately from the primary four-group analyses.

## Software requirements

The analysis was run with:

| Software | Version |
|---|---|
| R | 4.6.1 |
| survival | 3.8.12 |
| openxlsx | 4.2.9 |
| zip | 3.0.2 |

The `splines` package is included with R.

Install the required additional packages if needed:

```r
install.packages(c("survival", "openxlsx", "zip"))
```

## Running the analysis

1. Download and extract the complete repository.
2. Start a fresh R session and set the working directory to the extracted repository folder.
3. Open `R/00_Final_Analysis.R`.
4. Run **Module 00 through Module 32** sequentially.

The script initially looks for `ASAS01to10_Processed.txt.gz` in the working directory. If the file is absent, a dialog opens so that the input file can be selected without moving it.

If the repository’s `reference_results` or `assets/original_figures` folder cannot be found, a second dialog asks for the extracted package’s `R/00_Final_Analysis.R` file.

The default input encoding is **CP949**.

The script contains the analysis code directly within numbered modules and does not require an earlier R workspace or a `source()` driver.

After the main analysis, `R/01_Capture_Environment.R` can be run in the same session to record dependency versions. If `renv` is already installed, it can also generate a lockfile from the installed environment. This step does not install or update analysis packages.

## Outputs

Results are saved directly beneath the initial working directory:

```text
Output_YYYYMMDD_HHMMSS_FEF_Final/
```

A corresponding ZIP archive is created alongside the output folder.

Outputs include:

- `All_Analysis_Tables.xlsx`: analysis tables in separate worksheets, with an index.
- `Tables/`: individual aggregate result tables in CSV format.
- `Figures/`: figures in PNG, TIFF and PDF formats.
- `sessionInfo.txt`: the R session information.
- `package_versions.csv`: versions of the main software dependencies.

PNG and TIFF figures are exported at **1200 dpi**. PDF figures are provided in vector format.

The approved manuscript Figures 1 and 2 are included. A separately labelled `Figure2_Recomputed_QC` file provides an additional rendering of the Kaplan–Meier analysis.

## Study population

| Group | Exposure eligible | Follow-up | Follow-up events | Complete cases | Complete-case events |
|---|---:|---:|---:|---:|---:|
| Never | 2,991 | 2,832 | 136 | 2,808 | 132 |
| Single | 136 | 128 | 46 | 127 | 45 |
| Recurrent | 58 | 54 | 22 | 54 | 22 |
| Frequent/Persistent | 53 | 46 | 20 | 46 | 20 |
| **Total** | **3,238** | **3,060** | **224** | **3,035** | **219** |

Model 1 uses the follow-up cohort of **3,060 participants with 224 events**. Models 2–4 use **3,035 complete cases with 219 events**.

Cox models stratify by study site and use the Efron method for tied event times.

Confirmation-based analyses use different event definitions, so their event counts differ from those of the first-observed airflow-obstruction analysis. Alternative exposure thresholds may change group membership within the same analytical cohort.

## FEF percent-predicted values

Exposure classification uses the FEF percent-predicted values supplied in the cohort data.

The exact FEF-specific reference equation and visit-specific prediction settings remain to be confirmed. No alternative reference equation is substituted in this analysis.

## Repository contents

| Path | Contents |
|---|---|
| `R/00_Final_Analysis.R` | Main analysis script |
| `R/01_Capture_Environment.R` | Environment and dependency recording |
| `R/99_Validate_Syntax.R` | Optional R syntax check |
| `reference_results/` | Archived aggregate reference results |
| `assets/original_figures/` | Approved manuscript Figures 1 and 2 |
| `docs/` | Variable mappings, manuscript–code correspondence and supporting documentation |
| `CITATION.cff` | Software citation metadata |
| `LICENSE` | Code licence |

## Data availability

Participant-level KoGES data are not included in this repository. Access requires the applicable approval and compliance with the KDCA/National Biobank of Korea data-use conditions.

The analysis exports aggregate results. Participant identifiers, participant-level records and fitted-model RDS files are not included in the exported results package.

## Citation

The analysis code is archived in Zenodo:

**https://doi.org/10.5281/zenodo.23383064**

Please cite the archived software version and refer to `CITATION.cff` for the citation metadata.

## Licence

See `LICENSE` for the terms governing the analysis code.

The code licence does not grant access to restricted KoGES data or replace the licences of third-party software.
