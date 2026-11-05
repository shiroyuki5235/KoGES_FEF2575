#Module 00. Record the actual analysis environment ----
# Run after Module 38 of 00_Final_Analysis.R in the same session.
if(!exists("completion_output") || !file.exists(file.path(completion_output,"All_Analysis_Tables.xlsx")))stop("Complete the analysis first.")
writeLines(capture.output(sessionInfo()),file.path(completion_output,"sessionInfo.txt"))
p <- installed.packages()
write.csv(p[,c("Package","Version","Built"),drop=FALSE],file.path(completion_output,"Installed_packages.csv"),row.names=FALSE)
#Module 01. Refresh the aggregate output archive ----
result_files <- list.files(completion_output,recursive=TRUE,full.names=FALSE)
result_files <- result_files[!dir.exists(file.path(completion_output,result_files))]
zip::zipr(paste0(completion_output,".zip"),files=result_files,root=completion_output,recurse=FALSE,include_directories=FALSE,mode="mirror")
