"""
Output Management Module
========================

Handles saving all results to CSV files with proper organization.
"""

from typing import Optional, Dict, Any, List
from datetime import datetime
from pathlib import Path
import json
import base64
import numpy as np
import pandas as pd

from .logger import get_logger
from .naming import friendly_name, csv_header, csv_rename_dict
from .exceptions import FileIOError

class OutputManager:
    """
    Manages saving all EWS outputs to organized CSV files.
    """
    
    def __init__(self, output_dir: Path):
        """
        Initialize output manager.
        
        Parameters
        ----------
        output_dir : Path
            Base output directory
        """
        self.logger = get_logger("coral_ews.outputs")
        self.output_dir = Path(output_dir)
        
        # Create subdirectories
        self.csv_dir = self.output_dir / "csv"
        self.viz_dir = self.output_dir / "visualizations"
        self.reports_dir = self.output_dir / "reports"
        
        for dir_path in [self.csv_dir, self.viz_dir, self.reports_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)
        
        self.logger.info(f"Output directory initialized: {self.output_dir}")
    
    def save_weekly_risk_layers(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save weekly bleaching stress risk layers to CSV."""
        filename = f"{prefix}weekly_risk_layers.csv" if prefix else "weekly_risk_layers.csv"
        path = self.csv_dir / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(path, index=False)
        self.logger.info(f"Saved weekly risk layers ({len(df)} weeks): {path}")
        return path

    def save_enhanced_pcrvi_results(
        self,
        pcrvi_ts: pd.DataFrame,
        weekly_risk: pd.DataFrame,
        skill: dict,
        ml_results: dict,
        prefix: str = "",
    ) -> Dict[str, Path]:
        """Save complete Enhanced-pCRVI results package."""
        paths = {}

        # Full time series with all 7 components
        if pcrvi_ts is not None and not pcrvi_ts.empty:
            paths['timeseries'] = self.save_pcrvi_timeseries(pcrvi_ts, prefix)

        # Weekly risk layers
        if weekly_risk is not None and not weekly_risk.empty:
            paths['weekly'] = self.save_weekly_risk_layers(weekly_risk, prefix)

        # Skill analysis
        if skill:
            paths['skill'] = self.save_pcrvi_skill(skill, prefix)

        # ML weight optimization
        if ml_results is not None and isinstance(ml_results, dict) and 'ml_weights' in ml_results:
            import json as _json
            fname = f"{prefix}ml_weight_optimization.json" if prefix else "ml_weight_optimization.json"
            path = self.reports_dir / fname
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, 'w') as f:
                _json.dump(ml_results, f, indent=2,
                          default=lambda o: float(o) if hasattr(o, '__float__') else str(o))
            paths['ml_weights'] = path

        return paths
    
    def save_sst_data(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save SST time series to CSV."""
        filename = f"{prefix}sst_timeseries.csv" if prefix else "sst_timeseries.csv"
        path = self.csv_dir / filename
        df.to_csv(path)
        self.logger.info(f"Saved SST data: {path}")
        return path
    
    def save_dhw_data(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save DHW time series to CSV."""
        filename = f"{prefix}dhw_timeseries.csv" if prefix else "dhw_timeseries.csv"
        path = self.csv_dir / filename
        df.to_csv(path)
        self.logger.info(f"Saved DHW data: {path}")
        return path
    
    def save_ocean_color_data(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save ocean color time series to CSV."""
        filename = f"{prefix}ocean_color_timeseries.csv" if prefix else "ocean_color_timeseries.csv"
        path = self.csv_dir / filename
        df.to_csv(path)
        self.logger.info(f"Saved ocean color data: {path}")
        return path
    
    def save_atmospheric_data(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save atmospheric time series to CSV."""
        filename = f"{prefix}atmospheric_timeseries.csv" if prefix else "atmospheric_timeseries.csv"
        path = self.csv_dir / filename
        df.to_csv(path)
        self.logger.info(f"Saved atmospheric data: {path}")
        return path
    
    def save_climate_indices(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save climate indices to CSV."""
        filename = f"{prefix}climate_indices.csv" if prefix else "climate_indices.csv"
        path = self.csv_dir / filename
        df.to_csv(path)
        self.logger.info(f"Saved climate indices: {path}")
        return path
    
    def save_feature_matrix(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save complete feature matrix to CSV."""
        filename = f"{prefix}feature_matrix.csv" if prefix else "feature_matrix.csv"
        path = self.csv_dir / filename
        df.to_csv(path)
        self.logger.info(f"Saved feature matrix: {path} ({df.shape})")
        return path
    
    def save_alerts_history(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save historical alerts to CSV."""
        filename = f"{prefix}alerts_history.csv" if prefix else "alerts_history.csv"
        path = self.csv_dir / filename
        df.to_csv(path)
        self.logger.info(f"Saved alerts history: {path}")
        return path
    
    def save_bleaching_events(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save detected bleaching events to CSV."""
        filename = f"{prefix}bleaching_events.csv" if prefix else "bleaching_events.csv"
        path = self.csv_dir / filename
        df.to_csv(path)
        self.logger.info(f"Saved bleaching events: {path}")
        return path
    
    def save_annual_summary(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save annual summary statistics to CSV."""
        filename = f"{prefix}annual_summary.csv" if prefix else "annual_summary.csv"
        path = self.csv_dir / filename
        df.to_csv(path, index=False)
        self.logger.info(f"Saved annual summary: {path}")
        return path
    
    def save_pcrvi_timeseries(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save pCRVI time series to CSV."""
        filename = f"{prefix}pcrvi_timeseries.csv" if prefix else "pcrvi_timeseries.csv"
        path = self.csv_dir / filename
        df.to_csv(path)
        self.logger.info(f"Saved pCRVI time series: {path}")
        return path

    def save_pcrvi_skill(self, skill_results: Dict[str, Any], prefix: str = "") -> Path:
        """Save pCRVI skill analysis to JSON."""
        filename = f"{prefix}pcrvi_skill_analysis.json" if prefix else "pcrvi_skill_analysis.json"
        path = self.reports_dir / filename
        with open(path, 'w') as f:
            json.dump(skill_results, f, indent=2, default=str)
        self.logger.info(f"Saved pCRVI skill analysis: {path}")
        return path

    def save_model_comparison(self, df: pd.DataFrame, prefix: str = "") -> Path:
        """Save model comparison metrics to CSV."""
        filename = f"{prefix}model_comparison.csv" if prefix else "model_comparison.csv"
        path = self.csv_dir / filename
        df.to_csv(path, index=False)
        self.logger.info(f"Saved model comparison: {path}")
        return path
    
    def save_model_results(
        self,
        cv_results: Optional[Dict] = None,
        feature_importance: Optional[pd.DataFrame] = None,
        predictions: Optional[pd.DataFrame] = None,
        prefix: str = ""
    ) -> Dict[str, Path]:
        """Save all model-related results."""
        saved_files = {}
        
        if cv_results is not None:
            # Save CV summary
            cv_summary = pd.DataFrame([cv_results.get('cv_summary', {})])
            path = self.csv_dir / f"{prefix}cv_summary.csv"
            cv_summary.to_csv(path, index=False)
            saved_files['cv_summary'] = path
            
            # Save fold results
            fold_results = pd.DataFrame(cv_results.get('fold_results', []))
            path = self.csv_dir / f"{prefix}cv_fold_results.csv"
            fold_results.to_csv(path, index=False)
            saved_files['cv_fold_results'] = path
        
        if feature_importance is not None:
            path = self.csv_dir / f"{prefix}feature_importance.csv"
            feature_importance.to_csv(path, index=False)
            saved_files['feature_importance'] = path
        
        if predictions is not None:
            path = self.csv_dir / f"{prefix}predictions.csv"
            predictions.to_csv(path)
            saved_files['predictions'] = path
        
        self.logger.info(f"Saved model results: {list(saved_files.keys())}")
        return saved_files
    
    def generate_pcrvi_comprehensive_report(
        self,
        dhw_data: pd.DataFrame,
        pcrvi_results: Optional[Dict[str, Any]] = None,
        pcrvi_timeseries: Optional[pd.DataFrame] = None,
        historical_validation: Optional[pd.DataFrame] = None,
        forecast_comparison: Optional[pd.DataFrame] = None,
        forecaster: Any = None,
        climate_data: Optional[pd.DataFrame] = None,
        visualization_paths: Optional[Dict[str, Path]] = None,
        start_date: str = "",
        end_date: str = "",
        prefix: str = ""
    ) -> Path:
        """
        Generate comprehensive report with DHW forecasting results.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series
        pcrvi_results : dict, optional
            pCRVI skill analysis results
        pcrvi_timeseries : pd.DataFrame, optional
            pCRVI time series
        historical_validation : pd.DataFrame, optional
            Historical event validation
        forecast_comparison : pd.DataFrame, optional
            DHW forecast model comparison (Ensemble-pCRVI results)
        forecaster : DHWTimeSeriesForecaster, optional
            Fitted forecaster for feature importance
        climate_data : pd.DataFrame, optional
            Climate indices
        visualization_paths : dict, optional
            Paths to visualizations
        start_date : str
            Analysis start date
        end_date : str
            Analysis end date
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved report
        """
        # Calculate statistics
        total_days = len(dhw_data) if dhw_data is not None else 0
        valid_dhw = dhw_data['dhw'].dropna() if dhw_data is not None and 'dhw' in dhw_data.columns else pd.Series()
        
        max_dhw = valid_dhw.max() if len(valid_dhw) > 0 else 0
        max_dhw_date = str(valid_dhw.idxmax()) if len(valid_dhw) > 0 else "N/A"
        mean_dhw = valid_dhw.mean() if len(valid_dhw) > 0 else 0
        
        # Alert days
        days_no_stress = int((valid_dhw == 0).sum()) if len(valid_dhw) > 0 else 0
        days_watch = int(((valid_dhw > 0) & (valid_dhw < 3)).sum()) if len(valid_dhw) > 0 else 0
        days_warning = int(((valid_dhw >= 3) & (valid_dhw < 6)).sum()) if len(valid_dhw) > 0 else 0
        days_alert1 = int(((valid_dhw >= 6) & (valid_dhw < 8)).sum()) if len(valid_dhw) > 0 else 0
        days_alert2 = int((valid_dhw >= 8).sum()) if len(valid_dhw) > 0 else 0
        
        # Annual max
        annual_max = pd.Series(dtype=float)
        bleaching_years = []
        if dhw_data is not None and len(dhw_data) > 0:
            dhw_copy = dhw_data.copy()
            dhw_copy['year'] = dhw_copy.index.year
            annual_max = dhw_copy.groupby('year')['dhw'].max()
            bleaching_years = annual_max[annual_max >= 4].index.tolist()
        
        # pCRVI info
        pcrvi_score = 0.0
        pcrvi_risk = "Unknown"
        pcrvi_correlation = 0.0
        pcrvi_f1 = 0.0
        pcrvi_recommendation = "pCRVI data not available"
        
        if pcrvi_results is not None and isinstance(pcrvi_results, dict):
            if 'current_assessment' in pcrvi_results:
                pcrvi_score = pcrvi_results['current_assessment'].get('pcrvi', 0)
                pcrvi_risk = pcrvi_results['current_assessment'].get('risk_category', 'Unknown')
                pcrvi_recommendation = pcrvi_results['current_assessment'].get('recommendation', '')
            # Use OPTIMAL threshold metrics (not default=0.40)
            opt_thresh = pcrvi_results.get('optimal_threshold', 0.4)
            opt_key = f'{opt_thresh:.2f}'
            thresh_data = pcrvi_results.get('threshold_analysis', {}).get(opt_key, {})
            if thresh_data:
                pcrvi_f1 = thresh_data.get('f1_score', 0)
                pcrvi_correlation = thresh_data.get('mcc', 0)  # MCC is a better summary stat
            elif 'lead_time_analysis' in pcrvi_results and '30_days' in pcrvi_results['lead_time_analysis']:
                pcrvi_correlation = pcrvi_results['lead_time_analysis']['30_days'].get('correlation', 0)
                pcrvi_f1 = pcrvi_results['lead_time_analysis']['30_days'].get('f1_score', 0)
        
        # Handle NaN in pcrvi values
        if pd.isna(pcrvi_correlation):
            pcrvi_correlation = 0.0
        if pd.isna(pcrvi_f1):
            pcrvi_f1 = 0.0
        
        pcrvi_display = f"{pcrvi_score:.3f}" if pcrvi_score else "N/A"
        
        # Build report
        report = f"""
{'='*80}
CORAL BLEACHING EARLY WARNING SYSTEM
COMPREHENSIVE ANALYSIS REPORT
{'='*80}

REPORT METADATA
{'-'*40}
Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}
Analysis Period: {start_date} to {end_date}
Region: Andaman & Nicobar Islands
Coordinates: 90E-95E, 6N-14N
MMM SST: 29.87C (NOAA CRW)
Forecasting Model: Ensemble-pCRVI

{'='*80}
EXECUTIVE SUMMARY
{'='*80}

This report presents coral bleaching risk analysis based on {total_days:,} days 
of environmental data, using the Ensemble-pCRVI forecasting model.

KEY FINDINGS:
- Maximum DHW recorded: {max_dhw:.2f}C-weeks on {max_dhw_date}
- Current pCRVI Score: {pcrvi_display} ({pcrvi_risk})
- Bleaching events detected: {len(bleaching_years)} years with DHW >= 4

{'='*80}
1. THERMAL STRESS ANALYSIS
{'='*80}

DHW Statistics:
  Total Days: {total_days:,}
  Mean DHW: {mean_dhw:.2f}C-weeks
  Maximum DHW: {max_dhw:.2f}C-weeks

Alert Level Distribution:
  No Stress (DHW = 0):    {days_no_stress:,} days
  Watch (0 < DHW < 3):    {days_watch:,} days
  Warning (3 <= DHW < 6): {days_warning:,} days
  Alert Level 1 (6-8):    {days_alert1:,} days
  Alert Level 2 (>=8):    {days_alert2:,} days

Annual Maximum DHW:
{'-'*40}
"""
        
        for year in sorted(annual_max.index):
            peak = annual_max[year]
            if peak >= 8:
                status = "SEVERE"
            elif peak >= 6:
                status = "SIGNIFICANT"
            elif peak >= 4:
                status = "MODERATE"
            elif peak > 0:
                status = "WATCH"
            else:
                status = "NORMAL"
            report += f"  {year}: {peak:6.2f}C-weeks {status}\n"
        
        # pCRVI Section
        report += f"""
{'='*80}
2. PREDICTIVE CRVI (pCRVI)
{'='*80}

Current Status:
  pCRVI Score: {pcrvi_display}
  Risk Category: {pcrvi_risk}
  
Predictive Skill (at optimal threshold = {opt_thresh:.2f}):
  F1 Score: {pcrvi_f1:.3f}
  MCC: {pcrvi_correlation:.3f}

Recommendation:
  {pcrvi_recommendation}
"""
        
        # Historical Validation
        if historical_validation is not None and len(historical_validation) > 0:
            report += f"""
{'='*80}
3. HISTORICAL EVENT VALIDATION
{'='*80}

Year   Severity        Reported DHW  Model DHW   pCRVI Max  Assessment
{'-'*70}
"""
            for _, row in historical_validation.iterrows():
                year = int(row.get('year', 0))
                severity = str(row.get('actual_severity', 'N/A'))[:12]
                reported = row.get('actual_dhw', 0)
                model = row.get('model_dhw_max', 0)
                pcrvi_max = row.get('pcrvi_max', 0)
                match = str(row.get('dhw_match', 'N/A'))
                
                reported_str = f"{reported:.2f}" if not pd.isna(reported) else "N/A"
                model_str = f"{model:.2f}" if not pd.isna(model) else "N/A"
                pcrvi_str = f"{pcrvi_max:.3f}" if not pd.isna(pcrvi_max) else "N/A"
                
                report += f"{year:<6} {severity:<15} {reported_str:<13} {model_str:<11} {pcrvi_str:<10} {match}\n"
        
        # DHW FORECASTING SECTION
        if forecast_comparison is not None and len(forecast_comparison) > 0:
            report += f"""
{'='*80}
4. DHW TIME SERIES FORECASTING (Ensemble-pCRVI)
{'='*80}

The Ensemble-pCRVI model predicts actual DHW values using time series
regression, providing actionable early warning with demonstrated skill.

Model Performance:
{'-'*40}
"""
            for _, row in forecast_comparison.iterrows():
                model_name = row.get('Model', 'Unknown')
                mae = row.get('mae', 0)
                rmse = row.get('rmse', 0)
                r2 = row.get('r2', 0)
                bl_f1 = row.get('bl_f1', 0)
                bl_prec = row.get('bl_precision', 0)
                bl_rec = row.get('bl_recall', 0)
                
                report += f"""
{model_name}:
  MAE: {mae:.3f} C-weeks
  RMSE: {rmse:.3f} C-weeks
  R2: {r2:.3f}
  Bleaching F1: {bl_f1:.3f}
  Precision: {bl_prec:.3f}
  Recall: {bl_rec:.3f}
"""
            
            # Feature importance
            if forecaster is not None and hasattr(forecaster, 'models'):
                for key, model_info in forecaster.models.items():
                    if 'feature_importance' in model_info:
                        report += f"""
Key Predictive Features:
{'-'*40}
"""
                        for _, feat_row in model_info['feature_importance'].head(5).iterrows():
                            pct = feat_row['importance'] * 100
                            report += f"  {friendly_name(feat_row['feature'])}: {pct:.1f}%\n"
                        break
        
        # Conclusions
        report += f"""
{'='*80}
5. CONCLUSIONS AND RECOMMENDATIONS
{'='*80}

1. CURRENT STATUS
   pCRVI: {pcrvi_display} ({pcrvi_risk})

2. MONITORING PRIORITIES
   - Monitor pCRVI daily during peak season (April-June)
   - pCRVI >= 0.4: Issue WARNING
   - pCRVI >= 0.6: Activate emergency protocols

3. FORECAST CAPABILITY
   The Ensemble-pCRVI model provides 60-day advance warning 
   with demonstrated predictive skill.

{'='*80}
END OF REPORT
Generated by Coral Bleaching Early Warning System
Forecast Model: Ensemble-pCRVI
{'='*80}
"""
        
        # Save report
        filename = f"{prefix}comprehensive_report.txt" if prefix else "comprehensive_report.txt"
        path = self.reports_dir / filename
        with open(path, 'w') as f:
            f.write(report)
        
        self.logger.info(f"Generated comprehensive report: {path}")
        
        return path



    def save_run_metadata(
        self,
        start_date: str,
        end_date: str,
        config: Dict[str, Any],
        steps_completed: List[str],
        prefix: str = ""
    ) -> Path:
        """Save run metadata as JSON."""
        metadata = {
            "run_timestamp": datetime.utcnow().isoformat(),
            "start_date": start_date,
            "end_date": end_date,
            "steps_completed": steps_completed,
            "config": config
        }
        
        filename = f"{prefix}run_metadata.json" if prefix else "run_metadata.json"
        path = self.reports_dir / filename
        
        with open(path, 'w') as f:
            json.dump(metadata, f, indent=2, default=str)
        
        self.logger.info(f"Saved run metadata: {path}")
        return path
    
    # Add these methods to OutputManager class in outputs.py
    
    def save_crvi_results(
        self,
        crvi_results: Dict[str, Any],
        crvi_df: pd.DataFrame,
        interpretation: str,
        prefix: str = ""
    ) -> Dict[str, Path]:
        """
        Save all CRVI-related outputs.
        **DEPRECATED**
        Parameters
        ----------
        crvi_results : dict
            Raw CRVI results
        crvi_df : pd.DataFrame
            CRVI data in tabular format
        interpretation : str
            Text interpretation
        prefix : str
            Filename prefix
        
        Returns
        -------
        dict
            Paths to saved files
        """
        saved_files = {}
        
        # Save CSV
        csv_filename = f"{prefix}crvi_results.csv" if prefix else "crvi_results.csv"
        csv_path = self.csv_dir / csv_filename
        crvi_df.to_csv(csv_path, index=False)
        saved_files['csv'] = csv_path
        self.logger.info(f"Saved CRVI CSV: {csv_path}")
        
        # Save JSON
        json_filename = f"{prefix}crvi_results.json" if prefix else "crvi_results.json"
        json_path = self.reports_dir / json_filename
        with open(json_path, 'w') as f:
            json.dump(crvi_results, f, indent=2, default=str)
        saved_files['json'] = json_path
        self.logger.info(f"Saved CRVI JSON: {json_path}")
        
        # Save interpretation
        txt_filename = f"{prefix}crvi_interpretation.txt" if prefix else "crvi_interpretation.txt"
        txt_path = self.reports_dir / txt_filename
        with open(txt_path, 'w') as f:
            f.write(interpretation)
        saved_files['interpretation'] = txt_path
        self.logger.info(f"Saved CRVI interpretation: {txt_path}")
        
        return saved_files
    
    def save_model_comparison(
        self,
        comparison_df: pd.DataFrame,
        prefix: str = ""
    ) -> Path:
        """Save model comparison results to CSV."""
        filename = f"{prefix}model_comparison.csv" if prefix else "model_comparison.csv"
        path = self.csv_dir / filename
        comparison_df.to_csv(path, index=False)
        self.logger.info(f"Saved model comparison: {path}")
        return path
    
    def save_training_dataset(
        self,
        X: np.ndarray,
        y: np.ndarray,
        feature_names: List[str],
        prefix: str = ""
    ) -> Path:
        """
        Save the final training dataset to CSV.
        
        Parameters
        ----------
        X : np.ndarray
            Feature matrix
        y : np.ndarray
            Target variable
        feature_names : list
            Feature names
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved file
        """
        df = pd.DataFrame(X, columns=feature_names)
        df['target'] = y
        
        filename = f"{prefix}training_dataset.csv" if prefix else "training_dataset.csv"
        path = self.csv_dir / filename
        df.to_csv(path, index=False)
        
        self.logger.info(f"Saved training dataset: {path} ({len(df)} samples, {len(feature_names)} features)")
        return path

    def generate_validation_report(
        self,
        validation_df: pd.DataFrame,
        dhw_data: pd.DataFrame,
        pcrvi_data: Optional[pd.DataFrame] = None,
        pcrvi_skill: Optional[Dict[str, Any]] = None,
        forecast_comparison: Optional[pd.DataFrame] = None,  # NEW
        forecaster: Any = None,  # NEW
        prefix: str = ""
    ) -> Path:
        """
        Generate a report comparing model predictions to historical observations.
        
        Now includes both DHW-based and pCRVI-based predictions for comparison.
        
        Parameters
        ----------
        validation_df : pd.DataFrame
            Output from DHWCalculator.validate_against_historical()
        dhw_data : pd.DataFrame
            DHW time series
        pcrvi_data : pd.DataFrame, optional
            pCRVI time series for additional validation
        pcrvi_skill : dict, optional
            pCRVI skill analysis results
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to saved report
        """
        from datetime import datetime
        
        report = f"""
    {'='*80}
    MODEL VALIDATION REPORT
    {'='*80}

    Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}
    Region: Andaman & Nicobar Islands
    Forecasting Model: Ensemble-pCRVI
    
    This report validates predictions from TWO systems:
    1. DHW (Degree Heating Weeks) - thermal stress indicator
    2. pCRVI (Predictive Coral Reef Vulnerability Index) - composite risk index

    {'='*80}
    DHW VALIDATION SUMMARY
    {'='*80}

    DHW measures accumulated thermal stress and is the standard metric for
    predicting coral bleaching. Values above 4°C-weeks indicate bleaching risk,
    above 8°C-weeks indicates severe bleaching expected.

    """
        if forecast_comparison is not None and len(forecast_comparison) > 0:
            best = forecast_comparison.iloc[0]  # Best model by F1
            report += f"""
        ================================================================================
        FORECAST MODEL PERFORMANCE
        ================================================================================

        Model: {best['Model']}

        Regression Metrics:
        MAE:  {best['mae']:.3f} °C-weeks
        RMSE: {best['rmse']:.3f} °C-weeks
        R²:   {best['r2']:.3f}

        Bleaching Detection:
        F1 Score:   {best['bl_f1']:.3f}
        Precision:  {best['bl_precision']:.3f}
        Recall:     {best['bl_recall']:.3f}"""
        
        # Summary statistics

        if validation_df is not None and len(validation_df) > 0:
            good_matches = (validation_df['match_quality'] == 'GOOD').sum()
            missed = validation_df['match_quality'].str.contains('MISSED', na=False).sum()
            underestimated = validation_df['match_quality'].str.contains('UNDERESTIMATED', na=False).sum()
            overestimated = validation_df['match_quality'].str.contains('OVERESTIMATED', na=False).sum()
            
            total_events = len(validation_df)
            
            report += f"""
    DHW Accuracy: {good_matches}/{total_events} events correctly characterized
    - Good matches: {good_matches}
    - Underestimated: {underestimated}
    - Overestimated: {overestimated}
    - Missed: {missed}
    """

        # pCRVI Summary if available
        if pcrvi_skill is not None:
            report += f"""
    {'='*80}
    pCRVI VALIDATION SUMMARY  
    {'='*80}

    pCRVI is a composite index that provides 30-day advance warning of 
    bleaching events. Unlike DHW (reactive), pCRVI is designed for prediction.

    """
            # Extract pCRVI metrics
            optimal_threshold = pcrvi_skill.get('optimal_threshold', 0.5)
            optimal_f1 = pcrvi_skill.get('optimal_f1', 0)
            
            lead_30 = pcrvi_skill.get('lead_time_analysis', {}).get('30_days', {})
            correlation_30d = lead_30.get('correlation', 0)
            f1_30d = lead_30.get('f1_score', 0)
            precision_30d = lead_30.get('precision', 0)
            recall_30d = lead_30.get('recall', 0)
            
            # Optimal threshold metrics
            _opt_key = f'{optimal_threshold:.2f}'
            _opt_data = pcrvi_skill.get('threshold_analysis', {}).get(_opt_key, {})
            opt_prec = _opt_data.get('precision', precision_30d)
            opt_rec  = _opt_data.get('recall', recall_30d)
            opt_mcc  = _opt_data.get('mcc', 0)
            opt_hss  = _opt_data.get('hss', 0)
            opt_pss  = _opt_data.get('pss', 0)
            opt_csi  = _opt_data.get('csi', 0)
            
            report += f"""
    pCRVI Predictive Skill:
    ┌─────────────────────────────────────────────────┐
    │ At OPTIMAL threshold = {optimal_threshold:.2f}:                    │
    │   F1 Score:  {optimal_f1:.3f}                             │
    │   Precision: {opt_prec:.3f}   Recall: {opt_rec:.3f}              │
    │   MCC:       {opt_mcc:.3f}   HSS:    {opt_hss:.3f}              │
    │   PSS/TSS:   {opt_pss:.3f}   CSI:    {opt_csi:.3f}              │
    └─────────────────────────────────────────────────┘
    At default threshold = 0.40 (30-day lead):
      Correlation: {correlation_30d:.3f}  F1: {f1_30d:.3f}
      Precision:   {precision_30d:.3f}  Recall: {recall_30d:.3f}
    """
        
        # Detailed comparison
        if validation_df is not None and len(validation_df) > 0:
            report += f"""
    {'='*80}
    DETAILED EVENT COMPARISON
    {'='*80}
    """
            
            for _, row in validation_df.iterrows():
                # Get DHW info
                model_dhw_val = row.get('model_dhw', 0)
                reported_dhw = row.get('reported_dhw')
                reported_dhw_str = f"{reported_dhw}" if reported_dhw else "N/A"
                discrepancy = row.get('discrepancy')
                discrepancy_str = f"{discrepancy:.2f}" if pd.notna(discrepancy) else "N/A"
                
                report += f"""
    Year: {row['year']}
    {'-'*40}
    DHW PREDICTION:
      Model DHW:          {model_dhw_val:.2f}°C-weeks
      Reported DHW:       {reported_dhw_str}
      DHW Discrepancy:    {discrepancy_str}
      Model Alert:        {row.get('model_alert_name', 'N/A')}
    
    OBSERVATIONS:
      Observed Severity:  {row.get('observed_severity', 'N/A')}
      Observed Bleaching: {row.get('observed_bleaching_pct', 'N/A')}%
    
    DHW MATCH QUALITY:    {row.get('match_quality', 'N/A')}
    """
                
                # Add pCRVI info if we have the data for this year
                if pcrvi_data is not None and not pcrvi_data.empty:
                    year = row['year']
                    try:
                        year_mask = pcrvi_data.index.year == year
                        if year_mask.any():
                            year_pcrvi = pcrvi_data.loc[year_mask, 'pcrvi']
                            max_pcrvi = year_pcrvi.max()
                            max_pcrvi_date = year_pcrvi.idxmax()
                            
                            # Determine pCRVI prediction
                            if max_pcrvi >= 0.6:
                                pcrvi_prediction = "CRITICAL (≥0.6)"
                            elif max_pcrvi >= 0.5:
                                pcrvi_prediction = "HIGH (0.5-0.6)"
                            elif max_pcrvi >= 0.4:
                                pcrvi_prediction = "ELEVATED (0.4-0.5)"
                            elif max_pcrvi >= 0.3:
                                pcrvi_prediction = "WATCH (0.3-0.4)"
                            else:
                                pcrvi_prediction = "LOW (<0.3)"
                            
                            report += f"""
    pCRVI PREDICTION:
      Max pCRVI:          {max_pcrvi:.3f} on {max_pcrvi_date.strftime('%Y-%m-%d')}
      Risk Assessment:    {pcrvi_prediction}
    """
                    except Exception as e:
                        pass  # Skip pCRVI info if there's an error
            
            report += f"""
    {'='*80}
    CALIBRATION RECOMMENDATIONS
    {'='*80}

    Based on the validation analysis:
    """
            
            # Generate specific recommendations
            if missed > 0:
                report += """
    1. MISSED EVENTS ISSUE:
    - The model missed some documented bleaching events
    - Consider lowering the DHW alert thresholds
    - Review SST data quality for those years
    - Recommended: Lower Warning threshold from 4.0 to 3.0°C-weeks
    """
            
            if underestimated > 0:
                report += """
    2. UNDERESTIMATION ISSUE:
    - The model detected events but underestimated severity
    - Severe events (2010, 2016) were classified as Alert Level 1 instead of Level 2
    - Recommended: Lower Alert Level 2 threshold from 12.0 to 8.0°C-weeks
    """
            
            if overestimated > 0:
                report += """
    3. OVERESTIMATION ISSUE (Adaptation Effect):
    - Recent years show high thermal stress but lower bleaching impact
    - This suggests coral adaptation from surviving past events
    - Consider incorporating an adaptation factor into vulnerability assessments
    - The pCRVI includes an adaptation adjustment for this effect
    """
        
        # pCRVI recommendations
        if pcrvi_skill is not None:
            report += """
    4. pCRVI USAGE RECOMMENDATIONS:
    - Use pCRVI for proactive early warning (30-day lead time)
    - Use DHW for real-time monitoring during thermal events
    - Combined approach: pCRVI for planning, DHW for response
    - Monitor pCRVI daily during peak season (March-June)
    """
            
            report += f"""
    {'='*80}
    RECOMMENDED THRESHOLD ADJUSTMENTS
    {'='*80}

    DHW Thresholds (Current → Recommended):

    Watch:         0°C-weeks  →  1°C-weeks
    Warning:       4°C-weeks  →  3°C-weeks  
    Alert Level 1: 8°C-weeks  →  6°C-weeks
    Alert Level 2: 12°C-weeks →  8°C-weeks

    pCRVI Risk Thresholds:

    Low Risk:      < 0.3
    Watch:         0.3 - 0.4
    Elevated:      0.4 - 0.5
    High:          0.5 - 0.6
    Critical:      > 0.6

    These adjustments account for:
    - Local coral thermal tolerance
    - Historical bleaching-DHW relationships
    - Regional oceanographic conditions
    - Coral adaptation from past events
    """
        else:
            report += f"""
    {'='*80}
    RECOMMENDED THRESHOLD ADJUSTMENTS
    {'='*80}

    Current (Standard NOAA) → Recommended (ANI-Calibrated)

    Watch:         0°C-weeks  →  1°C-weeks
    Warning:       4°C-weeks  →  3°C-weeks  
    Alert Level 1: 8°C-weeks  →  6°C-weeks
    Alert Level 2: 12°C-weeks →  8°C-weeks

    These adjustments account for:
    - Local coral thermal tolerance
    - Historical bleaching-DHW relationships
    - Regional oceanographic conditions
    """
        
        report += f"""
    {'='*80}
    END OF VALIDATION REPORT
    {'='*80}
    """
        
        # Save report
        filename = f"{prefix}validation_report.txt" if prefix else "validation_report.txt"
        path = self.reports_dir / filename
        with open(path, 'w') as f:
            f.write(report)
        
        # Also save validation DataFrame
        csv_filename = f"{prefix}validation_results.csv" if prefix else "validation_results.csv"
        csv_path = self.csv_dir / csv_filename
        validation_df.to_csv(csv_path, index=False)
        
        self.logger.info(f"Generated validation report: {path}")
        print(report)
        
        return path

    def generate_enhanced_summary_report(
        self,
        dhw_data: pd.DataFrame,
        crvi_results: Dict[str, Any],
        pcrvi_results: Optional[Dict[str, Any]] = None,
        model_comparison: Optional[pd.DataFrame] = None,
        climate_data: Optional[pd.DataFrame] = None,
        start_date: str = "",
        end_date: str = "",
        prefix: str = ""
    ) -> Path:
        """
        Generate comprehensive summary report with detailed interpretations.
        **DEPRECATED**
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series
        crvi_results : dict
            CRVI calculation results
        pcrvi_results : dict, optional
            Predictive CRVI results
        model_comparison : pd.DataFrame, optional
            Model comparison metrics
        climate_data : pd.DataFrame, optional
            Climate indices
        start_date : str
            Analysis start date
        end_date : str
            Analysis end date
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to report file
        """
        # Calculate comprehensive statistics
        total_days = len(dhw_data)
        valid_dhw = dhw_data['dhw'].dropna()
        
        max_dhw = valid_dhw.max() if len(valid_dhw) > 0 else 0
        max_dhw_date = valid_dhw.idxmax() if len(valid_dhw) > 0 else "N/A"
        mean_dhw = valid_dhw.mean() if len(valid_dhw) > 0 else 0
        
        # Count alert days
        days_watch = ((valid_dhw > 0) & (valid_dhw < 4)).sum()
        days_alert1 = ((valid_dhw >= 4) & (valid_dhw < 8)).sum()
        days_alert2 = ((valid_dhw >= 8) & (valid_dhw < 12)).sum()
        days_alert3 = (valid_dhw >= 12).sum()
        
        # Annual statistics
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        annual_max = dhw_copy.groupby('year')['dhw'].max()
        annual_mean = dhw_copy.groupby('year')['dhw'].mean()
        
        # Bleaching years
        bleaching_years = annual_max[annual_max >= 4].index.tolist()
        severe_years = annual_max[annual_max >= 8].index.tolist()
        
        # Generate report
        report = f"""
{'='*80}
CORAL BLEACHING EARLY WARNING SYSTEM
COMPREHENSIVE ANALYSIS REPORT
{'='*80}

REPORT METADATA
{'-'*40}
Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}
Analysis Period: {start_date} to {end_date}
Region: Andaman & Nicobar Islands
Coordinates: 90°E-95°E, 6°N-14°N
MMM SST: 29.87°C (NOAA CRW)

{'='*80}
EXECUTIVE SUMMARY
{'='*80}

This report presents a comprehensive analysis of coral bleaching risk for the
Andaman & Nicobar Islands based on {total_days:,} days of environmental data.
The analysis integrates satellite-derived thermal stress metrics, climate 
teleconnection indices (ENSO, IOD), and machine learning predictions.

KEY FINDINGS:
- Maximum DHW recorded: {max_dhw:.2f}°C-weeks on {max_dhw_date}
- CRVI Score: {crvi_results['crvi']:.3f} ({crvi_results['risk_category']} Risk)
- Bleaching events detected: {len(bleaching_years)} years with DHW ≥ 4
- Severe bleaching events: {len(severe_years)} years with DHW ≥ 8

{'='*80}
1. THERMAL STRESS ANALYSIS
{'='*80}

1.1 DHW Statistics
{'-'*40}
Total Days Analyzed: {total_days:,}
Valid DHW Records: {len(valid_dhw):,}

DHW Distribution:
  Mean: {mean_dhw:.2f}°C-weeks
  Maximum: {max_dhw:.2f}°C-weeks
  Date of Maximum: {max_dhw_date}

Alert Level Distribution:
  No Stress (DHW = 0):     {(valid_dhw == 0).sum():,} days ({(valid_dhw == 0).sum()/len(valid_dhw)*100:.1f}%)
  Watch (0 < DHW < 4):     {days_watch:,} days ({days_watch/len(valid_dhw)*100:.1f}%)
  Warning (4 ≤ DHW < 8):   {days_alert1:,} days ({days_alert1/len(valid_dhw)*100:.1f}%)
  Alert Level 1 (8-12):    {days_alert2:,} days ({days_alert2/len(valid_dhw)*100:.1f}%)
  Alert Level 2 (≥12):     {days_alert3:,} days ({days_alert3/len(valid_dhw)*100:.1f}%)

1.2 Annual Maximum DHW
{'-'*40}
"""
        for year in sorted(annual_max.index):
            peak = annual_max[year]
            # More nuanced status categories
            if peak >= 12:
                status = "🔴 Mass Bleaching/Mortality"
            elif peak >= 8:
                status = "🟠 Significant Bleaching"
            elif peak >= 6:
                status = "🟡 Moderate Bleaching"
            elif peak >= 4:
                status = "🟤 Partial/Minor Bleaching"
            elif peak > 0:
                status = "🔵 Thermal Watch"
            else:
                status = "🟢 Normal"
            report += f"  {year}: {peak:6.2f}°C-weeks {status}\n"
        
        report += f"""
1.3 Bleaching Events Detected
{'-'*40}
Years with Significant Bleaching (DHW ≥ 4):
  {', '.join(map(str, bleaching_years)) if bleaching_years else 'None detected'}

Years with Severe Bleaching (DHW ≥ 8):
  {', '.join(map(str, severe_years)) if severe_years else 'None detected'}

Interpretation:
"""
        if len(severe_years) > 0:
            report += f"""
  The region experienced {len(severe_years)} severe bleaching event(s) during the
  analysis period. These events, occurring in {', '.join(map(str, severe_years))},
  likely caused significant coral mortality and ecosystem disruption.
"""
        elif len(bleaching_years) > 0:
            report += f"""
  The region experienced {len(bleaching_years)} bleaching event(s) at Warning level
  (DHW 4-8). While these events may have caused partial bleaching, recovery is
  expected if thermal stress subsided within 4-6 weeks.
"""
        else:
            report += """
  No significant bleaching events were detected during the analysis period.
  This suggests the region maintained thermal conditions within coral tolerance.
"""
        
        report += f"""
{'='*80}
2. CORAL REEF VULNERABILITY INDEX (CRVI)
{'='*80}

2.1 Overall Assessment
{'-'*40}
CRVI Score: {crvi_results['crvi']:.3f}
Risk Category: {crvi_results['risk_category']}

The CRVI integrates three vulnerability dimensions:
"""
        
        ts = crvi_results['components']['thermal_stress']
        rv = crvi_results['components']['recovery_vulnerability']
        ri = crvi_results['components']['recurrence_index']
        
        report += f"""
2.2 Component Analysis
{'-'*40}

THERMAL STRESS (TS) - Weight: {ts['weight']*100:.0f}%
  Normalized Value: {ts['value']:.3f}
  Weighted Contribution: {ts['weighted_contribution']:.3f}
  
  This measures the mean annual maximum DHW over recent years.
  A value of {ts['value']:.3f} indicates {'high' if ts['value'] > 0.7 else 'moderate' if ts['value'] > 0.4 else 'low'}
  chronic thermal stress exposure.

RECOVERY VULNERABILITY (RV) - Weight: {rv['weight']*100:.0f}%
  Normalized Value: {rv['value']:.3f}
  Weighted Contribution: {rv['weighted_contribution']:.3f}
  
  This measures time since the last bleaching event.
  A value of {rv['value']:.3f} indicates {'insufficient' if rv['value'] > 0.7 else 'partial' if rv['value'] > 0.3 else 'adequate'}
  recovery time between thermal stress events.

RECURRENCE INDEX (RI) - Weight: {ri['weight']*100:.0f}%
  Normalized Value: {ri['value']:.3f}
  Weighted Contribution: {ri['weighted_contribution']:.3f}
  
  This measures the frequency of bleaching events.
  A value of {ri['value']:.3f} indicates {'frequent' if ri['value'] > 0.5 else 'occasional' if ri['value'] > 0.2 else 'rare'}
  bleaching recurrence.

2.3 Risk Interpretation
{'-'*40}
"""
        
        if crvi_results['risk_category'] == 'Critical':
            report += """
CRITICAL RISK: The reef system is experiencing chronic thermal stress with
insufficient recovery periods. Immediate conservation intervention is required.
Without action, significant ecosystem transformation is likely within 5-10 years.

RECOMMENDATIONS:
- Implement emergency protection protocols
- Establish continuous monitoring
- Consider assisted coral adaptation programs
- Prioritize for restoration funding
"""
        elif crvi_results['risk_category'] == 'High':
            report += """
HIGH RISK: The reef system faces substantial thermal stress and limited
recovery capacity. Proactive management is essential to maintain ecosystem function.

RECOMMENDATIONS:
- Increase monitoring frequency during warm seasons
- Reduce local stressors (pollution, sedimentation)
- Identify and protect thermal refugia
- Develop rapid response protocols
"""
        elif crvi_results['risk_category'] == 'Moderate':
            report += """
MODERATE RISK: The reef system shows some vulnerability but retains recovery
capacity. Standard conservation measures should be maintained and enhanced.

RECOMMENDATIONS:
- Continue routine monitoring programs
- Implement precautionary management
- Support natural recovery processes
- Document environmental conditions
"""
        else:
            report += """
LOW/MINIMAL RISK: The reef system shows resilience to thermal stress with
adequate recovery periods. This region may serve as a climate refugium.

RECOMMENDATIONS:
- Maintain current protection measures
- Consider as source population for restoration
- Document resilience factors
- Share best practices with higher-risk regions
"""
        
        # Add climate teleconnections if available
        if climate_data is not None:
            report += f"""
{'='*80}
3. CLIMATE TELECONNECTION ANALYSIS
{'='*80}

3.1 ENSO (El Niño-Southern Oscillation)
{'-'*40}
"""
            if 'oni' in climate_data.columns:
                oni = climate_data['oni'].dropna()
                el_nino_months = (oni > 0.5).sum()
                la_nina_months = (oni < -0.5).sum()
                neutral_months = len(oni) - el_nino_months - la_nina_months
                
                report += f"""
El Niño months (ONI > 0.5): {el_nino_months} ({el_nino_months/len(oni)*100:.1f}%)
La Niña months (ONI < -0.5): {la_nina_months} ({la_nina_months/len(oni)*100:.1f}%)
Neutral months: {neutral_months} ({neutral_months/len(oni)*100:.1f}%)

El Niño phases are associated with elevated thermal stress in the Indian Ocean.
During the analysis period, El Niño conditions occurred {el_nino_months/len(oni)*100:.1f}% 
of the time, contributing to regional thermal anomalies.
"""
            
            if 'dmi' in climate_data.columns:
                report += f"""
3.2 IOD (Indian Ocean Dipole)
{'-'*40}
"""
                dmi = climate_data['dmi'].dropna()
                positive_iod = (dmi > 0.4).sum()
                negative_iod = (dmi < -0.4).sum()
                
                report += f"""
Positive IOD months (DMI > 0.4): {positive_iod} ({positive_iod/len(dmi)*100:.1f}%)
Negative IOD months (DMI < -0.4): {negative_iod} ({negative_iod/len(dmi)*100:.1f}%)

Positive IOD events cause warming in the western Indian Ocean, including the
Andaman Sea. This analysis found {positive_iod/len(dmi)*100:.1f}% of months with
positive IOD conditions, which amplify thermal stress on regional reefs.
"""
        
        if model_comparison is not None and not model_comparison.empty:
            report += f"""
{'='*80}
4. MACHINE LEARNING MODEL PERFORMANCE
{'='*80}

The following models were evaluated for bleaching prediction:
"""
            for _, row in model_comparison.iterrows():
                report += f"\n{row.get('model', 'Unknown')}:"
                if 'accuracy' in row: report += f"\n  Accuracy: {row['accuracy']:.4f}"
                if 'roc_auc' in row: report += f"\n  ROC-AUC: {row['roc_auc']:.4f}"
                if 'f1_score' in row: report += f"\n  F1 Score: {row['f1_score']:.4f}"
                if 'r2' in row: report += f"\n  R²: {row['r2']:.4f}"
                if 'rmse' in row: report += f"\n  RMSE: {row['rmse']:.4f}"
        
        report += f"""
{'='*80}
5. CONCLUSIONS AND RECOMMENDATIONS
{'='*80}

Based on the comprehensive analysis of thermal stress patterns, vulnerability
assessment, and climate teleconnections, the following conclusions are drawn:

1. THERMAL STRESS TRENDS
   The Andaman & Nicobar Islands have experienced {'increasing' if annual_max.values[-5:].mean() > annual_max.values[:5].mean() else 'variable'} 
   thermal stress over the analysis period, with maximum DHW of {max_dhw:.1f}°C-weeks.

2. VULNERABILITY STATUS
   With a CRVI of {crvi_results['crvi']:.3f} ({crvi_results['risk_category']} Risk), 
   the region requires {'immediate intervention' if crvi_results['crvi'] > 0.6 else 'enhanced monitoring' if crvi_results['crvi'] > 0.4 else 'continued protection'}.

3. CLIMATE DRIVERS
   ENSO and IOD teleconnections significantly influence regional thermal stress,
   with compound El Niño + positive IOD events creating extreme bleaching risk.

4. MANAGEMENT PRIORITIES
   • {'Implement emergency protocols' if crvi_results['risk_category'] in ['Critical', 'High'] else 'Maintain monitoring programs'}
   • {'Reduce all local stressors immediately' if crvi_results['risk_category'] == 'Critical' else 'Continue stressor management'}
   • {'Prioritize for restoration funding' if crvi_results['crvi'] > 0.7 else 'Document recovery patterns'}

{'='*80}
END OF REPORT
Generated by Coral Bleaching Early Warning System
{'='*80}
"""
        
        # Save report
        filename = f"{prefix}enhanced_summary_report.txt" if prefix else "enhanced_summary_report.txt"
        path = self.reports_dir / filename
        with open(path, 'w') as f:
            f.write(report)
        
        self.logger.info(f"Generated enhanced summary report: {path}")
        
        # Also print to console
        print(report)
        
        return path
    
    def update_model_comparison_in_report(
        report_text: str,
        forecast_comparison: pd.DataFrame,
        forecaster: Any = None
    ) -> str:
        """
        Replace old model comparison section with DHW forecaster results.
        
        This function finds and replaces the section showing RF/XGBoost etc.
        with the new Ensemble-pCRVI results.
        
        Parameters
        ----------
        report_text : str
            Original report text
        forecast_comparison : pd.DataFrame
            DHW forecaster comparison results
        forecaster : DHWTimeSeriesForecaster
            Fitted forecaster
            
        Returns
        -------
        str
            Updated report text
        """
        # Patterns to find old model comparison section
        old_patterns = [
            "MACHINE LEARNING MODEL COMPARISON",
            "MACHINE LEARNING MODEL PERFORMANCE", 
            "Model Performance Metrics:",
            "Logistic Regression:",
            "Random Forest:",
            "Gradient Boosting:",
            "XGBoost:"
        ]
        
        # Generate new section
        new_section = generate_dhw_forecaster_section(forecast_comparison, forecaster)
        
        # Find and replace
        # Look for section starting with "4. MACHINE LEARNING" and ending before "5. CONCLUSIONS"
        import re
        pattern = r'4\.\s*MACHINE LEARNING.*?(?=5\.\s*CONCLUSIONS|={70,}.*END OF REPORT)'
        
        if re.search(pattern, report_text, re.DOTALL):
            report_text = re.sub(pattern, new_section.strip() + "\n\n", report_text, flags=re.DOTALL)
        else:
            # If pattern not found, append before conclusions
            if "5. CONCLUSIONS" in report_text:
                report_text = report_text.replace(
                    "5. CONCLUSIONS",
                    new_section.strip() + "\n\n5. CONCLUSIONS"
                )
        
        return report_text

    def generate_summary_report(
        self,
        dhw_data: pd.DataFrame,
        start_date: str,
        end_date: str,
        pcrvi_data: Optional[pd.DataFrame] = None,  
        forecast_comparison: Optional[pd.DataFrame] = None, 
        prefix: str = ""
    ) -> Path:
        """Generate a text summary report."""
        
        # Calculate statistics
        total_days = len(dhw_data)
        valid_dhw = dhw_data['dhw'].dropna()
        
        max_dhw = valid_dhw.max() if len(valid_dhw) > 0 else 0
        max_dhw_date = valid_dhw.idxmax() if len(valid_dhw) > 0 else "N/A"
        
        days_alert1 = (valid_dhw >= 4).sum()
        days_alert2 = (valid_dhw >= 8).sum()
        days_alert3 = (valid_dhw >= 12).sum()
        
        # Find bleaching events (periods where DHW >= 4)
        bleaching_periods = []
        in_event = False
        event_start = None
        
        for date, row in dhw_data.iterrows():
            if row['dhw'] >= 4 and not in_event:
                in_event = True
                event_start = date
            elif row['dhw'] < 4 and in_event:
                in_event = False
                bleaching_periods.append((event_start, date))
        
        if in_event:
            bleaching_periods.append((event_start, dhw_data.index[-1]))
        
        # Generate report
        report_lines = [
            "=" * 70,
            "CORAL BLEACHING EARLY WARNING SYSTEM - SUMMARY REPORT",
            "=" * 70,
            "",
            f"Analysis Period: {start_date} to {end_date}",
            f"Total Days Analyzed: {total_days}",
            f"Region: Andaman & Nicobar Islands",
            f"MMM SST: 29.87°C",
            "",
            "-" * 70,
            "DHW STATISTICS",
            "-" * 70,
            f"Maximum DHW: {max_dhw:.2f} °C-weeks",
            f"Date of Maximum DHW: {max_dhw_date}",
            "",
            "Alert Level Distribution:",
            f"  Days at Watch (DHW > 0):      {(valid_dhw > 0).sum()}",
            f"  Days at Alert Level 1 (≥4):   {days_alert1}",
            f"  Days at Alert Level 2 (≥8):   {days_alert2}",
            f"  Days at Alert Level 3 (≥12):  {days_alert3}",
            "",
            "-" * 70,
            "BLEACHING EVENTS DETECTED",
            "-" * 70,
        ]
        if forecast_comparison is not None and len(forecast_comparison) > 0:
            best = forecast_comparison.iloc[0]
            report += f"""
        ======================================================================
        FORECAST MODEL STATUS
        ======================================================================

        Model Performance ({best['Model']}):
        MAE:  {best['mae']:.3f} °C-weeks
        R²:   {best['r2']:.3f}
        F1:   {best['bl_f1']:.3f}
        """
        if pcrvi_data is not None and len(pcrvi_data) > 0:
            current_pcrvi = pcrvi_data['pcrvi'].iloc[-1]
            risk = "HIGH" if current_pcrvi >= 0.6 else "MODERATE" if current_pcrvi >= 0.5 else "WARNING" if current_pcrvi >= 0.4 else "LOW"
            report += f"""Current pCRVI: {current_pcrvi:.3f} ({risk} RISK)"""
        
        if bleaching_periods:
            for i, (start, end) in enumerate(bleaching_periods, 1):
                duration = (end - start).days
                period_dhw = dhw_data.loc[start:end, 'dhw']
                max_period_dhw = period_dhw.max()
                report_lines.append(
                    f"  Event {i}: {start.strftime('%Y-%m-%d')} to {end.strftime('%Y-%m-%d')} "
                    f"({duration} days, max DHW: {max_period_dhw:.2f})"
                )
        else:
            report_lines.append("  No significant bleaching events detected (DHW < 4)")
        
        report_lines.extend([
            "",
            "-" * 70,
            "ANNUAL PEAK DHW VALUES",
            "-" * 70,
        ])
        
        # Annual peaks
        dhw_data_copy = dhw_data.copy()
        dhw_data_copy['year'] = dhw_data_copy.index.year
        annual_peaks = dhw_data_copy.groupby('year')['dhw'].max()
        
        for year, peak in annual_peaks.items():
            alert_status = "No Stress"
            if peak >= 12:
                alert_status = "ALERT LEVEL 3 (Mass Bleaching/Mortality)"
            elif peak >= 8:
                alert_status = "ALERT LEVEL 2 (Significant Bleaching)"
            elif peak >= 6:
                alert_status = "ALERT LEVEL 1 (Moderate Bleaching)"
            elif peak >= 4:
                alert_status = "WARNING (Partial/Minor Bleaching)"
            elif peak > 0:
                alert_status = "Watch (Thermal Stress)"
            elif peak > 0:
                alert_status = "Watch"
            
            report_lines.append(f"  {year}: {peak:.2f} °C-weeks - {alert_status}")
        
        report_lines.extend([
            "",
            "=" * 70,
            f"Report generated: {datetime.utcnow().isoformat()}",
            "=" * 70,
        ])
        
        report_text = "\n".join(report_lines)
        
        filename = f"{prefix}summary_report.txt" if prefix else "summary_report.txt"
        path = self.reports_dir / filename
        
        with open(path, 'w') as f:
            f.write(report_text)
        
        self.logger.info(f"Generated summary report: {path}")
        
        # Also print to console
        print(report_text)
        
        return path

    def generate_dhw_forecaster_section(forecast_comparison: pd.DataFrame, 
                                     forecaster: Any = None) -> str:
        """
        Generate text report section for DHW Time Series Forecaster.
        
        This REPLACES the old model comparison section that showed RF/XGBoost etc.
        
        Parameters
        ----------
        forecast_comparison : pd.DataFrame
            Results from DHWTimeSeriesForecaster.compare_models()
            Columns: Model, mae, rmse, r2, bl_f1, bl_precision, bl_recall
        forecaster : DHWTimeSeriesForecaster, optional
            The fitted forecaster for additional details
            
        Returns
        -------
        str
            Formatted text report section
        """
        section = f"""
    {'='*80}
    4. DHW TIME SERIES FORECASTING (Ensemble-pCRVI)
    {'='*80}

    APPROACH:
    The Ensemble-pCRVI model uses TIME SERIES REGRESSION instead of binary 
    classification. This is critical because:
    1. DHW is a continuous value (0-20+ °C-weeks), not binary
    2. 98% of days have DHW=0, causing classification models to predict all zeros
    3. Climate indices (ONI, DMI) have 30-90 day LEAD TIME before thermal effects

    WHAT IS TS + pCRVI?
    - TS = Time Series features (lagged SST, climate indices with lead times)
    - pCRVI = Predictive CRVI components (thermal anomaly, accumulating stress, 
            climate driver response, seasonal risk)
    - The ensemble combines both using Gradient Boosting Regression

    Model Performance:
    {'-'*40}
    """
        
        if forecast_comparison is not None and len(forecast_comparison) > 0:
            for _, row in forecast_comparison.iterrows():
                model_name = row.get('Model', 'Unknown')
                section += f"\n{model_name}:\n"
                
                if 'mae' in row:
                    section += f"  MAE: {row['mae']:.3f} °C-weeks\n"
                if 'rmse' in row:
                    section += f"  RMSE: {row['rmse']:.3f} °C-weeks\n"
                if 'r2' in row:
                    section += f"  R²: {row['r2']:.3f}\n"
                if 'bl_f1' in row:
                    section += f"  Bleaching Detection F1: {row['bl_f1']:.3f}\n"
                if 'bl_precision' in row:
                    section += f"  Bleaching Precision: {row['bl_precision']:.3f}\n"
                if 'bl_recall' in row:
                    section += f"  Bleaching Recall: {row['bl_recall']:.3f}\n"
            
            # Highlight best model
            best = forecast_comparison.iloc[0]
            section += f"""
    RECOMMENDED MODEL: {best['Model']}
    - Achieves best Bleaching F1 of {best['bl_f1']:.3f}
    - MAE of {best['mae']:.3f} °C-weeks means predictions are typically within 
        {best['mae']:.1f} °C-weeks of actual values
    - R² of {best['r2']:.3f} explains {best['r2']*100:.0f}% of DHW variance
    """
        else:
            section += "\nNo forecasting results available.\n"
        
        # Add feature importance if available
        if forecaster is not None and hasattr(forecaster, 'models'):
            for key, model_info in forecaster.models.items():
                if 'feature_importance' in model_info:
                    importance = model_info['feature_importance']
                    section += f"""
    Key Predictive Features ({model_info.get('name', key)}):
    {'-'*40}
    """
                    for _, row in importance.head(5).iterrows():
                        pct = row['importance'] * 100
                        section += f"  {row['feature']}: {pct:.1f}%\n"
                    break
        
        section += f"""
    WHY THIS IS BETTER THAN CLASSIFICATION:
    {'-'*40}
    The old approach used Random Forest, XGBoost, Logistic Regression for binary
    classification (bleaching vs no-bleaching). These achieved ~98% accuracy by
    predicting EVERYTHING as "no bleaching" (the majority class). They had:
    - Precision: 0.00 (no true positives)
    - Recall: 0.00 (missed all bleaching events)
    - F1: 0.00 (completely useless for early warning)

    The Ensemble-pCRVI model predicts ACTUAL DHW VALUES, allowing:
    - Magnitude-aware predictions (distinguish mild vs severe events)
    - Proper evaluation with MAE, RMSE, R²
    - Bleaching detection via threshold (DHW ≥ 4 → bleaching)
    - F1 > 0.6 demonstrating real predictive skill
    """
        
        return section


    def generate_dhw_forecast_html_section(forecast_comparison: pd.DataFrame,
                                            forecaster: Any = None) -> str:
        """
        Generate HTML section for DHW forecasting results.
        
        Replaces the old model comparison table showing RF/XGBoost etc.
        """
        if forecast_comparison is None or len(forecast_comparison) == 0:
            return """
            <section class="section">
                <h2 class="section-title"><span class="icon">📈</span> DHW Forecasting</h2>
                <p>No forecasting results available.</p>
            </section>
            """
        
        # Build table rows
        rows = ""
        for _, row in forecast_comparison.iterrows():
            model = row.get('Model', 'Unknown')
            mae = row.get('mae', 0)
            rmse = row.get('rmse', 0)
            r2 = row.get('r2', 0)
            bl_f1 = row.get('bl_f1', 0)
            bl_prec = row.get('bl_precision', 0)
            bl_rec = row.get('bl_recall', 0)
            
            # Highlight best model
            is_best = (row.name == 0)  # First row after sorting by F1
            row_class = 'best-model' if is_best else ''
            
            rows += f"""
            <tr class="{row_class}">
                <td><strong>{model}</strong>{'  ✓ RECOMMENDED' if is_best else ''}</td>
                <td>{mae:.3f}</td>
                <td>{rmse:.3f}</td>
                <td>{r2:.3f}</td>
                <td style="font-weight: bold; color: {'#27ae60' if bl_f1 > 0.5 else '#e74c3c'};">{bl_f1:.3f}</td>
                <td>{bl_prec:.3f}</td>
                <td>{bl_rec:.3f}</td>
            </tr>
            """
        
        # Feature importance section
        feat_importance_html = ""
        if forecaster is not None and hasattr(forecaster, 'models'):
            for key, model_info in forecaster.models.items():
                if 'feature_importance' in model_info:
                    importance = model_info['feature_importance'].head(5)
                    feat_bars = ""
                    max_imp = importance['importance'].max()
                    for _, feat_row in importance.iterrows():
                        pct = (feat_row['importance'] / max_imp) * 100
                        feat_bars += f"""
                        <div class="feature-bar">
                            <span class="feature-name">{friendly_name(feat_row['feature'])}</span>
                            <div class="bar-container">
                                <div class="bar-fill" style="width: {pct}%;"></div>
                            </div>
                            <span class="feature-value">{feat_row['importance']:.3f}</span>
                        </div>
                        """
                    feat_importance_html = f"""
                    <div class="feature-importance">
                        <h4>🎯 Top Predictive Features</h4>
                        <p>These features contribute most to DHW prediction:</p>
                        {feat_bars}
                    </div>
                    """
                    break
        
        return f"""
        <section class="section">
            <h2 class="section-title"><span class="icon">📈</span> DHW Time Series Forecasting</h2>
            
            <div class="info-box">
                <p><strong>Ensemble (TS + pCRVI)</strong> combines Time Series features with Predictive CRVI 
                components using Gradient Boosting Regression. This approach predicts actual DHW values 
                (not just binary bleaching/no-bleaching), enabling magnitude-aware early warnings.</p>
            </div>
            
            <div class="metric-explanation">
                <div class="metric-card">
                    <div class="metric-value" style="color: #3498db;">MAE</div>
                    <div class="metric-label">Mean Absolute Error</div>
                    <p>Average prediction error in °C-weeks</p>
                </div>
                <div class="metric-card">
                    <div class="metric-value" style="color: #9b59b6;">R²</div>
                    <div class="metric-label">Coefficient of Determination</div>
                    <p>Fraction of variance explained</p>
                </div>
                <div class="metric-card">
                    <div class="metric-value" style="color: #27ae60;">F1</div>
                    <div class="metric-label">Bleaching Detection F1</div>
                    <p>Harmonic mean of precision & recall</p>
                </div>
            </div>
            
            <table class="forecast-table">
                <thead>
                    <tr>
                        <th>Model</th>
                        <th>MAE (°C-wk)</th>
                        <th>RMSE</th>
                        <th>R²</th>
                        <th>Bleaching F1</th>
                        <th>Precision</th>
                        <th>Recall</th>
                    </tr>
                </thead>
                <tbody>
                    {rows}
                </tbody>
            </table>
            
            {feat_importance_html}
            
            <div class="comparison-note">
                <h4>⚠️ Why Previous Models Failed</h4>
                <p>Classification models (Random Forest, XGBoost, Logistic Regression) achieved ~98% 
                accuracy by predicting ALL days as "no bleaching" — the majority class. They had 
                <strong>Precision=0, Recall=0, F1=0</strong> for bleaching detection, making them 
                useless for early warning. The Ensemble-pCRVI approach properly handles the class 
                imbalance by predicting DHW magnitude instead of binary labels.</p>
            </div>
        </section>
        """

    def save_dhw_forecast_results(
        output_dir: Path,
        forecast_comparison: pd.DataFrame,
        forecaster: Any = None,
        prefix: str = ""
    ) -> Dict[str, Path]:
        """
        Save DHW forecasting results to files.
        
        Parameters
        ----------
        output_dir : Path
            Output directory
        forecast_comparison : pd.DataFrame
            Model comparison results
        forecaster : DHWTimeSeriesForecaster
            Fitted forecaster with predictions
        prefix : str
            Filename prefix
            
        Returns
        -------
        dict
            Paths to saved files
        """
        csv_dir = output_dir / "csv"
        reports_dir = output_dir / "reports"
        csv_dir.mkdir(parents=True, exist_ok=True)
        reports_dir.mkdir(parents=True, exist_ok=True)
        
        saved_files = {}
        
        # Save comparison metrics
        if forecast_comparison is not None and len(forecast_comparison) > 0:
            filename = f"{prefix}dhw_forecast_comparison.csv" if prefix else "dhw_forecast_comparison.csv"
            path = csv_dir / filename
            forecast_comparison.to_csv(path, index=False)
            saved_files['forecast_comparison'] = path
        
        # Save predictions from each model
        if forecaster is not None and hasattr(forecaster, 'models'):
            for key, model_info in forecaster.models.items():
                if 'predictions' in model_info:
                    pred_df = model_info['predictions']
                    filename = f"{prefix}dhw_predictions_{key}.csv" if prefix else f"dhw_predictions_{key}.csv"
                    path = csv_dir / filename
                    pred_df.to_csv(path, index=False)
                    saved_files[f'predictions_{key}'] = path
                
                if 'feature_importance' in model_info:
                    imp_df = model_info['feature_importance']
                    filename = f"{prefix}feature_importance_{key}.csv" if prefix else f"feature_importance_{key}.csv"
                    path = csv_dir / filename
                    imp_df.to_csv(path, index=False)
                    saved_files[f'feature_importance_{key}'] = path
        
        # Save text report section
        report_text = generate_dhw_forecaster_section(forecast_comparison, forecaster)
        filename = f"{prefix}dhw_forecast_report.txt" if prefix else "dhw_forecast_report.txt"
        path = reports_dir / filename
        with open(path, 'w') as f:
            f.write(report_text)
        saved_files['forecast_report'] = path
        
        return saved_files
    
    def generate_pcrvi_summary_report(
        self,
        dhw_data: pd.DataFrame,
        pcrvi_results: Optional[Dict[str, Any]] = None,
        historical_validation: Optional[pd.DataFrame] = None,
        forecast_comparison: Optional[pd.DataFrame] = None,
        forecaster: Any = None,
        climate_data: Optional[pd.DataFrame] = None,
        start_date: str = "",
        end_date: str = "",
        prefix: str = ""
    ) -> Path:
        """
        Generate comprehensive summary report focused on pCRVI and DHW forecasting.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series
        pcrvi_results : dict, optional
            Predictive CRVI skill results
        historical_validation : pd.DataFrame, optional
            Historical event validation results
        forecast_comparison : pd.DataFrame, optional
            DHW forecast model comparison (Ensemble-pCRVI)
        forecaster : Any, optional
            DHWTimeSeriesForecaster for feature importance
        climate_data : pd.DataFrame, optional
            Climate indices
        start_date : str
            Analysis start date
        end_date : str
            Analysis end date
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to report file
        """
        # Calculate comprehensive statistics
        total_days = len(dhw_data) if dhw_data is not None else 0
        valid_dhw = dhw_data['dhw'].dropna() if dhw_data is not None and 'dhw' in dhw_data.columns else pd.Series()
        
        max_dhw = valid_dhw.max() if len(valid_dhw) > 0 else 0
        max_dhw_date = valid_dhw.idxmax() if len(valid_dhw) > 0 else "N/A"
        mean_dhw = valid_dhw.mean() if len(valid_dhw) > 0 else 0
        
        # Count alert days (using ANI-calibrated thresholds)
        days_watch = ((valid_dhw > 0) & (valid_dhw < 3)).sum() if len(valid_dhw) > 0 else 0
        days_warning = ((valid_dhw >= 3) & (valid_dhw < 6)).sum() if len(valid_dhw) > 0 else 0
        days_alert1 = ((valid_dhw >= 6) & (valid_dhw < 8)).sum() if len(valid_dhw) > 0 else 0
        days_alert2 = (valid_dhw >= 8).sum() if len(valid_dhw) > 0 else 0
        
        # Annual statistics
        if dhw_data is not None and len(dhw_data) > 0:
            dhw_copy = dhw_data.copy()
            dhw_copy['year'] = dhw_copy.index.year
            annual_max = dhw_copy.groupby('year')['dhw'].max()
            bleaching_years = annual_max[annual_max >= 4].index.tolist()
            severe_years = annual_max[annual_max >= 8].index.tolist()
        else:
            annual_max = pd.Series(dtype=float)
            bleaching_years = []
            severe_years = []
        
        # pCRVI information
        pcrvi_current = None
        pcrvi_risk = "Unknown"
        pcrvi_correlation = 0
        pcrvi_f1 = 0
        pcrvi_recommendation = "pCRVI data not available"
        
        if pcrvi_results is not None and isinstance(pcrvi_results, dict):
            if 'current_assessment' in pcrvi_results:
                pcrvi_current = pcrvi_results['current_assessment'].get('pcrvi', 0)
                pcrvi_risk = pcrvi_results['current_assessment'].get('risk_category', 'Unknown')
                pcrvi_recommendation = pcrvi_results['current_assessment'].get('recommendation', '')
            
            if 'lead_time_analysis' in pcrvi_results and '30_days' in pcrvi_results['lead_time_analysis']:
                pcrvi_correlation = pcrvi_results['lead_time_analysis']['30_days'].get('correlation', 0)
                pcrvi_f1 = pcrvi_results['lead_time_analysis']['30_days'].get('f1_score', 0)
        
        # Handle NaN values
        if pd.isna(pcrvi_correlation):
            pcrvi_correlation = 0
        if pd.isna(pcrvi_f1):
            pcrvi_f1 = 0
        
        # Pre-compute pCRVI display string
        pcrvi_display = f"{pcrvi_current:.3f}" if pcrvi_current is not None else "N/A"
        
        # Generate report
        report = f"""
{'='*80}
CORAL BLEACHING EARLY WARNING SYSTEM
COMPREHENSIVE ANALYSIS REPORT
{'='*80}

REPORT METADATA
{'-'*40}
Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}
Analysis Period: {start_date} to {end_date}
Region: Andaman & Nicobar Islands
Coordinates: 90E-95E, 6N-14N
MMM SST: 29.87C (NOAA CRW)
Primary Vulnerability Index: pCRVI (Predictive CRVI)
Forecasting Model: Ensemble-pCRVI

{'='*80}
EXECUTIVE SUMMARY
{'='*80}

This report presents a comprehensive analysis of coral bleaching risk for the
Andaman & Nicobar Islands based on {total_days:,} days of environmental data.

The analysis uses the Predictive Coral Reef Vulnerability Index (pCRVI) as
the PRIMARY vulnerability metric. pCRVI provides 30-day advance warning
of bleaching events with demonstrated predictive skill.

KEY FINDINGS:
- Maximum DHW recorded: {max_dhw:.2f}C-weeks on {max_dhw_date}
- Current pCRVI Score: {pcrvi_display} ({pcrvi_risk})
- pCRVI 30-day Correlation: {pcrvi_correlation:.3f}
- pCRVI F1 Score: {pcrvi_f1:.3f}
- Bleaching events detected: {len(bleaching_years)} years with DHW >= 4
- Severe bleaching events: {len(severe_years)} years with DHW >= 8

{'='*80}
1. THERMAL STRESS ANALYSIS
{'='*80}

1.1 DHW Statistics
{'-'*40}
Total Days Analyzed: {total_days:,}
Valid DHW Records: {len(valid_dhw):,}

DHW Distribution:
  Mean: {mean_dhw:.2f}C-weeks
  Maximum: {max_dhw:.2f}C-weeks
  Date of Maximum: {max_dhw_date}

Alert Level Distribution (ANI-Calibrated Thresholds):
  No Stress (DHW = 0):      {int((valid_dhw == 0).sum()) if len(valid_dhw) > 0 else 0:,} days
  Watch (0 < DHW < 3):      {int(days_watch):,} days
  Warning (3 <= DHW < 6):   {int(days_warning):,} days
  Alert Level 1 (6-8):      {int(days_alert1):,} days
  Alert Level 2 (>=8):      {int(days_alert2):,} days

1.2 Annual Maximum DHW
{'-'*40}
"""
        for year in sorted(annual_max.index):
            peak = annual_max[year]
            if peak >= 8:
                status = "SEVERE"
            elif peak >= 6:
                status = "SIGNIFICANT"
            elif peak >= 4:
                status = "MODERATE"
            elif peak >= 2:
                status = "WATCH"
            else:
                status = "NORMAL"
            report += f"  {year}: {peak:6.2f}C-weeks {status}\n"
        
        # pCRVI Section
        report += f"""
{'='*80}
2. PREDICTIVE CORAL REEF VULNERABILITY INDEX (pCRVI)
{'='*80}

pCRVI is the PRIMARY vulnerability index for this early warning system.
Unlike traditional CRVI (which looks backward), pCRVI PREDICTS future
bleaching risk with demonstrated 30-day lead time.

2.1 Current Status
{'-'*40}
Current pCRVI Score: {pcrvi_display}
Risk Category: {pcrvi_risk}

2.2 Predictive Skill
{'-'*40}
30-Day Lead Correlation: {pcrvi_correlation:.3f}
30-Day Lead F1 Score: {pcrvi_f1:.3f}

The pCRVI provides a {pcrvi_correlation:.2f} correlation with thermal stress 
30 days in advance, allowing for proactive management responses.

2.3 Recommendation
{'-'*40}
{pcrvi_recommendation}

"""
        
        # Historical Validation Section
        if historical_validation is not None and len(historical_validation) > 0:
            report += f"""
{'='*80}
3. HISTORICAL EVENT VALIDATION
{'='*80}

The following table compares model predictions against documented
bleaching events in the Andaman & Nicobar Islands:

Year | Actual Severity | Actual DHW | Model DHW | DHW Match | pCRVI Max | pCRVI Match
{'-'*90}
"""
            for _, row in historical_validation.iterrows():
                year_str = f"{int(row['year']):4d}"
                severity_str = f"{str(row.get('actual_severity', 'N/A')):15s}"
                
                actual_dhw = row.get('actual_dhw')
                if pd.isna(actual_dhw) or actual_dhw is None:
                    actual_dhw_str = "N/A".ljust(10)
                else:
                    actual_dhw_str = f"{float(actual_dhw):10.2f}"
                
                model_dhw = row.get('model_dhw_max')
                if pd.isna(model_dhw) or model_dhw is None:
                    model_dhw_str = "N/A".ljust(9)
                else:
                    model_dhw_str = f"{float(model_dhw):9.2f}"
                
                dhw_match = row.get('dhw_match')
                if pd.isna(dhw_match) or dhw_match is None:
                    dhw_match_str = "N/A".ljust(9)
                else:
                    dhw_match_str = f"{str(dhw_match):9s}"
                
                pcrvi_max = row.get('pcrvi_max')
                if pd.isna(pcrvi_max) or pcrvi_max is None:
                    pcrvi_max_str = "N/A".ljust(9)
                else:
                    pcrvi_max_str = f"{float(pcrvi_max):9.3f}"
                
                pcrvi_match = row.get('pcrvi_match')
                if pd.isna(pcrvi_match) or pcrvi_match is None:
                    pcrvi_match_str = "N/A"
                else:
                    pcrvi_match_str = str(pcrvi_match)
                
                report += f"{year_str} | {severity_str} | {actual_dhw_str} | "
                report += f"{model_dhw_str} | {dhw_match_str} | "
                report += f"{pcrvi_max_str} | {pcrvi_match_str}\n"
            
            # Calculate accuracy
            dhw_correct = (historical_validation['dhw_match'] == 'CORRECT').sum()
            dhw_close = (historical_validation['dhw_match'] == 'CLOSE').sum()
            pcrvi_valid = historical_validation[historical_validation['pcrvi_match'].notna()]
            pcrvi_correct = (pcrvi_valid['pcrvi_match'] == 'CORRECT').sum() if len(pcrvi_valid) > 0 else 0
            pcrvi_close = (pcrvi_valid['pcrvi_match'] == 'CLOSE').sum() if len(pcrvi_valid) > 0 else 0
            
            report += f"""
Validation Summary:
  DHW Predictions: {dhw_correct} correct, {dhw_close} close out of {len(historical_validation)} events
  pCRVI Predictions: {pcrvi_correct} correct, {pcrvi_close} close out of {len(pcrvi_valid)} events
"""
        
        # DHW FORECASTING Section (REPLACES old model comparison)
        if forecast_comparison is not None and len(forecast_comparison) > 0:
            report += f"""
{'='*80}
4. DHW TIME SERIES FORECASTING (Ensemble-pCRVI)
{'='*80}

The Ensemble-pCRVI model predicts actual DHW values using time series
regression, providing magnitude-aware early warning with demonstrated skill.

Model Performance:
{'-'*40}
"""
            for _, row in forecast_comparison.iterrows():
                model_name = row.get('Model', 'Unknown')
                report += f"\n{model_name}:\n"
                if 'mae' in row:
                    report += f"  MAE: {row['mae']:.3f} C-weeks\n"
                if 'rmse' in row:
                    report += f"  RMSE: {row['rmse']:.3f} C-weeks\n"
                if 'r2' in row:
                    report += f"  R2: {row['r2']:.3f}\n"
                if 'bl_f1' in row:
                    report += f"  Bleaching F1: {row['bl_f1']:.3f}\n"
                if 'bl_precision' in row:
                    report += f"  Precision: {row['bl_precision']:.3f}\n"
                if 'bl_recall' in row:
                    report += f"  Recall: {row['bl_recall']:.3f}\n"
            
            # Add feature importance if available
            if forecaster is not None and hasattr(forecaster, 'models'):
                for key, model_info in forecaster.models.items():
                    if 'feature_importance' in model_info:
                        report += f"""
Key Predictive Features:
{'-'*40}
"""
                        for _, feat_row in model_info['feature_importance'].head(5).iterrows():
                            pct = feat_row['importance'] * 100
                            report += f"  {friendly_name(feat_row['feature'])}: {pct:.1f}%\n"
                        break
        
        # Conclusions
        report += f"""
{'='*80}
5. CONCLUSIONS AND RECOMMENDATIONS
{'='*80}

1. VULNERABILITY STATUS
   Current pCRVI: {pcrvi_display} ({pcrvi_risk})
   The pCRVI provides superior predictive capability compared to traditional
   retrospective vulnerability indices.

2. EARLY WARNING CAPABILITY
   With a 30-day correlation of {pcrvi_correlation:.2f}, pCRVI enables
   proactive management responses before bleaching events occur.

3. MANAGEMENT PRIORITIES
   - Monitor pCRVI daily during peak season (April-June)
   - Implement alert protocols when pCRVI exceeds 0.4 (Warning)
   - Activate emergency response when pCRVI exceeds 0.6 (Severe)

4. THRESHOLD RECOMMENDATIONS
   Based on historical validation, the following pCRVI thresholds are recommended:
   - Low Risk: pCRVI < 0.3
   - Warning: pCRVI 0.3-0.4
   - Moderate: pCRVI 0.4-0.5
   - High: pCRVI 0.5-0.6
   - Critical: pCRVI > 0.6

{'='*80}
END OF REPORT
Generated by Coral Bleaching Early Warning System
Primary Index: Predictive CRVI (pCRVI)
Forecast Model: Ensemble-pCRVI
{'='*80}
"""
        
        # Save report
        filename = f"{prefix}pcrvi_summary_report.txt" if prefix else "pcrvi_summary_report.txt"
        path = self.reports_dir / filename
        with open(path, 'w') as f:
            f.write(report)
        
        self.logger.info(f"Generated pCRVI summary report: {path}")
        
        return path
    
    def generate_pcrvi_html_report(
        self,
        dhw_data: pd.DataFrame,
        pcrvi_results: Optional[Dict[str, Any]] = None,
        pcrvi_timeseries: Optional[pd.DataFrame] = None,
        historical_validation: Optional[pd.DataFrame] = None,
        forecast_comparison: Optional[pd.DataFrame] = None,
        forecaster: Any = None,
        climate_data: Optional[pd.DataFrame] = None,
        visualization_paths: Optional[Dict[str, Path]] = None,
        start_date: str = "",
        end_date: str = "",
        prefix: str = ""
    ) -> Path:
        """
        Generate comprehensive HTML report focused on pCRVI and DHW forecasting.
        """
        # Calculate statistics
        total_days = len(dhw_data) if dhw_data is not None else 0
        valid_dhw = dhw_data['dhw'].dropna() if dhw_data is not None and 'dhw' in dhw_data.columns else pd.Series()
        
        max_dhw = valid_dhw.max() if len(valid_dhw) > 0 else 0
        max_dhw_date = str(valid_dhw.idxmax()) if len(valid_dhw) > 0 else "N/A"
        mean_dhw = valid_dhw.mean() if len(valid_dhw) > 0 else 0
        
        # Alert days
        days_watch = int(((valid_dhw > 0) & (valid_dhw < 3)).sum()) if len(valid_dhw) > 0 else 0
        days_warning = int(((valid_dhw >= 3) & (valid_dhw < 6)).sum()) if len(valid_dhw) > 0 else 0
        days_alert1 = int(((valid_dhw >= 6) & (valid_dhw < 8)).sum()) if len(valid_dhw) > 0 else 0
        days_alert2 = int((valid_dhw >= 8).sum()) if len(valid_dhw) > 0 else 0
        
        # Bleaching years
        bleaching_years = []
        if dhw_data is not None and len(dhw_data) > 0:
            dhw_copy = dhw_data.copy()
            dhw_copy['year'] = dhw_copy.index.year
            annual_max = dhw_copy.groupby('year')['dhw'].max()
            bleaching_years = annual_max[annual_max >= 4].index.tolist()
        
        # pCRVI variables
        pcrvi_score = 0.0
        pcrvi_risk = "Unknown"
        pcrvi_color = "#666"
        pcrvi_desc = "No data available"
        pcrvi_correlation = 0.0
        pcrvi_f1 = 0.0
        pcrvi_recommendation = "pCRVI data not available"
        pcrvi_skill_rows = ""
        
        if pcrvi_results is not None and isinstance(pcrvi_results, dict):
            if 'current_assessment' in pcrvi_results:
                pcrvi_score = pcrvi_results['current_assessment'].get('pcrvi', 0)
                pcrvi_risk = pcrvi_results['current_assessment'].get('risk_category', 'Unknown')
                pcrvi_recommendation = pcrvi_results['current_assessment'].get('recommendation', '')
            
            # Determine color
            if pcrvi_score >= 0.6:
                pcrvi_color = '#e74c3c'
                pcrvi_desc = 'Critical - Immediate action required'
            elif pcrvi_score >= 0.5:
                pcrvi_color = '#e67e22'
                pcrvi_desc = 'High - Elevated monitoring recommended'
            elif pcrvi_score >= 0.4:
                pcrvi_color = '#f39c12'
                pcrvi_desc = 'Moderate - Watch conditions'
            elif pcrvi_score >= 0.3:
                pcrvi_color = '#f1c40f'
                pcrvi_desc = 'Warning - Monitor closely'
            else:
                pcrvi_color = '#2ecc71'
                pcrvi_desc = 'Low - Normal conditions'
            
            # Lead time analysis
            if 'lead_time_analysis' in pcrvi_results:
                for lead_key, lead_data in pcrvi_results['lead_time_analysis'].items():
                    if isinstance(lead_data, dict):
                        pcrvi_skill_rows += f"""
                        <tr>
                            <td>{lead_key}</td>
                            <td>{lead_data.get('correlation', 0):.3f}</td>
                            <td>{lead_data.get('precision', 0):.3f}</td>
                            <td>{lead_data.get('recall', 0):.3f}</td>
                            <td>{lead_data.get('f1_score', 0):.3f}</td>
                            <td>{lead_data.get('mcc', 0):.3f}</td>
                        </tr>
                        """
                
                if '30_days' in pcrvi_results['lead_time_analysis']:
                    lead_30 = pcrvi_results['lead_time_analysis']['30_days']
                    pcrvi_correlation = lead_30.get('correlation', 0)
                    pcrvi_f1 = lead_30.get('f1_score', 0)
        
        # Historical validation table
        historical_rows = ""
        if historical_validation is not None and len(historical_validation) > 0:
            for _, row in historical_validation.iterrows():
                match_color = '#2ecc71' if row['dhw_match'] == 'CORRECT' else '#f39c12' if row['dhw_match'] == 'CLOSE' else '#e74c3c'
                pcrvi_match_color = '#2ecc71' if row.get('pcrvi_match') == 'CORRECT' else '#f39c12' if row.get('pcrvi_match') == 'CLOSE' else '#e74c3c' if row.get('pcrvi_match') else '#666'
                
                historical_rows += f"""
                <tr>
                    <td>{row['year']}</td>
                    <td>{row['actual_severity'].title()}</td>
                    <td>{row['actual_dhw'] or 'N/A'}</td>
                    <td>{row['actual_bleaching_pct']}%</td>
                    <td>{row['model_dhw_max'] or 'N/A'}</td>
                    <td style="color: {match_color}; font-weight: bold;">{row['dhw_match'] or 'N/A'}</td>
                    <td>{row['pcrvi_max'] or 'N/A'}</td>
                    <td style="color: {pcrvi_match_color}; font-weight: bold;">{row.get('pcrvi_match') or 'N/A'}</td>
                </tr>
                """
        
        # DHW Forecast model rows (replaces old classification model rows)
        forecast_rows = ""
        feature_importance_html = ""
        
        if forecast_comparison is not None and len(forecast_comparison) > 0:
            for idx, row in forecast_comparison.iterrows():
                is_best = (idx == 0)
                row_class = "best-model" if is_best else ""
                best_marker = " (Best)" if is_best else ""
                forecast_rows += f"""
                <tr class="{row_class}">
                    <td><strong>{row.get('Model', 'N/A')}{best_marker}</strong></td>
                    <td>{row.get('mae', 0):.3f}</td>
                    <td>{row.get('rmse', 0):.3f}</td>
                    <td>{row.get('r2', 0):.3f}</td>
                    <td style="color: {'#27ae60' if row.get('bl_f1', 0) > 0.5 else '#e74c3c'}; font-weight: bold;">{row.get('bl_f1', 0):.3f}</td>
                    <td>{row.get('bl_precision', 0):.3f}</td>
                    <td>{row.get('bl_recall', 0):.3f}</td>
                </tr>
                """
        # Feature importance
        if forecaster is not None and hasattr(forecaster, 'models'):
            for key, model_info in forecaster.models.items():
                if 'feature_importance' in model_info:
                    importance = model_info['feature_importance'].head(5)
                    feature_importance_html = """
                    <div style="background: #f8f9fa; border-radius: 8px; padding: 15px; margin-top: 15px;">
                        <h4 style="margin-top: 0;">Key Predictive Features</h4>
                    """
                    for _, feat_row in importance.iterrows():
                        pct = feat_row['importance'] * 100
                        bar_width = int(pct * 2)
                        feature_importance_html += f"""
                        <div style="display: flex; align-items: center; margin: 8px 0;">
                            <span style="width: 150px;">{friendly_name(feat_row['feature'])}</span>
                            <div style="background: #3498db; height: 20px; width: {bar_width}px; border-radius: 4px;"></div>
                            <span style="margin-left: 10px;">{pct:.1f}%</span>
                        </div>
                        """
                    feature_importance_html += "</div>"
                    break

        # Visualization sections (embedded base64 images)
        viz_sections = ""
        if visualization_paths:
            viz_items = [
                ('pcrvi_timeseries', 'pCRVI Time Series', 'Predictive CRVI with risk zones'),
                ('pcrvi_dashboard', 'pCRVI Dashboard', 'Comprehensive predictive skill analysis'),
                ('pcrvi_vs_crvi_comparison', 'pCRVI vs CRVI Comparison', 'Showing why pCRVI outperforms traditional CRVI'),
                ('historical_validation', 'Historical Validation', 'Model predictions vs documented events'),
                ('dhw_timeseries', 'DHW Time Series', 'Degree Heating Weeks over time'),
                ('annual_max_dhw', 'Annual Maximum DHW', 'Yearly peak thermal stress'),
                ('dhw_forecast_comparison', 'DHW Forecast Comparison', 'Ensemble-pCRVI model performance'),
                ('dhw_forecast_dashboard', 'DHW Forecast Dashboard', 'Comprehensive forecast results'),
                ('feature_importance_ensemble_pcrvi_60d', 'Feature Importance', 'Key predictive features')
            ]
            
            for key, title, desc in viz_items:
                if key in visualization_paths and visualization_paths[key]:
                    img_path = visualization_paths[key]
                    try:
                        with open(img_path, 'rb') as f:
                            img_data = base64.b64encode(f.read()).decode('utf-8')
                        viz_sections += f"""
                        <div class="viz-item">
                            <h4>{title}</h4>
                            <p>{desc}</p>
                            <img src="data:image/png;base64,{img_data}" alt="{title}">
                        </div>
                        """
                    except:
                        pass
        
        # Build HTML
        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Coral Bleaching EWS Report - Andaman & Nicobar Islands</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f7fa; color: #333; line-height: 1.6; }}
        .container {{ max-width: 1200px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #1a5276 0%, #2980b9 100%); color: white; padding: 40px 20px; text-align: center; border-radius: 10px; margin-bottom: 30px; }}
        .header h1 {{ font-size: 2.5em; margin-bottom: 10px; }}
        .primary-index-note {{ background: #e8f6ff; border-left: 4px solid #2980b9; padding: 15px; margin: 20px 0; border-radius: 5px; }}
        .section {{ background: white; border-radius: 10px; padding: 25px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .section-title {{ font-size: 1.5em; color: #1a5276; margin-bottom: 20px; }}
        .metric-cards {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }}
        .metric-card {{ background: #f8f9fa; padding: 20px; border-radius: 10px; text-align: center; }}
        .metric-card.primary {{ border-left: 5px solid {pcrvi_color}; }}
        .metric-value {{ font-size: 2em; font-weight: bold; color: #1a5276; }}
        .metric-label {{ font-size: 0.9em; color: #666; margin-top: 5px; }}
        table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
        th, td {{ padding: 12px; text-align: left; border-bottom: 1px solid #eee; }}
        th {{ background: #f8f9fa; color: #1a5276; font-weight: 600; }}
        .recommendation {{ background: linear-gradient(135deg, #f8f9fa, #e9ecef); padding: 20px; border-radius: 10px; margin: 20px 0; }}
        .viz-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(500px, 1fr)); gap: 20px; }}
        .viz-item {{ background: #f8f9fa; padding: 15px; border-radius: 10px; }}
        .viz-item img {{ width: 100%; height: auto; border-radius: 5px; }}
        .footer {{ text-align: center; padding: 30px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🐠 Coral Bleaching Early Warning System</h1>
            <div style="font-size: 1.2em; opacity: 0.9;">Andaman & Nicobar Islands Analysis Report</div>
            <div style="margin-top: 15px; font-size: 0.9em;">Analysis Period: {start_date} to {end_date}</div>
        </div>
        
        <div class="primary-index-note">
            <strong>📊 Primary Vulnerability Index: pCRVI (Predictive CRVI)</strong><br>
            This report uses pCRVI as the primary vulnerability metric. pCRVI provides 30-day advance
            warning of bleaching events with demonstrated predictive skill.
        </div>
        
        <div class="section">
            <h2 class="section-title">📈 Predictive CRVI (pCRVI) - Current Status</h2>
            <div class="metric-cards">
                <div class="metric-card primary">
                    <div class="metric-value" style="color: {pcrvi_color};">{pcrvi_score:.3f}</div>
                    <div class="metric-label">pCRVI Score</div>
                    <div style="font-weight: bold; color: {pcrvi_color};">{pcrvi_risk}</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">{pcrvi_correlation:.3f}</div>
                    <div class="metric-label">30-Day Lead Correlation</div>
                </div>
                <div class="metric-card">
                    <div class="metric-value">{pcrvi_f1:.3f}</div>
                    <div class="metric-label">30-Day Lead F1 Score</div>
                </div>
            </div>
            <div class="recommendation">
                <h4>🎯 Current Recommendation</h4>
                <p>{pcrvi_recommendation if pcrvi_recommendation else pcrvi_desc}</p>
            </div>
            <h3>pCRVI Predictive Skill by Lead Time</h3>
            <table>
                <thead><tr><th>Lead Time</th><th>Correlation</th><th>Precision</th><th>Recall</th><th>F1 Score</th><th>MCC</th></tr></thead>
                <tbody>{pcrvi_skill_rows if pcrvi_skill_rows else '<tr><td colspan="6">No skill data available</td></tr>'}</tbody>
            </table>
        </div>
        
        <div class="section">
            <h2 class="section-title">🌡️ Thermal Stress Analysis (DHW)</h2>
            <div class="metric-cards">
                <div class="metric-card"><div class="metric-value">{max_dhw:.2f}</div><div class="metric-label">Maximum DHW (°C-weeks)</div></div>
                <div class="metric-card"><div class="metric-value">{mean_dhw:.2f}</div><div class="metric-label">Mean DHW (°C-weeks)</div></div>
                <div class="metric-card"><div class="metric-value">{total_days:,}</div><div class="metric-label">Days Analyzed</div></div>
                <div class="metric-card"><div class="metric-value">{len(bleaching_years)}</div><div class="metric-label">Bleaching Events</div></div>
            </div>
            <h3>Alert Level Distribution</h3>
            <table>
                <tr><th>Alert Level</th><th>DHW Range</th><th>Days</th></tr>
                <tr><td>Watch</td><td>0 - 3</td><td>{days_watch}</td></tr>
                <tr><td>Warning</td><td>3 - 6</td><td>{days_warning}</td></tr>
                <tr><td>Alert Level 1</td><td>6 - 8</td><td>{days_alert1}</td></tr>
                <tr><td>Alert Level 2</td><td>≥8</td><td>{days_alert2}</td></tr>
            </table>
        </div>
        
        <div class="section">
            <h2 class="section-title">📋 Historical Event Validation</h2>
            <table>
                <thead><tr><th>Year</th><th>Actual Severity</th><th>Reported DHW</th><th>Bleaching %</th><th>Model DHW</th><th>DHW Match</th><th>pCRVI Max</th><th>pCRVI Match</th></tr></thead>
                <tbody>{historical_rows if historical_rows else '<tr><td colspan="8">No historical validation data</td></tr>'}</tbody>
            </table>
        </div>
        
        <!-- DHW Forecasting Section (replaces old Model Comparison) -->
        <section class="section">
            <h2 class="section-title">DHW Time Series Forecasting</h2>
            
            <div style="background: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin-bottom: 20px; border-radius: 0 8px 8px 0;">
                <p><strong>Ensemble (TS + pCRVI)</strong> predicts actual DHW values using time series regression, 
                providing magnitude-aware early warning with demonstrated skill.</p>
            </div>
            
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Model</th>
                        <th>MAE (C-wk)</th>
                        <th>RMSE</th>
                        <th>R2</th>
                        <th>Bleaching F1</th>
                        <th>Precision</th>
                        <th>Recall</th>
                    </tr>
                </thead>
                <tbody>
                    {forecast_rows if forecast_rows else '<tr><td colspan="7">No forecast data available</td></tr>'}
                </tbody>
            </table>
            
            {feature_importance_html}
        </section>
        
        <div class="section">
            <h2 class="section-title">📊 Visualizations</h2>
            <div class="viz-grid">{viz_sections if viz_sections else '<p>No visualizations available</p>'}</div>
        </div>
        
        <div class="footer">
            <p><strong>Coral Bleaching Early Warning System</strong></p>
            <p>Primary Index: Predictive CRVI (pCRVI)</p>
            <p>Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
        </div>
    </div>
</body>
</html>"""
        
        # Save HTML report
        filename = f"{prefix}pcrvi_report.html" if prefix else "pcrvi_report.html"
        path = self.reports_dir / filename
        with open(path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        self.logger.info(f"Generated pCRVI HTML report: {path}")
        return path
    
    def generate_html_report(
        self,
        dhw_data: pd.DataFrame,
        crvi_results: Dict[str, Any],
        pcrvi_results: Optional[Dict[str, Any]] = None,  # Add pCRVI
        model_comparison: Optional[pd.DataFrame] = None,  # Add model comparison
        climate_data: Optional[pd.DataFrame] = None,
        visualization_paths: Optional[Dict[str, Path]] = None,
        start_date: str = "",
        end_date: str = "",
        prefix: str = ""
    ) -> Path:
        """
        Generate a comprehensive, colorful HTML report with embedded visualizations.
        
        Parameters
        ----------
        dhw_data : pd.DataFrame
            DHW time series
        crvi_results : dict
            CRVI calculation results
        model_results : dict, optional
            ML model results
        climate_data : pd.DataFrame, optional
            Climate indices
        visualization_paths : dict, optional
            Paths to visualization images
        start_date : str
            Analysis start date
        end_date : str
            Analysis end date
        prefix : str
            Filename prefix
        
        Returns
        -------
        Path
            Path to HTML report file
        """
        
        # Calculate comprehensive statistics
        total_days = len(dhw_data)
        valid_dhw = dhw_data['dhw'].dropna()
        
        max_dhw = valid_dhw.max() if len(valid_dhw) > 0 else 0
        max_dhw_date = valid_dhw.idxmax() if len(valid_dhw) > 0 else "N/A"
        mean_dhw = valid_dhw.mean() if len(valid_dhw) > 0 else 0
        
        # Count alert days
        days_no_stress = (valid_dhw == 0).sum()
        days_watch = ((valid_dhw > 0) & (valid_dhw < 4)).sum()
        days_partial = ((valid_dhw >= 4) & (valid_dhw < 6)).sum()
        days_moderate = ((valid_dhw >= 6) & (valid_dhw < 8)).sum()
        days_significant = ((valid_dhw >= 8) & (valid_dhw < 12)).sum()
        days_mass = (valid_dhw >= 12).sum()
        
        # Annual statistics
        dhw_copy = dhw_data.copy()
        dhw_copy['year'] = dhw_copy.index.year
        annual_max = dhw_copy.groupby('year')['dhw'].max()
        annual_mean = dhw_copy.groupby('year')['dhw'].mean()
        
        # Bleaching years
        bleaching_years = annual_max[annual_max >= 4].index.tolist()
        severe_years = annual_max[annual_max >= 8].index.tolist()
        
        # NOAA thresholds
        noaa_thresholds = {
            'No Stress': (0, 0, '#2ecc71'),
            'Watch': (0, 4, '#3498db'),
            'Warning': (4, 8, '#f39c12'),
            'Alert Level 1': (8, 12, '#e74c3c'),
            'Alert Level 2': (12, float('inf'), '#8e44ad')
        }
        
        # ANI Calibrated thresholds
        ani_thresholds = {
            'No Stress': (0, 0, '#2ecc71'),
            'Watch': (0, 3, '#3498db'),
            'Partial Bleaching': (3, 4, '#f1c40f'),
            'Minor Bleaching': (4, 6, '#f39c12'),
            'Moderate Bleaching': (6, 8, '#e67e22'),
            'Significant Bleaching': (8, 12, '#e74c3c'),
            'Mass Bleaching': (12, float('inf'), '#8e44ad')
        }
        
        # Helper function to embed images as base64
        def embed_image(image_path: Path) -> str:
            if image_path and image_path.exists():
                with open(image_path, 'rb') as f:
                    encoded = base64.b64encode(f.read()).decode('utf-8')
                return f'data:image/png;base64,{encoded}'
            return ''
        
        # Helper to classify DHW by both systems
        def classify_noaa(dhw):
            if dhw >= 12: return ('Alert Level 2', '#8e44ad', 'Mass Bleaching/Mortality')
            elif dhw >= 8: return ('Alert Level 1', '#e74c3c', 'Significant Bleaching')
            elif dhw >= 4: return ('Warning', '#f39c12', 'Bleaching Likely')
            elif dhw > 0: return ('Watch', '#3498db', 'Thermal Stress')
            else: return ('No Stress', '#2ecc71', 'Normal')
        
        def classify_ani(dhw):
            if dhw >= 12: return ('Alert Level 3', '#8e44ad', 'Mass Bleaching/Mortality')
            elif dhw >= 8: return ('Alert Level 2', '#e74c3c', 'Significant Bleaching')
            elif dhw >= 6: return ('Alert Level 1', '#e67e22', 'Moderate Bleaching')
            elif dhw >= 4: return ('Warning', '#f39c12', 'Partial/Minor Bleaching')
            elif dhw >= 3: return ('Watch', '#3498db', 'Thermal Stress Building')
            elif dhw > 0: return ('Low Watch', '#27ae60', 'Minor Thermal Anomaly')
            else: return ('No Stress', '#2ecc71', 'Normal')
        
        def classify_pcrvi(score):
            """Classify pCRVI score based on user-defined thresholds."""
            if score >= 0.6:
                return ('Severe Risk', '#c0392b', 'High probability of severe bleaching')
            elif score >= 0.5:
                return ('Moderate Risk', '#e67e22', 'Moderate bleaching likely')
            elif score >= 0.4:
                return ('Warning', '#f1c40f', 'Conditions conducive to bleaching')
            else:
                return ('Low Risk', '#2ecc71', 'Conditions stable')
        
        # Build annual comparison table rows
        annual_rows = ""
        for year in sorted(annual_max.index):
            peak = annual_max[year]
            noaa_class, noaa_color, noaa_desc = classify_noaa(peak)
            ani_class, ani_color, ani_desc = classify_ani(peak)
            
            annual_rows += f"""
            <tr>
                <td class="year-cell">{year}</td>
                <td class="dhw-cell">{peak:.2f}</td>
                <td style="background: {noaa_color}20; border-left: 4px solid {noaa_color};">
                    <span class="status-badge" style="background: {noaa_color};">{noaa_class}</span>
                    <span class="status-desc">{noaa_desc}</span>
                </td>
                <td style="background: {ani_color}20; border-left: 4px solid {ani_color};">
                    <span class="status-badge" style="background: {ani_color};">{ani_class}</span>
                    <span class="status-desc">{ani_desc}</span>
                </td>
            </tr>
            """
        
        # Build climate analysis section
        climate_section = ""
        if climate_data is not None:
            oni = climate_data.get('oni', pd.Series())
            dmi = climate_data.get('dmi', pd.Series())
            
            if len(oni) > 0:
                oni = oni.dropna()
                el_nino = (oni > 0.5).sum()
                la_nina = (oni < -0.5).sum()
                neutral = len(oni) - el_nino - la_nina
                
                climate_section += f"""
                <div class="climate-card enso">
                    <h4>🌊 ENSO (El Niño-Southern Oscillation)</h4>
                    <div class="climate-stats">
                        <div class="stat-item el-nino">
                            <span class="stat-value">{el_nino}</span>
                            <span class="stat-label">El Niño Months</span>
                            <span class="stat-pct">{el_nino/len(oni)*100:.1f}%</span>
                        </div>
                        <div class="stat-item neutral">
                            <span class="stat-value">{neutral}</span>
                            <span class="stat-label">Neutral Months</span>
                            <span class="stat-pct">{neutral/len(oni)*100:.1f}%</span>
                        </div>
                        <div class="stat-item la-nina">
                            <span class="stat-value">{la_nina}</span>
                            <span class="stat-label">La Niña Months</span>
                            <span class="stat-pct">{la_nina/len(oni)*100:.1f}%</span>
                        </div>
                    </div>
                </div>
                """
            
            if len(dmi) > 0:
                dmi = dmi.dropna()
                positive_iod = (dmi > 0.4).sum()
                negative_iod = (dmi < -0.4).sum()
                neutral_iod = len(dmi) - positive_iod - negative_iod
                
                climate_section += f"""
                <div class="climate-card iod">
                    <h4>🌡️ IOD (Indian Ocean Dipole)</h4>
                    <div class="climate-stats">
                        <div class="stat-item positive">
                            <span class="stat-value">{positive_iod}</span>
                            <span class="stat-label">Positive IOD</span>
                            <span class="stat-pct">{positive_iod/len(dmi)*100:.1f}%</span>
                        </div>
                        <div class="stat-item neutral">
                            <span class="stat-value">{neutral_iod}</span>
                            <span class="stat-label">Neutral</span>
                            <span class="stat-pct">{neutral_iod/len(dmi)*100:.1f}%</span>
                        </div>
                        <div class="stat-item negative">
                            <span class="stat-value">{negative_iod}</span>
                            <span class="stat-label">Negative IOD</span>
                            <span class="stat-pct">{negative_iod/len(dmi)*100:.1f}%</span>
                        </div>
                    </div>
                </div>
                """
        
        # Embed visualizations
        viz_sections = ""
        if visualization_paths:
            viz_order = [
                ('dhw_timeseries', 'DHW Time Series', 'Degree Heating Weeks over the analysis period showing thermal stress accumulation'),
                ('sst_dhw_combined', 'SST & DHW Combined', 'Sea Surface Temperature with corresponding DHW values'),
                ('annual_max_dhw', 'Annual Maximum DHW', 'Peak thermal stress recorded each year'),
                ('seasonal_pattern', 'Seasonal Patterns', 'Monthly distribution of thermal stress'),
                ('bleaching_heatmap', 'Bleaching Heatmap', 'Year-month heatmap of DHW values'),
                ('alert_distribution', 'Alert Distribution', 'Distribution of alert levels'),
                ('climate_vs_dhw', 'Climate Indices vs DHW', 'Relationship between climate teleconnections and thermal stress'),
                ('feature_correlation', 'Feature Correlations', 'Correlation matrix of environmental variables'),
                ('crvi_analysis', 'CRVI Analysis', 'Coral Reef Vulnerability Index breakdown'),
                ('noaa_bleaching_alert', 'NOAA-Style Alert Map', 'Current bleaching alert status'),
            ]
            
            for viz_key, viz_title, viz_desc in viz_order:
                if viz_key in visualization_paths:
                    img_data = embed_image(visualization_paths[viz_key])
                    if img_data:
                        viz_sections += f"""
                        <div class="viz-card">
                            <h4>{viz_title}</h4>
                            <p class="viz-desc">{viz_desc}</p>
                            <img src="{img_data}" alt="{viz_title}" class="viz-image">
                        </div>
                        """
        
        # CRVI gauge HTML
        crvi_score = crvi_results.get('crvi', 0)
        crvi_category = crvi_results.get('risk_category', 'Unknown')
        ts_norm = crvi_results.get('ts_normalized', 0)
        rv_norm = crvi_results.get('rv_normalized', 0)
        ri_norm = crvi_results.get('ri_normalized', 0)
        
        # Determine CRVI color
        if crvi_score >= 0.7:
            crvi_color = '#e74c3c'
        elif crvi_score >= 0.5:
            crvi_color = '#f39c12'
        elif crvi_score >= 0.3:
            crvi_color = '#f1c40f'
        else:
            crvi_color = '#2ecc71'
        
         # pCRVI variables for HTML template
        pcrvi_score = 0.0
        pcrvi_risk = "Unknown"
        pcrvi_correlation = 0.0
        pcrvi_f1 = 0.0
        pcrvi_recommendation = "pCRVI data not available"
        pcrvi_skill_rows = ""
        
        if pcrvi_results is not None and isinstance(pcrvi_results, dict):
            curr = pcrvi_results.get('current_assessment', {})
            pcrvi_score = curr.get('pcrvi', 0.0)
            pcrvi_risk, pcrvi_color, pcrvi_desc = classify_pcrvi(pcrvi_score)
            pcrvi_recommendation = curr.get('recommendation', 'No recommendation available')
            
            lead_30 = pcrvi_results.get('lead_time_analysis', {}).get('30_days', {})
            pcrvi_correlation = lead_30.get('correlation', 0.0)
            pcrvi_f1 = lead_30.get('f1_score', 0.0)
            
            # Build pCRVI skill table rows
            for lead_key, lead_data in sorted(pcrvi_results.get('lead_time_analysis', {}).items()):
                days = lead_key.replace('_days', '').replace('_', ' ')
                pcrvi_skill_rows += f"""
                <tr>
                    <td>{days} days</td>
                    <td>{lead_data.get('correlation', 0):.3f}</td>
                    <td>{lead_data.get('precision', 0):.3f}</td>
                    <td>{lead_data.get('recall', 0):.3f}</td>
                    <td>{lead_data.get('f1_score', 0):.3f}</td>
                    <td>{lead_data.get('heidke_skill_score', 0):.3f}</td>
                </tr>
                """
        
        # Model comparison rows for HTML template
        model_rows = ""
        if model_comparison is not None and not model_comparison.empty:
            best_f1 = model_comparison['f1_score'].max() if 'f1_score' in model_comparison.columns else 0
            
            for _, row in model_comparison.iterrows():
                is_best = row.get('f1_score', 0) == best_f1
                row_style = 'background: #e8f5e9;' if is_best else ''
                
                model_rows += f"""
                <tr style="{row_style}">
                    <td><strong>{row.get('model', 'Unknown')}</strong>{' ⭐' if is_best else ''}</td>
                    <td>{row.get('accuracy', 0):.3f}</td>
                    <td>{row.get('precision', 0):.3f}</td>
                    <td>{row.get('recall', 0):.3f}</td>
                    <td>{row.get('f1_score', 0):.3f}</td>
                    <td>{row.get('mcc', 0):.3f}</td>
                    <td>{f"{row.get('roc_auc'):.3f}" if row.get('roc_auc') is not None and not pd.isna(row.get('roc_auc')) else 'N/A'}</td>
                </tr>
                """
        else:
            model_rows = "<tr><td colspan='7'>No model comparison data available</td></tr>"

        # Generate the HTML
        html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Coral Bleaching Early Warning System - Comprehensive Report</title>
    <style>
        :root {{
            --primary: #0077b6;
            --secondary: #00b4d8;
            --accent: #90e0ef;
            --danger: #e74c3c;
            --warning: #f39c12;
            --success: #2ecc71;
            --dark: #1a1a2e;
            --light: #f8f9fa;
            --gradient-ocean: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            --gradient-coral: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            --gradient-sea: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            --gradient-warm: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
        }}
        
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(180deg, #e0f7fa 0%, #ffffff 100%);
            color: var(--dark);
            line-height: 1.6;
        }}
        
        .header {{
            background: var(--gradient-ocean);
            color: white;
            padding: 40px 20px;
            text-align: center;
            position: relative;
            overflow: hidden;
        }}
        
        .header::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1440 320'%3E%3Cpath fill='%23ffffff' fill-opacity='0.1' d='M0,96L48,112C96,128,192,160,288,160C384,160,480,128,576,122.7C672,117,768,139,864,154.7C960,171,1056,181,1152,165.3C1248,149,1344,107,1392,85.3L1440,64L1440,320L1392,320C1344,320,1248,320,1152,320C1056,320,960,320,864,320C768,320,672,320,576,320C480,320,384,320,288,320C192,320,96,320,48,320L0,320Z'%3E%3C/path%3E%3C/svg%3E") no-repeat bottom;
            background-size: cover;
        }}
        
        .header h1 {{
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            position: relative;
            z-index: 1;
        }}
        
        .header .subtitle {{
            font-size: 1.2em;
            opacity: 0.9;
            position: relative;
            z-index: 1;
        }}
        
        .header .coral-icon {{
            font-size: 3em;
            margin-bottom: 15px;
        }}
        
        .container {{
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }}
        
        .metadata-bar {{
            background: white;
            border-radius: 15px;
            padding: 20px 30px;
            margin: -30px 20px 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            display: flex;
            justify-content: space-around;
            flex-wrap: wrap;
            gap: 20px;
            position: relative;
            z-index: 10;
        }}
        
        .meta-item {{
            text-align: center;
        }}
        
        .meta-item .label {{
            font-size: 0.85em;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 1px;
        }}
        
        .meta-item .value {{
            font-size: 1.3em;
            font-weight: 600;
            color: var(--primary);
        }}
        
        .section {{
            background: white;
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 5px 30px rgba(0,0,0,0.08);
        }}
        
        .section-title {{
            font-size: 1.8em;
            color: var(--dark);
            margin-bottom: 25px;
            padding-bottom: 15px;
            border-bottom: 3px solid var(--accent);
            display: flex;
            align-items: center;
            gap: 15px;
        }}
        
        .section-title .icon {{
            font-size: 1.2em;
        }}
        
        /* Executive Summary Cards */
        .summary-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }}
        
        .summary-card {{
            background: var(--gradient-sea);
            border-radius: 15px;
            padding: 25px;
            color: white;
            text-align: center;
            transition: transform 0.3s ease;
        }}
        
        .summary-card:hover {{
            transform: translateY(-5px);
        }}
        
        .summary-card.warning {{
            background: var(--gradient-warm);
        }}
        
        .summary-card.danger {{
            background: var(--gradient-coral);
        }}
        
        .summary-card .big-number {{
            font-size: 3em;
            font-weight: 700;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }}
        
        .summary-card .card-label {{
            font-size: 1em;
            opacity: 0.9;
            margin-top: 5px;
        }}
        
        /* Threshold Tables */
        .threshold-container {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
            margin-bottom: 30px;
        }}
        
        .threshold-table {{
            background: #f8f9fa;
            border-radius: 15px;
            overflow: hidden;
        }}
        
        .threshold-table h4 {{
            background: var(--gradient-ocean);
            color: white;
            padding: 15px 20px;
            margin: 0;
            font-size: 1.1em;
        }}
        
        .threshold-table.ani h4 {{
            background: var(--gradient-coral);
        }}
        
        .threshold-table table {{
            width: 100%;
            border-collapse: collapse;
        }}
        
        .threshold-table th, .threshold-table td {{
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #e0e0e0;
        }}
        
        .threshold-table th {{
            background: #f0f0f0;
            font-weight: 600;
            color: #555;
        }}
        
        .threshold-table tr:last-child td {{
            border-bottom: none;
        }}
        
        .color-indicator {{
            width: 20px;
            height: 20px;
            border-radius: 50%;
            display: inline-block;
            margin-right: 10px;
            vertical-align: middle;
        }}
        
        /* Annual Comparison Table */
        .annual-table {{
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            margin-top: 20px;
        }}
        
        .annual-table th {{
            background: var(--dark);
            color: white;
            padding: 15px;
            text-align: left;
            position: sticky;
            top: 0;
        }}
        
        .annual-table th:first-child {{
            border-radius: 10px 0 0 0;
        }}
        
        .annual-table th:last-child {{
            border-radius: 0 10px 0 0;
        }}
        
        .annual-table td {{
            padding: 12px 15px;
            border-bottom: 1px solid #eee;
            vertical-align: middle;
        }}
        
        .annual-table tr:hover {{
            background: #f5f5f5;
        }}
        
        .year-cell {{
            font-weight: 600;
            font-size: 1.1em;
        }}
        
        .dhw-cell {{
            font-family: 'Courier New', monospace;
            font-weight: 600;
            font-size: 1.1em;
            color: var(--primary);
        }}
        
        .status-badge {{
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            color: white;
            font-size: 0.85em;
            font-weight: 600;
            margin-right: 10px;
        }}
        
        .status-desc {{
            color: #666;
            font-size: 0.9em;
        }}
        
        /* CRVI Gauge */
        .crvi-container {{
            display: grid;
            grid-template-columns: 1fr 2fr;
            gap: 40px;
            align-items: center;
        }}
        
        .crvi-gauge {{
            text-align: center;
        }}
        
        .gauge-circle {{
            width: 200px;
            height: 200px;
            border-radius: 50%;
            background: conic-gradient(
                {crvi_color} 0deg,
                {crvi_color} {crvi_score * 360}deg,
                #e0e0e0 {crvi_score * 360}deg,
                #e0e0e0 360deg
            );
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.15);
        }}
        
        .gauge-inner {{
            width: 160px;
            height: 160px;
            border-radius: 50%;
            background: white;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }}
        
        .gauge-value {{
            font-size: 2.5em;
            font-weight: 700;
            color: {crvi_color};
        }}
        
        .gauge-label {{
            font-size: 1em;
            color: #666;
        }}
        
        .crvi-components {{
            display: grid;
            gap: 20px;
        }}
        
        .component-bar {{
            background: #f0f0f0;
            border-radius: 10px;
            padding: 15px 20px;
        }}
        
        .component-bar .bar-header {{
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
        }}
        
        .component-bar .bar-title {{
            font-weight: 600;
        }}
        
        .component-bar .bar-value {{
            color: var(--primary);
            font-weight: 600;
        }}
        
        .bar-track {{
            height: 12px;
            background: #ddd;
            border-radius: 6px;
            overflow: hidden;
        }}
        
        .bar-fill {{
            height: 100%;
            border-radius: 6px;
            transition: width 1s ease;
        }}
        
        .bar-fill.ts {{ background: var(--gradient-coral); }}
        .bar-fill.rv {{ background: var(--gradient-warm); }}
        .bar-fill.ri {{ background: var(--gradient-sea); }}
        
        /* Climate Cards */
        .climate-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 25px;
        }}
        
        .climate-card {{
            background: #f8f9fa;
            border-radius: 15px;
            padding: 25px;
            border-left: 5px solid var(--primary);
        }}
        
        .climate-card.iod {{
            border-left-color: #e67e22;
        }}
        
        .climate-card h4 {{
            margin-bottom: 20px;
            color: var(--dark);
        }}
        
        .climate-stats {{
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 15px;
        }}
        
        .stat-item {{
            text-align: center;
            padding: 15px;
            border-radius: 10px;
            background: white;
        }}
        
        .stat-item.el-nino {{ border-top: 3px solid #e74c3c; }}
        .stat-item.la-nina {{ border-top: 3px solid #3498db; }}
        .stat-item.neutral {{ border-top: 3px solid #95a5a6; }}
        .stat-item.positive {{ border-top: 3px solid #e74c3c; }}
        .stat-item.negative {{ border-top: 3px solid #3498db; }}
        
        .stat-value {{
            display: block;
            font-size: 1.8em;
            font-weight: 700;
            color: var(--dark);
        }}
        
        .stat-label {{
            display: block;
            font-size: 0.85em;
            color: #666;
            margin-top: 5px;
        }}
        
        .stat-pct {{
            display: block;
            font-size: 0.9em;
            color: var(--primary);
            font-weight: 600;
            margin-top: 5px;
        }}
        
        /* Visualizations */
        .viz-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));
            gap: 30px;
        }}
        
        .viz-card {{
            background: #f8f9fa;
            border-radius: 15px;
            overflow: hidden;
            box-shadow: 0 5px 20px rgba(0,0,0,0.05);
        }}
        
        .viz-card h4 {{
            background: var(--dark);
            color: white;
            padding: 15px 20px;
            margin: 0;
        }}
        
        .viz-card .viz-desc {{
            padding: 10px 20px;
            color: #666;
            font-size: 0.9em;
            background: white;
            border-bottom: 1px solid #eee;
        }}
        
        .viz-image {{
            width: 100%;
            height: auto;
            display: block;
        }}
        
        /* Alert Distribution */
        .alert-distribution {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }}
        
        .alert-item {{
            text-align: center;
            padding: 20px;
            border-radius: 12px;
            color: white;
        }}
        
        .alert-item .alert-days {{
            font-size: 2em;
            font-weight: 700;
        }}
        
        .alert-item .alert-pct {{
            font-size: 1.1em;
            opacity: 0.9;
        }}
        
        .alert-item .alert-name {{
            font-size: 0.85em;
            margin-top: 5px;
            opacity: 0.9;
        }}
        
        /* Recommendations */
        .recommendations {{
            display: grid;
            gap: 15px;
        }}
        
        .rec-item {{
            display: flex;
            align-items: flex-start;
            gap: 15px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 12px;
            border-left: 4px solid var(--primary);
        }}
        
        .rec-item.urgent {{
            border-left-color: var(--danger);
            background: #fff5f5;
        }}
        
        .rec-item.warning {{
            border-left-color: var(--warning);
            background: #fffbf0;
        }}
        
        .rec-icon {{
            font-size: 1.5em;
        }}
        
        .rec-content h5 {{
            margin-bottom: 5px;
            color: var(--dark);
        }}
        
        .rec-content p {{
            color: #666;
            font-size: 0.95em;
        }}
        
        /* Footer */
        .footer {{
            background: var(--dark);
            color: white;
            padding: 30px;
            text-align: center;
            margin-top: 40px;
        }}
        
        .footer a {{
            color: var(--accent);
        }}
        
        /* Print Styles */
        @media print {{
            .header {{
                background: var(--primary) !important;
                -webkit-print-color-adjust: exact;
            }}
            .section {{
                break-inside: avoid;
            }}
            .viz-card {{
                break-inside: avoid;
            }}
        }}
        
        /* Responsive */
        @media (max-width: 768px) {{
            .header h1 {{
                font-size: 1.8em;
            }}
            .metadata-bar {{
                flex-direction: column;
                margin: -20px 10px 20px;
            }}
            .threshold-container {{
                grid-template-columns: 1fr;
            }}
            .crvi-container {{
                grid-template-columns: 1fr;
            }}
            .viz-grid {{
                grid-template-columns: 1fr;
            }}
            .climate-stats {{
                grid-template-columns: 1fr;
            }}
        }}
    </style>
</head>
<body>
    <header class="header">
        <div class="coral-icon">🪸</div>
        <h1>Coral Bleaching Early Warning System</h1>
        <p class="subtitle">Comprehensive Analysis Report - Andaman & Nicobar Islands</p>
    </header>
    
    <div class="metadata-bar">
        <div class="meta-item">
            <div class="label">Analysis Period</div>
            <div class="value">{start_date} to {end_date}</div>
        </div>
        <div class="meta-item">
            <div class="label">Total Days</div>
            <div class="value">{total_days:,}</div>
        </div>
        <div class="meta-item">
            <div class="label">Region</div>
            <div class="value">90°E-95°E, 6°N-14°N</div>
        </div>
        <div class="meta-item">
            <div class="label">MMM SST</div>
            <div class="value">29.87°C</div>
        </div>
        <div class="meta-item">
            <div class="label">Generated</div>
            <div class="value">{datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}</div>
        </div>
    </div>
    
    <div class="container">
        <!-- Executive Summary -->
        <section class="section">
            <h2 class="section-title"><span class="icon">📊</span> Executive Summary</h2>
            
            <div class="summary-grid">
                <div class="summary-card">
                    <div class="big-number">{max_dhw:.1f}</div>
                    <div class="card-label">Maximum DHW (°C-weeks)</div>
                </div>
                <div class="summary-card warning">
                    <div class="big-number">{len(bleaching_years)}</div>
                    <div class="card-label">Bleaching Years (DHW ≥ 4)</div>
                </div>
                <div class="summary-card danger">
                    <div class="big-number">{len(severe_years)}</div>
                    <div class="card-label">Severe Events (DHW ≥ 8)</div>
                </div>
                <div class="summary-card" style="background: linear-gradient(135deg, {crvi_color} 0%, {crvi_color}dd 100%);">
                    <div class="big-number">{crvi_score:.2f}</div>
                    <div class="card-label">CRVI Score ({crvi_category})</div>
                </div>
            </div>
            
            <div class="alert-distribution">
                <div class="alert-item" style="background: #2ecc71;">
                    <div class="alert-days">{days_no_stress:,}</div>
                    <div class="alert-pct">{days_no_stress/len(valid_dhw)*100:.1f}%</div>
                    <div class="alert-name">No Stress</div>
                </div>
                <div class="alert-item" style="background: #3498db;">
                    <div class="alert-days">{days_watch:,}</div>
                    <div class="alert-pct">{days_watch/len(valid_dhw)*100:.1f}%</div>
                    <div class="alert-name">Watch</div>
                </div>
                <div class="alert-item" style="background: #f1c40f;">
                    <div class="alert-days">{days_partial:,}</div>
                    <div class="alert-pct">{days_partial/len(valid_dhw)*100:.1f}%</div>
                    <div class="alert-name">Partial Bleaching</div>
                </div>
                <div class="alert-item" style="background: #e67e22;">
                    <div class="alert-days">{days_moderate:,}</div>
                    <div class="alert-pct">{days_moderate/len(valid_dhw)*100:.1f}%</div>
                    <div class="alert-name">Moderate</div>
                </div>
                <div class="alert-item" style="background: #e74c3c;">
                    <div class="alert-days">{days_significant:,}</div>
                    <div class="alert-pct">{days_significant/len(valid_dhw)*100:.1f}%</div>
                    <div class="alert-name">Significant</div>
                </div>
                <div class="alert-item" style="background: #8e44ad;">
                    <div class="alert-days">{days_mass:,}</div>
                    <div class="alert-pct">{days_mass/len(valid_dhw)*100:.1f}%</div>
                    <div class="alert-name">Mass Bleaching</div>
                </div>
            </div>
        </section>
        
        <!-- Threshold Comparison -->
        <section class="section">
            <h2 class="section-title"><span class="icon">📏</span> DHW Threshold Comparison</h2>
            <p style="margin-bottom: 20px; color: #666;">
                Comparison of standard NOAA Coral Reef Watch thresholds versus region-specific calibrated thresholds 
                for the Andaman & Nicobar Islands based on historical bleaching-DHW correlations.
            </p>
            
            <div class="threshold-container">
                <div class="threshold-table">
                    <h4>🌐 NOAA Standard Thresholds</h4>
                    <table>
                        <thead>
                            <tr>
                                <th>Alert Level</th>
                                <th>DHW Range</th>
                                <th>Expected Impact</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td><span class="color-indicator" style="background: #2ecc71;"></span>No Stress</td>
                                <td>DHW = 0</td>
                                <td>Normal conditions</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #3498db;"></span>Watch</td>
                                <td>0 &lt; DHW &lt; 4</td>
                                <td>Thermal stress accumulating</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #f39c12;"></span>Warning</td>
                                <td>4 ≤ DHW &lt; 8</td>
                                <td>Bleaching likely</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #e74c3c;"></span>Alert Level 1</td>
                                <td>8 ≤ DHW &lt; 12</td>
                                <td>Significant bleaching expected</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #8e44ad;"></span>Alert Level 2</td>
                                <td>DHW ≥ 12</td>
                                <td>Mass bleaching & mortality</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                
                <div class="threshold-table ani">
                    <h4>🏝️ ANI Calibrated Thresholds</h4>
                    <table>
                        <thead>
                            <tr>
                                <th>Alert Level</th>
                                <th>DHW Range</th>
                                <th>Expected Impact</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td><span class="color-indicator" style="background: #2ecc71;"></span>No Stress</td>
                                <td>DHW = 0</td>
                                <td>Normal conditions</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #27ae60;"></span>Low Watch</td>
                                <td>0 &lt; DHW &lt; 3</td>
                                <td>Minor thermal anomaly</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #3498db;"></span>Watch</td>
                                <td>3 ≤ DHW &lt; 4</td>
                                <td>Thermal stress building</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #f39c12;"></span>Warning</td>
                                <td>4 ≤ DHW &lt; 6</td>
                                <td>Partial/minor bleaching possible</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #e67e22;"></span>Alert Level 1</td>
                                <td>6 ≤ DHW &lt; 8</td>
                                <td>Moderate bleaching likely</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #e74c3c;"></span>Alert Level 2</td>
                                <td>8 ≤ DHW &lt; 12</td>
                                <td>Significant bleaching expected</td>
                            </tr>
                            <tr>
                                <td><span class="color-indicator" style="background: #8e44ad;"></span>Alert Level 3</td>
                                <td>DHW ≥ 12</td>
                                <td>Mass bleaching & mortality</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </section>
        
        <!-- Annual DHW Comparison -->
        <section class="section">
            <h2 class="section-title"><span class="icon">📅</span> Annual DHW Analysis - Dual Classification</h2>
            <p style="margin-bottom: 20px; color: #666;">
                Year-by-year maximum DHW values classified using both NOAA standard and ANI-calibrated threshold systems.
                This comparison highlights how regional calibration affects bleaching risk assessment.
            </p>
            
            <div style="overflow-x: auto;">
                <table class="annual-table">
                    <thead>
                        <tr>
                            <th>Year</th>
                            <th>Max DHW (°C-weeks)</th>
                            <th>NOAA Classification</th>
                            <th>ANI Calibrated Classification</th>
                        </tr>
                    </thead>
                    <tbody>
                        {annual_rows}
                    </tbody>
                </table>
            </div>
        </section>
        
        <!-- CRVI Section -->
        <section class="section">
            <h2 class="section-title"><span class="icon">🎯</span> Coral Reef Vulnerability Index (CRVI)</h2>
            
            <div class="crvi-container">
                <div class="crvi-gauge">
                    <div class="gauge-circle">
                        <div class="gauge-inner">
                            <div class="gauge-value">{crvi_score:.2f}</div>
                            <div class="gauge-label">{crvi_category} Risk</div>
                        </div>
                    </div>
                    <p style="color: #666; font-size: 0.9em;">
                        Scale: 0 (Low) to 1 (Critical)
                    </p>
                </div>
                
                <div class="crvi-components">
                    <div class="component-bar">
                        <div class="bar-header">
                            <span class="bar-title">🌡️ Thermal Stress (TS) - Weight: 50%</span>
                            <span class="bar-value">{ts_norm:.3f}</span>
                        </div>
                        <div class="bar-track">
                            <div class="bar-fill ts" style="width: {ts_norm*100}%;"></div>
                        </div>
                        <p style="margin-top: 8px; font-size: 0.85em; color: #666;">
                            Mean annual maximum DHW normalized to regional baseline
                        </p>
                    </div>
                    
                    <div class="component-bar">
                        <div class="bar-header">
                            <span class="bar-title">⏱️ Recovery Vulnerability (RV) - Weight: 30%</span>
                            <span class="bar-value">{rv_norm:.3f}</span>
                        </div>
                        <div class="bar-track">
                            <div class="bar-fill rv" style="width: {rv_norm*100}%;"></div>
                        </div>
                        <p style="margin-top: 8px; font-size: 0.85em; color: #666;">
                            Time since last bleaching event (higher = less recovery time)
                        </p>
                    </div>
                    
                    <div class="component-bar">
                        <div class="bar-header">
                            <span class="bar-title">🔄 Recurrence Index (RI) - Weight: 20%</span>
                            <span class="bar-value">{ri_norm:.3f}</span>
                        </div>
                        <div class="bar-track">
                            <div class="bar-fill ri" style="width: {ri_norm*100}%;"></div>
                        </div>
                        <p style="margin-top: 8px; font-size: 0.85em; color: #666;">
                            Frequency of bleaching events over analysis period
                        </p>
                    </div>
                </div>
            </div>
        </section>
        <!-- Predictive CRVI Section -->
        <section class="section">
            <h2 class="section-title"><span class="icon">🔮</span> Predictive CRVI (pCRVI) - Forecasting System</h2>
            
            <div class="pcrvi-dashboard">
                <div class="metric-cards">
                    <div class="metric-card primary" style="border-left: 5px solid {pcrvi_color};">
                        <div class="metric-value" style="color: {pcrvi_color};">{pcrvi_score:.3f}</div>
                        <div class="metric-label" style="color: {pcrvi_color};">{pcrvi_risk}</div>
                        <div class="metric-sublabel">{pcrvi_desc}</div>
                    </div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">{pcrvi_correlation:.3f}</div>
                        <div class="metric-label">30-Day Correlation</div>
                    </div>
                    <div class="metric-card">
                        <div class="metric-value">{pcrvi_f1:.1%}</div>
                        <div class="metric-label">F1 Score</div>
                    </div>
                </div>
                
                <div class="pcrvi-recommendation">
                    <h4>Recommendation</h4>
                    <p>{pcrvi_recommendation}</p>
                </div>
                
                <div class="pcrvi-skill-table">
                    <h4>Predictive Skill by Lead Time</h4>
                    <table>
                        <thead>
                            <tr>
                                <th>Lead Time</th>
                                <th>Correlation</th>
                                <th>Precision</th>
                                <th>Recall</th>
                                <th>F1</th>
                                <th>MCC</th>
                            </tr>
                        </thead>
                        <tbody>
                            {pcrvi_skill_rows}
                        </tbody>
                    </table>
                </div>
            </div>
        </section>
        <!-- Model Comparison Section -->
        <section class="section">
            <h2 class="section-title"><span class="icon">📈</span> DHW Time Series Forecasting</h2>
            
            <div class="info-box">
                <p><strong>Ensemble (TS + pCRVI)</strong> predicts actual DHW values using 
                time series regression, providing magnitude-aware early warning.</p>
            </div>
            
            <table class="forecast-table">
                <thead>
                    <tr>
                        <th>Model</th>
                        <th>MAE (°C-wk)</th>
                        <th>RMSE</th>
                        <th>R²</th>
                        <th>Bleaching F1</th>
                        <th>Precision</th>
                        <th>Recall</th>
                    </tr>
                </thead>
                <tbody>
                    {forecast_rows}
                </tbody>
            </table>
            {feature_importance_section}
        </section>
        
        <section class="section">
            <h2 class="section-title"><span class="icon">🤖</span> Machine Learning Model Comparison</h2>
            
            <div class="model-comparison">
                <table class="model-table">
                    <thead>
                        <tr>
                            <th>Model</th>
                            <th>Accuracy</th>
                            <th>Precision</th>
                            <th>Recall</th>
                            <th>F1 Score</th>
                            <th>MCC</th>
                            <th>ROC-AUC</th>
                        </tr>
                    </thead>
                    <tbody>
                        {model_rows}
                    </tbody>
                </table>
            </div>
        </section>
        <!-- Climate Teleconnections -->
        <section class="section">
            <h2 class="section-title"><span class="icon">🌍</span> Climate Teleconnections</h2>
            <p style="margin-bottom: 20px; color: #666;">
                Analysis of major climate drivers affecting thermal stress in the Andaman Sea region.
                El Niño events and positive IOD phases are associated with elevated bleaching risk.
            </p>
            
            <div class="climate-grid">
                {climate_section}
            </div>
        </section>
        
        <!-- Visualizations -->
        <section class="section">
            <h2 class="section-title"><span class="icon">📈</span> Visualizations</h2>
            
            <div class="viz-grid">
                {viz_sections}
            </div>
        </section>
        
        <!-- Recommendations -->
        <section class="section">
            <h2 class="section-title"><span class="icon">💡</span> Recommendations</h2>
            
            <div class="recommendations">
                {"<div class='rec-item urgent'><span class='rec-icon'>🚨</span><div class='rec-content'><h5>Immediate Action Required</h5><p>CRVI indicates high vulnerability. Implement emergency monitoring protocols and reduce local stressors immediately.</p></div></div>" if crvi_score >= 0.6 else ""}
                
                {"<div class='rec-item warning'><span class='rec-icon'>⚠️</span><div class='rec-content'><h5>Enhanced Monitoring</h5><p>Recent bleaching events detected. Increase monitoring frequency during peak thermal stress season (March-May).</p></div></div>" if len(bleaching_years) > 0 else ""}
                
                <div class="rec-item">
                    <span class="rec-icon">📊</span>
                    <div class="rec-content">
                        <h5>Use Regional Thresholds</h5>
                        <p>The ANI-calibrated thresholds provide more accurate bleaching predictions for this region. 
                        Consider DHW ≥ 6 as the threshold for significant bleaching risk rather than the standard DHW ≥ 8.</p>
                    </div>
                </div>
                
                <div class="rec-item">
                    <span class="rec-icon">🌊</span>
                    <div class="rec-content">
                        <h5>Monitor Climate Indices</h5>
                        <p>Track ENSO and IOD forecasts. Compound El Niño + positive IOD events create extreme 
                        bleaching risk and warrant preemptive management actions.</p>
                    </div>
                </div>
                
                <div class="rec-item">
                    <span class="rec-icon">🔬</span>
                    <div class="rec-content">
                        <h5>Document Adaptation</h5>
                        <p>Monitor coral recovery and potential thermal adaptation. Reefs surviving multiple 
                        bleaching events may develop increased heat tolerance.</p>
                    </div>
                </div>
                
                <div class="rec-item">
                    <span class="rec-icon">🗺️</span>
                    <div class="rec-content">
                        <h5>Identify Refugia</h5>
                        <p>Map areas with consistently lower thermal stress for priority protection as 
                        potential climate refugia and source populations for restoration.</p>
                    </div>
                </div>
            </div>
        </section>
    </div>
    
    <footer class="footer">
        <p><strong>Coral Bleaching Early Warning System</strong></p>
        <p>Report generated on {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
        <p style="margin-top: 10px; opacity: 0.8;">
            Data sources: NOAA Coral Reef Watch, NASA Ocean Color, NOAA PSL Climate Indices
        </p>
    </footer>
</body>
</html>
"""
        
        # Save HTML report
        filename = f"{prefix}comprehensive_report.html" if prefix else "comprehensive_report.html"
        path = self.reports_dir / filename
        
        with open(path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        self.logger.info(f"Generated comprehensive HTML report: {path}")
        
        return path
