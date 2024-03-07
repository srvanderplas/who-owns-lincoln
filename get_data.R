library(rvest)
library(purrr)
library(tidyr)
library(dplyr)
library(RSelenium)

url <- "https://app.lincoln.ne.gov/aspx/cnty/cto/"


# Selenium works using docker container...
# https://stackoverflow.com/questions/48568172/docker-sock-permission-denied
# in terminal, run
# docker run -d -p 4445:4444 selenium/standalone-firefox:2.53.1

remDr <- remoteDriver(
  remoteServerAddr = "localhost",
  port = 4445L,
  browserName = "firefox"
)
remDr$open()
remDr$getStatus()

remDr$navigate(url)

# Need 3-letter queries for property search by last name
query <- expand_grid(letters, letters, letters) %>%
  purrr::transpose() %>%
  purrr::map_chr(~paste(., collapse = ""))


last_name_field <- remDr$findElement(using = "id", value = "ctl00_ctl00_cph1_cph1_tcOptions_tpOwner_txtLName")
# Fill in query
last_name_field$sendKeysToElement(list(query[[1]]))
enter_btn <- remDr$findElement(using = "id", value = "ctl00_ctl00_cph1_cph1_tcOptions_tpOwner_btnOwner")
enter_btn$clickElement()

# Reading in data with multiple pages

# First, get all rows in table
tablerows <- remDr$findElements(using = "css selector", value = ".tableData tr")
lastpage <- try(tablerows[[length(tablerows)]]$findChildElement(using = "css selector", ".rowPage"))
if (!"try-error" %in% class(lastpage)) {
  # Deal with extra page links
}
*/tr[contains(@class, 'rowPage')]")
/html/body/div/div[2]/div[1]/div/form/div[4]/div[2]/div/table/tbody/tr[27]/td/table/tbody/tr/td[2]/a
