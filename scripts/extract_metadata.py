#!/usr/bin/env python3
"""Extract stable assembly metadata from an NCBI Datasets genome report.

This parser follows the current assembly_data_report.jsonl structure and does
not invent lineage ranks that are not present in that report. Use NCBI taxonomy
reports/dataformat separately when full lineage (genus/family/order/phylum) is
required.

Usage:
    python3 extract_metadata.py assembly_data_report.jsonl [output.tsv]

Options:
    --source all|RefSeq|GenBank   Filter assembly source (default: all)
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

FIELDS = [
    "accession", "current_accession", "paired_accession", "source_database",
    "organism_name", "strain", "taxid", "assembly_name", "assembly_level",
    "assembly_status", "refseq_category", "bioproject_accession", "release_date",
    "genome_size_bp", "gc_percent", "contig_count", "contig_n50",
    "scaffold_count", "scaffold_n50", "gene_count", "protein_count",
    "ncbi_checkm_completeness", "ncbi_checkm_contamination",
    "ncbi_ani_check_status", "ncbi_ani_best_match_status",
]


def normalize_source(value: str) -> str:
    value = (value or "").upper()
    if "REFSEQ" in value:
        return "RefSeq"
    if "GENBANK" in value:
        return "GenBank"
    return value


def record_to_row(record: dict) -> dict:
    org = record.get("organism") or {}
    assm = record.get("assemblyInfo") or {}
    stats = record.get("assemblyStats") or {}
    ann = record.get("annotationInfo") or {}
    ann_stats = ann.get("stats") or {}
    gene_counts = ann_stats.get("geneCounts") or {}
    checkm = record.get("checkmInfo") or {}
    ani = record.get("averageNucleotideIdentity") or {}
    infraspecific = org.get("infraspecificNames") or {}

    paired = record.get("pairedAccession")
    if not paired:
        paired = (assm.get("pairedAssembly") or {}).get("accession", "")

    return {
        "accession": record.get("accession", ""),
        "current_accession": record.get("currentAccession", ""),
        "paired_accession": paired or "",
        "source_database": normalize_source(record.get("sourceDatabase", "")),
        "organism_name": org.get("organismName", ""),
        "strain": infraspecific.get("strain", ""),
        "taxid": org.get("taxId", ""),
        "assembly_name": assm.get("assemblyName", ""),
        "assembly_level": assm.get("assemblyLevel", ""),
        "assembly_status": assm.get("assemblyStatus", ""),
        "refseq_category": assm.get("refseqCategory", ""),
        "bioproject_accession": assm.get("bioprojectAccession", ""),
        "release_date": assm.get("releaseDate", ""),
        "genome_size_bp": stats.get("totalSequenceLength", ""),
        "gc_percent": stats.get("gcPercent", ""),
        "contig_count": stats.get("numberOfContigs", ""),
        "contig_n50": stats.get("contigN50", ""),
        "scaffold_count": stats.get("numberOfScaffolds", ""),
        "scaffold_n50": stats.get("scaffoldN50", ""),
        "gene_count": gene_counts.get("total", ""),
        "protein_count": gene_counts.get("proteinCoding", ""),
        "ncbi_checkm_completeness": checkm.get("completeness", ""),
        "ncbi_checkm_contamination": checkm.get("contamination", ""),
        "ncbi_ani_check_status": ani.get("taxonomyCheckStatus", ""),
        "ncbi_ani_best_match_status": ani.get("matchStatus", ""),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("jsonl_file", type=Path)
    parser.add_argument("output", nargs="?", type=Path)
    parser.add_argument("--source", choices=["all", "RefSeq", "GenBank"], default="all")
    args = parser.parse_args()

    if not args.jsonl_file.is_file():
        parser.error(f"file not found: {args.jsonl_file}")

    output_handle = args.output.open("w", encoding="utf-8", newline="") if args.output else sys.stdout
    written = 0
    skipped = 0

    try:
        writer = csv.DictWriter(output_handle, fieldnames=FIELDS, delimiter="\t")
        writer.writeheader()
        with args.jsonl_file.open(encoding="utf-8") as handle:
            for line_number, line in enumerate(handle, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError as exc:
                    print(f"WARNING: malformed JSON on line {line_number}: {exc}", file=sys.stderr)
                    skipped += 1
                    continue
                row = record_to_row(record)
                if args.source != "all" and row["source_database"] != args.source:
                    skipped += 1
                    continue
                if not row["accession"]:
                    skipped += 1
                    continue
                writer.writerow(row)
                written += 1
    finally:
        if args.output:
            output_handle.close()

    print(f"Metadata records written: {written}", file=sys.stderr)
    print(f"Records skipped:          {skipped}", file=sys.stderr)
    if args.output:
        print(f"Output:                   {args.output}", file=sys.stderr)
    return 0 if written else 1


if __name__ == "__main__":
    raise SystemExit(main())
