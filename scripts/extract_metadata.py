#!/usr/bin/env python3
"""
extract_metadata.py
Extract taxonomy, assembly stats, and genome metadata from NCBI dataset report.

Usage:
    python3 extract_metadata.py <assembly_data_report.jsonl> [output.tsv]

Example:
    python3 extract_metadata.py \
        deinococcota_genomes/ncbi_dataset/data/assembly_data_report.jsonl \
        > metadata_table.tsv
"""

import json
import csv
import sys
import os

def extract_taxonomy(tax_data):
    genus = family = order = classt = phylum = ""
    for node in tax_data.get("classification", []):
        rank = node.get("rank", "")
        name = node.get("name", "")
        if rank == "GENUS":   genus  = name
        if rank == "FAMILY":  family = name
        if rank == "ORDER":   order  = name
        if rank == "CLASS":   classt = name
        if rank == "PHYLUM":  phylum = name
    return genus, family, order, classt, phylum


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    jsonl_file = sys.argv[1]

    if not os.path.exists(jsonl_file):
        print(f"Error: file not found: {jsonl_file}", file=sys.stderr)
        sys.exit(1)

    fields = [
        "accession", "species", "strain",
        "genus", "family", "order", "class", "phylum",
        "genome_size_bp", "gc_percent",
        "contig_count", "contig_n50",
        "scaffold_count", "scaffold_n50",
        "gene_count", "protein_count",
        "assembly_level", "refseq_category",
        "release_date", "taxid"
    ]

    writer = csv.DictWriter(
        sys.stdout, fieldnames=fields,
        delimiter="\t", extrasaction="ignore"
    )
    writer.writeheader()

    gcf_count = 0
    gca_count = 0
    skipped   = 0

    with open(jsonl_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                acc = d.get("accession", "")

                if acc.startswith("GCF"):
                    gcf_count += 1
                elif acc.startswith("GCA"):
                    gca_count += 1
                    continue  # skip GCA by default
                else:
                    skipped += 1
                    continue

                org  = d.get("organism", {})
                tax  = d.get("taxonomy", {})
                stat = d.get("assemblyStats", {})
                ann  = d.get("annotationInfo", {})

                genus, family, order, classt, phylum = extract_taxonomy(tax)

                # Strain name
                infraspecific = org.get("infraspecificNames", {})
                strain = infraspecific.get("strain", "")

                writer.writerow({
                    "accession":       acc,
                    "species":         org.get("organismName", ""),
                    "strain":          strain,
                    "genus":           genus,
                    "family":          family,
                    "order":           order,
                    "class":           classt,
                    "phylum":          phylum,
                    "genome_size_bp":  stat.get("totalSequenceLength", ""),
                    "gc_percent":      stat.get("gcPercent", ""),
                    "contig_count":    stat.get("numberOfContigs", ""),
                    "contig_n50":      stat.get("contigN50", ""),
                    "scaffold_count":  stat.get("numberOfScaffolds", ""),
                    "scaffold_n50":    stat.get("scaffoldN50", ""),
                    "gene_count":      ann.get("geneCount", {}).get("total", ""),
                    "protein_count":   ann.get("geneCount", {}).get("proteinCoding", ""),
                    "assembly_level":  d.get("assemblyInfo", {}).get("assemblyLevel", ""),
                    "refseq_category": d.get("assemblyInfo", {}).get("refseqCategory", ""),
                    "release_date":    d.get("assemblyInfo", {}).get("releaseDate", ""),
                    "taxid":           org.get("taxId", ""),
                })

            except json.JSONDecodeError:
                skipped += 1
                continue
            except Exception as e:
                skipped += 1
                continue

    print(f"\nSummary (written to stderr):", file=sys.stderr)
    print(f"  GCF records extracted: {gcf_count}", file=sys.stderr)
    print(f"  GCA records skipped:   {gca_count}", file=sys.stderr)
    print(f"  Other skipped:         {skipped}", file=sys.stderr)


if __name__ == "__main__":
    main()
