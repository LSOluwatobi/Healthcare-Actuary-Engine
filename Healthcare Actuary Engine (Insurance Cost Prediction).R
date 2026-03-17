# ==============================================================================
# PROJECT 6: Healthcare Actuary Engine (Insurance Cost Prediction)
# GOAL: Predict Medical Expenses using Non-Parametric Models
# MODELS: Decision Tree, K-Nearest Neighbors (KNN), Support Vector Regression (SVR)
# ==============================================================================

# ------------------------------------------------------------------------------
# PHASE 1: Setup & Data Acquisition
# ------------------------------------------------------------------------------
options(scipen = 999)
if(!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, caret, rpart, rpart.plot, e1071, scales, Metrics)
pacman::p_load(rpart.plot, Metrics)

# Load the Medical Insurance Dataset
url <- "https://raw.githubusercontent.com/stedy/Machine-Learning-with-R-datasets/master/insurance.csv"
df_raw <- read_csv(url)

# ------------------------------------------------------------------------------
# PHASE 2: Data Engineering & Transformation
# ------------------------------------------------------------------------------
# Non-parametric models require categorical variables to be handled properly.
df_clean <- df_raw %>%
  mutate(across(where(is.character), as.factor))

# Create Dummy Variables (One-Hot Encoding)
# KNN and SVR require numeric inputs for all features.
dummies <- dummyVars(charges ~ ., data = df_clean)
df_transformed <- as.data.frame(predict(dummies, newdata = df_clean))
df_transformed$charges <- df_clean$charges

# Split into Training (80%) and Testing (20%)
index <- createDataPartition(df_transformed$charges, p = 0.8, list = FALSE)
train_set <- df_transformed[index, ]
test_set  <- df_transformed[-index, ]

# Feature Scaling: MANDATORY for KNN and SVR (Distance-based models)
scaler <- preProcess(train_set, method = c("center", "scale"))
train_scaled <- predict(scaler, train_set)
test_scaled  <- predict(scaler, test_set)

# ------------------------------------------------------------------------------
# PHASE 3: Model Training (Non-Parametric Trio)
# ------------------------------------------------------------------------------

# 1. Decision Tree Regressor (Interpretable logic)
# We use rpart directly to allow for easy plotting later
fit_tree <- rpart(charges ~ ., data = train_set, method = "anova")

# 2. K-Nearest Neighbors (KNN)
# Using caret to tune the 'k' parameter (number of neighbors)
fit_knn <- train(charges ~ ., data = train_scaled, method = "knn",
                 tuneGrid = expand.grid(k = seq(1, 15, by = 2)))

# 3. Support Vector Regression (SVR)
# Using a Radial Basis Function (RBF) kernel to capture non-linear costs
fit_svr <- svm(charges ~ ., data = train_scaled, kernel = "radial")

# ------------------------------------------------------------------------------
# PHASE 4: Professional Evaluation & Comparison
# ------------------------------------------------------------------------------
eval_metrics <- function(actual, predicted, model_name) {
  rmse <- rmse(actual, predicted)
  mae  <- mae(actual, predicted)
  r2   <- cor(actual, predicted)^2
  return(data.frame(Model = model_name, RMSE = rmse, MAE = mae, R_Squared = r2))
}

# Generate Predictions
pred_tree <- predict(fit_tree, test_set)
pred_knn  <- predict(fit_knn, test_scaled)
pred_svr  <- predict(fit_svr, test_scaled)

# Comparison Table
comparison_table <- rbind(
  eval_metrics(test_set$charges, pred_tree, "Decision Tree"),
  eval_metrics(test_set$charges, pred_knn, "KNN"),
  eval_metrics(test_set$charges, pred_svr, "SVR (Radial)")
)

print("--- Model Performance Comparison ---")
print(comparison_table)

# ------------------------------------------------------------------------------
# PHASE 5: Visualizing Logic & Importance
# ------------------------------------------------------------------------------

# 1. Visualizing the Decision Tree (The "Actuary's Logic")
# This shows exactly which factors (like smoking) trigger cost increases.
rpart.plot(fit_tree, main = "Insurance Cost Decision Logic", box.palette = "RdYlGn")

# 2. Actual vs Predicted (SVR)
ggplot(data.frame(Actual = test_set$charges, Predicted = pred_svr), aes(x = Actual, y = Predicted)) +
  geom_point(alpha = 0.4, color = "#16a085") +
  geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
  scale_x_continuous(labels = label_dollar()) +
  scale_y_continuous(labels = label_dollar()) +
  labs(title = "SVR Performance: Actual vs Predicted Medical Charges",
       subtitle = "Capturing non-linear healthcare cost spikes") +
  theme_minimal()
