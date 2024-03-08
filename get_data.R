library(rvest)
library(purrr)
library(tidyr)
library(dplyr)
library(RSelenium)
library(stringr)

# Selenium works using docker container...
# https://stackoverflow.com/questions/48568172/docker-sock-permission-denied
# in terminal, run
# docker run -d -p 4445:4444 selenium/standalone-firefox:2.53.1

# Need 3-letter queries for property search by last name
query <- expand_grid(letters, letters, letters) %>%
  purrr::transpose() %>%
  purrr::map_chr(~paste(., collapse = ""))

max_display <- 10 # still need to hook this up...

url <- "https://app.lincoln.ne.gov/aspx/cnty/cto/"

# ---- Helper functions --------------------------------------------------------

refresh_elements <- function(remDr, value) {
  remDr$findElements(
    using = "css selector",
    value = value)
}

get_source_from_link <- function(remDr, link) {
  link$clickElement()
  # remDr$screenshot(display = T)
  source <- link$getPageSource()
  remDr$goBack()
  # remDr$screenshot(display = T)
  return(source)
}

property_page_to_df <- function(source) {
  parsed <- read_html(source[[1]])
  datapairs <- html_elements(parsed, "span[id*='ctl00_ctl00_cph1_cph1_fvProperty']")
  element_names <- map_chr(datapairs, ~html_attr(., 'id')) %>%
    str_remove("ctl00_ctl00_cph1_cph1_fvProperty_?") %>%
    str_remove("_?lbl(NotFound)?") %>%
    str_remove("rp") %>%
    str_remove_all("_ctl00") %>%
    str_replace("TotalMillageTotalMillage", "TotalMillage")

  element_values <- map_chr(datapairs, ~html_text(.)) %>%
    str_trim() %>% str_squish()

  assessor_link_stub <- "https://orion.lancaster.ne.gov/appraisal/publicaccess/PropertyDetail.aspx?PropertyNumber="
  data.frame(t(element_values)) %>% set_names(element_names) %>%
    mutate(assessor_link = paste0(assessor_link_stub, Parcel))
}


# ---- Setting up driver and navigating to search page -------------------------
remDr <- remoteDriver(
  remoteServerAddr = "localhost",
  port = 4445L,
  browserName = "firefox"
)
remDr$open()
remDr$getStatus()

remDr$navigate(url)
remDr$screenshot(display = T)

# ---- Search query setup ------------------------------------------------------
last_name_field <- remDr$findElement(
  using = "id",
  value = "ctl00_ctl00_cph1_cph1_tcOptions_tpOwner_txtLName")
# Fill in query
last_name_field$sendKeysToElement(list(query[[12489]]))
# Hit enter
enter_btn <- remDr$findElement(
  using = "id",
  value = "ctl00_ctl00_cph1_cph1_tcOptions_tpOwner_btnOwner")
enter_btn$clickElement()
remDr$screenshot(display = T)

# ---- Search query responses --------------------------------------------------
# Get table displayed
source <- remDr$getPageSource()
parsed <- read_html(source[[1]])
summary_tab <- html_table(parsed)[[1]]
# Get all rows in table
tablerows <- remDr$findElements(using = "css selector", value = ".tableData tr")
# Get last row with links to other stuff
lastrow <- tablerows[[length(tablerows)]]
if (nrow(summary_tab) > max_display) {
  lastpage <- try(lastrow$findChildElement(using = "css selector", ".rowPage"))
  if (!"try-error" %in% class(lastpage)) {
    # Deal with extra page links
  }
}
remDr$screenshot(display = T)



# Read in links on the page
css_val <- "a[id*='ctl00_ctl00_cph1_cph1_gvProperty'][id$='_btnSelect']"
view_links <- refresh_elements(remDr, css_val)

res <- tibble()
counter <- 0
repeat {
  counter <- counter + 1
  view_links <- refresh_elements(remDr, css_val)
  if (counter > length(view_links)) break;
  new <- get_source_from_link(remDr, view_links[[counter]]) %>%
    property_page_to_df()
  res <- bind_rows(res, new)

}
full_df <- left_join(summary_tab, res)
