#Module 00. Record the actual executed environment ----
# Run AFTER 00_Final_Analysis.R, in the same R session.
if(!exists("completion_output") || !file.exists(file.path(completion_output,"Tables","Reproduction_checks.csv"))) stop("Complete the main analysis first.")
checks <- read.csv(file.path(completion_output,"Tables","Reproduction_checks.csv"))
stopifnot(all(checks$pass))
writeLines(capture.output(sessionInfo()),file.path(completion_output,"sessionInfo.txt"))
installed <- as.data.frame(installed.packages(),stringsAsFactors=FALSE)
dependency_names <- unique(c("survival","openxlsx","zip",unlist(tools::package_dependencies(c("survival","openxlsx","zip"),db=installed,recursive=TRUE))))
dependency_table <- installed[installed$Package %in% dependency_names,intersect(c("Package","Version","Built","Priority"),names(installed)),drop=FALSE]
dependency_table <- dependency_table[order(dependency_table$Package),,drop=FALSE]
write.csv(dependency_table,file.path(completion_output,"dependency_versions.csv"),row.names=FALSE)

#Module 01. Optional lockfile from ACTUAL installed packages ----
# No guessed versions, automatic installation, activation, or package updates.
if(requireNamespace("renv",quietly=TRUE)) {
 renv::snapshot(project=PROJECT_DIR,lockfile=file.path(completion_output,"renv.lock"),packages=c("survival","openxlsx","zip"),prompt=FALSE)
} else {
 message("Dependency CSV and sessionInfo saved. renv not installed; no lockfile fabricated.")
}

#Module 02. Refresh the aggregate output ZIP ----
result_files <- list.files(completion_output,recursive=TRUE,full.names=FALSE)
result_files <- result_files[!dir.exists(file.path(completion_output,result_files))]
zip::zipr(paste0(completion_output,".zip"),files=result_files,root=completion_output,recurse=FALSE,include_directories=FALSE,mode="mirror")
