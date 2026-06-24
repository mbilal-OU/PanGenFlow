#!/usr/bin/env python3
"""
deduplicate_genomes.py
Remove GCA/GCF duplicates from NCBI genome downloads.
Keeps GCF (RefSeq) where available, GCA otherwise.

Usage:
    python3 deduplicate_genomes.py <data_directory> [output_list.txt]

Example:
    python3 deduplicate_genomes.py \
        deinococcota_genomes/ncbi_dataset/data/ \
        genome_list_clean.txt
"""

import os
import sys
import glob


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    data_dir   = sys.argv[1].rstrip("/")
    output_file = sys.argv[2] if len(sys.argv) > 2 else "genome_list_clean.txt"

    # Find all accession folders
    all_folders = [
        os.path.basename(d)
        for d in glob.glob(f"{data_dir}/GC[AF]_*/")
    ]

    gcf_accessions = {a for a in all_folders if a.startswith("GCF_")}
    gca_accessions = {a for a in all_folders if a.startswith("GCA_")}

    # Extract numeric IDs
    gcf_nums = {a.replace("GCF_", "") for a in gcf_accessions}
    gca_nums = {a.replace("GCA_", "") for a in gca_accessions}

    # GCA with no GCF counterpart
    gca_only_nums = gca_nums - gcf_nums

    # Build final accession list
    final_accessions = list(gcf_accessions)
    for num in gca_only_nums:
        final_accessions.append(f"GCA_{num}")

    final_accessions.sort()

    # Find FASTA paths
    found = []
    missing = []

    for acc in final_accessions:
        fna_files = glob.glob(f"{data_dir}/{acc}/*.fna")
        if fna_files:
            found.append(fna_files[0])
        else:
            missing.append(acc)

    # Write output
    with open(output_file, "w") as out:
        for path in found:
            out.write(path + "\n")

    # Report
    print(f"Data directory    : {data_dir}")
    print(f"Total GCF folders : {len(gcf_accessions)}")
    print(f"Total GCA folders : {len(gca_accessions)}")
    print(f"GCA-only added    : {len(gca_only_nums)}")
    print(f"Total final       : {len(found)}")
    print(f"Missing FASTA     : {len(missing)}")
    print(f"Output written to : {output_file}")

    if missing:
        print("\nAccessions with no FASTA found:")
        for m in missing:
            print(f"  {m}")


if __name__ == "__main__":
    main()
