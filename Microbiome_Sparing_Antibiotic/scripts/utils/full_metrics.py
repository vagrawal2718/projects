"""
utils/full_metrics.py

Full suite of binary classification metrics for publication-quality reporting.
Computes: ROC-AUC, PR-AUC, F1 (macro, weighted, per-class), MCC, sensitivity,
specificity, PPV, NPV, balanced accuracy, Brier score, confusion matrix.

All metrics computed at threshold=0.5 unless otherwise stated.
"""

import numpy as np
from sklearn.metrics import (
    roc_auc_score, average_precision_score, roc_curve, precision_recall_curve,
    f1_score, matthews_corrcoef, accuracy_score, balanced_accuracy_score,
    precision_score, recall_score, confusion_matrix, brier_score_loss,
    classification_report
)


def compute_full_metrics(y_true, y_prob, threshold=0.5):
    """
    Compute comprehensive binary classification metrics.

    Parameters
    ----------
    y_true : array-like of int (0/1)
    y_prob : array-like of float (predicted probability of class 1)
    threshold : float, decision threshold for hard predictions

    Returns
    -------
    dict with all metrics (all values are Python floats, JSON-serializable)
    """
    y_true = np.asarray(y_true, dtype=int)
    y_prob = np.asarray(y_prob, dtype=float)

    # Hard predictions at threshold
    y_pred = (y_prob >= threshold).astype(int)

    n = len(y_true)
    n_pos = int(y_true.sum())
    n_neg = n - n_pos
    prevalence = n_pos / n if n > 0 else 0.0

    metrics = {
        'n_samples': n,
        'n_positive': n_pos,
        'n_negative': n_neg,
        'prevalence': round(prevalence, 4),
        'threshold': threshold,
    }

    # -- Probability-based metrics (threshold-independent) --
    try:
        metrics['roc_auc'] = round(float(roc_auc_score(y_true, y_prob)), 4)
    except ValueError:
        metrics['roc_auc'] = float('nan')

    try:
        metrics['pr_auc'] = round(float(average_precision_score(y_true, y_prob)), 4)
    except ValueError:
        metrics['pr_auc'] = float('nan')

    try:
        metrics['brier_score'] = round(float(brier_score_loss(y_true, y_prob)), 4)
    except ValueError:
        metrics['brier_score'] = float('nan')

    # -- Threshold-based metrics --
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred, labels=[0, 1]).ravel()
    metrics['tp'] = int(tp)
    metrics['tn'] = int(tn)
    metrics['fp'] = int(fp)
    metrics['fn'] = int(fn)

    # Sensitivity (recall, true positive rate)
    metrics['sensitivity'] = round(float(tp / (tp + fn)) if (tp + fn) > 0 else 0.0, 4)
    # Specificity (true negative rate)
    metrics['specificity'] = round(float(tn / (tn + fp)) if (tn + fp) > 0 else 0.0, 4)
    # Positive predictive value (precision)
    metrics['ppv'] = round(float(tp / (tp + fp)) if (tp + fp) > 0 else 0.0, 4)
    # Negative predictive value
    metrics['npv'] = round(float(tn / (tn + fn)) if (tn + fn) > 0 else 0.0, 4)

    # Accuracy
    metrics['accuracy'] = round(float(accuracy_score(y_true, y_pred)), 4)
    # Balanced accuracy
    metrics['balanced_accuracy'] = round(float(balanced_accuracy_score(y_true, y_pred)), 4)

    # F1 scores
    metrics['f1_macro'] = round(float(f1_score(y_true, y_pred, average='macro', zero_division=0)), 4)
    metrics['f1_weighted'] = round(float(f1_score(y_true, y_pred, average='weighted', zero_division=0)), 4)
    metrics['f1_class0'] = round(float(f1_score(y_true, y_pred, pos_label=0, zero_division=0)), 4)
    metrics['f1_class1'] = round(float(f1_score(y_true, y_pred, pos_label=1, zero_division=0)), 4)

    # MCC (Matthews Correlation Coefficient)
    metrics['mcc'] = round(float(matthews_corrcoef(y_true, y_pred)), 4)

    # Precision and recall per class
    metrics['precision_class1'] = metrics['ppv']
    metrics['recall_class1'] = metrics['sensitivity']
    metrics['precision_class0'] = metrics['npv']  # Note: NPV is "precision" for class 0
    metrics['recall_class0'] = metrics['specificity']

    # ROC curve points (for plotting)
    try:
        fpr, tpr, _ = roc_curve(y_true, y_prob)
        metrics['roc_fpr'] = fpr.tolist()
        metrics['roc_tpr'] = tpr.tolist()
    except ValueError:
        pass

    # PR curve points (for plotting)
    try:
        prec, rec, _ = precision_recall_curve(y_true, y_prob)
        metrics['pr_precision'] = prec.tolist()
        metrics['pr_recall'] = rec.tolist()
    except ValueError:
        pass

    return metrics


def aggregate_fold_metrics(fold_metrics_list):
    """
    Aggregate per-fold metrics into mean +/- std.

    Parameters
    ----------
    fold_metrics_list : list of dicts (each from compute_full_metrics)

    Returns
    -------
    dict with mean_X, std_X for all numeric metrics
    """
    if not fold_metrics_list:
        return {}

    # Collect all numeric keys (exclude arrays and non-numeric)
    skip_keys = {'roc_fpr', 'roc_tpr', 'pr_precision', 'pr_recall',
                 'n_samples', 'n_positive', 'n_negative', 'threshold',
                 'tp', 'tn', 'fp', 'fn'}
    numeric_keys = [k for k in fold_metrics_list[0]
                    if k not in skip_keys and isinstance(fold_metrics_list[0][k], (int, float))
                    and not np.isnan(fold_metrics_list[0].get(k, 0))]

    agg = {}
    for key in numeric_keys:
        values = [m[key] for m in fold_metrics_list if key in m and not np.isnan(m.get(key, float('nan')))]
        if values:
            agg[f'mean_{key}'] = round(float(np.mean(values)), 4)
            agg[f'std_{key}'] = round(float(np.std(values)), 4)

    # Totals
    agg['n_folds'] = len(fold_metrics_list)
    agg['total_samples'] = sum(m.get('n_samples', 0) for m in fold_metrics_list)
    agg['total_positive'] = sum(m.get('n_positive', 0) for m in fold_metrics_list)

    return agg


def metrics_to_row(task_name, pipeline_name, agg_metrics):
    """
    Convert aggregated metrics to a flat dict suitable for a DataFrame row.
    """
    row = {
        'task': task_name,
        'pipeline': pipeline_name,
    }
    for k, v in agg_metrics.items():
        row[k] = v
    return row


# Key metrics for the summary comparison table
SUMMARY_COLUMNS = [
    'task', 'pipeline',
    'mean_roc_auc', 'std_roc_auc',
    'mean_pr_auc', 'std_pr_auc',
    'mean_f1_macro', 'std_f1_macro',
    'mean_mcc', 'std_mcc',
    'mean_sensitivity', 'std_sensitivity',
    'mean_specificity', 'std_specificity',
    'mean_balanced_accuracy', 'std_balanced_accuracy',
    'mean_brier_score', 'std_brier_score',
]


def format_metric(mean_val, std_val, decimals=4):
    """Format as 'mean +/- std'."""
    if mean_val is None or np.isnan(mean_val):
        return 'N/A'
    fmt = f"{{:.{decimals}f}}"
    return f"{fmt.format(mean_val)} +/- {fmt.format(std_val)}"
