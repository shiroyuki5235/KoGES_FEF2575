#Module 00. Settings and dependencies ----
# Release candidate 1.0.0-rc2.2. Run top to bottom in a fresh R session.
# Set the working directory to this repository root. No source() driver is used.
options(stringsAsFactors=FALSE, scipen=999, contrasts=c("contr.treatment","contr.poly"), warn=2)
set.seed(20261013)
WORK_DIR <- normalizePath(getwd(),winslash="/",mustWork=TRUE)
PROJECT_DIR <- WORK_DIR
DATA_FILE <- file.path(WORK_DIR,"ASAS01to10_Processed.txt.gz")
OUTPUT_ROOT <- WORK_DIR
# 원자료가 지정 경로에 없으면 파일 선택. 원자료를 옮길 필요가 없습니다.
if(!file.exists(DATA_FILE)) {
 if(!interactive()) stop("DATA_FILE 경로를 지정하세요. 파일 선택창은 RStudio 대화형 실행에서 사용할 수 있습니다.")
 message("ASAS01to10_Processed.txt.gz 원자료를 선택하세요.")
 DATA_FILE <- tryCatch(file.choose(),error=function(e)stop("원자료 선택이 취소되었습니다. Module 00부터 다시 실행하세요.",call.=FALSE))
}
DATA_FILE <- normalizePath(DATA_FILE,winslash="/",mustWork=TRUE)
# 참조표와 원본 그림이 다른 폴더에 있으면 압축 해제한 패키지의 R 스크립트를 선택합니다.
if(!dir.exists(file.path(PROJECT_DIR,"reference_results")) || !dir.exists(file.path(PROJECT_DIR,"assets","original_figures"))) {
 if(!interactive()) stop("PROJECT_DIR을 reference_results와 assets가 있는 압축 해제 폴더로 지정하세요.")
 message("압축 해제한 코드 세트의 R/00_Final_Analysis.R 파일을 선택하세요.")
 project_script <- tryCatch(file.choose(),error=function(e)stop("코드 파일 선택이 취소되었습니다. Module 00부터 다시 실행하세요.",call.=FALSE))
 project_script <- normalizePath(project_script,winslash="/",mustWork=TRUE)
 if(basename(project_script)!="00_Final_Analysis.R" || basename(dirname(project_script))!="R")
  stop("압축 해제한 패키지의 R/00_Final_Analysis.R을 선택하세요.")
 PROJECT_DIR <- dirname(dirname(project_script))
}
stopifnot(dir.exists(file.path(PROJECT_DIR,"reference_results")),dir.exists(file.path(PROJECT_DIR,"assets","original_figures")))
cat("Input:",DATA_FILE,"\nPackage:",PROJECT_DIR,"\nOutput root:",OUTPUT_ROOT,"\n")
INPUT_ENCODING <- "CP949"
PRIMARY_CUTOFF <- 65; RATIO_SCALE <- 100
EXCLUDE_KNOWN_ASTHMA_MED <- TRUE; REQUIRE_ALL_ASTHMA_SCREENS <- TRUE
FIGURE_DPI <- 1200L
REFERENCE_DIR <- file.path(PROJECT_DIR,"reference_results")
required_packages <- c("survival","openxlsx","zip")
for(pkg in required_packages) if(!requireNamespace(pkg,quietly=TRUE)) stop("Install before running: ",pkg)
library(survival)
completion_output <- file.path(OUTPUT_ROOT,paste0("Output_",format(Sys.time(),"%Y%m%d_%H%M%S"),"_FEF_Final"))
if(dir.exists(completion_output)) stop("Output directory already exists.")
dir.create(completion_output,recursive=TRUE)
completion_tables <- file.path(completion_output,"Tables");dir.create(completion_tables)
completion_figures <- file.path(completion_output,"Figures");dir.create(completion_figures)
completion_status <- data.frame(module=character(),status=character(),message=character())
# Results below are calculated from local approved data; reference results are validation targets only.
#Module 01. 원자료 변수 매핑 ----------------------------------------------------
visit_map <- data.frame(
  visit = sprintf("AS%02d", 1:7),
  date_col = paste0(sprintf("AS%02d", 1:7), "_EDATE", 1:7),
  fef_col = c("AS01_SPFEFPP", "AS02_SPFEFPP", "AS03_SPFEFPP", paste0(sprintf("AS%02d", 4:7), "_SP4_3")),
  fev1_col = c("AS01_SPFEVPP", "AS02_SPFEVPP", "AS03_SPFEVPP", paste0(sprintf("AS%02d", 4:7), "_SP2_3")),
  fvc_col = c("AS01_SPFVCPP", "AS02_SPFVCPP", "AS03_SPFVCPP", paste0(sprintf("AS%02d", 4:7), "_SP1_3")),
  ratio_col = c("AS01_SPFEV_FVCB", "AS02_SPFEV_FVCB", "AS03_SPFEV_FVCB", paste0(sprintf("AS%02d", 4:7), "_SP3_2"))
)
fef_identity_map <- data.frame(visit=visit_map$visit,
 predicted_col=c(paste0(visit_map$visit[1:3],"_SPFEFP"),paste0(visit_map$visit[4:7],"_SP4_1")),
 measured_col=c(paste0(visit_map$visit[1:3],"_SPFEFB"),paste0(visit_map$visit[4:7],"_SP4_2")),
 supplied_pp_col=visit_map$fef_col)
asthma_dx_cols <- c("AS01_PDAS", "AS02_PDAS", "AS02_PDFAS", "AS03_PDFAS", "AS04_ASTH")
asthma_med_cols <- c("AS01_DRUGAS", "AS01_DRUGASCU", "AS01_ASTHDRG", "AS01_ASTHDRG1", "AS01_ASTHDRG2",
                     "AS02_DRUGAS", "AS02_DRUGASCU", "AS02_ASTHDRG", "AS03_DRUGAS", "AS03_DRUGASCU", "AS03_ASTHDRG",
                     "AS04_D65A", "AS04_D65D")
covariate_cols <- c("AS04_AGE", "AS04_SEX", "AS01_AREA", "AS04_BMI", "AS04_SMOKE", "AS04_PACKYR", "AS04_SP1_2", "AS04_SP2_2", "AS04_SP4_2")
header_con <- if (grepl("\\.gz$", DATA_FILE, ignore.case = TRUE)) gzfile(DATA_FILE, "rt", encoding = INPUT_ENCODING) else file(DATA_FILE, "rt", encoding = INPUT_ENCODING)
header_text <- readLines(header_con, n = 1L, warn = FALSE); close(header_con)
header_cols <- strsplit(sub("^\ufeff", "", header_text), "\t", fixed = TRUE)[[1]]
if (anyDuplicated(header_cols)) stop("원자료에 중복 열 이름이 있습니다.")
required_cols <- unique(c("DIST_ID", unlist(visit_map[1:4, -1]), visit_map$ratio_col[5:7], visit_map$date_col[5:7],
                         asthma_dx_cols[c(1, 4, 5)], covariate_cols))
if (!any(c("AS02_PDAS", "AS02_PDFAS") %in% header_cols)) stop("AS02 천식 진단력 열이 없습니다.")
missing_required_cols <- setdiff(required_cols, header_cols)
if (length(missing_required_cols)) stop("필수 열 없음: ", paste(missing_required_cols, collapse = ", "))
visit_optional_cols <- c(paste0(visit_map$visit,"_AGE"),paste0(visit_map$visit,"_HEIGHT"),paste0(visit_map$visit,"_SEX"))
selection_optional_cols <- c("AS01_AGE","AS01_SEX","AS01_BMI","AS01_SMOKE")
selected_cols <- intersect(unique(c(required_cols, asthma_dx_cols, asthma_med_cols, visit_optional_cols, selection_optional_cols, unlist(fef_identity_map[,-1]))), header_cols)
column_classes <- rep("NULL", length(header_cols)); column_classes[header_cols %in% selected_cols] <- "character"
input_con <- if (grepl("\\.gz$", DATA_FILE, ignore.case = TRUE)) gzfile(DATA_FILE, "rt", encoding = INPUT_ENCODING) else file(DATA_FILE, "rt", encoding = INPUT_ENCODING)
KoGES_raw_selected <- read.delim(input_con, header = TRUE, sep = "\t", quote = "", comment.char = "",
                               colClasses = column_classes, check.names = FALSE,
                               na.strings = c("", "NA", "NaN", "NULL", "."))
close(input_con)
KoGES_raw_selected$DIST_ID <- trimws(KoGES_raw_selected$DIST_ID)
cat("Loaded:", nrow(KoGES_raw_selected), "participants x", ncol(KoGES_raw_selected), "columns\n")
if (anyNA(KoGES_raw_selected$DIST_ID) || any(KoGES_raw_selected$DIST_ID == "")) stop("ID 결측이 있습니다.")
if (anyDuplicated(KoGES_raw_selected$DIST_ID)) stop("ID 중복이 있습니다. 임의 삭제하지 않습니다.")
KoGES_raw_selected <- KoGES_raw_selected[order(KoGES_raw_selected$DIST_ID), , drop = FALSE]
stopifnot(identical(KoGES_raw_selected$DIST_ID, sort(KoGES_raw_selected$DIST_ID)))
cat("Missing input cells:", sum(is.na(KoGES_raw_selected)), "\n")

#Module 02. 결측 정리와 검사일 전처리 -------------------------------------------
KoGES_clean <- KoGES_raw_selected
missing_numeric_codes <- c(66666, 77777, 88888, 99999, 666666, 777777, 888888, 999999,
                           6666666, 7777777, 8888888, 9999999)
numeric_cols <- setdiff(names(KoGES_clean), c("DIST_ID", visit_map$date_col))
for (column_name in numeric_cols) {
  raw_text <- trimws(KoGES_clean[[column_name]]); numeric_value <- suppressWarnings(as.numeric(raw_text))
  invalid_text <- !is.na(raw_text) & raw_text != "" & is.na(numeric_value)
  if (any(invalid_text)) stop("숫자 변환 불가: ", column_name)
  numeric_value[numeric_value %in% missing_numeric_codes | !is.finite(numeric_value)] <- NA_real_
  KoGES_clean[[column_name]] <- numeric_value
}
KoGES_date_month <- matrix(NA_real_, nrow(KoGES_clean), 7L, dimnames = list(NULL, visit_map$visit))
for (visit_index in 1:7) {
  date_text <- trimws(KoGES_clean[[visit_map$date_col[visit_index]]])
  date_text[date_text %in% as.character(missing_numeric_codes)] <- NA_character_
  valid_format <- !is.na(date_text) & grepl("^[0-9]{6}$", date_text)
  date_year <- suppressWarnings(as.integer(substr(date_text, 1, 4))); date_month <- suppressWarnings(as.integer(substr(date_text, 5, 6)))
  valid_date <- valid_format & date_year >= 1990 & date_year <= 2100 & date_month >= 1 & date_month <= 12
  valid_date[is.na(valid_date)] <- FALSE
  KoGES_date_month[valid_date, visit_index] <- date_year[valid_date] * 12 + date_month[valid_date] - 1
  if (any(!is.na(date_text) & !valid_date)) stop("YYYYMM 날짜 형식 오류: ", visit_map$visit[visit_index])
}
exposure_date_error <- rep(FALSE, nrow(KoGES_clean))
followup_date_error <- rep(FALSE, nrow(KoGES_clean))
for (visit_index in 1:3) {
  for (later_index in (visit_index + 1):4) {
    bad_order <- !is.na(KoGES_date_month[, visit_index]) & !is.na(KoGES_date_month[, later_index]) &
                 KoGES_date_month[, later_index] <= KoGES_date_month[, visit_index]
    exposure_date_error <- exposure_date_error | bad_order
  }
}
for (visit_index in 4:6) {
  for (later_index in (visit_index + 1):7) {
    bad_order <- !is.na(KoGES_date_month[, visit_index]) & !is.na(KoGES_date_month[, later_index]) &
                 KoGES_date_month[, later_index] <= KoGES_date_month[, visit_index]
    followup_date_error <- followup_date_error | bad_order
  }
}
KoGES_fef_exposure <- KoGES_fev1_exposure <- KoGES_fvc_exposure <- KoGES_ratio_exposure <- matrix(NA_real_, nrow(KoGES_clean), 4L)
for (visit_index in 1:7) {
  ratio_value <- KoGES_clean[[visit_map$ratio_col[visit_index]]] / RATIO_SCALE
  invalid_ratio <- !is.na(ratio_value) & (ratio_value <= 0 | ratio_value > 1)
  if (any(invalid_ratio)) stop("BEST FEV1/FVC 값/단위 오류: ", visit_map$visit[visit_index])
  if (RATIO_SCALE == 100 && sum(!is.na(ratio_value)) > 0 && median(ratio_value, na.rm = TRUE) < 0.1) stop("ratio 단위를 확인하세요.")
  KoGES_clean[[paste0(visit_map$visit[visit_index], "_ratio_observed")]] <- ratio_value
  if (visit_index <= 4) {
    KoGES_ratio_exposure[, visit_index] <- ratio_value
    KoGES_fef_exposure[, visit_index] <- KoGES_clean[[visit_map$fef_col[visit_index]]]
    KoGES_fev1_exposure[, visit_index] <- KoGES_clean[[visit_map$fev1_col[visit_index]]]
    KoGES_fvc_exposure[, visit_index] <- KoGES_clean[[visit_map$fvc_col[visit_index]]]
    for (metric_name in c("fef_col", "fev1_col", "fvc_col")) {
      metric_value <- KoGES_clean[[visit_map[[metric_name]][visit_index]]]
      if (any(!is.na(metric_value) & metric_value <= 0)) stop("%predicted <=0 값 확인: ", visit_map[[metric_name]][visit_index])
    }
  }
}

colnames(KoGES_fef_exposure) <- colnames(KoGES_fev1_exposure) <- colnames(KoGES_fvc_exposure) <- colnames(KoGES_ratio_exposure) <- visit_map$visit[1:4]

#Module 03. FEF 측정값/예측값/%predicted 연결 검증 ----
# 단위·예측식 이름은 확정하지 않습니다. 제공 %predicted로 기존 노출 정의를 유지합니다.
FEF_identity_summary <- data.frame()
FEF_identity_missing <- data.frame(visit=character(),missing_columns=character())
FEF_identity_bins <- data.frame(visit=character(),difference_bin=character(),n=integer())
for (fef_visit_index in 1:7) {
 fef_fields <- unlist(fef_identity_map[fef_visit_index,-1],use.names=FALSE)
 fef_absent <- setdiff(fef_fields,names(KoGES_clean))
 if(length(fef_absent)) {
  FEF_identity_missing <- rbind(FEF_identity_missing,data.frame(visit=fef_identity_map$visit[fef_visit_index],missing_columns=paste(fef_absent,collapse=";")))
  next
 }
 fef_pred <- KoGES_clean[[fef_fields[1]]]; fef_measured <- KoGES_clean[[fef_fields[2]]]; fef_supplied <- KoGES_clean[[fef_fields[3]]]
 fef_valid <- is.finite(fef_pred) & fef_pred>0 & is.finite(fef_measured) & fef_measured>0 & is.finite(fef_supplied) & fef_supplied>0
 fef_reconstructed <- rep(NA_real_,nrow(KoGES_clean))
 fef_reconstructed[fef_valid] <- 100*fef_measured[fef_valid]/fef_pred[fef_valid]
 fef_difference <- fef_reconstructed[fef_valid]-fef_supplied[fef_valid]
 fef_abs_difference <- abs(fef_difference)
 # 차이 단위는 percentage points; 0.5/1.0/2.0은 기술적 요약 기준입니다.
 FEF_identity_summary <- rbind(FEF_identity_summary,data.frame(visit=fef_identity_map$visit[fef_visit_index],
  predicted_candidate=fef_fields[1],measured=fef_fields[2],supplied_percent_predicted=fef_fields[3],n_total=nrow(KoGES_clean),
  predicted_missing=sum(is.na(fef_pred)),measured_missing=sum(is.na(fef_measured)),pp_missing=sum(is.na(fef_supplied)),
  nonpositive_any=sum((is.finite(fef_pred)&fef_pred<=0)|(is.finite(fef_measured)&fef_measured<=0)|(is.finite(fef_supplied)&fef_supplied<=0)),
  valid_triples=sum(fef_valid),median_signed_difference=if(length(fef_difference))median(fef_difference) else NA_real_,
  median_abs_difference=if(length(fef_difference))median(fef_abs_difference) else NA_real_,
  P95_abs_difference=if(length(fef_difference))unname(quantile(fef_abs_difference,.95)) else NA_real_,
  max_abs_difference=if(length(fef_difference))max(fef_abs_difference) else NA_real_,
  within_0_5_pp_pct=if(length(fef_difference))100*mean(fef_abs_difference<=.5) else NA_real_,
  within_1_pp_pct=if(length(fef_difference))100*mean(fef_abs_difference<=1) else NA_real_,
  within_2_pp_pct=if(length(fef_difference))100*mean(fef_abs_difference<=2) else NA_real_,
  cutoff65_discordant_n=sum((fef_reconstructed[fef_valid]<PRIMARY_CUTOFF)!=(fef_supplied[fef_valid]<PRIMARY_CUTOFF)),
  cutoff65_discordant_pct=if(sum(fef_valid))100*mean((fef_reconstructed[fef_valid]<PRIMARY_CUTOFF)!=(fef_supplied[fef_valid]<PRIMARY_CUTOFF)) else NA_real_))
 fef_bin <- table(cut(fef_abs_difference,breaks=c(-Inf,.5,1,2,5,Inf),labels=c("<=0.5","0.5-1","1-2","2-5",">5")))
 FEF_identity_bins <- rbind(FEF_identity_bins,data.frame(visit=fef_identity_map$visit[fef_visit_index],difference_bin=names(fef_bin),n=as.integer(fef_bin)))
}
write.csv(fef_identity_map,file.path(completion_tables,"FEF_identity_variable_map.csv"),row.names=FALSE)
write.csv(FEF_identity_summary,file.path(completion_tables,"FEF_identity_summary.csv"),row.names=FALSE)
write.csv(FEF_identity_missing,file.path(completion_tables,"FEF_identity_missing_columns.csv"),row.names=FALSE)
write.csv(FEF_identity_bins,file.path(completion_tables,"FEF_identity_difference_bins.csv"),row.names=FALSE)
completion_status <- rbind(completion_status,data.frame(module="FEF_identity",status=if(!nrow(FEF_identity_summary))"NO_TRIPLES" else if(any(FEF_identity_summary$valid_triples==0))"CHECK_NO_VALID_TRIPLES" else if(nrow(FEF_identity_missing))"PARTIAL_MISSING_COLUMNS" else "COMPLETED",message="Arithmetic agreement does not identify the reference equation; the supplied percent predicted remains the exposure."))
print(FEF_identity_summary)

#Module 04. 천식 진단력과 약물력 -------------------------------------------------
asthma_dx_present_cols <- intersect(asthma_dx_cols, names(KoGES_clean))
asthma_med_present_cols <- intersect(asthma_med_cols, names(KoGES_clean))
for (column_name in unique(c(asthma_dx_present_cols, asthma_med_present_cols))) {
  if (any(!is.na(KoGES_clean[[column_name]]) & !KoGES_clean[[column_name]] %in% c(1, 2))) stop("1/2 코딩 이외 값: ", column_name)
}
KoGES_asthma_dx <- as.matrix(KoGES_clean[, asthma_dx_present_cols, drop = FALSE])
asthma_diagnosis_yes <- rowSums(KoGES_asthma_dx == 2, na.rm = TRUE) > 0
as02_dx_cols <- intersect(c("AS02_PDAS", "AS02_PDFAS"), asthma_dx_present_cols)
as02_dx_known <- rowSums(!is.na(KoGES_clean[, as02_dx_cols, drop = FALSE])) > 0
asthma_screens_complete <- !is.na(KoGES_clean$AS01_PDAS) & as02_dx_known &
                           !is.na(KoGES_clean$AS03_PDFAS) & !is.na(KoGES_clean$AS04_ASTH)
asthma_medication_yes <- rep(FALSE, nrow(KoGES_clean))
if (length(asthma_med_present_cols)) {
  KoGES_asthma_med <- as.matrix(KoGES_clean[, asthma_med_present_cols, drop = FALSE])
  asthma_medication_yes <- rowSums(KoGES_asthma_med == 2, na.rm = TRUE) > 0
}

#Module 05. 대상자 선정 ---------------------------------------------------------
exposure_fef_complete <- rowSums(!is.na(KoGES_fef_exposure)) == 4
exposure_spirometry_complete <- rowSums(!is.na(KoGES_ratio_exposure) & !is.na(KoGES_fev1_exposure) & !is.na(KoGES_fvc_exposure)) == 4
exposure_obstruction <- rowSums(KoGES_ratio_exposure < 0.70, na.rm = TRUE) > 0
exposure_low_fev1 <- rowSums(KoGES_fev1_exposure < 80, na.rm = TRUE) > 0
exposure_low_fvc <- rowSums(KoGES_fvc_exposure < 80, na.rm = TRUE) > 0
selection_conditions <- list(
  FEF_AS01_AS04_complete = exposure_fef_complete,
  No_obstruction_AS01_AS04 = !exposure_obstruction,
  No_low_FEV1_AS01_AS04 = !exposure_low_fev1,
  No_low_FVC_AS01_AS04 = !exposure_low_fvc,
  Normal_status_fully_observed = exposure_spirometry_complete,
  No_physician_diagnosed_asthma = !asthma_diagnosis_yes,
  Asthma_screens_observed = if (REQUIRE_ALL_ASTHMA_SCREENS) asthma_screens_complete else rep(TRUE, nrow(KoGES_clean)),
  No_documented_asthma_medication = if (EXCLUDE_KNOWN_ASTHMA_MED) !asthma_medication_yes else rep(TRUE, nrow(KoGES_clean)),
  AS04_time_zero_observed = !is.na(KoGES_date_month[, 4]),
  Exposure_date_order_valid = !exposure_date_error
)
cohort_keep <- rep(TRUE, nrow(KoGES_clean))
selection_flow <- data.frame(step = "All_unique_IDs", before_n = nrow(KoGES_clean), excluded_n = 0L, remaining_n = nrow(KoGES_clean))
for (step_name in names(selection_conditions)) {
  before_n <- sum(cohort_keep); cohort_keep <- cohort_keep & selection_conditions[[step_name]]
  selection_flow <- rbind(selection_flow, data.frame(step = step_name, before_n = before_n,
                                      excluded_n = before_n - sum(cohort_keep), remaining_n = sum(cohort_keep)))
}
KoGES_exposure_cohort <- KoGES_clean[cohort_keep, , drop = FALSE]
KoGES_exposure_dates <- KoGES_date_month[cohort_keep, , drop = FALSE]
KoGES_cohort_fef <- KoGES_fef_exposure[cohort_keep, , drop = FALSE]
cat("Exposure cohort:", nrow(KoGES_exposure_cohort), "\n")
if (!nrow(KoGES_exposure_cohort)) stop("선정 기준을 충족한 대상자가 없습니다.")
stopifnot(!anyDuplicated(KoGES_exposure_cohort$DIST_ID), !anyNA(KoGES_cohort_fef))

#Module 06. cutoff 분포와 반복 저하 그룹 -----------------------------------------
KoGES_cohort_low <- KoGES_cohort_fef < PRIMARY_CUTOFF
KoGES_exposure_cohort$low_count <- rowSums(KoGES_cohort_low)
KoGES_exposure_cohort$fef_group <- factor(pmin(KoGES_exposure_cohort$low_count, 3L), levels = 0:3,
                                       labels = c("Never low", "Single low", "Recurrent low", "Frequent/Persistent low"))
#Module 07. AS05-AS07 첫 기류폐쇄와 censoring ------------------------------------
KoGES_followup_ratio <- as.matrix(KoGES_exposure_cohort[, paste0(visit_map$visit[5:7], "_ratio_observed"), drop = FALSE])
KoGES_followup_dates <- KoGES_exposure_dates[, 5:7, drop = FALSE]
KoGES_time_zero_month <- KoGES_exposure_dates[, 4]
followup_observed <- !is.na(KoGES_followup_ratio) & !is.na(KoGES_followup_dates)
followup_positive_undated <- rowSums(!is.na(KoGES_followup_ratio) & KoGES_followup_ratio < 0.70 & is.na(KoGES_followup_dates)) > 0
followup_date_error_cohort <- followup_date_error[cohort_keep]
followup_valid_n <- rowSums(followup_observed)
KoGES_exposure_cohort$event <- 0L
KoGES_exposure_cohort$event_visit <- NA_character_
KoGES_exposure_cohort$end_month <- NA_real_
KoGES_exposure_cohort$last_normal_month <- KoGES_time_zero_month
for (visit_index in 1:3) {
  visit_observed <- followup_observed[, visit_index]
  not_yet_event <- KoGES_exposure_cohort$event == 0L
  update_endpoint <- visit_observed & not_yet_event
  KoGES_exposure_cohort$end_month[update_endpoint] <- KoGES_followup_dates[update_endpoint, visit_index]
  visit_event <- visit_observed & not_yet_event & !is.na(KoGES_followup_ratio[, visit_index]) & KoGES_followup_ratio[, visit_index] < 0.70
  KoGES_exposure_cohort$event[visit_event] <- 1L
  KoGES_exposure_cohort$event_visit[visit_event] <- visit_map$visit[visit_index + 4L]
  normal_visit <- visit_observed & not_yet_event & !is.na(KoGES_followup_ratio[, visit_index]) & KoGES_followup_ratio[, visit_index] >= 0.70
  KoGES_exposure_cohort$last_normal_month[normal_visit] <- KoGES_followup_dates[normal_visit, visit_index]
}
KoGES_exposure_cohort$followup_years <- (KoGES_exposure_cohort$end_month - KoGES_time_zero_month) / 12
KoGES_exposure_cohort$event_interval_years <- ifelse(KoGES_exposure_cohort$event == 1L,
                              (KoGES_exposure_cohort$end_month - KoGES_exposure_cohort$last_normal_month) / 12, NA_real_)
followup_usable <- followup_valid_n > 0 & !followup_positive_undated & !followup_date_error_cohort &
                   !is.na(KoGES_exposure_cohort$followup_years) & KoGES_exposure_cohort$followup_years > 0
KoGES_exposure_cohort$followup_usable <- followup_usable
KoGES_analysis <- KoGES_exposure_cohort[followup_usable, , drop = FALSE]
selection_flow <- rbind(selection_flow, data.frame(step = "Usable_followup_AS05_AS07", before_n = nrow(KoGES_exposure_cohort),
                           excluded_n = sum(!followup_usable), remaining_n = nrow(KoGES_analysis)))
stopifnot(!anyDuplicated(KoGES_analysis$DIST_ID), all(KoGES_analysis$followup_years > 0), all(KoGES_analysis$event %in% 0:1))
cat("Follow-up cohort:", nrow(KoGES_analysis), "Events:", sum(KoGES_analysis$event), "\n")
FEF_incidence <- data.frame()
for (group_name in levels(KoGES_exposure_cohort$fef_group)) {
  exposure_in_group <- KoGES_exposure_cohort$fef_group == group_name
  analysis_in_group <- KoGES_analysis$fef_group == group_name
  group_n <- sum(analysis_in_group); group_events <- sum(KoGES_analysis$event[analysis_in_group])
  person_years <- sum(KoGES_analysis$followup_years[analysis_in_group])
  FEF_incidence <- rbind(FEF_incidence, data.frame(fef_group = group_name, exposure_n = sum(exposure_in_group),
             followup_n = group_n, no_usable_followup_n = sum(exposure_in_group) - group_n, event_n = group_events,
             event_pct = if (group_n) 100 * group_events / group_n else NA_real_,
             person_years = person_years, events_per_1000_PY = if (person_years > 0) 1000 * group_events / person_years else NA_real_))
}

if (!nrow(KoGES_analysis)) stop("유효 추적 대상자가 없습니다.")

#Module 08. AS04 공변량 ----
KoGES_clean$age_AS04 <- KoGES_clean$AS04_AGE
KoGES_clean$sex <- factor(KoGES_clean$AS04_SEX, levels = c(1, 2), labels = c("Male", "Female"))
KoGES_clean$site <- factor(KoGES_clean$AS01_AREA, levels = c(1, 2), labels = c("Ansung", "Ansan"))
KoGES_clean$bmi_AS04 <- KoGES_clean$AS04_BMI
KoGES_clean$smoking_AS04 <- factor(KoGES_clean$AS04_SMOKE, levels = 1:3, labels = c("Never", "Former", "Current"))
KoGES_clean$packyears_AS04 <- KoGES_clean$AS04_PACKYR
never_packyears_missing <- !is.na(KoGES_clean$smoking_AS04) & KoGES_clean$smoking_AS04 == "Never" & is.na(KoGES_clean$packyears_AS04)
KoGES_clean$packyears_AS04[never_packyears_missing] <- 0
never_packyears_conflict <- !is.na(KoGES_clean$smoking_AS04) & KoGES_clean$smoking_AS04 == "Never" &
                           !is.na(KoGES_clean$packyears_AS04) & KoGES_clean$packyears_AS04 > 0
KoGES_clean$packyears_AS04[never_packyears_conflict] <- NA_real_
KoGES_clean$packyears_AS04[!is.na(KoGES_clean$packyears_AS04) & KoGES_clean$packyears_AS04 < 0] <- NA_real_
KoGES_clean$age_AS04[!is.na(KoGES_clean$age_AS04) & (KoGES_clean$age_AS04 <= 0 | KoGES_clean$age_AS04 > 120)] <- NA_real_
KoGES_clean$bmi_AS04[!is.na(KoGES_clean$bmi_AS04) & KoGES_clean$bmi_AS04 <= 0] <- NA_real_
KoGES_clean$ratio_AS04 <- KoGES_clean$AS04_ratio_observed
KoGES_clean$fvc_pp_AS04 <- KoGES_clean$AS04_SP1_3
KoGES_clean$fef_pp_AS04 <- KoGES_clean$AS04_SP4_3

KoGES_clean$low_count <- rowSums(KoGES_clean[,visit_map$fef_col[1:4],drop=FALSE] < PRIMARY_CUTOFF,na.rm=FALSE)
completion_covariate_names <- c("age_AS04","sex","site","bmi_AS04","smoking_AS04","packyears_AS04","ratio_AS04","fvc_pp_AS04","fef_pp_AS04","low_count")
completion_match <- match(KoGES_exposure_cohort$DIST_ID,KoGES_clean$DIST_ID)
stopifnot(!anyNA(completion_match))
KoGES_exposure_cohort[,completion_covariate_names] <- KoGES_clean[completion_match,completion_covariate_names]
KoGES_analysis <- KoGES_exposure_cohort[followup_usable,,drop=FALSE]

#Module 09. 기존 표본과 사건 구간 확인 ----
completion_required <- c("DIST_ID","low_count","followup_years","event","age_AS04","sex","site","bmi_AS04","smoking_AS04","packyears_AS04","ratio_AS04","fvc_pp_AS04","fef_pp_AS04")
completion_followup <- KoGES_analysis[order(KoGES_analysis$DIST_ID),,drop=FALSE]
stopifnot(nrow(KoGES_clean)==10030L,nrow(KoGES_exposure_cohort)==3238L,nrow(completion_followup)==3060L,
 sum(completion_followup$event)==224L,!anyNA(completion_followup$DIST_ID),!anyDuplicated(completion_followup$DIST_ID),
 all(completion_followup$low_count %in% 0:4),!is.unsorted(completion_followup$DIST_ID))
completion_followup$fef_group4 <- factor(pmin(completion_followup$low_count,3L),levels=0:3,labels=c("Never","Single","Recurrent","Frequent"))
stopifnot(identical(as.integer(table(completion_followup$fef_group4)),c(2832L,128L,54L,46L)))
print(colSums(is.na(completion_followup[,completion_required])))
completion_complete <- completion_followup[complete.cases(completion_followup[,completion_required]),,drop=FALSE]
rownames(completion_complete) <- NULL
stopifnot(nrow(completion_complete)==3035L,sum(completion_complete$event)==219L)
completion_numeric <- completion_required[!completion_required %in% c("DIST_ID","sex","site","smoking_AS04")]
stopifnot(all(vapply(completion_complete[,completion_numeric],is.numeric,logical(1))),
 all(is.finite(as.matrix(completion_complete[,completion_numeric]))),all(completion_complete$followup_years>0))
completion_index <- match(completion_complete$DIST_ID,KoGES_exposure_cohort$DIST_ID)
stopifnot(!anyNA(completion_index),identical(completion_complete$DIST_ID,KoGES_exposure_cohort$DIST_ID[completion_index]))
completion_dates <- KoGES_exposure_dates[completion_index,,drop=FALSE]
completion_ratio <- as.matrix(completion_complete[,paste0("AS0",5:7,"_ratio_observed")])
completion_time <- (completion_dates[,5:7,drop=FALSE]-completion_dates[,4])/12
completion_interval <- completion_complete
completion_interval$left_year <- (completion_interval$last_normal_month-completion_dates[,4])/12
completion_interval$left_year[completion_interval$event==0L] <- completion_interval$followup_years[completion_interval$event==0L]
completion_interval$right_year <- ifelse(completion_interval$event==1L,completion_interval$followup_years,Inf)
stopifnot(!anyNA(completion_interval$left_year),all(completion_interval$left_year>=0),
 all(completion_interval$right_year>completion_interval$left_year),
 max(abs(completion_interval$left_year[completion_interval$event==1L] -
  (completion_interval$followup_years-completion_interval$event_interval_years)[completion_interval$event==1L]))<1e-8)
completion_cohorts <- data.frame(cohort=c("Original","Exposure","Followup","Complete"),n=c(nrow(KoGES_clean),nrow(KoGES_exposure_cohort),nrow(completion_followup),nrow(completion_complete)),events=c(NA,NA,sum(completion_followup$event),sum(completion_complete$event)))
write.csv(completion_cohorts,file.path(completion_tables,"Cohort_counts.csv"),row.names=FALSE)
write.csv(selection_flow,file.path(completion_tables,"Selection_flow.csv"),row.names=FALSE)
write.csv(visit_map,file.path(completion_tables,"Source_variable_mapping.csv"),row.names=FALSE)
cat("Exposure 3238; follow-up 3060/224; complete 3035/219 confirmed\n")

#Module 10. Immutable cohort checks ----
stopifnot(identical(as.integer(table(completion_complete$fef_group4)),c(2808L,127L,54L,46L)),
 identical(as.integer(tapply(completion_followup$event,completion_followup$fef_group4,sum)),c(136L,46L,22L,20L)),
 identical(as.integer(tapply(completion_complete$event,completion_complete$fef_group4,sum)),c(132L,45L,22L,20L)))
exposure_groups <- factor(pmin(KoGES_exposure_cohort$low_count,3L),levels=0:3,labels=levels(completion_complete$fef_group4))
stopifnot(identical(as.integer(table(exposure_groups)),c(2991L,136L,58L,53L)))
fixed_ids <- completion_complete$DIST_ID;fixed_groups <- completion_complete$fef_group4
fixed_followup_ids <- completion_followup$DIST_ID;fixed_followup_groups <- completion_followup$fef_group4
denominators <- data.frame(group=levels(fixed_groups),exposure_n=as.integer(table(exposure_groups)),
 followup_n=as.integer(table(fixed_followup_groups)),followup_events=as.integer(tapply(completion_followup$event,fixed_followup_groups,sum)),
 complete_n=as.integer(table(fixed_groups)),complete_events=as.integer(tapply(completion_complete$event,fixed_groups,sum)))
denominators$no_followup_n <- denominators$exposure_n-denominators$followup_n
write.csv(denominators,file.path(completion_tables,"S1A_Denominators.csv"),row.names=FALSE)
#Module 11. Model 4 재현과 진단 ----
completion_formulas <- list(
 M1=Surv(followup_years,event)~fef_group4+age_AS04+sex+strata(site),
 M2=Surv(followup_years,event)~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+strata(site),
 M3=Surv(followup_years,event)~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+ratio_AS04+fvc_pp_AS04+strata(site),
 M4=Surv(followup_years,event)~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+ratio_AS04+fvc_pp_AS04+fef_pp_AS04+strata(site))
completion_fits <- list(); completion_hr <- completion_ph <- completion_fit_table <- data.frame()
for (completion_model in names(completion_formulas)) {
 completion_data <- if(completion_model=="M1") completion_followup else completion_complete
 completion_warnings <- character()
 completion_fit <- tryCatch(withCallingHandlers(
  survival::coxph(completion_formulas[[completion_model]],data=completion_data,ties="efron",x=TRUE,y=TRUE,model=TRUE,na.action=na.fail,singular.ok=FALSE),
  warning=function(w) {completion_warnings <<- c(completion_warnings,conditionMessage(w)); invokeRestart("muffleWarning")}),error=function(e)e)
 if (inherits(completion_fit,"error")) {
  completion_status <- rbind(completion_status,data.frame(module=completion_model,status="FAILED",message=conditionMessage(completion_fit)))
  stop(conditionMessage(completion_fit))
  next
 }
 stopifnot(all(is.finite(coef(completion_fit))),all(is.finite(vcov(completion_fit))))
 completion_fits[[completion_model]] <- completion_fit
 completion_s <- summary(completion_fit); completion_i <- grep("^fef_group4",rownames(completion_s$coefficients))
 completion_rows <- data.frame(model=completion_model,term=rownames(completion_s$coefficients)[completion_i],n=completion_fit$n,events=completion_fit$nevent,
  HR=completion_s$conf.int[completion_i,"exp(coef)"],CI_low=completion_s$conf.int[completion_i,"lower .95"],CI_high=completion_s$conf.int[completion_i,"upper .95"],p=completion_s$coefficients[completion_i,"Pr(>|z|)"])
 completion_rows$BH_three <- p.adjust(completion_rows$p,"BH"); completion_hr <- rbind(completion_hr,completion_rows)
 completion_z <- tryCatch(survival::cox.zph(completion_fit,transform="km",terms=TRUE,global=TRUE),error=function(e)e)
 if (!inherits(completion_z,"error")) completion_ph <- rbind(completion_ph,data.frame(model=completion_model,term=rownames(completion_z$table),completion_z$table,row.names=NULL))
 if (inherits(completion_z,"error")) completion_warnings <- c(completion_warnings,paste("PH:",conditionMessage(completion_z)))
 completion_fit_table <- rbind(completion_fit_table,data.frame(model=completion_model,n=completion_fit$n,events=completion_fit$nevent,parameters=length(coef(completion_fit)),logLik=as.numeric(logLik(completion_fit)),AIC=AIC(completion_fit)))
 completion_status <- rbind(completion_status,data.frame(module=completion_model,status=if(length(completion_warnings))"CHECK_WARNINGS" else "FITTED",message=paste(unique(completion_warnings),collapse=" | ")))
}
completion_reference <- c(1.334661981,2.229675438,2.264021996)
stopifnot(max(abs(completion_hr$HR[completion_hr$model=="M4"]-completion_reference))<1e-4)
write.csv(completion_hr,file.path(completion_tables,"Main_Models1to4.csv"),row.names=FALSE)
write.csv(completion_ph,file.path(completion_tables,"Main_PH.csv"),row.names=FALSE)
write.csv(completion_fit_table,file.path(completion_tables,"Main_fit.csv"),row.names=FALSE)

#Module 12. 공변량 분포의 겹침과 공선성 ----
completion_distribution <- completion_overlap <- completion_correlation <- data.frame()
completion_distribution_vars <- c("ratio_AS04","fvc_pp_AS04","fef_pp_AS04")
for (completion_var in completion_distribution_vars) {
 for (completion_group in levels(completion_complete$fef_group4)) {
  completion_values <- completion_complete[[completion_var]][completion_complete$fef_group4==completion_group]
  completion_q <- quantile(completion_values,c(0,.025,.25,.5,.75,.975,1),names=FALSE)
  completion_distribution <- rbind(completion_distribution,data.frame(variable=completion_var,group=completion_group,n=length(completion_values),mean=mean(completion_values),SD=sd(completion_values),min=completion_q[1],P025=completion_q[2],Q1=completion_q[3],median=completion_q[4],Q3=completion_q[5],P975=completion_q[6],max=completion_q[7]))
  for (completion_reference_group in setdiff(levels(completion_complete$fef_group4),completion_group)) {
   completion_ref_values <- completion_complete[[completion_var]][completion_complete$fef_group4==completion_reference_group]
   completion_bounds <- quantile(completion_ref_values,c(.025,.975),names=FALSE)
   completion_overlap <- rbind(completion_overlap,data.frame(variable=completion_var,group=completion_group,reference_group=completion_reference_group,n=length(completion_values),reference_P025=completion_bounds[1],reference_P975=completion_bounds[2],inside_reference_central95_pct=100*mean(completion_values>=completion_bounds[1] & completion_values<=completion_bounds[2])))
  }
 }
}
completion_cor <- cor(completion_complete[,completion_distribution_vars],method="spearman")
write.csv(completion_distribution,file.path(completion_tables,"Covariate_distribution.csv"),row.names=FALSE)
write.csv(completion_overlap,file.path(completion_tables,"Pairwise_covariate_support.csv"),row.names=FALSE)
write.csv(completion_cor,file.path(completion_tables,"Covariate_Spearman.csv"))
completion_design <- data.frame()
for (completion_model in names(completion_fits)) {
 completion_x <- completion_fits[[completion_model]]$x
 completion_x <- completion_x[,apply(completion_x,2,sd)>0,drop=FALSE]
 completion_rx <- cor(completion_x); completion_rank <- qr(completion_x)$rank
 completion_vif <- tryCatch(diag(solve(completion_rx)),error=function(e)rep(NA_real_,ncol(completion_x)))
 completion_design <- rbind(completion_design,data.frame(model=completion_model,column=colnames(completion_x),column_VIF=completion_vif,rank=completion_rank,columns=ncol(completion_x)))
}
write.csv(completion_design,file.path(completion_tables,"Design_column_VIF.csv"),row.names=FALSE)

#Module 13. 두 단계의 대상자 선택과 방문별 FEF 분포 ----
completion_selection <- data.frame()
completion_selection_sets <- list(Four_FEF_visits=KoGES_clean,Usable_followup=KoGES_exposure_cohort)
for (completion_stage in names(completion_selection_sets)) {
 completion_data <- completion_selection_sets[[completion_stage]]
 completion_keep <- if(completion_stage=="Four_FEF_visits") exposure_fef_complete else completion_data$followup_usable
 completion_vars <- if(completion_stage=="Four_FEF_visits") intersect(c("AS01_AGE","AS01_BMI","AS01_SEX","AS01_SMOKE",visit_map$fef_col[1],visit_map$fev1_col[1],visit_map$fvc_col[1],"AS01_ratio_observed"),names(completion_data)) else c("age_AS04","sex","site","bmi_AS04","smoking_AS04","packyears_AS04","ratio_AS04","fvc_pp_AS04","fef_pp_AS04")
 for (completion_var in completion_vars) {
  completion_x <- completion_data[[completion_var]]
  completion_cat <- is.factor(completion_x) || completion_var %in% c("AS01_SEX","AS01_SMOKE")
  completion_levels <- if(completion_cat) sort(unique(as.character(completion_x[!is.na(completion_x)]))) else "Continuous"
  for (completion_level in completion_levels) {
   completion_y <- if(completion_cat) as.numeric(as.character(completion_x)==completion_level) else completion_x
   completion_a <- completion_y[completion_keep]; completion_b <- completion_y[!completion_keep]
   completion_ma <- mean(completion_a,na.rm=TRUE); completion_mb <- mean(completion_b,na.rm=TRUE)
   completion_den <- if(completion_cat) sqrt((completion_ma*(1-completion_ma)+completion_mb*(1-completion_mb))/2) else sqrt((var(completion_a,na.rm=TRUE)+var(completion_b,na.rm=TRUE))/2)
   completion_selection <- rbind(completion_selection,data.frame(stage=completion_stage,variable=completion_var,level=completion_level,included_n=length(completion_a),excluded_n=length(completion_b),included_missing=sum(is.na(completion_a)),excluded_missing=sum(is.na(completion_b)),included_mean_or_fraction=completion_ma,excluded_mean_or_fraction=completion_mb,SMD=if(is.finite(completion_den)&&completion_den>0)(completion_ma-completion_mb)/completion_den else NA_real_))
  }
 }
}
write.csv(completion_selection,file.path(completion_tables,"Selection_two_stages.csv"),row.names=FALSE)
completion_visit_summary <- data.frame()
for(completion_visit in 1:4) for(completion_set in c("All_available","Four_complete_visits","Exposure_eligible")) {
 completion_values <- KoGES_clean[[visit_map$fef_col[completion_visit]]]
 completion_sel <- switch(completion_set,All_available=rep(TRUE,nrow(KoGES_clean)),Four_complete_visits=exposure_fef_complete,Exposure_eligible=cohort_keep)
 completion_values <- completion_values[completion_sel]; completion_good <- completion_values[is.finite(completion_values)]
 completion_visit_summary <- rbind(completion_visit_summary,data.frame(visit=visit_map$visit[completion_visit],variable=visit_map$fef_col[completion_visit],cohort=completion_set,n=length(completion_values),observed=length(completion_good),missing=sum(is.na(completion_values)),median=median(completion_good),Q1=unname(quantile(completion_good,.25)),Q3=unname(quantile(completion_good,.75)),low65_pct=100*mean(completion_good<65)))
}
write.csv(completion_visit_summary,file.path(completion_tables,"FEF_visit_distribution.csv"),row.names=FALSE)

#Module 14. 구간 검열 AFT 분포 민감도 ----
# 양의 시간 분포에서는 (0,R]가 좌측 검열과 같은 확률을 갖습니다.
# 실제 구간 left_year는 보존하고 적합용 lower_fit만 NA로 표현합니다. epsilon은 사용하지 않습니다.
completion_interval$lower_fit <- completion_interval$left_year
completion_zero_lower <- completion_interval$event==1L & completion_interval$left_year==0
completion_interval$lower_fit[completion_zero_lower] <- NA_real_
completion_response <- with(completion_interval,Surv(lower_fit,right_year,type="interval2"))
stopifnot(sum(completion_response[,"status"]==2)==sum(completion_zero_lower),
 sum(completion_response[,"status"]==0)==sum(completion_interval$event==0),
 sum(completion_response[,"status"]==3)==sum(completion_interval$event==1 & !completion_zero_lower),
 !anyNA(completion_response))
write.csv(data.frame(censoring=c("left_at_AS04","interval_positive_lower","right"),
 n=c(sum(completion_zero_lower),sum(completion_interval$event==1 & !completion_zero_lower),sum(completion_interval$event==0))),
 file.path(completion_tables,"AFT_censoring_encoding.csv"),row.names=FALSE)
completion_aft_formula <- Surv(lower_fit,right_year,type="interval2")~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+ratio_AS04+fvc_pp_AS04+fef_pp_AS04+site+strata(site)
completion_aft_results <- completion_aft_fit <- completion_interval_summary <- data.frame()
for (completion_dist in c("weibull","lognormal","loglogistic")) {
 completion_warnings <- character()
 completion_fit <- tryCatch(withCallingHandlers(survival::survreg(completion_aft_formula,data=completion_interval,dist=completion_dist,na.action=na.fail,control=survreg.control(maxiter=100)),warning=function(w){completion_warnings <<- c(completion_warnings,conditionMessage(w));invokeRestart("muffleWarning")}),error=function(e)e)
 if (inherits(completion_fit,"error")) {
  completion_status <- rbind(completion_status,data.frame(module=paste0("AFT_",completion_dist),status="FAILED",message=conditionMessage(completion_fit))); next
 }
 if(any(!is.finite(coef(completion_fit))) || any(!is.finite(vcov(completion_fit))) || any(!is.finite(completion_fit$scale)) || any(completion_fit$scale<=0) || !is.finite(as.numeric(logLik(completion_fit))) || any(diag(vcov(completion_fit))<=0) || (!is.null(completion_fit$fail) && !identical(completion_fit$fail,FALSE) && !identical(completion_fit$fail,0L) && !identical(completion_fit$fail,0))) {
  completion_status <- rbind(completion_status,data.frame(module=paste0("AFT_",completion_dist),status="FAILED",message="Invalid coefficients, covariance, scale, likelihood, or fit failure flag")); next
 }
 completion_s <- summary(completion_fit)$table; completion_i <- grep("^fef_group4",rownames(completion_s))
 completion_rows <- data.frame(distribution=completion_dist,term=rownames(completion_s)[completion_i],n=nrow(completion_interval),events=sum(completion_interval$event),TR=exp(completion_s[completion_i,"Value"]),CI_low=exp(completion_s[completion_i,"Value"]-qnorm(.975)*completion_s[completion_i,"Std. Error"]),CI_high=exp(completion_s[completion_i,"Value"]+qnorm(.975)*completion_s[completion_i,"Std. Error"]),p=completion_s[completion_i,"p"])
 completion_rows$fit_status <- if(length(completion_warnings)) "CHECK_WARNINGS" else "FITTED"
 completion_rows$BH_three <- p.adjust(completion_rows$p,"BH");completion_aft_results <- rbind(completion_aft_results,completion_rows)
 completion_aft_fit <- rbind(completion_aft_fit,data.frame(distribution=completion_dist,n=nrow(completion_interval),events=sum(completion_interval$event),logLik=as.numeric(logLik(completion_fit)),parameters=attr(logLik(completion_fit),"df"),AIC=AIC(completion_fit),fit_status=if(length(completion_warnings)) "CHECK_WARNINGS" else "FITTED",scale=paste(signif(completion_fit$scale,6),collapse=";")))
 completion_status <- rbind(completion_status,data.frame(module=paste0("AFT_",completion_dist),status=if(length(completion_warnings))"CHECK_WARNINGS" else "FITTED",message=paste(unique(completion_warnings),collapse=" | ")))
}
if(nrow(completion_aft_fit)) {
 completion_aft_fit$delta_AIC_within_AFT <- NA_real_
 completion_ok <- completion_aft_fit$fit_status=="FITTED"
 if(any(completion_ok)) completion_aft_fit$delta_AIC_within_AFT[completion_ok] <- completion_aft_fit$AIC[completion_ok]-min(completion_aft_fit$AIC[completion_ok])
}
for (completion_group in levels(completion_interval$fef_group4)) {
 completion_data <- completion_interval[completion_interval$fef_group4==completion_group,,drop=FALSE]
 completion_width <- (completion_data$right_year-completion_data$left_year)[completion_data$event==1L]
 completion_interval_summary <- rbind(completion_interval_summary,data.frame(group=completion_group,n=nrow(completion_data),events=sum(completion_data$event),left_at_AS04=sum(completion_data$event==1L & completion_data$left_year==0),interval_median=median(completion_width),interval_Q1=unname(quantile(completion_width,.25)),interval_Q3=unname(quantile(completion_width,.75)),interval_max=max(completion_width)))
}
write.csv(completion_aft_results,file.path(completion_tables,"AFT_distribution_TR.csv"),row.names=FALSE)
write.csv(completion_aft_fit,file.path(completion_tables,"AFT_distribution_fit.csv"),row.names=FALSE)
write.csv(completion_interval_summary,file.path(completion_tables,"Event_interval_summary.csv"),row.names=FALSE)

#Module 15. 연속 유효 검사와 연속 정규 방문의 확인형 사건 ----
completion_confirmation <- completion_pair_summary <- completion_confirmation_hr <- completion_confirmation_ph <- completion_confirmation_legacy <- data.frame()
completion_patterns <- data.frame()
completion_pattern <- rep("",nrow(completion_complete))
for (completion_j in 1:3) {
 completion_valid <- is.finite(completion_ratio[,completion_j]) & is.finite(completion_time[,completion_j])
 completion_pattern <- paste0(completion_pattern,ifelse(!completion_valid,"M",ifelse(completion_ratio[,completion_j]<.70,"P","N")))
}
completion_patterns <- as.data.frame(table(group=completion_complete$fef_group4,pattern=completion_pattern),stringsAsFactors=FALSE)
names(completion_patterns)[3] <- "n"
for (completion_definition in c("Consecutive_observed","Consecutive_scheduled")) {
 completion_confirmed <- completion_complete
 completion_confirmed$confirmed_event <- 0L;completion_confirmed$confirmed_years <- NA_real_
 completion_confirmed$pair_gap <- NA_real_;completion_confirmed$skipped_wave <- NA_integer_
 completion_confirmed$confirmed_status <- NA_character_;completion_confirmed$valid_tests <- 0L
 for (completion_i in seq_len(nrow(completion_confirmed))) {
  completion_last_positive <- FALSE;completion_any_positive <- FALSE;completion_prior_wave <- NA_integer_;completion_prior_time <- NA_real_
  for (completion_j in 1:3) {
   if(!is.finite(completion_ratio[completion_i,completion_j]) || !is.finite(completion_time[completion_i,completion_j])) next
   completion_current_positive <- completion_ratio[completion_i,completion_j]<.70
   completion_confirmed$valid_tests[completion_i] <- completion_confirmed$valid_tests[completion_i]+1L
   completion_confirmed$confirmed_years[completion_i] <- completion_time[completion_i,completion_j]
   completion_any_positive <- completion_any_positive || completion_current_positive
   completion_adjacent <- completion_definition=="Consecutive_observed" || (!is.na(completion_prior_wave) && completion_j-completion_prior_wave==1L)
   if(completion_last_positive && completion_current_positive && completion_adjacent) {
    completion_confirmed$confirmed_event[completion_i] <- 1L
    completion_confirmed$confirmed_status[completion_i] <- "Confirmed_at_second_positive"
    completion_confirmed$pair_gap[completion_i] <- completion_time[completion_i,completion_j]-completion_prior_time
    completion_confirmed$skipped_wave[completion_i] <- completion_j-completion_prior_wave-1L
    break
   }
   completion_last_positive <- completion_current_positive;completion_prior_wave <- completion_j;completion_prior_time <- completion_time[completion_i,completion_j]
  }
  if(completion_confirmed$confirmed_event[completion_i]==0L) completion_confirmed$confirmed_status[completion_i] <- if(completion_last_positive) "Last_positive_unconfirmed" else if(completion_any_positive) "Positive_then_normal_unconfirmed" else "No_positive_observed"
 }
 stopifnot(sum(completion_confirmed$confirmed_event)==if(completion_definition=="Consecutive_scheduled")92L else 93L)
 stopifnot(!anyNA(completion_confirmed$confirmed_years),all(completion_confirmed$confirmed_years>0),all(completion_confirmed$confirmed_event<=completion_confirmed$event))
 for(completion_group in c("Overall",levels(completion_confirmed$fef_group4))) {
  completion_data <- if(completion_group=="Overall") completion_confirmed else completion_confirmed[completion_confirmed$fef_group4==completion_group,,drop=FALSE]
  completion_gaps <- completion_data$pair_gap[completion_data$confirmed_event==1L]
  completion_confirmation <- rbind(completion_confirmation,data.frame(definition=completion_definition,group=completion_group,n=nrow(completion_data),events=sum(completion_data$confirmed_event),first_positive_events=sum(completion_data$event),unconfirmed_last_positive=sum(completion_data$confirmed_status=="Last_positive_unconfirmed"),positive_then_normal=sum(completion_data$confirmed_status=="Positive_then_normal_unconfirmed"),one_observed_test=sum(completion_data$valid_tests==1),two_observed_tests=sum(completion_data$valid_tests==2),three_observed_tests=sum(completion_data$valid_tests==3),person_years=sum(completion_data$confirmed_years)))
  completion_pair_summary <- rbind(completion_pair_summary,data.frame(definition=completion_definition,group=completion_group,confirmed_n=length(completion_gaps),gap_median=if(length(completion_gaps))median(completion_gaps) else NA_real_,gap_min=if(length(completion_gaps))min(completion_gaps) else NA_real_,gap_max=if(length(completion_gaps))max(completion_gaps) else NA_real_,skipped_pairs=sum(completion_data$skipped_wave>0,na.rm=TRUE)))
 }
 for(completion_grouping in "Four_group") {
  completion_formula <- Surv(confirmed_years,confirmed_event)~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+ratio_AS04+fvc_pp_AS04+fef_pp_AS04+strata(site)
  completion_warnings <- character()
  completion_fit <- tryCatch(withCallingHandlers(survival::coxph(completion_formula,data=completion_confirmed,ties="efron",x=TRUE,y=TRUE,singular.ok=FALSE,na.action=na.fail),warning=function(w){completion_warnings <<- c(completion_warnings,conditionMessage(w));invokeRestart("muffleWarning")}),error=function(e)e)
  if(inherits(completion_fit,"error")) {completion_status <- rbind(completion_status,data.frame(module=paste(completion_definition,completion_grouping),status="FAILED",message=conditionMessage(completion_fit)));next}
  completion_beta <- coef(completion_fit); completion_v <- vcov(completion_fit)
  if(any(!is.finite(completion_beta))||any(!is.finite(completion_v))) {completion_status <- rbind(completion_status,data.frame(module=paste(completion_definition,completion_grouping),status="FAILED",message="Nonfinite estimates"));next}
  completion_contrasts <- list("Single vs Never"=c("fef_group4Single"=1),"Recurrent vs Never"=c("fef_group4Recurrent"=1),"Frequent vs Never"=c("fef_group4Frequent"=1))
  completion_rows <- data.frame()
  for(completion_contrast in names(completion_contrasts)) {
   completion_l <- setNames(rep(0,length(completion_beta)),names(completion_beta));completion_weights <- completion_contrasts[[completion_contrast]]
   stopifnot(all(names(completion_weights) %in% names(completion_l)))
   completion_l[names(completion_weights)] <- completion_weights
   completion_b <- sum(completion_l*completion_beta);completion_se <- sqrt(drop(t(completion_l)%*%completion_v%*%completion_l))
   completion_rows <- rbind(completion_rows,data.frame(definition=completion_definition,grouping=completion_grouping,contrast=completion_contrast,n=nrow(completion_confirmed),events=sum(completion_confirmed$confirmed_event),HR=exp(completion_b),CI_low=exp(completion_b-qnorm(.975)*completion_se),CI_high=exp(completion_b+qnorm(.975)*completion_se),p=2*pnorm(-abs(completion_b/completion_se))))
  }
  completion_rows$BH_three <- p.adjust(completion_rows$p,"BH");completion_confirmation_hr <- rbind(completion_confirmation_hr,completion_rows)
  completion_z <- tryCatch(survival::cox.zph(completion_fit,transform="km",terms=TRUE,global=TRUE),error=function(e)e)
  if(!inherits(completion_z,"error")) completion_confirmation_ph <- rbind(completion_confirmation_ph,data.frame(definition=completion_definition,grouping=completion_grouping,term=rownames(completion_z$table),completion_z$table,row.names=NULL))
  if(inherits(completion_z,"error")) completion_warnings <- c(completion_warnings,paste("PH:",conditionMessage(completion_z)))
  completion_status <- rbind(completion_status,data.frame(module=paste(completion_definition,completion_grouping),status=if(length(completion_warnings))"CHECK_WARNINGS" else "FITTED",message=paste(unique(completion_warnings),collapse=" | ")))
 }
}
scheduled_confirmed <- completion_confirmed # loop ends with Consecutive_scheduled
completion_confirmation_legacy <- completion_confirmation[completion_confirmation$group=="Overall",c("definition","n","events"),drop=FALSE]
completion_confirmation_legacy$expected_events <- ifelse(completion_confirmation_legacy$definition=="Consecutive_scheduled",92L,93L)
completion_confirmation_legacy$matches_previous_output <- completion_confirmation_legacy$events==completion_confirmation_legacy$expected_events
write.csv(completion_confirmation,file.path(completion_tables,"Confirmation_opportunity.csv"),row.names=FALSE)
write.csv(completion_pair_summary,file.path(completion_tables,"Confirmation_pair_gap.csv"),row.names=FALSE)
write.csv(completion_patterns,file.path(completion_tables,"Followup_patterns_counts.csv"),row.names=FALSE)
write.csv(completion_confirmation_hr,file.path(completion_tables,"Confirmation_HR.csv"),row.names=FALSE)
write.csv(completion_confirmation_ph,file.path(completion_tables,"Confirmation_PH.csv"),row.names=FALSE)
write.csv(completion_confirmation_legacy,file.path(completion_tables,"Confirmation_legacy_comparison.csv"),row.names=FALSE)

#Module 16. KM 시점별 추정치와 집계 곡선 데이터 ----
completion_km_points <- completion_km_steps <- data.frame()
for(completion_group in levels(completion_followup$fef_group4)) {
 completion_data <- completion_followup[completion_followup$fef_group4==completion_group,,drop=FALSE]
 completion_km <- survival::survfit(Surv(followup_years,event)~1,data=completion_data,conf.type="log-log")
 completion_s <- summary(completion_km,times=c(2,4,6),extend=FALSE)
 completion_km_points <- rbind(completion_km_points,data.frame(group=completion_group,year=completion_s$time,n_at_risk=completion_s$n.risk,survival=completion_s$surv,cumulative_detection=1-completion_s$surv,risk_CI_low=1-completion_s$upper,risk_CI_high=1-completion_s$lower))
 completion_s <- summary(completion_km,censored=TRUE)
 completion_km_steps <- rbind(completion_km_steps,data.frame(group=completion_group,year=completion_s$time,n_at_risk=completion_s$n.risk,n_event=completion_s$n.event,n_censor=completion_s$n.censor,survival=completion_s$surv,survival_CI_low=completion_s$lower,survival_CI_high=completion_s$upper))
}
write.csv(completion_km_points,file.path(completion_tables,"KM_2_4_6_years_CI.csv"),row.names=FALSE)
write.csv(completion_km_steps,file.path(completion_tables,"KM_aggregate_steps.csv"),row.names=FALSE)

#Module 17. 보완 Figure PNG TIFF PDF 저장 ----
completion_colors <- c(Never="#2166AC",Single="#D98500",Recurrent="#8E5EA2",Frequent="#B2182B")
for(completion_var in c("ratio_AS04","fef_pp_AS04")) for(completion_format in c("pdf","png","tiff")) {
 completion_path <- file.path(completion_figures,paste0("Covariate_support_",completion_var,".",completion_format))
 if(completion_format=="pdf") pdf(completion_path,width=6.4,height=4.8,useDingbats=FALSE)
 if(completion_format=="png") png(completion_path,width=6.4,height=4.8,units="in",res=FIGURE_DPI)
 if(completion_format=="tiff") tiff(completion_path,width=6.4,height=4.8,units="in",res=FIGURE_DPI,compression="lzw")
 par(mar=c(4.5,4.5,2.4,1))
 completion_hist <- list();completion_breaks <- pretty(range(completion_complete[[completion_var]]),n=25)
 for(completion_group in levels(completion_complete$fef_group4)) completion_hist[[completion_group]] <- hist(completion_complete[[completion_var]][completion_complete$fef_group4==completion_group],breaks=completion_breaks,plot=FALSE)
 completion_ymax <- max(vapply(completion_hist,function(x)max(x$density),numeric(1)))
 plot(NA,xlim=range(completion_breaks),ylim=c(0,completion_ymax*1.18),xlab=if(completion_var=="ratio_AS04")"AS04 FEV1/FVC" else "AS04 FEF25-75 (% predicted)",ylab="Density",main="Observed covariate support by exposure group")
 for(completion_group in names(completion_hist)) lines(completion_hist[[completion_group]]$mids,completion_hist[[completion_group]]$density,type="s",col=completion_colors[completion_group],lwd=1.7)
 legend("topright",names(completion_colors),col=completion_colors,lwd=1.7,bty="n",cex=.8);dev.off()
}

#Module 18. 첫 양성 이후 실제 확인 기회 집계 ----
# 전체 관측 방문을 사용합니다. 확인 사건 이후 검사를 중단해 세는 표와 구분합니다.
completion_first_opportunity <- data.frame()
for(completion_definition in c("Consecutive_scheduled","Consecutive_observed")) {
 completion_opportunity <- rep("No_positive_observed",nrow(completion_complete))
 completion_first_wave <- rep(NA_character_,nrow(completion_complete))
 for(completion_i in seq_len(nrow(completion_complete))) {
  completion_valid_waves <- which(is.finite(completion_ratio[completion_i,]) & is.finite(completion_time[completion_i,]))
  completion_positive_waves <- completion_valid_waves[completion_ratio[completion_i,completion_valid_waves]<.70]
  if(!length(completion_positive_waves)) next
  completion_first_j <- completion_positive_waves[1]; completion_first_wave[completion_i] <- paste0("AS0",completion_first_j+4)
  if(completion_first_j==3L) {
   completion_opportunity[completion_i] <- "First_positive_AS07_no_later_wave"; next
  }
  completion_later <- completion_valid_waves[completion_valid_waves>completion_first_j]
  if(completion_definition=="Consecutive_scheduled") {
   completion_next_j <- completion_first_j+1L
   if(!completion_next_j %in% completion_valid_waves) {
    completion_opportunity[completion_i] <- if(length(completion_later)) "Next_scheduled_missing_later_observed" else "No_later_valid_test"
    next
   }
  } else {
   if(!length(completion_later)) {completion_opportunity[completion_i] <- "No_later_valid_test";next}
   completion_next_j <- completion_later[1]
  }
  completion_opportunity[completion_i] <- if(completion_ratio[completion_i,completion_next_j]<.70) "Next_qualifying_test_positive" else "Next_qualifying_test_normal"
 }
 stopifnot(sum(completion_opportunity!="No_positive_observed")==sum(completion_complete$event))
 for(completion_group in c("Overall",levels(completion_complete$fef_group4))) {
  completion_sel <- if(completion_group=="Overall") rep(TRUE,nrow(completion_complete)) else completion_complete$fef_group4==completion_group
  completion_tab <- table(completion_opportunity[completion_sel])
  completion_first_opportunity <- rbind(completion_first_opportunity,data.frame(definition=completion_definition,group=completion_group,status=names(completion_tab),n=as.integer(completion_tab)))
 }
}
write.csv(completion_first_opportunity,file.path(completion_tables,"First_positive_confirmation_opportunity.csv"),row.names=FALSE)
# 서로 다른 정의의 기존 사건수와 비교하되, 일치만으로 개인별 사건 정의가 같다고 단정하지 않습니다.
completion_status <- rbind(completion_status,data.frame(module="Confirmation_event_counts",status=if(all(completion_confirmation_legacy$matches_previous_output))"MATCHED" else "CHECK_MISMATCH",message=paste(completion_confirmation_legacy$definition,completion_confirmation_legacy$events,collapse="; ")))

#Module 19. 최종 대상자의 공급값과 재구성값 연결 ----
# 기준식의 정확성을 검증하는 작업이 아닙니다. 주분석은 공급된 %predicted를 유지합니다.
stability_match <- match(completion_complete$DIST_ID,KoGES_clean$DIST_ID)
stopifnot(!anyNA(stability_match),identical(completion_complete$DIST_ID,KoGES_clean$DIST_ID[stability_match]))
stability_supplied <- as.matrix(KoGES_clean[stability_match,visit_map$fef_col[1:4],drop=FALSE])
stability_reconstructed <- matrix(NA_real_,nrow(completion_complete),4L,dimnames=list(NULL,visit_map$visit[1:4]))
stability_visit_table <- data.frame()
for (stability_visit in 1:4) {
 stability_fields <- unlist(fef_identity_map[stability_visit,-1],use.names=FALSE)
 if (!all(stability_fields %in% names(KoGES_clean))) stop("FEF 연결 검증 열 누락: ",paste(setdiff(stability_fields,names(KoGES_clean)),collapse=", "))
 stability_pred <- KoGES_clean[[stability_fields[1]]][stability_match]
 stability_best <- KoGES_clean[[stability_fields[2]]][stability_match]
 stability_pp <- stability_supplied[,stability_visit]
 stability_valid <- is.finite(stability_pred)&stability_pred>0&is.finite(stability_best)&stability_best>0&is.finite(stability_pp)&stability_pp>0
 stability_reconstructed[stability_valid,stability_visit] <- 100*stability_best[stability_valid]/stability_pred[stability_valid]
 stability_delta <- stability_reconstructed[stability_valid,stability_visit]-stability_pp[stability_valid]
 stability_discordant <- (stability_pp[stability_valid]<65)!=(stability_reconstructed[stability_valid,stability_visit]<65)
 stability_visit_table <- rbind(stability_visit_table,data.frame(visit=visit_map$visit[stability_visit],analysis_n=nrow(completion_complete),valid_n=sum(stability_valid),not_reconstructable_n=sum(!stability_valid),discordant_low_status_n=sum(stability_discordant),discordant_pct=if(sum(stability_valid)>0)100*mean(stability_discordant) else NA_real_,median_absolute_pp=if(length(stability_delta)>0)median(abs(stability_delta)) else NA_real_))
}
stability_all_valid <- rowSums(is.finite(stability_reconstructed))==4L
stability_count_supplied <- rowSums(stability_supplied<65)
stability_count_reconstructed <- rowSums(stability_reconstructed<65,na.rm=FALSE)
stopifnot(identical(as.numeric(stability_count_supplied),as.numeric(completion_complete$low_count)))
stability_group_supplied <- pmin(stability_count_supplied,3L)
stability_group_reconstructed <- pmin(stability_count_reconstructed,3L)
stability_changed <- stability_group_supplied!=stability_group_reconstructed
stability_count_changed <- stability_count_supplied!=stability_count_reconstructed
stability_any_visit_changed <- rowSums((stability_supplied<65)!=(stability_reconstructed<65),na.rm=FALSE)>0
cat("Complete cohort:",nrow(completion_complete),"; reconstructable at all 4 visits:",sum(stability_all_valid),"\n")
cat("Any visit change / exact count change / four-group change:",sum(stability_any_visit_changed,na.rm=TRUE),sum(stability_count_changed,na.rm=TRUE),sum(stability_changed,na.rm=TRUE),"\n")
# Unknown reconstruction remains unknown, not an unchanged classification.
stability_summary <- data.frame(metric=c("Final_complete_n","All_four_reconstructable_n","Any_unavailable_n","Any_visit_low_status_changed_n","Exact_low_count_changed_n","Four_group_changed_n","First_events_among_group_changed"),value=c(nrow(completion_complete),sum(stability_all_valid),sum(!stability_all_valid),sum(stability_any_visit_changed,na.rm=TRUE),sum(stability_count_changed,na.rm=TRUE),sum(stability_changed,na.rm=TRUE),sum(completion_complete$event[which(stability_changed)])))
stability_cross <- as.data.frame(table(supplied_group=factor(stability_group_supplied,levels=0:3,labels=c("0","1","2","3-4")),reconstructed_group=factor(ifelse(stability_all_valid,as.character(stability_group_reconstructed),"Unknown"),levels=c("0","1","2","3","Unknown"),labels=c("0","1","2","3-4","Unknown"))),stringsAsFactors=FALSE)
stability_group_summary <- data.frame()
for (stability_group in 0:3) {
 stability_in <- stability_group_supplied==stability_group; stability_den <- sum(stability_in&stability_all_valid)
 stability_group_summary <- rbind(stability_group_summary,data.frame(supplied_group=ifelse(stability_group==3,"3-4",as.character(stability_group)),n=sum(stability_in),events=sum(completion_complete$event[stability_in]),reconstructable_n=stability_den,unknown_n=sum(stability_in&!stability_all_valid),changed_n=sum(stability_changed[stability_in],na.rm=TRUE),changed_pct_among_reconstructable=if(stability_den>0)100*sum(stability_changed[stability_in],na.rm=TRUE)/stability_den else NA_real_))
}
write.csv(stability_visit_table,file.path(completion_tables,"Final_cohort_FEF_arithmetic.csv"),row.names=FALSE)
write.csv(stability_summary,file.path(completion_tables,"Classification_stability_summary.csv"),row.names=FALSE)
write.csv(stability_cross,file.path(completion_tables,"Four_group_reclassification.csv"),row.names=FALSE)
write.csv(stability_group_summary,file.path(completion_tables,"Classification_stability_by_group.csv"),row.names=FALSE)
print(stability_group_summary)

stopifnot(sum(stability_all_valid)==3035L,sum(stability_changed)==20L,
 sum(stability_any_visit_changed)==21L,identical(stability_visit_table$discordant_low_status_n,c(5L,6L,7L,4L)))
#Module 20. 기존 분석 자료 및 표본 확인 ----

ph_required <- c("DIST_ID","low_count","followup_years","event","age_AS04","sex","site","bmi_AS04","smoking_AS04","packyears_AS04","ratio_AS04","fvc_pp_AS04","fef_pp_AS04")
stopifnot(all(ph_required %in% names(KoGES_analysis)))
ph_followup <- KoGES_analysis[,ph_required]; ph_followup <- ph_followup[order(ph_followup$DIST_ID),]
stopifnot(nrow(ph_followup)==3060L,!anyNA(ph_followup$DIST_ID),!anyDuplicated(ph_followup$DIST_ID),sum(ph_followup$event)==224L,all(ph_followup$event %in% 0:1),!anyNA(ph_followup$low_count),all(ph_followup$low_count %in% 0:4))
print(colSums(is.na(ph_followup)))
ph_complete <- ph_followup[complete.cases(ph_followup),]; rownames(ph_complete) <- NULL
stopifnot(nrow(ph_complete)==3035L,sum(ph_complete$event)==219L,!is.unsorted(ph_complete$DIST_ID))
ph_numeric <- c("followup_years","age_AS04","bmi_AS04","packyears_AS04","ratio_AS04","fvc_pp_AS04","fef_pp_AS04")
stopifnot(all(vapply(ph_complete[,ph_numeric],is.numeric,logical(1))),all(is.finite(as.matrix(ph_complete[,ph_numeric]))),all(ph_complete$followup_years>0),all(ph_complete$ratio_AS04>0 & ph_complete$ratio_AS04<=1))
ph_complete$fef_group4 <- factor(pmin(ph_complete$low_count,3L),levels=0:3,labels=c("Never","Single","Recurrent","Frequent"))
print(table(ph_complete$fef_group4)); cat("n=",nrow(ph_complete)," events=",sum(ph_complete$event),"\n")

#Module 21. 기존 선형 및 스플라인 모형 재현 ----
ph_linear <- coxph(Surv(followup_years,event)~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+ratio_AS04+fvc_pp_AS04+fef_pp_AS04+strata(site),data=ph_complete,ties="efron",x=TRUE,y=TRUE)
ph_spline <- coxph(Surv(followup_years,event)~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+splines::ns(ratio_AS04,df=3)+fvc_pp_AS04+splines::ns(fef_pp_AS04,df=3)+strata(site),data=ph_complete,ties="efron",x=TRUE,y=TRUE)
stopifnot(max(abs(exp(coef(ph_linear)[1:3])-c(1.334661981,2.229675438,2.264021996)))<1e-5,max(abs(exp(coef(ph_spline)[1:3])-c(1.591021393,2.837066808,3.160895198)))<1e-5)
ph_tests <- data.frame()
for (ph_model in c("Linear","Spline")) {
 ph_fit <- if(ph_model=="Linear") ph_linear else ph_spline
 ph_z <- cox.zph(ph_fit,transform="km",terms=TRUE,global=TRUE)
 ph_tests <- rbind(ph_tests,data.frame(model=ph_model,term=rownames(ph_z$table),ph_z$table,row.names=NULL))
 for (j in seq_len(ncol(ph_z$y))) {
  ph_title <- colnames(ph_z$y)[j]
  ph_stem <- file.path(completion_figures,sprintf("Schoenfeld_%s_%02d",ph_model,j))
  for (fmt in c("pdf","png","tiff")) {
   if(fmt=="pdf") pdf(paste0(ph_stem,".pdf"),width=6,height=4.5)
   if(fmt=="png") png(paste0(ph_stem,".png"),width=6,height=4.5,units="in",res=1200)
   if(fmt=="tiff") tiff(paste0(ph_stem,".tiff"),width=6,height=4.5,units="in",res=1200,compression="lzw")
   par(mar=c(4.5,4.5,3,1)); plot(ph_z,var=j,se=TRUE,df=4,xlab="Follow-up time (years)",ylab="Scaled Schoenfeld effect")
   title(main=paste(ph_model,ph_title),cex.main=.8); dev.off()
  }
 }
}
write.csv(ph_tests,file.path(completion_tables,"PH_tests.csv"),row.names=FALSE)

#Module 22. 고정 스플라인 기저와 시간가변 FEV1/FVC 효과 ----
ph_ratio_basis <- splines::ns(ph_complete$ratio_AS04,df=3)
ph_fef_basis <- splines::ns(ph_complete$fef_pp_AS04,df=3)
ph_complete[,paste0("ratio_b",1:3)] <- ph_ratio_basis
ph_complete[,paste0("fef_b",1:3)] <- ph_fef_basis
ph_base <- coxph(Surv(followup_years,event)~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+ratio_b1+ratio_b2+ratio_b3+fvc_pp_AS04+fef_b1+fef_b2+fef_b3+strata(site),data=ph_complete,ties="efron")
stopifnot(abs(as.numeric(logLik(ph_base))-as.numeric(logLik(ph_spline)))<1e-7)
# 기저값은 AS04에 고정; 계수만 log(1+t)-log(2)에 따라 변합니다.
ph_tv <- coxph(Surv(followup_years,event)~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+ratio_b1+ratio_b2+ratio_b3+fvc_pp_AS04+fef_b1+fef_b2+fef_b3+strata(site)+tt(ratio_b1)+tt(ratio_b2)+tt(ratio_b3),data=ph_complete,ties="efron",tt=function(x,t,...) x*(log1p(t)-log(2)),control=coxph.control(iter.max=50))
stopifnot(all(is.finite(coef(ph_tv))),all(is.finite(vcov(ph_tv))))

#Module 23. 보정 후 FEF 효과의 시간가변성 추가 검정 ----
ph_complete$fef_single <- as.integer(ph_complete$fef_group4=="Single")
ph_complete$fef_recurrent <- as.integer(ph_complete$fef_group4=="Recurrent")
ph_complete$fef_frequent <- as.integer(ph_complete$fef_group4=="Frequent")
ph_tv_exposure <- coxph(Surv(followup_years,event)~fef_group4+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+ratio_b1+ratio_b2+ratio_b3+fvc_pp_AS04+fef_b1+fef_b2+fef_b3+strata(site)+tt(ratio_b1)+tt(ratio_b2)+tt(ratio_b3)+tt(fef_single)+tt(fef_recurrent)+tt(fef_frequent),data=ph_complete,ties="efron",tt=function(x,t,...) x*(log1p(t)-log(2)),control=coxph.control(iter.max=50))
stopifnot(all(is.finite(coef(ph_tv_exposure))),all(is.finite(vcov(ph_tv_exposure))))
ph_lrt <- data.frame(test=c("Ratio time effect: TV vs spline","FEF time effect after ratio TV"),chisq=c(2*(as.numeric(logLik(ph_tv))-as.numeric(logLik(ph_base))),2*(as.numeric(logLik(ph_tv_exposure))-as.numeric(logLik(ph_tv)))),df=c(length(coef(ph_tv))-length(coef(ph_base)),length(coef(ph_tv_exposure))-length(coef(ph_tv))))
stopifnot(all(ph_lrt$chisq> -1e-6)); ph_lrt$chisq <- pmax(ph_lrt$chisq,0)
ph_lrt$p <- pchisq(ph_lrt$chisq,df=ph_lrt$df,lower.tail=FALSE)
write.csv(ph_lrt,file.path(completion_tables,"Time_effect_LRT.csv"),row.names=FALSE)

#Module 24. 모형별 효과 및 계수 저장 ----
ph_models <- list(Linear=ph_linear,Spline=ph_spline,Ratio_TV=ph_tv,Ratio_and_FEF_TV=ph_tv_exposure)
ph_estimates <- data.frame(); ph_all <- data.frame(); ph_fit_table <- data.frame()
for (nm in names(ph_models)) {
 fit <- ph_models[[nm]]; sm <- summary(fit)
 ph_all <- rbind(ph_all,data.frame(model=nm,term=rownames(sm$coefficients),sm$coefficients,row.names=NULL,check.names=FALSE))
 ph_fit_table <- rbind(ph_fit_table,data.frame(model=nm,participants=nrow(ph_complete),events=sum(ph_complete$event),parameters=length(coef(fit)),logLik=as.numeric(logLik(fit)),AIC=AIC(fit),iterations=paste(fit$iter,collapse=";")))
 if(nm!="Ratio_and_FEF_TV") {
  ii <- grep("^fef_group4",rownames(sm$coefficients))
  rr <- data.frame(model=nm,term=rownames(sm$coefficients)[ii],HR=sm$conf.int[ii,"exp(coef)"],CI_low=sm$conf.int[ii,"lower .95"],CI_high=sm$conf.int[ii,"upper .95"],p=sm$coefficients[ii,"Pr(>|z|)"])
  rr$BH_three <- p.adjust(rr$p,"BH"); ph_estimates <- rbind(ph_estimates,rr)
 }
}
write.csv(ph_estimates,file.path(completion_tables,"FEF_HR_comparison.csv"),row.names=FALSE)
write.csv(ph_all,file.path(completion_tables,"All_coefficients.csv"),row.names=FALSE)
write.csv(ph_fit_table,file.path(completion_tables,"Model_fit.csv"),row.names=FALSE)

#Module 25. Record the actual spline basis ----
spline_settings <- data.frame(variable=c("ratio_AS04","fef_pp_AS04"),
 knot1=c(attr(ph_ratio_basis,"knots")[1],attr(ph_fef_basis,"knots")[1]),
 knot2=c(attr(ph_ratio_basis,"knots")[2],attr(ph_fef_basis,"knots")[2]),
 boundary_low=c(attr(ph_ratio_basis,"Boundary.knots")[1],attr(ph_fef_basis,"Boundary.knots")[1]),
 boundary_high=c(attr(ph_ratio_basis,"Boundary.knots")[2],attr(ph_fef_basis,"Boundary.knots")[2]),df=3L,intercept=FALSE)
write.csv(spline_settings,file.path(completion_tables,"Spline_settings.csv"),row.names=FALSE)
#Module 26. Reproduce the existing post hoc three-group sensitivity analyses ----
# These are the previously reported pooled analyses, not new four-group cutoff analyses.
# Primary group objects and participant membership must not change.
pooled_results <- data.frame()
for(pooled_scenario in c("First_60","First_65","First_70","Confirmed_65")) {
 pooled_data <- if(pooled_scenario=="Confirmed_65") scheduled_confirmed else completion_complete
 pooled_cutoff <- as.numeric(sub(".*_","",pooled_scenario))
 pooled_data$fef_group3 <- factor(pmin(rowSums(pooled_data[,visit_map$fef_col[1:4],drop=FALSE]<pooled_cutoff),2L),
  levels=0:2,labels=c("Never low","Single low","Repeated low"))
 if(pooled_scenario=="Confirmed_65") {
  pooled_data$event <- pooled_data$confirmed_event
  pooled_data$followup_years <- pooled_data$confirmed_years
 }
 stopifnot(identical(pooled_data$DIST_ID,fixed_ids),nrow(pooled_data)==3035L,
  sum(pooled_data$event)==if(pooled_scenario=="Confirmed_65")92L else 219L)
 pooled_fit <- coxph(Surv(followup_years,event)~fef_group3+age_AS04+sex+bmi_AS04+smoking_AS04+packyears_AS04+
  ratio_AS04+fvc_pp_AS04+fef_pp_AS04+strata(site),data=pooled_data,ties="efron",na.action=na.fail,singular.ok=FALSE)
 pooled_beta <- coef(pooled_fit);pooled_cov <- vcov(pooled_fit)
 stopifnot(all(is.finite(pooled_beta)),all(is.finite(pooled_cov)))
 pooled_contrasts <- list("Single low vs Never low"=c("fef_group3Single low"=1),
  "Repeated low vs Never low"=c("fef_group3Repeated low"=1),
  "Repeated low vs Single low"=c("fef_group3Single low"=-1,"fef_group3Repeated low"=1))
 for(pooled_contrast in names(pooled_contrasts)) {
  pooled_l <- setNames(rep(0,length(pooled_beta)),names(pooled_beta))
  pooled_l[names(pooled_contrasts[[pooled_contrast]])] <- pooled_contrasts[[pooled_contrast]]
  pooled_b <- sum(pooled_l*pooled_beta);pooled_se <- sqrt(drop(t(pooled_l)%*%pooled_cov%*%pooled_l))
  pooled_results <- rbind(pooled_results,data.frame(analysis=pooled_scenario,comparison=pooled_contrast,n=nrow(pooled_data),events=sum(pooled_data$event),
   HR=exp(pooled_b),CI_low=exp(pooled_b-qnorm(.975)*pooled_se),CI_high=exp(pooled_b+qnorm(.975)*pooled_se),p_value=2*pnorm(-abs(pooled_b/pooled_se))))
 }
 # Refit with Single as reference to validate the covariance-based contrast.
 pooled_single <- pooled_data;pooled_single$fef_group3 <- relevel(pooled_single$fef_group3,"Single low")
 pooled_refit <- coxph(formula(pooled_fit),data=pooled_single,ties="efron",na.action=na.fail,singular.ok=FALSE)
 stopifnot(abs(unname(coef(pooled_refit)["fef_group3Repeated low"])-pooled_b)<1e-7,
  abs(sqrt(vcov(pooled_refit)["fef_group3Repeated low","fef_group3Repeated low"])-pooled_se)<1e-7)
}
pooled_results$BH_nine <- NA_real_
pooled_extra <- pooled_results$analysis!="First_65"
stopifnot(sum(pooled_extra)==9L)
pooled_results$BH_nine[pooled_extra] <- p.adjust(pooled_results$p_value[pooled_extra],"BH",n=9L)
write.csv(pooled_results,file.path(completion_tables,"S2B_Pooled_sensitivity.csv"),row.names=FALSE)

#Module 27. Table S4: pooled historical models on the fixed complete cases ----
# S4 archived comparison tables use Wald CI z=1.96; retain that convention for exact reproduction.
KoGES_history_common <- completion_complete
KoGES_history_common$fef_group3 <- factor(pmin(KoGES_history_common$low_count,2L),levels=0:2,labels=c("Never low","Single low","Repeated low"))
KoGES_history_common$ratio_mean_AS01_AS03 <- rowMeans(KoGES_history_common[,paste0("AS0",1:3,"_ratio_observed")],na.rm=FALSE)
KoGES_history_common$fvc_mean_AS01_AS03 <- rowMeans(KoGES_history_common[,visit_map$fvc_col[1:3]],na.rm=FALSE)
KoGES_history_common$fef_mean_AS01_AS03 <- rowMeans(KoGES_history_common[,visit_map$fef_col[1:3]],na.rm=FALSE)
history_columns <- c("ratio_mean_AS01_AS03","fvc_mean_AS01_AS03","fef_mean_AS01_AS03")
stopifnot(!anyNA(KoGES_history_common[,history_columns]),identical(KoGES_history_common$DIST_ID,fixed_ids),
 identical(KoGES_history_common$fef_group4,fixed_groups),!anyDuplicated(KoGES_history_common$DIST_ID),
 !is.unsorted(KoGES_history_common$DIST_ID),nrow(KoGES_history_common)==3035L,sum(KoGES_history_common$event)==219L,
 identical(as.integer(table(KoGES_history_common$fef_group3)),c(2808L,127L,100L)))
print(colSums(is.na(KoGES_history_common[,history_columns]))); print(table(KoGES_history_common$fef_group3))
rownames(KoGES_history_common) <- KoGES_history_common$DIST_ID
KoGES_Model4_original <- KoGES_history_common

# A/B에는 FEF 그룹이 없습니다. 모든 모델은 site 층화, Efron ties, 선형 연속항.
Model4_formula <- Surv(followup_years,event) ~ fef_group3 + age_AS04 + sex + bmi_AS04 + smoking_AS04 + packyears_AS04 + ratio_AS04 + fvc_pp_AS04 + fef_pp_AS04 + strata(site)
Model5_formula <- Surv(followup_years,event) ~ fef_group3 + age_AS04 + sex + bmi_AS04 + smoking_AS04 + packyears_AS04 + ratio_AS04 + fvc_pp_AS04 + fef_pp_AS04 + ratio_mean_AS01_AS03 + fvc_mean_AS01_AS03 + strata(site)
ModelA_formula <- Surv(followup_years,event) ~ age_AS04 + sex + bmi_AS04 + smoking_AS04 + packyears_AS04 + ratio_AS04 + fvc_pp_AS04 + fef_pp_AS04 + ratio_mean_AS01_AS03 + fvc_mean_AS01_AS03 + strata(site)
ModelB_formula <- Surv(followup_years,event) ~ age_AS04 + sex + bmi_AS04 + smoking_AS04 + packyears_AS04 + ratio_AS04 + fvc_pp_AS04 + fef_pp_AS04 + ratio_mean_AS01_AS03 + fvc_mean_AS01_AS03 + fef_mean_AS01_AS03 + strata(site)
ModelC_formula <- Surv(followup_years,event) ~ age_AS04 + sex + bmi_AS04 + smoking_AS04 + packyears_AS04 + ratio_AS04 + fvc_pp_AS04 + fef_pp_AS04 + ratio_mean_AS01_AS03 + fvc_mean_AS01_AS03 + fef_mean_AS01_AS03 + fef_group3 + strata(site)
Model_formulas <- list(Model4=Model4_formula,Model5=Model5_formula,A=ModelA_formula,B=ModelB_formula,C=ModelC_formula)
Model_fits <- list(); Model_status <- data.frame(); All_coefficients <- data.frame(); PH_tests <- data.frame()
Collinearity <- data.frame(); Model_warnings <- data.frame(model=character(),stage=character(),message=character())
for(model_name in names(Model_formulas)) {
 fit_warnings <- character()
 model_fit <- withCallingHandlers(coxph(Model_formulas[[model_name]],data=KoGES_history_common,
  ties="efron",na.action=na.fail,singular.ok=FALSE,x=TRUE,y=TRUE,model=TRUE),
  warning=function(w){fit_warnings <<- c(fit_warnings,conditionMessage(w));invokeRestart("muffleWarning")})
 stopifnot(identical(rownames(model_fit$model),KoGES_history_common$DIST_ID),
  all(is.finite(coef(model_fit))), all(is.finite(vcov(model_fit))), model_fit$n==nrow(KoGES_history_common))
 Model_fits[[model_name]] <- model_fit
 if(length(fit_warnings))Model_warnings <- rbind(Model_warnings,data.frame(model=model_name,stage="Fit",message=fit_warnings))
 beta <- coef(model_fit); se <- sqrt(diag(vcov(model_fit)))
 All_coefficients <- rbind(All_coefficients,data.frame(model=model_name,term=names(beta),beta=unname(beta),SE=unname(se),
  HR=exp(beta),CI_low=exp(beta-qnorm(.975)*se),CI_high=exp(beta+qnorm(.975)*se),p_value=2*pnorm(-abs(beta/se)),row.names=NULL))
 ph_fit <- cox.zph(model_fit,transform="km",terms=TRUE,global=TRUE)
 PH_tests <- rbind(PH_tests,data.frame(model=model_name,term=rownames(ph_fit$table),ph_fit$table,row.names=NULL))
 # 표준화 설계행렬의 condition number 및 열별 VIF는 공선성 진단이며 검정 p값이 아닙니다.
 design_x <- model_fit$x; design_scaled <- scale(design_x)
 design_rank <- qr(design_scaled)$rank
 if(design_rank < ncol(design_scaled))stop("설계행렬 rank 부족: ",model_name)
 singular_values <- svd(design_scaled,nu=0,nv=0)$d
 condition_number <- max(singular_values)/min(singular_values)
 column_vif <- diag(solve(cor(design_x)))
 Collinearity <- rbind(Collinearity,data.frame(model=model_name,term=colnames(design_x),VIF=unname(column_vif)))
 Model_status <- rbind(Model_status,data.frame(model=model_name,n=model_fit$n,events=model_fit$nevent,
  parameters=length(beta),logLik=as.numeric(logLik(model_fit)),AIC=AIC(model_fit),
  warnings=length(fit_warnings),PH_global_p=ph_fit$table["GLOBAL","p"],
  rank=design_rank,condition_number=condition_number,max_column_VIF=max(column_vif),
  status=if(length(fit_warnings))"REVIEW_WARNING" else if(ph_fit$table["GLOBAL","p"]<.05)"CHECK_PH_ASSUMPTION" else "FITTED"))
}
stopifnot(identical(Model_fits$A$y,Model_fits$B$y),identical(Model_fits$B$y,Model_fits$C$y),
 identical(Model_fits$Model4$y,Model_fits$Model5$y))
print(Model_status)

# Same-sample group contrasts and reference-level verification
Contrast_results <- data.frame(); Direct_validation <- data.frame()
for(model_name in c("Model4","Model5","C")) {
 model_fit <- Model_fits[[model_name]]; beta <- coef(model_fit); variance <- vcov(model_fit)
 term_single <- "fef_group3Single low"; term_repeated <- "fef_group3Repeated low"
 contrast_matrix <- matrix(0,3,length(beta),dimnames=list(c("Single vs Never","Repeated vs Never","Repeated vs Single"),names(beta)))
 contrast_matrix[1,term_single] <- 1; contrast_matrix[2,term_repeated] <- 1
 contrast_matrix[3,term_repeated] <- 1; contrast_matrix[3,term_single] <- -1
 contrast_beta <- as.vector(contrast_matrix %*% beta)
 contrast_se <- sqrt(diag(contrast_matrix %*% variance %*% t(contrast_matrix)))
 contrast_table <- data.frame(model=model_name,comparison=rownames(contrast_matrix),n=model_fit$n,events=model_fit$nevent,
  beta=contrast_beta,SE=contrast_se,HR=exp(contrast_beta),CI_low=exp(contrast_beta-1.96*contrast_se),
  CI_high=exp(contrast_beta+1.96*contrast_se),p_value=2*pnorm(-abs(contrast_beta/contrast_se)))
 contrast_table$FDR_three_contrasts_within_model <- p.adjust(contrast_table$p_value,method="BH")
 Contrast_results <- rbind(Contrast_results,contrast_table)
 KoGES_single_reference <- KoGES_history_common
 KoGES_single_reference$fef_group3 <- relevel(KoGES_single_reference$fef_group3,ref="Single low")
 refit <- coxph(Model_formulas[[model_name]],data=KoGES_single_reference,ties="efron",na.action=na.fail,singular.ok=FALSE)
 beta_difference <- abs(coef(refit)[term_repeated]-contrast_beta[3])
 se_difference <- abs(sqrt(vcov(refit)[term_repeated,term_repeated])-contrast_se[3])
 Direct_validation <- rbind(Direct_validation,data.frame(model=model_name,beta_abs_difference=beta_difference,SE_abs_difference=se_difference,pass=beta_difference<1e-7 & se_difference<1e-7))
}
stopifnot(all(Direct_validation$pass))
# 기존 Model 4 재현. 공통 표본이 줄면 별도의 원래 Model 4 완전사례 표본에서 대조합니다.
Original_Model4_fit <- coxph(Model4_formula,data=KoGES_Model4_original,ties="efron",na.action=na.fail,singular.ok=FALSE)
original_beta <- coef(Original_Model4_fit)
Original_reproduction <- data.frame(comparison=c("Single vs Never","Repeated vs Never","Repeated vs Single"),
 previous_HR=c(1.3345,2.2448,1.6821),
 current_HR=exp(c(original_beta[term_single],original_beta[term_repeated],original_beta[term_repeated]-original_beta[term_single])))
Original_reproduction$matches_rounding <- abs(Original_reproduction$previous_HR-Original_reproduction$current_HR)<.0001
stopifnot(all(Original_reproduction$matches_rounding))
Model4_table <- Contrast_results[Contrast_results$model=="Model4",c("comparison","n","events","HR","CI_low","CI_high","p_value","FDR_three_contrasts_within_model")]
Model5_table <- Contrast_results[Contrast_results$model=="Model5",c("comparison","n","events","HR","CI_low","CI_high","p_value","FDR_three_contrasts_within_model")]
Model4_vs_Model5 <- merge(Model4_table,Model5_table,by="comparison",suffixes=c("_Model4","_Model5"),sort=FALSE)
Model4_vs_Model5 <- Model4_vs_Model5[match(c("Single vs Never","Repeated vs Never","Repeated vs Single"),Model4_vs_Model5$comparison),]

# Same-sample B versus C model comparison
B_vs_C <- anova(Model_fits$B,Model_fits$C,test="Chisq")
lrt_statistic <- 2*(as.numeric(logLik(Model_fits$C))-as.numeric(logLik(Model_fits$B)))
lrt_df <- attr(logLik(Model_fits$C),"df")-attr(logLik(Model_fits$B),"df")
stopifnot(lrt_df==2L,lrt_statistic>=0)
lrt_p <- pchisq(lrt_statistic,df=lrt_df,lower.tail=FALSE)
stopifnot(abs(B_vs_C[2,"Pr(>|Chi|)"]-lrt_p)<1e-10)
LRT_result <- data.frame(comparison="B vs C: addition of FEF group",n=nrow(KoGES_history_common),events=sum(KoGES_history_common$event),
 chisq=lrt_statistic,df=lrt_df,p_value=lrt_p,AIC_B=AIC(Model_fits$B),AIC_C=AIC(Model_fits$C),
 delta_AIC_C_minus_B=AIC(Model_fits$C)-AIC(Model_fits$B))
# Exploratory LRT is unadjusted; contrast BH values are within-model.
continuous_columns <- c("age_AS04","bmi_AS04","packyears_AS04","ratio_AS04","fvc_pp_AS04","fef_pp_AS04",history_columns)
Correlation_matrix <- cor(KoGES_history_common[,continuous_columns])
Correlation_table <- data.frame(variable=rownames(Correlation_matrix),Correlation_matrix,check.names=FALSE,row.names=NULL)
History_summary <- data.frame()
for(g in levels(KoGES_history_common$fef_group3))for(v in history_columns) {
 z <- KoGES_history_common[KoGES_history_common$fef_group3==g,v]
 History_summary <- rbind(History_summary,data.frame(group=g,variable=v,n=length(z),mean=mean(z),SD=sd(z),min=min(z),max=max(z)))
}


PH_tests$BH_covariates <- NA_real_
for(model_name in unique(PH_tests$model)) {
 idx <- PH_tests$model==model_name & PH_tests$term!="GLOBAL"
 PH_tests$BH_covariates[idx] <- p.adjust(PH_tests$p[idx],method="BH")
}
if(nrow(Model_warnings)>0)stop("Historical model warning; inspect before release.")
#Module 28. Table S4: baseline BMI coefficient varying with follow-up time ----
History_TV_fits <- list(); History_TV_contrasts <- History_BMI_time_tests <- data.frame()
for(model_name in names(Model_formulas)) {
 history_tv_formula <- update(Model_formulas[[model_name]], . ~ . + tt(bmi_AS04))
 history_tv_fit <- survival::coxph(history_tv_formula,data=KoGES_history_common,ties="efron",
  na.action=na.fail,singular.ok=FALSE,x=TRUE,y=TRUE,
  tt=function(x,t,...)x*(log1p(t)-log(2)))
 # tt() models use risk-set expansion; ordinary cox.zph is not applicable.
 stopifnot(history_tv_fit$nevent==219L,
  all(is.finite(coef(history_tv_fit))),all(is.finite(vcov(history_tv_fit))))
 History_TV_fits[[model_name]] <- history_tv_fit
 history_chisq <- 2*(as.numeric(logLik(history_tv_fit))-as.numeric(logLik(Model_fits[[model_name]])))
 history_df <- attr(logLik(history_tv_fit),"df")-attr(logLik(Model_fits[[model_name]]),"df")
 stopifnot(history_df==1L,history_chisq>=0)
 History_BMI_time_tests <- rbind(History_BMI_time_tests,data.frame(model=model_name,chisq=history_chisq,df=history_df,p_value=pchisq(history_chisq,history_df,lower.tail=FALSE)))
 if(model_name %in% c("Model4","Model5","C")) {
  beta <- coef(history_tv_fit); variance <- vcov(history_tv_fit)
  contrast_matrix <- matrix(0,3,length(beta),dimnames=list(c("Single vs Never","Repeated vs Never","Repeated vs Single"),names(beta)))
  contrast_matrix[1,"fef_group3Single low"] <- 1;contrast_matrix[2,"fef_group3Repeated low"] <- 1
  contrast_matrix[3,"fef_group3Repeated low"] <- 1;contrast_matrix[3,"fef_group3Single low"] <- -1
  contrast_beta <- as.vector(contrast_matrix %*% beta);contrast_se <- sqrt(diag(contrast_matrix %*% variance %*% t(contrast_matrix)))
  contrast_table <- data.frame(model=model_name,comparison=rownames(contrast_matrix),n=3035L,events=219L,
   HR=exp(contrast_beta),CI_low=exp(contrast_beta-1.96*contrast_se),CI_high=exp(contrast_beta+1.96*contrast_se),p_value=2*pnorm(-abs(contrast_beta/contrast_se)))
  contrast_table$FDR_within_model <- p.adjust(contrast_table$p_value,"BH")
  History_TV_contrasts <- rbind(History_TV_contrasts,contrast_table)
 }
}
history_tv_lrt <- 2*(as.numeric(logLik(History_TV_fits$C))-as.numeric(logLik(History_TV_fits$B)))
history_tv_df <- attr(logLik(History_TV_fits$C),"df")-attr(logLik(History_TV_fits$B),"df")
stopifnot(history_tv_df==2L,history_tv_lrt>=0)
History_TV_BC <- data.frame(chisq=history_tv_lrt,df=history_tv_df,p_value=pchisq(history_tv_lrt,history_tv_df,lower.tail=FALSE),
 AIC_B=AIC(History_TV_fits$B),AIC_C=AIC(History_TV_fits$C),delta_AIC_C_minus_B=AIC(History_TV_fits$C)-AIC(History_TV_fits$B))
History_tables <- list(S4_Original_contrasts=Contrast_results,S4_BMI_TV_contrasts=History_TV_contrasts,
 S4_Model_status=Model_status,S4_PH_tests=PH_tests,S4_VIF=Collinearity,S4_BMI_time_tests=History_BMI_time_tests,
 S4_Original_B_vs_C=LRT_result,S4_BMI_TV_B_vs_C=History_TV_BC,S4_Correlations=Correlation_table,
 S4_History_summary=History_summary,S4_All_coefficients=All_coefficients,S4_Reference_validation=Direct_validation)
for(history_name in names(History_tables))write.csv(History_tables[[history_name]],file.path(completion_tables,paste0(history_name,".csv")),row.names=FALSE)
# Existing results are verification targets only, never replacements for calculated estimates.
history_reference <- read.csv(file.path(REFERENCE_DIR,"BMI_TV_FEF_comparison.csv"))
history_checks <- data.frame()
for(history_variant in c("Original","BMI_TV")) {
 current <- if(history_variant=="Original")Contrast_results else History_TV_contrasts
 idx <- match(paste(current$model,current$comparison),paste(history_reference$model,history_reference$comparison))
 stopifnot(!anyNA(idx))
 fields <- c("HR","CI_low","CI_high","p_value")
 err <- max(abs(as.matrix(current[,fields])-as.matrix(history_reference[idx,paste0(fields,"_",history_variant)])))
 history_checks <- rbind(history_checks,data.frame(item=paste("S4 contrasts",history_variant),max_absolute_error=err,tolerance=1e-5,pass=err<1e-5))
}
ref_bc <- read.csv(file.path(REFERENCE_DIR,"BMI_TV_B_vs_C.csv"))
for(history_variant in c("Original","BMI_time_varying")) {
 current <- if(history_variant=="Original")LRT_result else History_TV_BC
 fields <- c("chisq","df","p_value","AIC_B","AIC_C","delta_AIC_C_minus_B")
 err <- max(abs(as.matrix(current[,fields])-as.matrix(ref_bc[ref_bc$variant==history_variant,fields])))
 history_checks <- rbind(history_checks,data.frame(item=paste("S4 B versus C",history_variant),max_absolute_error=err,tolerance=1e-5,pass=err<1e-5))
}
ref_status <- read.csv(file.path(REFERENCE_DIR,"History_Model_status.csv"))
idx <- match(Model_status$model,ref_status$model);stopifnot(!anyNA(idx))
fields <- c("n","events","AIC","PH_global_p","max_column_VIF")
err <- max(abs(as.matrix(Model_status[,fields])-as.matrix(ref_status[idx,fields])))
history_checks <- rbind(history_checks,data.frame(item="S4 sample AIC PH VIF",max_absolute_error=err,tolerance=1e-5,pass=err<1e-5))
ref_bmi <- read.csv(file.path(REFERENCE_DIR,"BMI_TV_BMI_time_tests.csv"))
ref_bmi <- ref_bmi[ref_bmi$test=="BMI log-time effect",]
idx <- match(History_BMI_time_tests$model,ref_bmi$model);stopifnot(!anyNA(idx))
fields <- c("chisq","df","p_value")
err <- max(abs(as.matrix(History_BMI_time_tests[,fields])-as.matrix(ref_bmi[idx,fields])))
history_checks <- rbind(history_checks,data.frame(item="S4 BMI time-effect LRT",max_absolute_error=err,tolerance=1e-5,pass=err<1e-5))
ref_ph <- read.csv(file.path(REFERENCE_DIR,"History_PH_tests.csv"))
idx <- match(paste(PH_tests$model,PH_tests$term),paste(ref_ph$model,ref_ph$term));stopifnot(!anyNA(idx))
fields <- c("chisq","df","p")
err <- max(abs(as.matrix(PH_tests[,fields])-as.matrix(ref_ph[idx,fields])))
history_checks <- rbind(history_checks,data.frame(item="S4 term-level PH",max_absolute_error=err,tolerance=1e-5,pass=err<1e-5))
write.csv(history_checks,file.path(completion_tables,"S4_Reproduction_checks.csv"),row.names=FALSE)
print(history_checks,digits=15,row.names=FALSE)
if(!all(history_checks$pass))stop("S4 reproduction mismatch; no release-ready output generated.")
stopifnot(identical(completion_complete$DIST_ID,fixed_ids),identical(completion_complete$fef_group4,fixed_groups))

#Module 29. Main descriptive tables ----
baseline_spec <- data.frame(variable=c("age_AS04","sex","site","bmi_AS04","smoking_AS04","smoking_AS04","smoking_AS04", 
 "packyears_AS04","AS04_SP1_2","fvc_pp_AS04","AS04_SP2_2","AS04_SP2_3","ratio_AS04","AS04_SP4_2","fef_pp_AS04"),
 label=c("Age, years","Female, n (%)","Ansan site, n (%)","BMI, kg/m2","Never smoker, n (%)","Former smoker, n (%)","Current smoker, n (%)",
 "Pack-years, median (IQR)","FVC, L","FVC, % predicted, median (IQR)","FEV1, L","FEV1, % predicted, median (IQR)","FEV1/FVC","FEF25-75, L/s, median (IQR)","FEF25-75, % predicted, median (IQR)"),
 type=c("mean","category","category","mean","category","category","category","median","mean","median","mean","median","mean","median","median"),
 level=c("","Female","Ansan","","Never","Former","Current",rep("",8)))
baseline_table <- data.frame(Characteristic=baseline_spec$label)
baseline_numeric <- data.frame()
for(g in levels(fixed_groups)) {
 d <- completion_followup[completion_followup$fef_group4==g,,drop=FALSE];display <- character(nrow(baseline_spec))
 for(j in seq_len(nrow(baseline_spec))) {
  v <- d[[baseline_spec$variable[j]]];v <- v[!is.na(v)]
  if(baseline_spec$type[j]=="category") {
   n <- sum(as.character(v)==baseline_spec$level[j]);value <- 100*n/length(v)
   display[j] <- sprintf("%d (%.1f)",n,value)
   baseline_numeric <- rbind(baseline_numeric,data.frame(group=g,variable=baseline_spec$variable[j],level=baseline_spec$level[j],n_observed=length(v),statistic="n",value=n))
  } else {
   digits <- if(baseline_spec$variable[j]=="ratio_AS04")3L else 1L
   values <- if(baseline_spec$type[j]=="mean")c(mean(v),sd(v)) else as.numeric(quantile(v,c(.5,.25,.75)))
   labels <- if(baseline_spec$type[j]=="mean")c("mean","SD") else c("median","Q1","Q3")
   text_values <- formatC(values,format="f",digits=digits)
   display[j] <- if(length(values)==2)paste0(text_values[1]," (",text_values[2],")") else paste0(text_values[1]," (",text_values[2],"-",text_values[3],")")
   baseline_numeric <- rbind(baseline_numeric,data.frame(group=g,variable=baseline_spec$variable[j],level="",n_observed=length(v),statistic=labels,value=values))
  }
 }
 baseline_table[[g]] <- display
}
write.csv(baseline_table,file.path(completion_tables,"Table1_AS04.csv"),row.names=FALSE)
write.csv(baseline_numeric,file.path(completion_tables,"Table1_numeric.csv"),row.names=FALSE)
incidence <- data.frame()
for(g in levels(fixed_groups)) {
 d <- completion_followup[completion_followup$fef_group4==g,,drop=FALSE]
 incidence <- rbind(incidence,data.frame(group=g,n=nrow(d),events=sum(d$event),event_pct=100*mean(d$event),
  person_years=sum(d$followup_years),rate_per_1000=1000*sum(d$event)/sum(d$followup_years)))
}
write.csv(incidence,file.path(completion_tables,"Table2A_Incidence.csv"),row.names=FALSE)
followup_summary <- data.frame(n=nrow(completion_followup),events=sum(completion_followup$event),person_years=sum(completion_followup$followup_years),
 median=median(completion_followup$followup_years),Q1=unname(quantile(completion_followup$followup_years,.25)),Q3=unname(quantile(completion_followup$followup_years,.75)),maximum=max(completion_followup$followup_years))
write.csv(followup_summary,file.path(completion_tables,"Followup_summary.csv"),row.names=FALSE)

#Module 30. Numerical reproduction gates ----
# Stop on disagreement. Never edit counts or substitute archived values to force a match.
write.csv(completion_status,file.path(completion_tables,"Analysis_status.csv"),row.names=FALSE)
verification <- data.frame(item=character(),max_absolute_error=numeric(),tolerance=numeric(),pass=logical())
ref_main <- read.csv(file.path(REFERENCE_DIR,"Four_group_exposure_estimates.csv"),check.names=FALSE)
ref_main$model <- sub("Model","M",ref_main$model)
ref_main <- ref_main[ref_main$analysis=="Site_stratified" & ref_main$specification=="Categorical",]
ref_main$term <- sub("^fef_group","fef_group4",ref_main$term)
ref_main$term <- sub("Frequent/Persistent low","Frequent",ref_main$term,fixed=TRUE)
ref_main$term <- sub(" low$","",ref_main$term)
ref_main$p <- ref_main$p_value
main_keys <- paste(completion_hr$model,completion_hr$term)
ref_keys <- paste(ref_main$model,ref_main$term)
reference_index <- match(main_keys,ref_keys)
stopifnot(!anyNA(reference_index),!anyDuplicated(ref_keys))
main_error <- max(abs(as.matrix(completion_hr[,c("HR","CI_low","CI_high","p")])-as.matrix(ref_main[reference_index,c("HR","CI_low","CI_high","p")])))
verification <- rbind(verification,data.frame(item="Main Models 1-4 HR CI p",max_absolute_error=main_error,tolerance=1e-5,pass=main_error<1e-5))
ref_pooled <- read.csv(file.path(REFERENCE_DIR,"Pooled_sensitivity_all_contrasts.csv"),check.names=FALSE)
ref_pooled <- ref_pooled[ref_pooled$model=="Model4",]
reference_index <- match(paste(pooled_results$analysis,pooled_results$comparison),paste(ref_pooled$analysis,ref_pooled$comparison))
stopifnot(!anyNA(reference_index))
pooled_error <- max(abs(as.matrix(pooled_results[,c("HR","CI_low","CI_high","p_value")])-as.matrix(ref_pooled[reference_index,c("HR","CI_low","CI_high","p_value")])))
verification <- rbind(verification,data.frame(item="Existing pooled sensitivity",max_absolute_error=pooled_error,tolerance=1e-5,pass=pooled_error<1e-5))
for(check_name in c("AFT_distribution_TR","AFT_distribution_fit","Confirmation_HR","KM_2_4_6_years_CI","FEF_HR_comparison","Time_effect_LRT","PH_tests")) {
 current <- read.csv(file.path(completion_tables,paste0(check_name,".csv")),check.names=FALSE)
 expected <- read.csv(file.path(REFERENCE_DIR,paste0(check_name,".csv")),check.names=FALSE)
 stopifnot(identical(names(current),names(expected)),nrow(current)==nrow(expected))
 numeric_cols <- names(current)[vapply(current,is.numeric,logical(1))]
 other_cols <- setdiff(names(current),numeric_cols)
 stopifnot(identical(current[,other_cols,drop=FALSE],expected[,other_cols,drop=FALSE]),
  identical(is.na(current[,numeric_cols,drop=FALSE]),is.na(expected[,numeric_cols,drop=FALSE])))
 delta <- abs(as.matrix(current[,numeric_cols,drop=FALSE])-as.matrix(expected[,numeric_cols,drop=FALSE]))
 error <- if(all(is.na(delta)))0 else max(delta,na.rm=TRUE)
 verification <- rbind(verification,data.frame(item=check_name,max_absolute_error=error,tolerance=1e-5,pass=error<1e-5))
}
stopifnot(identical(completion_complete$DIST_ID,fixed_ids),identical(completion_complete$fef_group4,fixed_groups),
 identical(completion_followup$DIST_ID,fixed_followup_ids),identical(completion_followup$fef_group4,fixed_followup_groups))
write.csv(verification,file.path(completion_tables,"Reproduction_checks.csv"),row.names=FALSE)
if(!all(verification$pass)) stop("Reproduction mismatch; inspect Reproduction_checks.csv. No release-ready output generated.")
if(any(completion_status$status %in% c("FAILED","CHECK_WARNINGS","CHECK_MISMATCH","NO_TRIPLES","PARTIAL_MISSING_COLUMNS","CHECK_NO_VALID_TRIPLES")))
 stop("Review model/status warnings before release.")

#Module 31. Preserve approved figures and render a fresh KM check ----
# Canonical Figure 1/2 assets are byte-identical copies; the fresh figure below is a QC rendering.
asset_files <- list.files(file.path(PROJECT_DIR,"assets","original_figures"),full.names=TRUE)
stopifnot(length(asset_files)==6L)
for(asset_file in asset_files) {
 target <- file.path(completion_figures,basename(asset_file))
 stopifnot(file.copy(asset_file,target,overwrite=FALSE),unname(tools::md5sum(asset_file))==unname(tools::md5sum(target)))
}
km_all <- survfit(Surv(followup_years,event)~fef_group4,data=completion_followup,conf.type="log-log")
km_logrank <- survdiff(Surv(followup_years,event)~fef_group4,data=completion_followup)
write.csv(data.frame(chisq=km_logrank$chisq,df=3L,p=pchisq(km_logrank$chisq,3,lower.tail=FALSE)),file.path(completion_tables,"KM_Logrank.csv"),row.names=FALSE)
for(fmt in c("pdf","png","tiff")) {
 path <- file.path(completion_figures,paste0("Figure2_Recomputed_QC.",fmt))
 if(fmt=="pdf")pdf(path,width=7.2,height=6.1,useDingbats=FALSE)
 if(fmt=="png")png(path,width=7.2,height=6.1,units="in",res=FIGURE_DPI)
 if(fmt=="tiff")tiff(path,width=7.2,height=6.1,units="in",res=FIGURE_DPI,compression="lzw")
 layout(matrix(c(1,2),ncol=1),heights=c(3.8,1.45));par(mar=c(3,4.8,3.1,1.1))
 plot(km_all,conf.int=FALSE,mark.time=TRUE,col=completion_colors,lwd=1.6,lty=1,cex=.38,
  xlim=c(0,6),xaxs="r",ylim=c(0,1),xaxt="n",xlab="",ylab="Airflow-obstruction-free survival")
 axis(1,at=0:6);legend("bottomleft",levels(fixed_groups),col=completion_colors,lwd=1.6,bty="n",cex=.8)
 par(mar=c(3.2,4.8,.3,1.1));plot.new();plot.window(xlim=c(0,6),ylim=c(.5,5.2),xaxs="r")
 text(0,4.9,"Number at risk",adj=0,cex=.8,font=2)
 for(j in 1:4) {
  at_risk <- vapply(0:6,function(t)sum(completion_followup$fef_group4==levels(fixed_groups)[j]&completion_followup$followup_years>=t),numeric(1))
  text(0:6,5-j,at_risk,cex=.75);mtext(levels(fixed_groups)[j],side=2,at=5-j,las=1,line=.3,cex=.7)
 }
 axis(1,at=0:6);mtext("Years since AS04",side=1,line=1.9);dev.off()
}

#Module 32. One workbook with all calculated tables and execution record ----
write.csv(completion_status,file.path(completion_tables,"Analysis_status.csv"),row.names=FALSE)
csv_files <- sort(list.files(completion_tables,pattern="[.]csv$",full.names=TRUE))
workbook <- openxlsx::createWorkbook()
table_index <- data.frame(sheet=character(),csv=character())
for(j in seq_along(csv_files)) {
 sheet <- sprintf("T%02d_%s",j,substr(sub("[.]csv$","",basename(csv_files[j])),1,26))
 openxlsx::addWorksheet(workbook,sheet)
 values <- read.csv(csv_files[j],check.names=FALSE,stringsAsFactors=FALSE)
 openxlsx::writeData(workbook,sheet,values,withFilter=nrow(values)>0)
 openxlsx::freezePane(workbook,sheet,firstRow=TRUE)
 openxlsx::setColWidths(workbook,sheet,cols=seq_len(ncol(values)),widths=20)
 table_index <- rbind(table_index,data.frame(sheet=sheet,csv=basename(csv_files[j])))
}
openxlsx::addWorksheet(workbook,"INDEX");openxlsx::writeData(workbook,"INDEX",table_index)
openxlsx::setColWidths(workbook,"INDEX",1:2,widths=48)
openxlsx::saveWorkbook(workbook,file.path(completion_output,"All_Analysis_Tables.xlsx"),overwrite=FALSE)
write.csv(table_index,file.path(completion_output,"Workbook_index.csv"),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(completion_output,"sessionInfo.txt"))
package_versions <- data.frame(package=c("R",required_packages),version=c(as.character(getRversion()),vapply(required_packages,function(p)as.character(packageVersion(p)),character(1))))
write.csv(package_versions,file.path(completion_output,"package_versions.csv"),row.names=FALSE)
writeLines(c("All reproduction gates passed for the locally supplied data.",
 "No participant records, IDs, fitted model objects or raw input are exported.",
 "Table S4 pooled historical and BMI time-effect models match the current manuscript scope; primary four-group assignments are unchanged.",
 "The supplied FEF percent-predicted fields define the original four groups; reconstructed percentages are audit-only.",
 "FEF reference equation provenance requires documentary confirmation. No equation is inferred from the device name.",
 "PNG/TIFF plots are 1200 dpi; PDFs are vector. Figure2 is an unchanged approved asset; Figure2_Recomputed_QC is a new diagnostic rendering.",
 "Retain the approved local data release and original grouping records privately. Count/effect agreement alone does not prove identity with an unavailable historical ID manifest."),
 file.path(completion_output,"Run_notes.txt"))
analysis_script <- file.path(PROJECT_DIR,"R","00_Final_Analysis.R")
writeLines(paste("00_Final_Analysis.R MD5",unname(tools::md5sum(analysis_script))),file.path(completion_output,"Executed_code_checksum.txt"))
result_files <- list.files(completion_output,recursive=TRUE,full.names=FALSE)
result_files <- result_files[!dir.exists(file.path(completion_output,result_files))]
zip::zipr(paste0(completion_output,".zip"),files=result_files,root=completion_output,recurse=FALSE,include_directories=FALSE,mode="mirror")
cat("Completed:",paste0(completion_output,".zip"),"\n")
