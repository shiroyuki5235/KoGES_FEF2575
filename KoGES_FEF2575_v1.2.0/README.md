# KoGES repeated low FEF landmark analysis

Version 1.2.0. Aligned with the main manuscript and Additional file dated 5 November 2026.

## Run

1. Extract KoGES_FEF2575_v1.2.0 and set it as the RStudio working directory.
2. Install survival, openxlsx and zip if absent; splines is bundled with R.
3. Open R/00_Final_Analysis.R and run Modules 00–38 sequentially in a fresh R session.
4. DATA_FILE defaults to ASAS01to10_Processed.txt.gz. Edit the explicit path for approved local KoGES data, or use the interactive selection fallback. Input encoding is CP949.
5. Outputs go to Output_<timestamp>_FEF_Final, with aggregate CSVs, an Excel workbook, PNG/TIFF at 1200 dpi, vector PDFs and a results ZIP. R/01_Capture_Environment.R optionally records the installed package environment.

## Final manuscript mapping

| Final item | Output family retained from v1.1.0 |
|---|---|
| Tables 1–2, Figures 1–2 | Table1_AS04, Table2A_Incidence, Main_Models1to4; Figures 1–2 |
| S1: selection and attendance | S1 / selection outputs |
| S2: confirmation and alternative cutoffs | Confirmation_HR; S2B_Pooled_sensitivity |
| S3: spline and PH diagnostics | FEF_HR_comparison; Main_PH; PH_tests |
| S4: interval-censored AFT | AFT_* (legacy S5) |
| S5: FEF checks and overlap | FEF_identity_*, classification and covariate diagnostics (legacy S6) |
| S6: pointwise KM | KM_2_4_6_years_CI (legacy S7) |
| S7: restricted landmark ratio | S8_* (legacy S8) |

See docs/Manuscript_code_map.csv for exact modules and filenames. Legacy S4_* and S9_* historical-adjustment outputs are retained for reproducibility as additional analyses not reported in the final manuscript. They must not be interpreted as final manuscript Tables S4 or S9. The full sequential workflow still calculates these additional analyses; no model blocks have been removed.

## Analysis definitions

Four exposure groups count supplied FEF25–75 <65% predicted values across AS01–AS04: 0, 1, 2, 3–4. AS04 is the landmark; the outcome is first dated observed pre-bronchodilator FEV1/FVC <0.70 at AS05–AS07. Follow-up uses examination-month differences divided by 12.

Incidence and Model 1 use 3060 participants/224 events. Models 2–4 use 3035 complete cases/219 events. Model 4 adjusts for age, sex, BMI, smoking status, pack-years and landmark FEV1/FVC, FVC %pred and FEF %pred, with site strata and Efron ties. Natural-spline adjustment replaces the ratio and FEF linear terms with ns(df=3, intercept=FALSE). Restricted samples have 778/204 (0.70–<0.78) and 589/195 (0.70–<0.77).

Final Table S2 identifies exploratory pooled contrasts separately. The First_65 pooled comparisons use unadjusted p values; alternative-cutoff and confirmation contrasts retain their original BH families. Supplied percent-predicted values are not replaced by reconstructed percentages. The source FEF reference equation remains unconfirmed.

For the spline 3–4-low group, the full-precision upper CI is 5.89450892660711: display 5.89 to two decimal places. Correct the corresponding main-text and Table S3 entries; do not change the model or round an intermediate value first.

## Version and execution

This release derives from the v1.1.0 folder in Zenodo DOI 10.5281/zenodo.23552507. Statistical calculations and output filenames are preserved; changes are comments, a descriptive run note and manuscript/version documentation. The approved investigator execution was 22 October 2026, Windows 11, R 4.6.1, survival 3.8-12, openxlsx 4.2.9 and zip 3.0.2. No new participant-level run was performed during v1.2.0 preparation.

Only the current package is distributed. Restricted participant data, original results, older package directories and manuscript files are not bundled. Obtain data through the KDCA/National Biobank of Korea approval process. MIT covers the code, not KoGES data.

Cite the new version-specific DOI returned when v1.2.0 is published. The previous DOI above identifies v1.1.0 and must not be represented as the v1.2.0 DOI.
