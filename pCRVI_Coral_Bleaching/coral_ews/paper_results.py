"""
Paper & Poster Results Generator
==================================

Generates publication-ready tables, statistics, and LaTeX snippets
from the Coral EWS output data.

Usage:
    from coral_ews.paper_results import PaperResultsGenerator
    gen = PaperResultsGenerator(output_dir=Path('output'))
    gen.generate_all()

Output files (in output/paper/):
    - table1_validation_results.csv      LaTeX-ready validation table
    - table2_skill_metrics.csv           Full skill metric comparison
    - table3_feature_importance.csv      Top features with display names
    - table4_forecast_comparison.csv     Model comparison
    - table5_threshold_sensitivity.csv   Threshold sweep results
    - table6_annual_pcrvi_summary.csv    Annual pCRVI + DHW statistics
    - table7_ml_vs_expert_weights.csv    Weight comparison
    - key_statistics.json                All headline numbers for paper
    - key_statistics.tex                 LaTeX macros for inline citation
"""

import json
import numpy as np
import pandas as pd
from pathlib import Path
from typing import Dict, Any, Optional

from .logger import get_logger
from .naming import label, label_with_units, friendly_name, COMPONENT_LABELS


class PaperResultsGenerator:
    """Generate publication-ready tables and statistics."""

    def __init__(self, output_dir: Path):
        self.output_dir = Path(output_dir)
        self.paper_dir = self.output_dir / "paper"
        self.paper_dir.mkdir(parents=True, exist_ok=True)
        self.csv_dir = self.output_dir / "csv"
        self.report_dir = self.output_dir / "reports"
        self.logger = get_logger("coral_ews.paper_results")
        self.stats: Dict[str, Any] = {}

    def generate_all(
        self,
        pcrvi_ts: Optional[pd.DataFrame] = None,
        dhw_data: Optional[pd.DataFrame] = None,
        skill_results: Optional[Dict] = None,
        opt_results: Optional[Dict] = None,
    ):
        """Generate all paper-ready outputs."""
        self.logger.info("Generating paper-ready results...")

        # Load skill analysis from JSON if not passed
        if skill_results is None:
            skill_path = self.report_dir / "pcrvi_skill_analysis.json"
            if skill_path.exists():
                with open(skill_path) as f:
                    skill_results = json.load(f)

        # Load ML weights from JSON if not passed
        if opt_results is None:
            ml_path = self.report_dir / "ml_weight_optimization.json"
            if ml_path.exists():
                with open(ml_path) as f:
                    opt_results = json.load(f)

        self._table1_validation()
        self._table2_skill_metrics(skill_results)
        self._table3_feature_importance()
        self._table4_forecast_comparison()
        self._table5_threshold_sensitivity(skill_results)
        self._table6_annual_summary(pcrvi_ts, dhw_data)
        self._table7_weight_comparison()
        self._key_statistics(skill_results, opt_results)
        self._latex_macros()

        self.logger.info(f"Paper results written to {self.paper_dir}")
        return self.stats

    # ── Table 1: Historical Validation ────────────────────────────
    def _table1_validation(self):
        path = self.csv_dir / "validation_results.csv"
        if not path.exists():
            return
        df = pd.read_csv(path)
        # Reformat for paper
        table = df[['year', 'actual_severity', 'actual_dhw', 'actual_bleaching_pct',
                     'model_dhw_max', 'dhw_match', 'pcrvi_max', 'pcrvi_30d_lead',
                     'pcrvi_match', 'pcrvi_early_warning']].copy()
        table.columns = ['Year', 'Observed Severity', 'Reported DHW (°C-weeks)',
                         'Bleaching (%)', 'Model DHW', 'DHW Match',
                         'pCRVI Max', 'pCRVI 30d Lead', 'pCRVI Match', 'Early Warning']
        table.to_csv(self.paper_dir / "table1_validation_results.csv", index=False)

        # Stats
        n = len(table)
        self.stats['n_events_validated'] = n
        self.stats['pcrvi_correct'] = int((table['pCRVI Match'] == 'CORRECT').sum())
        self.stats['pcrvi_close'] = int((table['pCRVI Match'] == 'CLOSE').sum())
        self.stats['pcrvi_early_warning_pct'] = round(
            table['Early Warning'].astype(str).eq('True').sum() / n * 100, 1)
        self.stats['dhw_underestimate_pct'] = round(
            (table['DHW Match'] == 'UNDERESTIMATE').sum() / n * 100, 1)
        self.logger.info(f"  Table 1: {n} events, "
                         f"{self.stats['pcrvi_early_warning_pct']}% early warning")

    # ── Table 2: Skill Metrics ───────────────────────────────────
    def _table2_skill_metrics(self, skill_results):
        if not skill_results:
            return
        lead_data = skill_results.get('lead_time_analysis', {})
        rows = []
        for k in sorted(lead_data, key=lambda x: int(x.split('_')[0])):
            d = lead_data[k]
            rows.append({
                'Lead Time': k.replace('_', ' '),
                'Precision': d.get('precision', 0),
                'Recall (POD)': d.get('recall', 0),
                'F1 Score': d.get('f1_score', 0),
                'MCC': d.get('mcc', 0),
                'HSS': d.get('heidke_skill_score', 0),
                'PSS / TSS': d.get('peirce_skill_score', 0),
                'CSI': d.get('critical_success_index', 0),
                'FAR': d.get('false_alarm_ratio', 0),
                'POFD': d.get('prob_false_detection', 0),
                'Freq Bias': d.get('frequency_bias', 0),
                'Correlation': d.get('correlation', 0),
                'n': d.get('n_samples', 0),
            })
        df = pd.DataFrame(rows)
        df.to_csv(self.paper_dir / "table2_skill_metrics.csv", index=False)
        self.stats['optimal_threshold'] = skill_results.get('optimal_threshold', 0)
        self.stats['optimal_f1'] = skill_results.get('optimal_f1', 0)

        # Optimal threshold stats
        opt = skill_results.get('optimal_threshold', 0.6)
        opt_data = skill_results.get('threshold_analysis', {}).get(f'{opt:.2f}', {})
        self.stats['opt_precision'] = opt_data.get('precision', 0)
        self.stats['opt_recall'] = opt_data.get('recall', 0)
        self.stats['opt_mcc'] = opt_data.get('mcc', 0)
        self.stats['opt_hss'] = opt_data.get('hss', 0)
        self.stats['opt_pss'] = opt_data.get('pss', 0)
        self.stats['opt_csi'] = opt_data.get('csi', 0)

    # ── Table 3: Feature Importance ──────────────────────────────
    def _table3_feature_importance(self):
        # Try ensemble 30d first, then any available
        for suffix in ['ensemble_30d', 'ensemble_60d']:
            path = self.csv_dir / f"feature_importance_{suffix}.csv"
            if path.exists():
                df = pd.read_csv(path)
                break
        else:
            return

        # Add display_name if missing
        if 'display_name' not in df.columns:
            df['display_name'] = df['feature'].map(friendly_name)

        top15 = df.head(15).copy()
        top15['Cumulative %'] = (top15['importance'].cumsum() * 100).round(1)
        top15['Contribution %'] = (top15['importance'] * 100).round(1)
        top15 = top15.rename(columns={
            'display_name': 'Feature',
            'importance': 'Importance',
        })
        top15[['Feature', 'feature', 'Importance', 'Contribution %', 'Cumulative %']].to_csv(
            self.paper_dir / "table3_feature_importance.csv", index=False)

        self.stats['top_feature'] = df.iloc[0]['feature']
        self.stats['top_feature_name'] = friendly_name(df.iloc[0]['feature'])
        self.stats['top_feature_pct'] = round(df.iloc[0]['importance'] * 100, 1)
        self.stats['top3_cumulative_pct'] = round(df.head(3)['importance'].sum() * 100, 1)
        self.logger.info(f"  Table 3: Top feature = {self.stats['top_feature_name']} "
                         f"({self.stats['top_feature_pct']}%)")

    # ── Table 4: Forecast Comparison ─────────────────────────────
    def _table4_forecast_comparison(self):
        path = self.csv_dir / "dhw_forecast_comparison.csv"
        if not path.exists():
            return
        df = pd.read_csv(path)
        df = df.rename(columns={
            'mae': 'MAE (°C-weeks)', 'rmse': 'RMSE (°C-weeks)',
            'r2': 'R²', 'bl_f1': 'Bleaching F1',
            'bl_precision': 'Bleaching Precision', 'bl_recall': 'Bleaching Recall',
        })
        df.to_csv(self.paper_dir / "table4_forecast_comparison.csv", index=False)

        best = df.loc[df['R²'].idxmax()]
        self.stats['best_forecast_model'] = best['Model']
        self.stats['best_forecast_r2'] = round(float(best['R²']), 4)
        self.stats['best_forecast_mae'] = round(float(best['MAE (°C-weeks)']), 4)
        self.stats['best_forecast_bl_f1'] = round(float(best['Bleaching F1']), 4)

    # ── Table 5: Threshold Sensitivity ───────────────────────────
    def _table5_threshold_sensitivity(self, skill_results):
        if not skill_results:
            return
        thresh_data = skill_results.get('threshold_analysis', {})
        rows = []
        for t in sorted(thresh_data, key=float):
            d = thresh_data[t]
            rows.append({
                'Threshold': float(t),
                'F1': d.get('f1_score', 0),
                'Precision': d.get('precision', 0),
                'Recall': d.get('recall', 0),
                'MCC': d.get('mcc', 0),
                'HSS': d.get('hss', 0),
                'PSS': d.get('pss', 0),
                'CSI': d.get('csi', 0),
                'FAR': d.get('false_alarm_ratio', 0),
                'POFD': d.get('pofd', 0),
                'Alerts': d.get('n_alerts', 0),
            })
        df = pd.DataFrame(rows)
        df.to_csv(self.paper_dir / "table5_threshold_sensitivity.csv", index=False)

    # ── Table 6: Annual Summary with pCRVI ───────────────────────
    def _table6_annual_summary(self, pcrvi_ts, dhw_data):
        path = self.csv_dir / "annual_summary.csv"
        if not path.exists():
            return
        df = pd.read_csv(path)

        # Enrich with pCRVI stats if available
        if pcrvi_ts is not None and not pcrvi_ts.empty:
            pcrvi = pcrvi_ts.copy()
            if 'date' in pcrvi.columns:
                pcrvi['date'] = pd.to_datetime(pcrvi['date'])
                pcrvi = pcrvi.set_index('date')
            pcrvi.index = pd.to_datetime(pcrvi.index)

            annual_pcrvi = pcrvi.groupby(pcrvi.index.year).agg({
                'pcrvi': ['max', 'mean'],
                'risk_category': lambda x: (x.isin(['High', 'Critical', 'Severe'])).sum(),
            }).reset_index()
            annual_pcrvi.columns = ['year', 'pcrvi_max', 'pcrvi_mean', 'high_risk_days']

            df = df.merge(annual_pcrvi, on='year', how='left')

            # Add component peaks per year
            for comp in ['ta_norm', 'as_norm', 'wq_norm', 'la_norm']:
                if comp in pcrvi.columns:
                    comp_max = pcrvi.groupby(pcrvi.index.year)[comp].max().reset_index()
                    comp_max.columns = ['year', f'{comp}_max']
                    df = df.merge(comp_max, on='year', how='left')

        df.to_csv(self.paper_dir / "table6_annual_pcrvi_summary.csv", index=False)
        self.stats['analysis_years'] = f"{df['year'].min()}-{df['year'].max()}"
        self.stats['total_years'] = len(df)

    # ── Table 7: ML vs Expert Weights ────────────────────────────
    def _table7_weight_comparison(self):
        path = self.csv_dir / "ml_weight_comparison.csv"
        if not path.exists():
            return
        df = pd.read_csv(path)
        df.index = df.iloc[:, 0]
        df = df.iloc[:, 1:]

        # Add display names
        from .naming import WEIGHT_LABELS
        df.insert(0, 'Component', df.index.map(
            lambda k: COMPONENT_LABELS.get(k + '_norm',
                                            k.replace('_', ' ').title())))
        df.to_csv(self.paper_dir / "table7_ml_vs_expert_weights.csv")

    # ── Key Statistics ───────────────────────────────────────────
    def _key_statistics(self, skill_results, opt_results):
        # Add data scale stats
        pcrvi_path = self.csv_dir / "pcrvi_timeseries.csv"
        if pcrvi_path.exists():
            pcrvi = pd.read_csv(pcrvi_path)
            self.stats['total_days'] = len(pcrvi)
            self.stats['pcrvi_max_ever'] = round(pcrvi['pcrvi'].max(), 3)
            self.stats['n_features_used'] = len(pcrvi.columns) - 1

        dhw_path = self.csv_dir / "dhw_timeseries.csv"
        if dhw_path.exists():
            dhw = pd.read_csv(dhw_path)
            self.stats['dhw_max_ever'] = round(dhw['dhw'].max(), 2)

        # Save
        with open(self.paper_dir / "key_statistics.json", 'w') as f:
            json.dump(self.stats, f, indent=2, default=str)

        self.logger.info(f"  Key statistics: {len(self.stats)} metrics saved")
        return self.stats

    # ── LaTeX Macros ─────────────────────────────────────────────
    def _latex_macros(self):
        """Generate \\newcommand macros for inline citation in LaTeX."""
        lines = [
            "% Auto-generated by coral_ews.paper_results — DO NOT EDIT",
            "% Usage: \\optimalF{} → 0.539,  \\topFeature{} → AS",
            "",
        ]
        macro_map = {
            'optimalThreshold': ('optimal_threshold', '.2f'),
            'optimalF':         ('optimal_f1', '.3f'),
            'optPrecision':     ('opt_precision', '.3f'),
            'optRecall':        ('opt_recall', '.3f'),
            'optMCC':           ('opt_mcc', '.3f'),
            'optHSS':           ('opt_hss', '.3f'),
            'optPSS':           ('opt_pss', '.3f'),
            'optCSI':           ('opt_csi', '.3f'),
            'topFeature':       ('top_feature_name', 's'),
            'topFeaturePct':    ('top_feature_pct', '.1f'),
            'topThreePct':      ('top3_cumulative_pct', '.1f'),
            'bestR':            ('best_forecast_r2', '.3f'),
            'bestMAE':          ('best_forecast_mae', '.3f'),
            'bestBlF':          ('best_forecast_bl_f1', '.3f'),
            'earlyWarningPct':  ('pcrvi_early_warning_pct', '.0f'),
            'dhwUnderestPct':   ('dhw_underestimate_pct', '.0f'),
            'nEvents':          ('n_events_validated', 'd'),
            'totalDays':        ('total_days', ',d'),
            'pcrviMaxEver':     ('pcrvi_max_ever', '.3f'),
            'analysisYears':    ('analysis_years', 's'),
        }

        for cmd, (key, fmt) in macro_map.items():
            val = self.stats.get(key, '?')
            try:
                formatted = f'{val:{fmt}}'
            except (ValueError, TypeError):
                formatted = str(val)
            lines.append(f'\\newcommand{{\\{cmd}}}{{{formatted}}}')

        with open(self.paper_dir / "key_statistics.tex", 'w') as f:
            f.write('\n'.join(lines) + '\n')

        self.logger.info(f"  LaTeX macros: {len(macro_map)} commands written")
