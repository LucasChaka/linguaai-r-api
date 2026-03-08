FROM rocker/tidyverse:4.4.0

# System dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install only packages not already in rocker/tidyverse
RUN R -e "install.packages(c('plumber','broom','survival','survminer','MatchIt','BTYD','lme4','caret','glmnet','randomForest','CLVTools'), repos='https://cloud.r-project.org', dependencies=TRUE, Ncpus=4)"

WORKDIR /app
COPY plumber.R .
COPY run.R .

EXPOSE 8000

CMD ["Rscript", "run.R"]
