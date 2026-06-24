#!/usr/bin/env python3
"""
split_gff_by_genus.py
Split GFF files into genus-specific folders based on taxonomy table.
Also generates genus_list.txt for Roary array job.

Usage:
    python3 split_gff_by_genus.py \
        --gff-dir prokka_out/ \
        --metadata metadata_table.tsv \
        --output-dir gff_by_genus/ \
        --genome-list genome_list.txt

Or with NCBI GFF files directly:
    python3 split_gff_by_genus.py \
        --gff-dir ncbi_dataset/data/ \
        --metadata metadata_table.tsv \
        --output-dir gff_by_genus/ \
        --ncbi-mode
"""

import os
import sys
import glob
import shutil
import argparse
import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(description="Split GFF files by genus")
    parser.add_argument("--gff-dir",     required=True, help="Directory containing GFF files")
    parser.add_argument("--metadata",    required=True, help="Metadata TSV with accession and genus columns")
    parser.add_argument("--output-dir",  required=True, help="Output directory for genus folders")
    parser.add_argument("--ncbi-mode",   action="store_true", help="GFFs are nested in NCBI accession folders")
    parser.add_argument("--genus-list",  default="genus_list.txt", help="Output genus list file for Slurm array")
    return parser.parse_args()


def main():
    args = parse_args()

    # Load metadata
    meta = pd.read_csv(args.metadata, sep="\t")
    print(f"Metadata loaded: {len(meta)} genomes")
    print(f"Genera found: {meta['genus'].nunique()}")
    print(f"Genera: {sorted(meta['genus'].unique())}")

    # Build accession -> genus map
    acc_to_genus = dict(zip(meta["accession"], meta["genus"]))

    # Find all GFF files
    if args.ncbi_mode:
        gff_files = glob.glob(f"{args.gff_dir}/GCF_*/*.gff")
        gff_files += glob.glob(f"{args.gff_dir}/GCF_*/*.gff3")
    else:
        gff_files = glob.glob(f"{args.gff_dir}/**/*.gff", recursive=True)
        gff_files += glob.glob(f"{args.gff_dir}/**/*.gff3", recursive=True)

    print(f"\nGFF files found: {len(gff_files)}")

    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)

    # Counters
    copied    = 0
    skipped   = 0
    not_found = []

    for gff_path in gff_files:
        # Extract accession from path
        parts = gff_path.split("/")
        accession = None

        for part in parts:
            if part.startswith("GCF_") or part.startswith("GCA_"):
                accession = part
                break

        if accession is None:
            # Try filename
            basename = os.path.basename(gff_path)
            for acc in acc_to_genus.keys():
                if acc in basename:
                    accession = acc
                    break

        if accession is None:
            skipped += 1
            continue

        # Look up genus
        genus = acc_to_genus.get(accession)
        if not genus or pd.isna(genus):
            not_found.append(accession)
            skipped += 1
            continue

        # Create genus folder
        genus_dir = os.path.join(args.output_dir, genus)
        os.makedirs(genus_dir, exist_ok=True)

        # Copy GFF
        dest = os.path.join(genus_dir, f"{accession}.gff")
        shutil.copy2(gff_path, dest)
        copied += 1

    # Write genus list
    genera = sorted([
        d for d in os.listdir(args.output_dir)
        if os.path.isdir(os.path.join(args.output_dir, d))
    ])

    with open(args.genus_list, "w") as f:
        for genus in genera:
            f.write(genus + "\n")

    # Report
    print(f"\nResults:")
    print(f"  GFF files copied    : {copied}")
    print(f"  Skipped             : {skipped}")
    print(f"  Genera created      : {len(genera)}")
    print(f"\nGenus folders and GFF counts:")

    for genus in genera:
        genus_dir = os.path.join(args.output_dir, genus)
        count = len(glob.glob(f"{genus_dir}/*.gff"))
        status = "OK" if count >= 2 else "WARNING: only 1 genome — skip Roary"
        print(f"  {genus:<30} {count:3d} GFFs  [{status}]")

    # Update array count in genus_list
    valid_genera = [
        g for g in genera
        if len(glob.glob(f"{args.output_dir}/{g}/*.gff")) >= 2
    ]
    print(f"\nValid genera for Roary (>=2 genomes): {len(valid_genera)}")
    print(f"Genus list saved to: {args.genus_list}")
    print(f"\nUpdate your Slurm script:")
    print(f"  #SBATCH --array=1-{len(valid_genera)}")

    if not_found:
        print(f"\nAccessions with no genus in metadata ({len(not_found)}):")
        for a in not_found[:10]:
            print(f"  {a}")


if __name__ == "__main__":
    main()
