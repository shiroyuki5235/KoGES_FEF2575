# 1.0.0-rc2.2

- Match archived S4 contrast CI convention (z=1.96) in Modules 27/28.
- Print all S4 reproduction checks before stopping.
- Keep models, cohort, HR/p calculations and tolerance unchanged.

# 1.0.0-rc2.1

- Use the working-directory input when present; otherwise open a file chooser.
- Resolve missing package assets by selecting the extracted R/00_Final_Analysis.R.
- Write Output_YYYYMMDD_HHMMSS_FEF_Final directly under the initial working directory.
- Modules 01–32 are byte-identical to rc2; no analytical changes.

# 1.0.0-rc2

- Align with the current manuscript as explicitly requested. Restore pooled historical Models 5/A/B/C and BMI time-effect analyses for Table S4.
- Add same-participant guards and historical numerical reproduction gates.
- Preserve primary four-group definitions and approved figures.
- Static verification only; local R execution required.
