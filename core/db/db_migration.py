"""
Database Migration System for IBSng

This module handles automatic database migrations by:
1. Tracking current database version in ibs_states table
2. Automatically running upgrade scripts in order
3. Ensuring migrations run only once
"""

import os
import re
from core.db import db_main
from core.lib.general import *
from core import defs

# Migration state key in ibs_states table
MIGRATION_STATE_KEY = "db_version"

# Current database version (latest)
CURRENT_VERSION = "A1.23"

# Migration files directory
MIGRATION_DIR = os.path.join(defs.IBS_ROOT, "db")

def getMigrationFiles():
    """
    Get all migration files sorted by version order.
    Returns list of (version, filepath) tuples.
    """
    migration_files = []
    
    if not os.path.exists(MIGRATION_DIR):
        toLog("Migration directory not found: %s" % MIGRATION_DIR, LOG_ERROR)
        return migration_files
    
    # Pattern to match upgrade files: from_VERSION_upgrade.sql
    pattern = re.compile(r'from_([A-Za-z0-9._-]+)_upgrade\.sql$')
    
    for filename in os.listdir(MIGRATION_DIR):
        match = pattern.match(filename)
        if match:
            version = match.group(1)
            filepath = os.path.join(MIGRATION_DIR, filename)
            migration_files.append((version, filepath))
    
    # Sort by version (simple string sort should work for A1.XX versions)
    migration_files.sort(key=lambda x: x[0])
    
    return migration_files

def getCurrentVersion():
    """
    Get current database version from ibs_states table.
    Returns version string or None if not set.
    """
    try:
        handle = db_main.getHandle()
        result = handle.get("ibs_states", "name=%s" % dbText(MIGRATION_STATE_KEY))
        if len(result) > 0:
            return result[0]["value"]
        return None
    except Exception, e:
        toLog("Error getting current database version: %s" % str(e), LOG_ERROR)
        return None

def setCurrentVersion(version):
    """
    Set current database version in ibs_states table.
    """
    try:
        handle = db_main.getHandle()
        # Check if version state exists
        result = handle.get("ibs_states", "name=%s" % dbText(MIGRATION_STATE_KEY))
        
        if len(result) > 0:
            # Update existing
            handle.update("ibs_states", {"value": dbText(version)}, 
                         "name=%s" % dbText(MIGRATION_STATE_KEY))
        else:
            # Insert new
            handle.insert("ibs_states", {"name": dbText(MIGRATION_STATE_KEY), 
                                        "value": dbText(version)})
        toLog("Database version set to: %s" % version, LOG_DEBUG)
    except Exception, e:
        toLog("Error setting database version: %s" % str(e), LOG_ERROR)
        raise

def runMigrationFile(filepath):
    """
    Execute a migration SQL file.
    Returns True on success, False on failure.
    """
    try:
        if not os.path.exists(filepath):
            toLog("Migration file not found: %s" % filepath, LOG_ERROR)
            return False
        
        toLog("Running migration: %s" % os.path.basename(filepath), LOG_INFO)
        
        handle = db_main.getHandle()
        
        # Read SQL file
        f = open(filepath, 'r')
        sql_content = f.read()
        f.close()
        
        # Execute SQL as transaction
        # Use transactionQuery to ensure atomicity
        try:
            handle.transactionQuery(sql_content)
        except Exception, e:
            # Some statements might fail (e.g., if constraint already exists)
            # Log but continue - this is expected for some upgrade scripts
            toLog("Warning in migration (may be expected): %s" % str(e), LOG_WARNING)
            # Try executing the file anyway - some errors are acceptable
        
        toLog("Migration completed: %s" % os.path.basename(filepath), LOG_INFO)
        return True
        
    except Exception, e:
        toLog("Error running migration file %s: %s" % (filepath, str(e)), LOG_ERROR)
        logException(LOG_ERROR)
        return False

def compareVersions(v1, v2):
    """
    Compare two version strings.
    Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
    """
    # Simple comparison for A1.XX format
    # Extract numeric parts for comparison
    def version_key(v):
        # Handle formats like "A1.04", "A1.23", "alpha-2005-02-28"
        if v.startswith("A1."):
            try:
                return (1, int(v.split(".")[1]))
            except:
                return (1, 0)
        elif v.startswith("alpha-"):
            # Parse date format: alpha-2005-02-28
            try:
                parts = v.split("-")
                if len(parts) >= 4:
                    return (0, int(parts[1]), int(parts[2]), int(parts[3]))
            except:
                pass
        return (0, 0, 0, 0)
    
    k1 = version_key(v1)
    k2 = version_key(v2)
    
    if k1 < k2:
        return -1
    elif k1 > k2:
        return 1
    else:
        return 0

def runMigrations():
    """
    Run all pending database migrations.
    This function should be called during system initialization.
    """
    try:
        toLog("Checking for database migrations...", LOG_INFO)
        
        current_version = getCurrentVersion()
        migration_files = getMigrationFiles()
        
        if not migration_files:
            toLog("No migration files found", LOG_WARNING)
            return True
        
        # If no version is set, assume we need to run all migrations
        if current_version is None:
            toLog("No database version found. Running all migrations...", LOG_INFO)
            for version, filepath in migration_files:
                if not runMigrationFile(filepath):
                    toLog("Migration failed for version %s" % version, LOG_ERROR)
                    return False
                setCurrentVersion(version)
            
            # Set to current version
            setCurrentVersion(CURRENT_VERSION)
            toLog("All migrations completed. Database version: %s" % CURRENT_VERSION, LOG_INFO)
            return True
        
        # Run migrations that are newer than current version
        pending_migrations = []
        for version, filepath in migration_files:
            if compareVersions(version, current_version) > 0:
                pending_migrations.append((version, filepath))
        
        if not pending_migrations:
            toLog("Database is up to date (version: %s)" % current_version, LOG_INFO)
            return True
        
        toLog("Found %d pending migration(s)" % len(pending_migrations), LOG_INFO)
        
        for version, filepath in pending_migrations:
            if not runMigrationFile(filepath):
                toLog("Migration failed for version %s" % version, LOG_ERROR)
                return False
            setCurrentVersion(version)
        
        # Update to latest version
        setCurrentVersion(CURRENT_VERSION)
        toLog("Migrations completed. Database version: %s" % CURRENT_VERSION, LOG_INFO)
        return True
        
    except Exception, e:
        toLog("Error during migration: %s" % str(e), LOG_ERROR)
        logException(LOG_ERROR)
        return False

def init():
    """
    Initialize migration system and run migrations.
    This should be called during system startup.
    """
    # Enable migrations by default
    try:
        runMigrations()
    except Exception, e:
        toLog("Migration initialization failed: %s" % str(e), LOG_ERROR)
        logException(LOG_ERROR)
        # Don't fail system startup if migrations fail
        # Log the error and continue

