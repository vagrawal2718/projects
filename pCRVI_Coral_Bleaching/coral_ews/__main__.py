#!/usr/bin/env python3
"""
Coral Bleaching Early Warning System - Main Entry Point
=========================================================

Command-line interface for the Coral Bleaching EWS.

Usage:
    python -m coral_ews --help
    python -m coral_ews run --start 2020-01-01 --end 2020-12-31
    python -m coral_ews validate
    python -m coral_ews test-connections
"""

import argparse
import sys
from datetime import datetime, date, timedelta
from pathlib import Path
from typing import Optional

from .config import Config
from .logger import setup_logger, get_logger, create_diagnostic_report
from .exceptions import CoralEWSError
from .pipeline import CoralBleachingEWS


def parse_args():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Coral Bleaching Early Warning System for Andaman & Nicobar Islands",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Run full workflow for a date range
    python -m coral_ews run --start 2020-01-01 --end 2020-12-31
    
    # Test connections to data sources
    python -m coral_ews test-connections
    
    # Validate configuration
    python -m coral_ews validate
    
    # Generate alert for recent data
    python -m coral_ews alert --days 90
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # Run command
    run_parser = subparsers.add_parser('run', help='Run the EWS workflow')
    run_parser.add_argument(
    '--start', '-s',
    type=str,
    default='1998-01-01',
    help='Start date (YYYY-MM-DD, default: 1998-01-01)'
    )
    run_parser.add_argument(
    '--end', '-e',
    type=str,
    default='2025-12-31',
    help='End date (YYYY-MM-DD, default: 2025-12-31)'
    )
    run_parser.add_argument(
        '--skip-ocean-color',
        action='store_true',
        help='Skip ocean color data acquisition'
    )
    run_parser.add_argument(
        '--skip-atmospheric',
        action='store_true',
        help='Skip atmospheric data acquisition'
    )
    run_parser.add_argument(
        '--output', '-o',
        type=str,
        default='./output',
        help='Output directory'
    )
    run_parser.add_argument(
        '--gee-project',
        type=str,
        default=None,
        help='Google Earth Engine project ID'
    )
    
    # Region selection (mutually exclusive group)
    region_group = run_parser.add_mutually_exclusive_group()
    region_group.add_argument('--region', type=str, default=None,
        help='Run for a specific region key (e.g., gbr, lakshadweep)')
    region_group.add_argument('--all', action='store_true',
        help='Run for all 14 regions')
    region_group.add_argument('--india', action='store_true',
        help='Run for 5 Indian reef regions')
    region_group.add_argument('--southeast-asia', dest='southeast_asia',
        action='store_true', help='Run for 4 SE Asian reef regions')
    region_group.add_argument('--global', dest='global_hotspots',
        action='store_true', help='Run for 5 global hotspot regions')

    # Multi-region options
    run_parser.add_argument('--compare', action='store_true',
        help='Generate cross-region comparison plots after multi-region runs')
    run_parser.add_argument('--list-regions', action='store_true',
        help='List all available regions and exit')
    
    # Test connections command
    test_parser = subparsers.add_parser(
        'test-connections',
        help='Test connections to all data sources'
    )
    test_parser.add_argument(
        '--gee-project',
        type=str,
        default=None,
        help='Google Earth Engine project ID'
    )
    
    # Validate command
    validate_parser = subparsers.add_parser(
        'validate',
        help='Validate configuration and data sources'
    )
    
    # Alert command
    alert_parser = subparsers.add_parser(
        'alert',
        help='Generate current bleaching alert'
    )
    alert_parser.add_argument(
        '--days', '-d',
        type=int,
        default=90,
        help='Number of days of data to use (default: 90)'
    )
    alert_parser.add_argument(
        '--gee-project',
        type=str,
        default=None,
        help='Google Earth Engine project ID'
    )
    
    # Global options
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose output'
    )
    parser.add_argument(
        '--debug',
        action='store_true',
        help='Enable debug output'
    )
    
    return parser.parse_args()


def test_connections(gee_project: Optional[str] = None) -> bool:
    """
    Test connections to all data sources.
    
    Returns
    -------
    bool
        True if all connections successful
    """
    logger = get_logger("coral_ews.cli")
    logger.info("Testing connections to data sources...")
    
    all_ok = True
    results = {}
    
    # Test GEE
    logger.info("\n1. Testing Google Earth Engine...")
    try:
        from .data_acquisition import GEEClient
        gee = GEEClient(project_id=gee_project)
        gee.authenticate()
        
        # Check a dataset
        availability = gee.check_dataset_availability("NOAA/CDR/OISST/V2_1")
        if availability['available']:
            logger.info("   ✓ GEE: Connected and OISST available")
            results['gee'] = 'OK'
        else:
            logger.warning("   ✗ GEE: Connected but OISST not available")
            results['gee'] = 'PARTIAL'
            all_ok = False
    except Exception as e:
        logger.error(f"   ✗ GEE: {str(e)}")
        results['gee'] = f'FAILED: {str(e)}'
        all_ok = False
    
    # Test Copernicus
    logger.info("\n2. Testing Copernicus Marine...")
    try:
        from .data_acquisition import CopernicusClient
        cop = CopernicusClient()
        availability = cop.check_dataset_availability("OCEANCOLOUR_GLO_BGC_L3_MY_009_103")
        if availability['available']:
            logger.info("   ✓ Copernicus: Connected and ocean color available")
            results['copernicus'] = 'OK'
        else:
            logger.warning(f"   ✗ Copernicus: {availability.get('error', 'Unknown error')}")
            results['copernicus'] = 'PARTIAL'
            all_ok = False
    except Exception as e:
        logger.error(f"   ✗ Copernicus: {str(e)}")
        results['copernicus'] = f'FAILED: {str(e)}'
        all_ok = False
    
    # Test NOAA
    logger.info("\n3. Testing NOAA data sources...")
    try:
        from .data_acquisition import NOAAClient
        noaa = NOAAClient()
        # Just test if we can make HTTP requests
        import urllib.request
        with urllib.request.urlopen(
            "https://coralreefwatch.noaa.gov/product/vs/data/andaman.txt",
            timeout=30
        ) as response:
            if response.status == 200:
                logger.info("   ✓ NOAA: Virtual Station accessible")
                results['noaa'] = 'OK'
    except Exception as e:
        logger.error(f"   ✗ NOAA: {str(e)}")
        results['noaa'] = f'FAILED: {str(e)}'
        all_ok = False
    
    # Test Climate Indices
    logger.info("\n4. Testing Climate Indices...")
    try:
        from .data_acquisition import ClimateIndicesClient
        climate = ClimateIndicesClient()
        oni = climate.download_oni()
        if len(oni) > 0:
            logger.info("   ✓ ONI: Data accessible")
            results['oni'] = 'OK'
    except Exception as e:
        logger.error(f"   ✗ ONI: {str(e)}")
        results['oni'] = f'FAILED: {str(e)}'
        all_ok = False
    
    # Summary
    logger.info("\n" + "=" * 50)
    logger.info("Connection Test Summary:")
    logger.info("=" * 50)
    for source, status in results.items():
        symbol = "✓" if status == 'OK' else "✗"
        logger.info(f"  {symbol} {source.upper()}: {status}")
    
    if all_ok:
        logger.info("\nAll connections successful!")
    else:
        logger.warning("\nSome connections failed. Check errors above.")
    
    return all_ok


def validate_config() -> bool:
    """
    Validate configuration.
    
    Returns
    -------
    bool
        True if configuration is valid
    """
    logger = get_logger("coral_ews.cli")
    logger.info("Validating configuration...")
    
    config = Config()
    warnings = config.validate()
    
    if warnings:
        logger.warning("Configuration warnings:")
        for w in warnings:
            logger.warning(f"  - {w}")
        return False
    else:
        logger.info("Configuration is valid")
        
        # Print configuration summary
        logger.info("\nConfiguration Summary:")
        logger.info(f"  Region: {config.region.name}")
        logger.info(f"  Bounds: {config.region.bounds}")
        logger.info(f"  MMM SST: {config.region.mmm_sst}°C")
        logger.info(f"  DHW Window: {config.dhw_params.accumulation_days} days")
        logger.info(f"  Data directory: {config.data_dir}")
        logger.info(f"  Output directory: {config.output_dir}")
        
        return True


def run_workflow(args) -> int:
    """Run the EWS workflow (single or multi-region)."""
    from .reef_regions import REEF_REGISTRY, list_indian_regions, \
        list_southeast_asian_regions, list_global_hotspots, list_regions

    logger = get_logger("coral_ews.cli")

    # Handle --list-regions
    if getattr(args, 'list_regions', False):
        print("\nAvailable Regions:")
        print(f"  {'andaman':<22s} Andaman & Nicobar Islands (default)")
        for key, reg in REEF_REGISTRY.items():
            print(f"  {key:<22s} {reg.name}")
        return 0

    start_date = args.start
    end_date = args.end or datetime.now().strftime("%Y-%m-%d")
    output_dir = args.output
    gee_project = args.gee_project

    # Determine region keys
    if getattr(args, 'all', False):
        region_keys = ['andaman'] + list(REEF_REGISTRY.keys())
    elif getattr(args, 'india', False):
        region_keys = ['andaman'] + list(list_indian_regions().keys())
    elif getattr(args, 'southeast_asia', False):
        region_keys = list(list_southeast_asian_regions().keys())
    elif getattr(args, 'global_hotspots', False):
        region_keys = list(list_global_hotspots().keys())
    elif args.region:
        region_keys = [args.region]
    else:
        region_keys = ['andaman']

    multi = len(region_keys) > 1
    all_results = []

    for i, region_key in enumerate(region_keys, 1):
        logger.info(f"\n[{i}/{len(region_keys)}] Running region: {region_key}")
        try:
            import time as _time
            t0 = _time.time()

            if multi:
                cfg = Config.for_region(region_key)
                cfg.output_dir = Path(output_dir) / region_key
            else:
                cfg = Config.for_region(region_key)
                cfg.output_dir = Path(output_dir)

            ews = CoralBleachingEWS(
                config=cfg,
                gee_project_id=gee_project,
            )
            results = ews.run_full_workflow(
                start_date=start_date,
                end_date=end_date,
                skip_ocean_color=getattr(args, 'skip_ocean_color', False),
                skip_atmospheric=getattr(args, 'skip_atmospheric', False),
            )

            # Collect for cross-region comparison
            if multi and getattr(args, 'compare', False):
                from .cross_region import extract_region_result
                rr = extract_region_result(ews, region_key, _time.time() - t0)
                all_results.append(rr)

            logger.info(f"  ✓ {region_key} complete")

        except Exception as e:
            import traceback
            logger.error(f"  ✗ {region_key} FAILED: {e}")
            logger.error(traceback.format_exc())

    # Cross-region comparison
    if multi and getattr(args, 'compare', False) and len(all_results) > 1:
        from .cross_region import generate_all_comparison_plots
        comp_dir = Path(output_dir) / '_comparison'
        generate_all_comparison_plots(all_results, comp_dir)
        logger.info(f"Cross-region comparison saved to {comp_dir}")

    return 0


def generate_alert(days: int, gee_project: Optional[str]) -> int:
    """
    Generate current bleaching alert.
    
    Returns
    -------
    int
        Exit code
    """
    logger = get_logger("coral_ews.cli")
    
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    
    logger.info(f"Generating alert using {days} days of data...")
    
    try:
        ews = CoralBleachingEWS(gee_project_id=gee_project)
        
        # Minimal workflow for alert
        ews.acquire_sst_data(
            start_date.strftime("%Y-%m-%d"),
            end_date.strftime("%Y-%m-%d"),
            source='gee'
        )
        ews.calculate_dhw()
        alert = ews.generate_weekly_alert()
        
        # Print alert
        print("\n" + "=" * 60)
        print("CORAL BLEACHING ALERT")
        print("=" * 60)
        print(f"Region: {alert['region']}")
        print(f"Date: {alert['date']}")
        print(f"DHW: {alert['dhw']:.2f} °C-weeks" if alert['dhw'] else "DHW: N/A")
        print(f"Status: {alert['status']}")
        print(f"Alert Level: {alert['alert_level']}")
        print(f"Recommendation: {alert['recommendation']}")
        print("=" * 60)
        
        return 0
        
    except Exception as e:
        logger.error(f"Failed to generate alert: {e}")
        return 1


def main():
    """Main entry point."""
    args = parse_args()
    
    # Setup logging
    log_level = 10 if args.debug else (20 if args.verbose else 30)
    setup_logger("coral_ews", level=log_level)
    
    # Route to appropriate command
    if args.command == 'run':
        return run_workflow(args)
    
    elif args.command == 'test-connections':
        success = test_connections(gee_project=args.gee_project)
        return 0 if success else 1
    
    elif args.command == 'validate':
        success = validate_config()
        return 0 if success else 1
    
    elif args.command == 'alert':
        return generate_alert(days=args.days, gee_project=args.gee_project)
    
    else:
        print("No command specified. Use --help for usage information.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
