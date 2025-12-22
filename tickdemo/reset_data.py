#!/usr/bin/env python3
"""
Find files and directories whose absolute path matches a prefix followed by a date in yyyy.mm.dd format,
and either delete them or move them to a destination directory.

Usage:
    python find_dated_files.py <action> <path_prefix> <start_date> [<end_date>]

Arguments:
    action:       "list" to print paths, "delete" to remove files/directories, or a destination path (relative to path_prefix directory) to move them
    path_prefix:  Path prefix pattern to match (e.g., /data/logs_)
    start_date:   Start date in yyyy.mm.dd format
    end_date:     Optional end date in yyyy.mm.dd format

Examples:
    python find_dated_files.py list /data/logs_ 2025.12.22
    python find_dated_files.py delete /data/logs_ 2025.12.22
    python find_dated_files.py archive /data/logs_ 2025.12.20 2025.12.25
    python find_dated_files.py ../backup /data/logs_ 2025.12.22
"""

import sys
import os
import glob
import shutil
from datetime import datetime, timedelta

def parse_date(date_str):
    """Parse a date string in yyyy.mm.dd format."""
    try:
        return datetime.strptime(date_str, "%Y.%m.%d")
    except ValueError:
        print(f"Error: Invalid date format '{date_str}'. Expected yyyy.mm.dd", file=sys.stderr)
        sys.exit(1)

def date_to_string(date):
    """Convert datetime to yyyy.mm.dd format."""
    return date.strftime("%Y.%m.%d")

def find_paths_with_date(path_prefix, date_str):
    """Find all files and directories matching path_prefix + date_str pattern."""
    pattern = f"{path_prefix}{date_str}*"
    return glob.glob(pattern)

def process_path(path, action, dest_dir):
    """Process a file or directory based on the action: list, delete or move."""
    is_dir = os.path.isdir(path)
    path_type = "directory" if is_dir else "file"

    if action == "list":
        # Print path with trailing / for directories
        print(f"{path}/" if is_dir else path)
    elif action == "delete":
        try:
            if is_dir:
                shutil.rmtree(path)
            else:
                os.remove(path)
            print(f"Deleted {path_type}: {path}")
        except OSError as e:
            print(f"Error deleting {path_type} {path}: {e}", file=sys.stderr)
    else:
        # Move file or directory to destination directory
        try:
            os.makedirs(dest_dir, exist_ok=True)
            name = os.path.basename(path)
            dest_path = os.path.join(dest_dir, name)
            shutil.move(path, dest_path)
            print(f"Moved {path_type}: {path} -> {dest_path}")
        except (OSError, shutil.Error) as e:
            print(f"Error moving {path_type} {path}: {e}", file=sys.stderr)

def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)

    action = sys.argv[1]
    path_prefix = sys.argv[2]
    start_date_str = sys.argv[3]

    start_date = parse_date(start_date_str)

    # Determine destination directory for move operation
    dest_dir = None
    if action != "delete" and action != "list":
        # Extract base directory from path_prefix
        base_dir = os.path.dirname(path_prefix)
        if not base_dir:
            base_dir = "."
        # Construct destination path relative to base_dir
        dest_dir = os.path.join(base_dir, action)

    # If end_date provided, iterate over range; otherwise just use start_date
    if len(sys.argv) >= 5:
        end_date = parse_date(sys.argv[4])

        if end_date < start_date:
            print("Error: end_date must be >= start_date", file=sys.stderr)
            sys.exit(1)

        # Iterate over date range
        current_date = start_date
        while current_date <= end_date:
            date_str = date_to_string(current_date)
            paths = find_paths_with_date(path_prefix, date_str)
            for p in sorted(paths):
                process_path(p, action, dest_dir)
            current_date += timedelta(days=1)
    else:
        # Single date
        paths = find_paths_with_date(path_prefix, start_date_str)
        for p in sorted(paths):
            process_path(p, action, dest_dir)

if __name__ == "__main__":
    main()
