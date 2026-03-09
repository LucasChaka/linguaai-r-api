FROM rocker/tidyverse:4.4.0

# System dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages('plumber', repos='https://cloud.r-project.org', lib=.libPaths()[1])"
RUN R -e "install.packages('broom', repos='https://cloud.r-project.org', lib=.libPaths()[1])"
RUN R -e "install.packages('survival', repos='https://cloud.r-project.org', lib=.libPaths()[1])"
RUN R -e "install.packages('lme4', repos='https://cloud.r-project.org', lib=.libPaths()[1])"
RUN R -e "install.packages('glmnet', repos='https://cloud.r-project.org', lib=.libPaths()[1])"

WORKDIR /app
COPY plumber.R .
COPY run.R .

EXPOSE 8000

CMD ["Rscript", "run.R"]
