FROM openanalytics/r-base

# system libraries of general use
RUN apt-get update && apt-get install -y \
    sudo \
    pandoc \
    pandoc-citeproc \
    libcurl4-openssl-dev \
    libcairo2-dev \
    libxt-dev \
    libssl-dev \
    libssh2-1-dev \
    libssl1.0.0 \
    libxml2-dev \
    libcurl4-openssl-dev

# install required package dependencies
RUN R -e "install.packages(c('shiny','tidyverse','leaflet','lubridate','promises','future'))"

# copy the app to the image
RUN mkdir /root/nyc_metro_vis
COPY app-files /root/nyc_metro_vis

COPY Rprofile.site /usr/lib/R/etc/

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/root/nyc_metro_vis')"]
