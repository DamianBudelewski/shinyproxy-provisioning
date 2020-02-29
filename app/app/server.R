library(coindeskr) #R-Package connecting to Coindesk API 
library(gtrendsR) #Perform and Display Google Trends Queries
library(textshape)
library(zoo)

server <- function(input,output){
    
    # Download table with price and google hits for bitcoin
    btc_value <- get_historic_price(currency = "USD", start = Sys.Date() - 1826, end = Sys.Date())
    btc_trend <- gtrends("bitcoin", time = "today+5-y")

    # Choose only interest over time table for google trends response
    btc_trend_interest = btc_trend$interest_over_time

    # Move btc columnd date to row names
    btc_trend_converted <- column_to_rownames(btc_trend_interest,'date')
    
    # Delete unused columns
    btc_trend_converted$time <- NULL
    btc_trend_converted$geo <- NULL
    btc_trend_converted$keyword <- NULL
    btc_trend_converted$gprop <- NULL
    btc_trend_converted$category <- NULL
    
    # Merge both tables into one
    btc_merged <- merge(btc_trend_converted,btc_value,by = 0, all = TRUE)

    # replace each NA with the most recent non-NA 
    btc_merged <- na.locf(btc_merged)

    # Move btc columnd date to row names
    btc <- column_to_rownames(btc_merged,'Row.names')

    output$btc <- renderDygraph(
        dygraph(data = btc, main = "Bitcoin / Google Trends") %>% 

            # Name y axis
            dyAxis("y", label = "USD") %>%
            dyAxis("y2", label = "Search hits", independentTicks = TRUE) %>%
            
            # Assign columns to x axix
            dySeries("Price", axis=('y')) %>%
            dySeries("hits", axis=('y2')) %>%
            dyHighlight(highlightCircleSize = 2, 
                        highlightSeriesBackgroundAlpha = 0.5,
                        hideOnMouseOut = FALSE, highlightSeriesOpts = list(strokeWidth = 2)) %>%
            dyRangeSelector()
    )
}
