library(shiny) #To build the shiny App
library(dygraphs) #For interactive Time-series graphs

ui <- shinyUI(fluidPage(
    titlePanel('Bitcoin USD Price Correlation with Google Trends'),
    mainPanel(
        dygraphOutput("btc")
    )
))
