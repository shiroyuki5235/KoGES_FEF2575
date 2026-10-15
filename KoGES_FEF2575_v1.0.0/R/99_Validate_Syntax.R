#Module 00. Parse scripts without running analyses ----
scripts <- list.files("R",pattern="[.]R$",full.names=TRUE)
stopifnot(length(scripts)>=3L)
for(script in scripts) {
 parse(file=script,encoding="UTF-8")
 cat("Parsed:",script,"\n")
}
cat("Syntax parsing does not demonstrate statistical reproduction.\n")
