library(plumber)
library(tidyverse)
library(broom)
library(jsonlite)
library(survival)
library(glmnet)

#* @apiTitle Inlucyd R Analytics API
#* @apiDescription Runs statistical models on customer data

#* Health check
#* @get /health
function() list(status = "ok")

#* Auto-detect data type and recommend model
#* @post /recommend
#* @param data JSON array of transactions
function(req) {
  df <- fromJSON(req$postBody)
  
  has_plan     <- "plan" %in% names(df)
  has_category <- "category" %in% names(df)
  n_customers  <- length(unique(df$customer_id))
  n_rows       <- nrow(df)
  avg_orders   <- n_rows / n_customers
  
  if (has_plan) {
    type  <- "saas"
    model <- "logistic_churn"
    reason <- paste0(
      "Your data has a plan/subscription column, which means this is SaaS data. ",
      "With ", n_customers, " customers averaging ", round(avg_orders, 1), " transactions each, ",
      "the most useful analysis is churn prediction - which plan types, channels, and ",
      "languages are most associated with customers cancelling."
    )
    variables <- list(
      outcome    = "churned (yes/no)",
      predictors = c("plan", "channel", "category", "country", "months_active")
    )
  } else {
    type  <- "d2c"
    model <- "ols_ltv"
    reason <- paste0(
      "Your data looks like transactional D2C data - no subscription plan column detected. ",
      "With ", n_customers, " customers and ", n_rows, " transactions, ",
      "OLS regression on lifetime value is the right starting point to understand ",
      "which channels and behaviours drive your best customers."
    )
    variables <- list(
      outcome    = "lifetime value (total revenue per customer)",
      predictors = c("order_frequency", "recency_days", "avg_order_value", "channel")
    )
  }
  
  list(
    data_type      = type,
    model          = model,
    reason         = reason,
    variables      = variables,
    n_customers    = n_customers,
    n_transactions = n_rows
  )
}

#* Logistic regression - churn prediction (SaaS)
#* @post /logistic_churn
function(req) {
  df <- fromJSON(req$postBody)
  df$order_date <- as.Date(df$order_date)
  
  max_date <- max(df$order_date)
  
  cust <- df %>%
    group_by(customer_id) %>%
    summarise(
      months_active = as.numeric(difftime(max(order_date), min(order_date), units="days")) / 30,
      last_purchase = as.numeric(difftime(max_date, max(order_date), units="days")),
      n_orders      = n(),
      total_rev     = sum(revenue),
      plan          = last(plan),
      channel       = last(channel),
      category      = last(category),
      country       = last(country),
      .groups = "drop"
    ) %>%
    mutate(
      churned = as.integer(last_purchase > 60),
      plan    = factor(plan),
      channel = factor(channel),
      country = factor(country)
    )
  
  fit <- glm(churned ~ plan + channel + months_active + n_orders,
             data = cust, family = binomial())
  
  tidy_fit <- tidy(fit, exponentiate = TRUE, conf.int = TRUE) %>%
    mutate(across(where(is.numeric), ~round(., 4)))
  
  null_dev  <- fit$null.deviance
  res_dev   <- fit$deviance
  pseudo_r2 <- round(1 - res_dev / null_dev, 4)
  accuracy  <- mean((predict(fit, type="response") > 0.5) == cust$churned)
  
  churn_rate <- round(mean(cust$churned), 4)
  
  list(
    model        = "Logistic Regression - Churn Prediction",
    n            = nrow(cust),
    churn_rate   = churn_rate,
    pseudo_r2    = pseudo_r2,
    accuracy     = round(accuracy, 4),
    coefficients = tidy_fit
  )
}

#* OLS regression - LTV drivers (D2C)
#* @post /ols_ltv
function(req) {
  df <- fromJSON(req$postBody)
  df$order_date <- as.Date(df$order_date)
  now <- max(df$order_date)
  
  cust <- df %>%
    group_by(customer_id) %>%
    summarise(
      ltv         = sum(revenue),
      frequency   = n(),
      recency     = as.numeric(difftime(now, max(order_date), units="days")),
      aov         = sum(revenue) / n(),
      channel     = last(channel),
      .groups = "drop"
    ) %>%
    mutate(
      log_recency = log(recency + 1),
      channel     = factor(channel)
    )
  
  fit      <- lm(ltv ~ frequency + log_recency + aov + channel, data = cust)
  tidy_fit <- tidy(fit, conf.int = TRUE) %>%
    mutate(across(where(is.numeric), ~round(., 4)))
  r2     <- round(summary(fit)$r.squared, 4)
  adj_r2 <- round(summary(fit)$adj.r.squared, 4)
  
  list(
    model        = "OLS Regression - LTV Drivers",
    n            = nrow(cust),
    r2           = r2,
    adj_r2       = adj_r2,
    coefficients = tidy_fit
  )
}

#* Survival analysis - time to churn
#* @post /survival
function(req) {
  df <- fromJSON(req$postBody)
  df$order_date <- as.Date(df$order_date)
  
  max_date <- max(df$order_date)
  
  cust <- df %>%
    group_by(customer_id) %>%
    summarise(
      months_active = as.numeric(difftime(max(order_date), min(order_date), units="days")) / 30,
      last_purchase = as.numeric(difftime(max_date, max(order_date), units="days")),
      plan          = last(plan),
      channel       = last(channel),
      .groups = "drop"
    ) %>%
    mutate(
      churned       = as.integer(last_purchase > 60),
      months_active = pmax(months_active, 0.1),
      plan          = factor(plan),
      channel       = factor(channel)
    )
  
  km_fit     <- survfit(Surv(months_active, churned) ~ 1, data = cust)
  summary_km <- summary(km_fit, times = c(1, 2, 3, 6, 9, 12))
  
  curve <- data.frame(
    time     = summary_km$time,
    survival = round(summary_km$surv, 4),
    lower    = round(summary_km$lower, 4),
    upper    = round(summary_km$upper, 4)
  )
  
  cox_fit  <- coxph(Surv(months_active, churned) ~ plan + channel, data = cust)
  cox_tidy <- tidy(cox_fit, exponentiate = TRUE, conf.int = TRUE) %>%
    mutate(across(where(is.numeric), ~round(., 4)))
  
  list(
    model            = "Survival Analysis - Time to Churn",
    n                = nrow(cust),
    median_survival  = round(median(cust$months_active), 2),
    survival_curve   = curve,
    cox_coefficients = cox_tidy
  )
}