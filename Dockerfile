FROM rocker/r-ver:4.5.0

# System dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages('remotes', repos='https://cloud.r-project.org')"
RUN R -e "install.packages(c('plumber','tidyverse','broom','jsonlite','survival','survminer','MatchIt','BTYD','lme4','caret','glmnet','randomForest','CLVTools','lubridate','readxl'), repos='https://cloud.r-project.org', dependencies=TRUE)"

WORKDIR /app
COPY plumber.R .
COPY run.R .

EXPOSE 8000

CMD ["Rscript", "run.R"]
