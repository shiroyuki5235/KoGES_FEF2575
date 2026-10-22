# KoGES repeated low FEF analysis

Version 1.1.0 — manuscript alignment: 22 October 2026.

R code for the KoGES Ansan–Ansung four-group landmark analysis. This update retains the primary Models 1–4 and existing supplementary analyses, adds the post hoc analyses in Tables S8–S9, and documents the original Table S3 spline specification. The newly proposed exposure visit-pattern analysis B is not included.

## Run

1. Extract this repository and set the RStudio working directory to its root. Start a fresh R session.
2. Install `survival`, `openxlsx`, and `zip`. `splines` is included with R.
3. Open `R/00_Final_Analysis.R` and run Modules 00–38 sequentially. There is no `source()` driver and no dependency on an earlier R workspace.
4. The default input is `ASAS01to10_Processed.txt.gz` in the working directory. If absent, an interactive file dialog asks for the approved local data file. For noninteractive execution, edit `DATA_FILE`. Encoding is CP949. No `_private`, reference-results, or original-artwork folder is required.
5. Review the generated tables, figures, model messages and `sessionInfo.txt`. Optionally run `R/01_Capture_Environment.R` in the same session to add installed package versions and refresh the results ZIP.

Outputs are created in `Output_<timestamp>_FEF_Final/`: one `All_Analysis_Tables.xlsx` workbook with an INDEX and separate worksheets for all calculated CSV tables; aggregate CSVs; PNG and TIFF figures at 1200 dpi; vector PDFs; and an aggregate results ZIP alongside the folder. Vector PDF has no fixed raster dpi. Figure 1 and Figure 2 are generated from the current run and are not byte-identical copies of previously approved manuscript artwork. Review their layout before submission. High-resolution raster rendering can require substantial memory.

## Analysis organization

| Category | Manuscript items | Modules |
|---|---|---|
| Primary analyses | Table 1, Table 2, Figure 1, Figure 2 | 01–11, 29, 31 |
| Sensitivity analyses | Tables S2, S3, S5, S8 | 14–15, 18, 20–26, 32–36 |
| Historical adjustment and diagnostics | Tables S4, S9 | 27–28, 32–37 |
| Data checks and descriptive analyses | Tables S1, S6, S7 | 03, 05, 09, 12–13, 16, 19 |

See `docs/Manuscript_code_map.csv` for the output filenames and table panels. Additional diagnostic figures support interpretation and are not automatically numbered manuscript figures.

## Fixed primary cohorts

| Group | Exposure eligible | Follow-up | Follow-up events | Complete cases | Complete-case events |
|---|---:|---:|---:|---:|---:|
| Never | 2991 | 2832 | 136 | 2808 | 132 |
| Single | 136 | 128 | 46 | 127 | 45 |
| Recurrent | 58 | 54 | 22 | 54 | 22 |
| Frequent | 53 | 46 | 20 | 46 | 20 |

Model 1 uses 3060 participants/224 events; Models 2–4 use 3035/219. These intentional denominators are unchanged. Site is stratified and Cox ties use Efron. The supplied FEF percent-predicted values define groups (0, 1, 2, or 3–4 values below 65% predicted across AS01–AS04).

Table S8 explicitly uses smaller subsets: 0.70 ≤ landmark FEV1/FVC <0.78 includes 778 participants/204 events; <0.77 includes 589/195. At stored precision, ≤0.77 and <0.78 identify the same participants, and duplicate model fits are omitted. All three specifications within each restricted sample use the same participants. Table S9 retains the original 3035/219 complete cases and adds AS01–AS03 mean FEV1/FVC and mean FVC percent predicted; missing historical means cause a stop rather than silent participant deletion.

S8/S9 are post hoc conditional association analyses. Their HR attenuation does not quantify mediation or demonstrate incremental prediction. Time terms use landmark values multiplied by `log1p(t_years) - log(2)`, not time-updated measurements. Standard Schoenfeld tests are not applied to `tt()` models. BH adjustment for exposure contrasts is within each model (three contrasts), not across all post hoc analytical choices. S4 preserves its original pooled three-group specification and distinct tests.

## FEF variables and reference equation

Analyses use cohort-supplied FEF percent predicted. BEST/PRED reconstruction is a descriptive arithmetic check for Table S6 and does not replace exposure values. The FEF reference equation remains unconfirmed; no equation is inferred from a device name or substituted. See `docs/DATA_DICTIONARY.txt`.

## Data access and execution status

Participant data are restricted and must be obtained through the applicable KDCA/National Biobank process. This repository contains code and variable documentation only; it contains no participant records, IDs, fitted-model files, or input data. The script exports aggregate results only. Keep generated outputs out of public version control unless separately reviewed for release.

The investigator executed the integrated workflow locally on 22 October 2026 and supplied `Output_20261022_125116_FEF_Final.zip`. The reviewed outputs contain the intended primary cohort counts, matching primary model estimates, the existing supplementary results checked against archived references, and all 36 S8/S9 exposure contrasts matching the previously executed components. All 12 S8/S9 models were recorded as fitted with no warning messages. The 77 calculated CSV tables agree with their Excel worksheets; the workbook contains 78 sheets including INDEX. The output contains 32 PNG, 32 TIFF and 32 PDF figures; all PNG/TIFF files have 1200-dpi metadata.

Execution environment: Windows 11, R 4.6.1, survival 3.8-12, openxlsx 4.2.9 and zip 3.0.2. This release preparation preserves both supplied R scripts byte-for-byte and updates documentation only. No additional analysis run is required for this documentation finalization. The execution information is based on the investigator-supplied outputs; participant data were not accessed in the packaging environment.

Figure 1 retains consecutive labels for usable follow-up and the follow-up cohort (both n=3060), with events added in the latter. This is a presentational redundancy, not a second exclusion or a change in sample size. It is retained to preserve the reviewed plotting code. The scripts include runtime cohort checks for future reproducibility; these are not requests for another run by the depositing investigator.

## Citation and versioning

Original v1.0.0 record: https://doi.org/10.5281/zenodo.23383064

This package is version 1.1.0. Cite the version-specific DOI shown on the Zenodo record for this release. The original v1.0.0 record above is retained as a historical reference. Author and licence metadata are retained from the supplied code package.

The MIT licence applies to this code, not restricted KoGES data or third-party software.
