FROM rocker/tidyverse:4.4.0

# System dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install packages in small batches to avoid timeout
RUN R -e "install.packages('plumber', repos='https://cloud.r-project.org')"
RUN R -e "install.packages('broom', repos='https://cloud.r-project.org')"
RUN R -e "install.packages('survival', repos='https://cloud.r-project.org')"
RUN R -e "install.packages('lme4', repos='https://cloud.r-project.org')"
RUN R -e "install.packages('glmnet', repos='https://cloud.r-project.org')"

WORKDIR /app
COPY plumber.R .
COPY run.R .

EXPOSE 8000

CMD ["Rscript", "run.R"]
