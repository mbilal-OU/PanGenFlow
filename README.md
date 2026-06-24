# NCBI Genome Downloader — Complete CLI Guide

> A comprehensive, reproducible workflow for downloading complete bacterial genomes from NCBI using the Datasets CLI. Designed for pangenome studies, comparative genomics, and large-scale bioinformatics pipelines.

---

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [All Download Options](#all-download-options)
- [Filtering Strategies](#filtering-strategies)
- [Real Examples](#real-examples)
- [File Structure](#file-structure)
- [Deduplication](#deduplication)
- [Automation Scripts](#automation-scripts)
- [Troubleshooting](#troubleshooting)
- [Citation](#citation)

---

## Overview

The NCBI Datasets CLI (`datasets`) is the modern, official way to download genome data from NCBI. It replaces legacy approaches like `wget` from FTP and provides structured, metadata-rich downloads with built-in filtering.

```
NCBI Genome Database
        │
        ▼
datasets download genome
        │
        ├── taxon (by organism name or taxid)
        ├── accession (by specific accession)
        └── gene (by gene name)
        │
        ▼
ZIP archive
        │
        ├── ncbi_dataset/data/{accession}/
        │   ├── *_genomic.fna     ← genome sequence
        │   ├── *_genomic.gff     ← gene annotations
        │   ├── *_genomic.gbff    ← GenBank flat file
        │   └── protein.faa       ← protein sequences
        │
        ├── assembly_data_report.jsonl  ← metadata
        ├── dataset_catalog.json        ← file index
        └── README.md
```

---

## Installation

### Option 1 — Conda (recommended)

```bash
conda install -c conda-forge ncbi-datasets-cli -y
datasets --version
```

### Option 2 — Direct download (Linux)

```bash
curl -o datasets \
  "https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/datasets"
chmod +x datasets
sudo mv datasets /usr/local/bin/
datasets --version
```

### Option 3 — Direct download (macOS)

```bash
curl -o datasets \
  "https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/mac/datasets"
chmod +x datasets
sudo mv datasets /usr/local/bin/
```

### Verify installation

```bash
datasets --version
# Expected: datasets version 16.x.x
```

---

## Quick Start

### Download all complete genomes for a taxon

```bash
# By taxonomic name
datasets download genome taxon "Deinococcota" \
  --assembly-level complete \
  --filename deinococcota.zip

# Unzip
unzip deinococcota.zip -d deinococcota_genomes/

# Check what you got
ls deinococcota_genomes/ncbi_dataset/data/ | wc -l
```

### Download by specific accession

```bash
datasets download genome accession GCF_000008125.1 \
  --filename thermus_hb27.zip
```

---

## All Download Options

### Assembly level filters

```bash
# Complete genomes only (best for pangenomics)
--assembly-level complete

# Chromosome-level and above
--assembly-level chromosome

# Scaffold-level and above
--assembly-level scaffold

# All assembly levels
--assembly-level contig,scaffold,chromosome,complete
```

### Include specific file types

```bash
# Genome sequence only (default)
--include genome

# Genome + GFF annotation
--include genome,gff3

# Genome + GenBank flat file
--include genome,gbff

# Genome + protein sequences
--include genome,protein

# Everything
--include genome,rna,protein,cds,gff3,gbff,seq-report

# For pangenome studies (recommended)
--include genome,gff3,gbff,protein,seq-report
```

### Source database filters

```bash
# RefSeq only (higher quality, recommended)
--assembly-source RefSeq

# GenBank only
--assembly-source GenBank

# Both (default)
--assembly-source all
```

### Exclusion filters

```bash
# Exclude atypical assemblies (contaminated, misassembled)
--exclude-atypical

# Exclude metagenome-assembled genomes
# (use --assembly-source RefSeq instead — MAGs rarely in RefSeq)

# Exclude multi-isolate projects (large redundant datasets)
# Filter manually after download using metadata
```

### Annotation filters

```bash
# Only annotated genomes
--annotated

# Reference genomes only
--reference
```

### Limit results

```bash
# Download only first 50 genomes
--limit 50

# No limit (default — downloads all)
--limit none
```

---

## Filtering Strategies

### For pangenome studies (recommended settings)

```bash
datasets download genome taxon "YOUR_ORGANISM" \
  --assembly-level complete \
  --assembly-source RefSeq \
  --exclude-atypical \
  --annotated \
  --include genome,gff3,gbff,seq-report \
  --filename organism_complete.zip
```

### For large phyla (thousands of genomes)

```bash
# First check how many genomes exist
datasets summary genome taxon "Pseudomonadota" \
  --assembly-level complete \
  --assembly-source RefSeq | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d['total_count'])"

# Then download with a limit to test
datasets download genome taxon "Pseudomonadota" \
  --assembly-level complete \
  --assembly-source RefSeq \
  --limit 100 \
  --filename pseudomonadota_test.zip
```

### For specific species list

```bash
# Create accession list file
cat > accession_list.txt << EOF
GCF_000008125.1
GCF_000091545.1
GCF_000020685.1
GCF_000195335.1
EOF

# Download all at once
datasets download genome accession \
  --inputfile accession_list.txt \
  --include genome,gff3,gbff \
  --filename my_genomes.zip
```

---

## Real Examples

### Example 1 — Deinococcota phylum (this study)

```bash
# Download all complete Deinococcota genomes
datasets download genome taxon "Deinococcota" \
  --assembly-level complete \
  --exclude-atypical \
  --include genome,gff3,gbff,seq-report \
  --filename deinococcota_complete.zip

# Unzip
unzip deinococcota_complete.zip -d deinococcota_genomes/

# Count total genomes
ls deinococcota_genomes/ncbi_dataset/data/ | \
  grep -v "assembly_data_report\|dataset_catalog\|README" | wc -l
# Result: 258 folders (GCA + GCF pairs)

# Keep only GCF (RefSeq) accessions
find deinococcota_genomes/ncbi_dataset/data/ \
  -name "*.fna" -path "*/GCF_*" \
  > genome_list.txt

wc -l genome_list.txt
# Result: 116 complete GCF genomes
```

### Example 2 — Single genus download

```bash
# Download all complete Deinococcus genomes
datasets download genome taxon "Deinococcus" \
  --assembly-level complete \
  --assembly-source RefSeq \
  --exclude-atypical \
  --include genome,gff3,gbff \
  --filename deinococcus_complete.zip

unzip deinococcus_complete.zip -d deinococcus_genomes/

find deinococcus_genomes/ncbi_dataset/data/ \
  -name "*.fna" > deinococcus_genome_list.txt

wc -l deinococcus_genome_list.txt
# Result: ~60 genomes
```

### Example 3 — Check available genomes before downloading

```bash
# Summary — no download, just count
datasets summary genome taxon "Deinococcota" \
  --assembly-level complete \
  --assembly-source RefSeq \
  --report genome | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'Total genomes: {data[\"total_count\"]}')
for r in data.get('reports', [])[:5]:
    print(r['accession'], r['organism']['organism_name'])
"
```

### Example 4 — Download with full metadata

```bash
datasets download genome taxon "Thermus" \
  --assembly-level complete \
  --assembly-source RefSeq \
  --include genome,gff3,gbff,protein,seq-report \
  --filename thermus_full.zip

# Extract taxonomy metadata
python3 << 'EOF'
import json

with open("thermus_genomes/ncbi_dataset/data/assembly_data_report.jsonl") as f:
    for line in f:
        d = json.loads(line)
        if d.get("accession","").startswith("GCF"):
            name = d.get("organism",{}).get("organismName","")
            size = d.get("assemblyStats",{}).get("totalSequenceLength",0)
            print(f"{d['accession']}\t{name}\t{size:,} bp")
EOF
```

### Example 5 — Multiple taxa at once

```bash
# Download multiple genera simultaneously
for taxon in "Deinococcus" "Thermus" "Meiothermus"; do
    echo "Downloading $taxon..."
    datasets download genome taxon "$taxon" \
      --assembly-level complete \
      --assembly-source RefSeq \
      --exclude-atypical \
      --include genome,gff3 \
      --filename "${taxon,,}_complete.zip"
    
    mkdir -p "${taxon,,}_genomes"
    unzip "${taxon,,}_complete.zip" -d "${taxon,,}_genomes/"
    echo "Done: $taxon"
done
```

---

## File Structure

After downloading and unzipping, your directory looks like:

```
deinococcota_genomes/
├── README.md
├── md5sum.txt
└── ncbi_dataset/
    └── data/
        ├── assembly_data_report.jsonl    ← metadata for all genomes
        ├── dataset_catalog.json          ← index of all files
        ├── GCF_000008125.1/              ← one folder per accession
        │   ├── GCF_000008125.1_ASM812v1_genomic.fna     ← genome FASTA
        │   ├── GCF_000008125.1_ASM812v1_genomic.gff     ← GFF3 annotation
        │   ├── GCF_000008125.1_ASM812v1_genomic.gbff    ← GenBank flat file
        │   └── protein.faa                               ← protein sequences
        ├── GCF_000091545.1/
        │   └── ...
        └── GCF_000020685.1/
            └── ...
```

---

## Deduplication

NCBI provides both GCA (GenBank) and GCF (RefSeq) accessions for the same genome, doubling your file count. Always deduplicate before analysis.

### Keep GCF only (recommended)

```bash
# GCF = RefSeq = higher quality, curated
find ncbi_dataset/data/ -name "*.fna" -path "*/GCF_*" > genome_list.txt
wc -l genome_list.txt
```

### Keep GCA only (when GCF not available)

```bash
find ncbi_dataset/data/ -name "*.fna" -path "*/GCA_*" > gca_list.txt
```

### Smart deduplication — GCF where available, GCA otherwise

```bash
python3 << 'EOF'
import os, glob

data_dir = "ncbi_dataset/data/"
gcf = set()
gca = set()

for path in glob.glob(f"{data_dir}GCF_*/"):
    gcf.add(os.path.basename(path.rstrip("/")))

for path in glob.glob(f"{data_dir}GCA_*/"):
    gca.add(os.path.basename(path.rstrip("/")))

# Find GCA-only (no GCF counterpart)
gca_nums = {a.replace("GCA_","") for a in gca}
gcf_nums = {a.replace("GCF_","") for a in gcf}
gca_only_nums = gca_nums - gcf_nums

final = list(gcf)
for num in gca_only_nums:
    final.append(f"GCA_{num}")

with open("genome_list_dedup.txt", "w") as out:
    for acc in sorted(final):
        fna = glob.glob(f"{data_dir}{acc}/*.fna")
        if fna:
            out.write(fna[0] + "\n")

print(f"GCF genomes: {len(gcf)}")
print(f"GCA-only genomes added: {len(gca_only_nums)}")
print(f"Total final genomes: {len(final)}")
EOF
```

---

## Automation Scripts

### Batch download script

```bash
#!/bin/bash
# batch_download.sh — download genomes for multiple taxa

TAXA=(
    "Deinococcus"
    "Thermus"
    "Meiothermus"
    "Marinithermus"
    "Oceanithermus"
    "Vulcanithermus"
    "Rhabdothermus"
    "Truepera"
)

OUTDIR="genomes_by_genus"
mkdir -p "$OUTDIR"

for taxon in "${TAXA[@]}"; do
    safe_name=$(echo "$taxon" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
    echo "=== Downloading $taxon ==="
    
    datasets download genome taxon "$taxon" \
      --assembly-level complete \
      --assembly-source RefSeq \
      --exclude-atypical \
      --include genome,gff3,gbff \
      --filename "${OUTDIR}/${safe_name}.zip"
    
    unzip -q "${OUTDIR}/${safe_name}.zip" \
      -d "${OUTDIR}/${safe_name}/"
    
    count=$(find "${OUTDIR}/${safe_name}/" -name "*.fna" | wc -l)
    echo "Downloaded $count genomes for $taxon"
done

echo "All downloads complete"
```

### Metadata extraction script

```bash
#!/usr/bin/env python3
# extract_metadata.py — extract taxonomy and assembly stats

import json
import csv
import sys

jsonl_file = sys.argv[1] if len(sys.argv) > 1 else \
             "ncbi_dataset/data/assembly_data_report.jsonl"

fields = ["accession","species","genus","family","order",
          "genome_size","gc_content","contig_count","n50"]

writer = csv.DictWriter(sys.stdout, fieldnames=fields, delimiter="\t")
writer.writeheader()

with open(jsonl_file) as f:
    for line in f:
        try:
            d = json.loads(line)
            if not d.get("accession","").startswith("GCF"):
                continue
            
            org  = d.get("organism", {})
            tax  = d.get("taxonomy", {})
            stat = d.get("assemblyStats", {})
            
            genus = family = order = ""
            for node in tax.get("classification", []):
                r = node.get("rank","")
                n = node.get("name","")
                if r == "GENUS":  genus  = n
                if r == "FAMILY": family = n
                if r == "ORDER":  order  = n
            
            writer.writerow({
                "accession":    d.get("accession",""),
                "species":      org.get("organismName",""),
                "genus":        genus,
                "family":       family,
                "order":        order,
                "genome_size":  stat.get("totalSequenceLength",""),
                "gc_content":   stat.get("gcPercent",""),
                "contig_count": stat.get("numberOfContigs",""),
                "n50":          stat.get("contigN50",""),
            })
        except Exception as e:
            continue
```

Run it:

```bash
python3 extract_metadata.py \
  deinococcota_genomes/ncbi_dataset/data/assembly_data_report.jsonl \
  > metadata_table.tsv

column -t metadata_table.tsv | head -20
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `datasets: command not found` | Not installed or not in PATH | `conda install -c conda-forge ncbi-datasets-cli` |
| ZIP file incomplete | Download interrupted | Re-run download command — resumes automatically |
| 241 files instead of ~129 | GCA + GCF duplicates | Filter to GCF only — see Deduplication section |
| Missing GFF files | Not included in download | Re-download with `--include genome,gff3` |
| Empty folders | NCBI rate limiting | Add `--dehydrated` flag then `datasets rehydrate` |
| `No genomes found` | Taxon name spelling | Check spelling or use NCBI taxid instead |

### Using taxid instead of name (more reliable)

```bash
# Find taxid on NCBI Taxonomy browser
# Deinococcota taxid = 188787

datasets download genome taxon 188787 \
  --assembly-level complete \
  --filename deinococcota.zip
```

### Dehydrated download (large datasets)

```bash
# Download metadata only first (fast)
datasets download genome taxon "Deinococcota" \
  --assembly-level complete \
  --dehydrated \
  --filename deinococcota_dehydrated.zip

unzip deinococcota_dehydrated.zip -d deinococcota_genomes/

# Then rehydrate (download actual sequences)
datasets rehydrate \
  --directory deinococcota_genomes/ \
  --max-workers 8
```

---

## Citation

If you use NCBI Datasets in your research, cite:

> NCBI Resource Coordinators. Database resources of the National Center for Biotechnology Information. Nucleic Acids Research. 2018;46(D1):D8–D13. doi:10.1093/nar/gkx1095

> Sayers EW, et al. Database resources of the National Center for Biotechnology Information in 2023. Nucleic Acids Research. 2023;51(D1):D29–D38.

---

## License

MIT License — free to use, modify, and distribute with attribution.

---

*Developed as part of the Deinococcota Pangenome Study — BioMac Lab 2026*
