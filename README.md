# 🧬 PanGenFlow

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20WSL2%20%7C%20HPC-blue)]()
[![NCBI Datasets](https://img.shields.io/badge/NCBI-Datasets%20CLI-green)]()

> **Bulk download, deduplicate, and quality-control complete bacterial genomes from NCBI.**  
> Works for any taxon — from a single species to an entire phylum — in one reproducible workflow.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Step-by-Step Guide](#step-by-step-guide)
  - [Step 1 — Download Genomes](#step-1--download-genomes)
  - [Step 2 — Deduplicate](#step-2--deduplicate-gcagcf-pairs)
  - [Step 3 — Extract Metadata](#step-3--extract-metadata)
  - [Step 4 — ANI Validation](#step-4--ani-species-validation)
  - [Step 5 — Genome QC](#step-5--genome-quality-control)
- [All Download Options](#all-download-options)
- [Real Examples](#real-examples)
- [Output File Structure](#output-file-structure)
- [Taxid Reference](#taxid-reference)
- [Troubleshooting](#troubleshooting)
- [Citation](#citation)

---

## Overview

```
NCBI Genome Database
        │
        ▼
① batch_download.sh          Download any taxon in bulk
        │
        ▼
② deduplicate_genomes.py     Remove GCA/GCF duplicate pairs
        │
        ▼
③ extract_metadata.py        Pull taxonomy + assembly stats
        │
        ▼
④ run_fastani.sh             ANI species validation + heatmap
        │
        ▼
⑤ run_checkm2.sh             Completeness + contamination QC
        │
        ▼
   genome_list_clean.txt      Analysis-ready genome list
```

---

## Installation

### 1. NCBI Datasets CLI

```bash
conda install -c conda-forge ncbi-datasets-cli -y
datasets --version
```

### 2. FastANI

```bash
conda install -c bioconda fastani -y
fastANI --version
```

### 3. CheckM2

```bash
# Create dedicated environment
conda create -n checkm2_env python=3.8 -y
conda activate checkm2_env
pip install checkm2

# Download database (~1.7 GB)
checkm2 database --download --path ~/checkm2_db/
checkm2 --version
```

### 4. Python dependencies

```bash
pip install pandas seaborn matplotlib scipy numpy
```

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/mbilal-OU/PanGenFlow.git
cd PanGenFlow

# Download all complete Deinococcota genomes
bash scripts/batch_download.sh "Deinococcota" genomes/

# Deduplicate GCA/GCF pairs
python3 scripts/deduplicate_genomes.py \
    genomes/ncbi_dataset/data/ \
    genome_list.txt

# Extract taxonomy and assembly stats
python3 scripts/extract_metadata.py \
    genomes/ncbi_dataset/data/assembly_data_report.jsonl \
    > metadata_table.tsv

# Run ANI species validation
bash scripts/run_fastani.sh genome_list.txt fastani_results/ 8

# Run genome quality control
bash scripts/run_checkm2.sh \
    genome_list.txt \
    checkm2_results/ \
    ~/checkm2_db/CheckM2_database/uniref100.KO.1.dmnd \
    8
```

---

## Step-by-Step Guide

### Step 1 — Download Genomes

Use `batch_download.sh` to download complete genomes for any taxon from NCBI RefSeq.

```bash
bash scripts/batch_download.sh <taxon_name> <output_directory>
```

**Examples:**

```bash
# Single genus
bash scripts/batch_download.sh "Deinococcus" deinococcus_genomes/

# Multiple genera — run in sequence
bash scripts/batch_download.sh "Thermus" thermus_genomes/
bash scripts/batch_download.sh "Meiothermus" meiothermus_genomes/

# Full phylum
bash scripts/batch_download.sh "Deinococcota" deinococcota_genomes/

# Using taxid (more reliable than name)
datasets download genome taxon 188787 \
    --assembly-level complete \
    --assembly-source RefSeq \
    --exclude-atypical \
    --include genome,gff3,gbff \
    --filename deinococcota.zip
```

**Check genome count before downloading:**

```bash
datasets summary genome taxon "Deinococcota" \
    --assembly-level complete \
    --assembly-source RefSeq | \
    python3 -c "import json,sys; print(json.load(sys.stdin)['total_count'])"
```

**What gets downloaded:**

```
output_directory/
├── README.md
├── md5sum.txt
└── ncbi_dataset/
    └── data/
        ├── assembly_data_report.jsonl    ← metadata for all genomes
        ├── dataset_catalog.json
        ├── GCF_000008125.1/
        │   ├── *_genomic.fna             ← genome sequence
        │   ├── *_genomic.gff             ← gene annotations
        │   └── *_genomic.gbff            ← GenBank flat file
        └── GCF_000091545.1/
            └── ...
```

---

### Step 2 — Deduplicate GCA/GCF Pairs

NCBI provides both GCA (GenBank) and GCF (RefSeq) accessions for the same genome,
doubling your file count. This script removes duplicates — keeping GCF where
available, GCA otherwise.

```bash
python3 scripts/deduplicate_genomes.py \
    <data_directory> \
    <output_genome_list.txt>
```

**Example:**

```bash
python3 scripts/deduplicate_genomes.py \
    deinococcota_genomes/ncbi_dataset/data/ \
    genome_list.txt
```

**Expected output:**

```
Data directory    : deinococcota_genomes/ncbi_dataset/data/
Total GCF folders : 116
Total GCA folders : 125
GCA-only added    : 9
Total final       : 125
Output written to : genome_list.txt
```

**What `genome_list.txt` looks like:**

```
deinococcota_genomes/ncbi_dataset/data/GCF_000008125.1/GCF_000008125.1_ASM812v1_genomic.fna
deinococcota_genomes/ncbi_dataset/data/GCF_000091545.1/GCF_000091545.1_ASM9154v1_genomic.fna
deinococcota_genomes/ncbi_dataset/data/GCF_000020685.1/GCF_000020685.1_ASM2068v1_genomic.fna
...
```

---

### Step 3 — Extract Metadata

Extract species name, genus, family, order, genome size, GC content, gene count,
and assembly statistics from the NCBI assembly report.

```bash
python3 scripts/extract_metadata.py \
    <assembly_data_report.jsonl> \
    > metadata_table.tsv
```

**Example:**

```bash
python3 scripts/extract_metadata.py \
    deinococcota_genomes/ncbi_dataset/data/assembly_data_report.jsonl \
    > metadata_table.tsv

# Preview the table
column -t metadata_table.tsv | head -5
```

**Output columns:**

| Column | Description |
|---|---|
| accession | GCF accession number |
| species | Full organism name |
| strain | Strain designation |
| genus | Genus name |
| family | Family name |
| order | Order name |
| phylum | Phylum name |
| genome_size_bp | Total genome size in base pairs |
| gc_percent | GC content percentage |
| contig_n50 | N50 contig length |
| gene_count | Total gene count |
| protein_count | Protein-coding gene count |
| assembly_level | Complete / Chromosome / Scaffold |
| release_date | Date deposited to NCBI |

---

### Step 4 — ANI Species Validation

Run FastANI all-vs-all comparison to validate species identity and detect
contaminated or misidentified genomes. Generates a publication-ready
hierarchically clustered heatmap.

```bash
bash scripts/run_fastani.sh <genome_list.txt> <output_dir> <threads>
```

**Example:**

```bash
bash scripts/run_fastani.sh genome_list.txt fastani_results/ 8
```

**What it does:**

1. Runs FastANI all-vs-all (116 × 116 = 13,456 comparisons)
2. Forces matrix symmetry (averages bidirectional values)
3. Hierarchically clusters genomes by ANI distance
4. Generates clustered heatmap PDF and PNG
5. Reports ANI summary statistics
6. Flags any genomes with suspiciously low ANI

**ANI thresholds:**

| ANI Range | Interpretation |
|---|---|
| > 96% | Same species |
| 80–96% | Same genus |
| 70–80% | Same family / order (expected at phylum level) |
| < 70% | Potential contamination — investigate |

**Output files:**

```
fastani_results/
├── fastani_results.txt          ← pairwise ANI table
└── fastani_results.txt.matrix   ← square matrix format

figures/
├── ANI_heatmap_clustered.pdf    ← publication-ready Figure 1
└── ANI_heatmap_clustered.png    ← PNG version
```

**Example terminal output:**

```
Genomes detected: 116
ANI Summary:
  Min   : 76.58%
  Max   : 99.99%
  Mean  : 85.59%
  Median: 83.33%

No outlier genomes detected.
Heatmap saved to figures/
```

---

### Step 5 — Genome Quality Control

Assess completeness and contamination for all genomes using CheckM2.
Automatically generates a clean genome list with only QC-passing genomes.

```bash
bash scripts/run_checkm2.sh \
    <genome_list.txt> \
    <output_dir> \
    <database_path> \
    <threads>
```

**Example:**

```bash
conda activate checkm2_env

bash scripts/run_checkm2.sh \
    genome_list.txt \
    checkm2_results/ \
    ~/checkm2_db/CheckM2_database/uniref100.KO.1.dmnd \
    8
```

**Default quality thresholds:**

| Metric | Threshold | Meaning |
|---|---|---|
| Completeness | ≥ 90% | Genome is sufficiently complete |
| Contamination | ≤ 5% | Genome is not contaminated |

> Both thresholds can be edited inside `run_checkm2.sh`

**Output files:**

```
checkm2_results/
├── quality_report.tsv               ← full QC metrics per genome
├── genome_list_qc_passed.txt        ← use this for downstream analysis
└── genome_list_qc_failed.txt        ← investigate or remove these
```

**Example terminal output:**

```
Total genomes assessed : 116
Passed QC              : 114
Failed QC              : 2

Failed genomes:
  GCF_000XXXXX.1: completeness=82.3%, contamination=1.2%
  GCF_000YYYYY.1: completeness=78.9%, contamination=0.8%

Quality Summary:
  Mean completeness  : 98.7%
  Mean contamination : 0.4%
```

---

## All Download Options

```bash
datasets download genome taxon "ORGANISM" \
  --assembly-level complete \        # complete chromosome scaffold contig
  --assembly-source RefSeq \         # RefSeq GenBank all
  --exclude-atypical \               # remove contaminated assemblies
  --annotated \                      # only annotated genomes
  --include genome,gff3,gbff \       # file types to download
  --limit 50 \                       # limit number (remove for all)
  --filename output.zip
```

### File type options

| Flag | Files included |
|---|---|
| `--include genome` | FASTA sequence only |
| `--include genome,gff3` | + GFF3 gene annotations |
| `--include genome,gff3,gbff` | + GenBank flat file |
| `--include genome,gff3,gbff,protein` | + protein FASTA |
| `--include genome,gff3,gbff,protein,seq-report` | + sequence report |

---

## Real Examples

### Download a single species

```bash
datasets download genome taxon "Deinococcus radiodurans" \
    --assembly-level complete \
    --assembly-source RefSeq \
    --exclude-atypical \
    --include genome,gff3,gbff \
    --filename d_radiodurans.zip

unzip d_radiodurans.zip -d d_radiodurans_genomes/
```

### Download a genus

```bash
datasets download genome taxon "Thermus" \
    --assembly-level complete \
    --assembly-source RefSeq \
    --exclude-atypical \
    --include genome,gff3,gbff \
    --filename thermus.zip

unzip thermus.zip -d thermus_genomes/
find thermus_genomes/ -name "*.fna" -path "*/GCF_*" > thermus_genome_list.txt
wc -l thermus_genome_list.txt
```

### Download a full phylum

```bash
datasets download genome taxon "Deinococcota" \
    --assembly-level complete \
    --assembly-source RefSeq \
    --exclude-atypical \
    --include genome,gff3,gbff,seq-report \
    --filename deinococcota.zip

unzip deinococcota.zip -d deinococcota_genomes/
```

### Download specific accessions from a list

```bash
# Create accession list
cat > my_accessions.txt << EOF
GCF_000008125.1
GCF_000091545.1
GCF_000020685.1
GCF_000186385.1
EOF

datasets download genome accession \
    --inputfile my_accessions.txt \
    --include genome,gff3,gbff \
    --filename selected_genomes.zip
```

### Large dataset — dehydrate first (faster)

```bash
# Download metadata only first (seconds)
datasets download genome taxon "Pseudomonadota" \
    --assembly-level complete \
    --assembly-source RefSeq \
    --dehydrated \
    --filename pseudomonadota_dehydrated.zip

unzip pseudomonadota_dehydrated.zip -d pseudomonadota_genomes/

# Then download actual sequences
datasets rehydrate \
    --directory pseudomonadota_genomes/ \
    --max-workers 8
```

---

## Output File Structure

After running all five steps your working directory looks like:

```
project/
├── genome_list.txt                       ← deduplicated FASTA paths
├── metadata_table.tsv                    ← taxonomy + assembly stats
│
├── deinococcota_genomes/                 ← raw NCBI download
│   ├── md5sum.txt
│   └── ncbi_dataset/
│       └── data/
│           ├── assembly_data_report.jsonl
│           ├── GCF_000008125.1/
│           │   ├── *_genomic.fna
│           │   ├── *_genomic.gff
│           │   └── *_genomic.gbff
│           └── ...
│
├── fastani_results/
│   ├── fastani_results.txt               ← pairwise ANI values
│   └── fastani_results.txt.matrix        ← square matrix
│
├── checkm2_results/
│   ├── quality_report.tsv                ← completeness + contamination
│   ├── genome_list_qc_passed.txt         ← clean genomes for analysis
│   └── genome_list_qc_failed.txt         ← genomes to investigate
│
└── figures/
    ├── ANI_heatmap_clustered.pdf          ← Figure 1 for publication
    └── ANI_heatmap_clustered.png
```

---

## Taxid Reference

Use taxid instead of organism name for more reliable downloads:

```bash
datasets download genome taxon 188787 --assembly-level complete
```

| Organism | Taxid |
|---|---|
| Deinococcota (phylum) | 188787 |
| Deinococcus (genus) | 1298 |
| Thermus (genus) | 270 |
| Meiothermus (genus) | 33958 |
| Actinomycetota (phylum) | 201174 |
| Pseudomonadota (phylum) | 1224 |
| Bacillota (phylum) | 1239 |
| Bacteroidota (phylum) | 976 |
| Cyanobacteria (phylum) | 1117 |
| Corynebacterium (genus) | 1716 |
| Streptomyces (genus) | 1883 |
| Bacillus (genus) | 1386 |
| Mycobacterium (genus) | 1763 |

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `datasets: command not found` | Not installed | `conda install -c conda-forge ncbi-datasets-cli` |
| Download interrupted | Network issue | Re-run same command — resumes automatically |
| 2× more files than expected | GCA + GCF duplicates | Run `deduplicate_genomes.py` |
| Missing GFF files | Not included in download | Re-download with `--include genome,gff3` |
| `No genomes found` | Taxon name misspelled | Use taxid instead of name |
| Very slow download | Large dataset | Use `--dehydrated` then `datasets rehydrate` |
| `checkm2: command not found` | Wrong conda env | `conda activate checkm2_env` |
| CheckM2 pandas error | Version conflict | `sed -i "s/.str.split(sep, 1,/.str.split(sep, n=1,/g" predictQuality.py` |

---

## Citation

If you use PanGenFlow in your research please cite the following tools:

**NCBI Datasets:**
> Sayers EW, et al. Database resources of the National Center for Biotechnology Information in 2023. *Nucleic Acids Research.* 2023;51(D1):D29–D38. doi:10.1093/nar/gkac1052

**FastANI:**
> Jain C, Rodriguez-R LM, Phillippy AM, Konstantinidis KT, Aluru S. High throughput ANI analysis of 90K prokaryotic genomes reveals clear species boundaries. *Nature Communications.* 2018;9(1):5114. doi:10.1038/s41467-018-07641-9

**CheckM2:**
> Chklovski A, Parks DH, Woodcroft BJ, Tyson GW. CheckM2: a rapid, scalable and accurate tool for assessing microbial genome quality using machine learning. *Nature Methods.* 2023;20:1203–1212. doi:10.1038/s41592-023-01940-w

---

## License

MIT License — free to use, modify, and distribute with attribution.

---

*PanGenFlow — making large-scale genome acquisition reproducible and easy.*
