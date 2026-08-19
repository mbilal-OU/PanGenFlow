# PanGenFlow

[![Test scripts](https://github.com/mbilal-OU/PanGenFlow/actions/workflows/test.yml/badge.svg)](https://github.com/mbilal-OU/PanGenFlow/actions/workflows/test.yml)
[![Docs](https://github.com/mbilal-OU/PanGenFlow/actions/workflows/docs.yml/badge.svg)](https://github.com/mbilal-OU/PanGenFlow/actions/workflows/docs.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20WSL2%20%7C%20HPC-blue)]()

**PanGenFlow** is a reproducible toolkit for acquiring and curating microbial genome collections from NCBI before downstream comparative-genomics analysis.

> **Goal:** turn an NCBI taxon query into a traceable, non-redundant, quality-filtered genome list without hiding what was downloaded, retained, filtered, or left unresolved.

<p align="center">
  <img src="figures/pangenflow_workflow.svg" alt="PanGenFlow genome acquisition and curation workflow" width="100%">
</p>

Documentation: **https://mbilal-ou.github.io/PanGenFlow/**

---

## Background

Large comparative-genomics projects often fail upstream of the actual analysis: assembly versions are mixed, paired GenBank/RefSeq records are counted twice, metadata are parsed inconsistently, low-quality genomes enter the cohort, or broad taxonomic datasets are forced through similarity tools outside their useful range.

PanGenFlow focuses only on this preparation layer. It does **not** perform pangenome reconstruction. Its job is to make the genome cohort defensible before tools such as Roary, Panaroo, phylogenomic pipelines, or custom analyses are run.

## What PanGenFlow helps you answer

1. Which assemblies did NCBI return for a taxon under explicit assembly filters?
2. Which GCA/GCF records represent the same assembly family, and which record was retained?
3. What assembly and annotation metadata accompany each genome?
4. Which genomes pass a defined completeness/contamination threshold?
5. For sufficiently related genome sets, which pairs receive FastANI estimates and which comparisons are unresolved?
6. What exact genome list should be passed downstream?

## Workflow

| Stage | Tool / script | Purpose | Main output |
|---|---|---|---|
| Genome acquisition | NCBI Datasets + `batch_download.sh` | filtered download by taxon or taxid | NCBI data package + downloaded genome list |
| GCA/GCF harmonization | `deduplicate_genomes.py` | prefer current RefSeq when a paired assembly exists | `genome_list_clean.txt` |
| Metadata extraction | `extract_metadata.py` | flatten current NCBI assembly-report fields | `metadata_table.tsv` |
| Genome quality | CheckM2 + `run_checkm2.sh` | completeness/contamination filtering | passed/failed genome lists + QC table |
| Optional relatedness | FastANI + `run_fastani.sh` | close-genome relatedness check | pair table, ANI matrix, summary + heatmap |

**FastANI is optional.** It is most useful for sufficiently related genomes; PanGenFlow preserves unreported comparisons as missing rather than replacing them with an arbitrary ANI value.

## Quick start

### 1. Install the core environment

```bash
git clone https://github.com/mbilal-OU/PanGenFlow.git
cd PanGenFlow

conda env create -f environment.yml
conda activate pangenflow
```

Install CheckM2 in its own environment:

```bash
mamba create -n checkm2 -c bioconda -c conda-forge checkm2
conda activate checkm2
checkm2 database --download --path ~/checkm2_db/
checkm2 testrun
```

### 2. Download genomes

Small or moderate package:

```bash
bash scripts/batch_download.sh "Deinococcus" genomes/
```

Large package:

```bash
bash scripts/batch_download.sh "Deinococcota" genomes/ \
  --dehydrated \
  --workers 12
```

Useful options:

```text
--source RefSeq|GenBank|all
--level complete|chromosome|scaffold|contig (comma-separated allowed)
--include genome,gff3,gbff,seq-report
--dehydrated
--workers 1-30
```

### 3. Harmonize paired GCA/GCF assemblies

```bash
python scripts/deduplicate_genomes.py \
  genomes/ncbi_dataset/data \
  genome_list_clean.txt
```

PanGenFlow groups paired assembly families by their shared numeric assembly identifier, prefers GCF when available, and keeps the highest version within the selected source.

### 4. Extract assembly metadata

```bash
python scripts/extract_metadata.py \
  genomes/ncbi_dataset/data/assembly_data_report.jsonl \
  metadata_table.tsv
```

The metadata parser follows the NCBI genome assembly data-report structure and includes fields such as accession, paired accession, source database, organism name, taxid, assembly level, assembly statistics, annotation gene counts, and NCBI-supplied CheckM/ANI status when present.

Full taxonomic lineage (for example family/order/phylum) should be obtained from an NCBI taxonomy report rather than inferred from the assembly report.

### 5. Run CheckM2 quality filtering

```bash
conda activate checkm2

bash scripts/run_checkm2.sh \
  genome_list_clean.txt \
  checkm2_results/ \
  ~/checkm2_db/CheckM2_database/uniref100.KO.1.dmnd \
  8 \
  90 \
  5
```

The last two values are configurable minimum completeness and maximum contamination. For a stricter pangenome cohort, for example:

```bash
bash scripts/run_checkm2.sh genome_list_clean.txt checkm2_results/ "$CHECKM2DB" 8 95 5
```

The script stages genomes with **symlinks rather than copies**, keeps a path mapping, and writes:

```text
checkm2_results/
├── quality_report.tsv
├── quality_report_with_paths.tsv
├── input_mapping.tsv
├── genome_list_qc_passed.txt
└── genome_list_qc_failed.txt
```

### 6. Optional: FastANI relatedness check

For a species-level or otherwise sufficiently related genome set:

```bash
conda activate pangenflow
bash scripts/run_fastani.sh \
  checkm2_results/genome_list_qc_passed.txt \
  fastani_results/ \
  8
```

Outputs:

```text
fastani_results/
├── fastani_results.tsv
├── fastani_pairs.tsv
├── ani_matrix.tsv
├── ani_summary.tsv
└── figures/
    ├── ANI_heatmap.png
    └── ANI_heatmap.pdf
```

Missing FastANI cells remain `NA`. They are **not** interpreted as 70%, 75%, or any other fabricated value.

## Large NCBI downloads

For large genome packages, use `--dehydrated`. PanGenFlow downloads the metadata package, unpacks it, and calls `datasets rehydrate` with the requested number of workers.

```bash
bash scripts/batch_download.sh "Pseudomonadota" pseudomonadota/ \
  --dehydrated \
  --workers 16
```

## Repository structure

```text
PanGenFlow/
├── README.md
├── environment.yml
├── CITATION.cff
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── scripts/
│   ├── batch_download.sh
│   ├── deduplicate_genomes.py
│   ├── extract_metadata.py
│   ├── run_checkm2.sh
│   └── run_fastani.sh
├── tests/
│   └── test_scripts.py
├── examples/
├── figures/
│   └── pangenflow_workflow.svg
├── docs/
└── .github/workflows/
```

## Scientific guardrails

- **GCA/GCF pairing is not biological dereplication.** It removes paired NCBI representations of the same assembly family; it does not remove biologically redundant strains.
- **CheckM2 evaluates completeness and contamination**, but thresholds should be chosen for the biological question and genome type.
- **FastANI is not a universal phylum-wide distance method.** Unreported divergent pairs are retained as missing.
- **ANI is not a contamination detector by itself.** Unexpected relatedness patterns should trigger investigation, not automatic biological conclusions.
- **Metadata lineage is not guessed.** PanGenFlow extracts fields present in the assembly report and leaves full lineage retrieval to NCBI taxonomy data.

## Optional downstream companion: PanPhyloFlow

PanGenFlow ends with analysis-ready genomes. If your next step is microbial pangenome reconstruction and core-genome phylogenomics, see **[PanPhyloFlow](https://github.com/mbilal-OU/PanPhyloFlow)**.

```text
PanGenFlow
  genome acquisition + curation + QC
                 │
                 ▼
       analysis-ready genomes
                 │
                 └──► PanPhyloFlow (optional)
                       pangenome + phylogeny + report
```

PanPhyloFlow is optional; PanGenFlow can feed any downstream genome-analysis workflow.

## Validation

GitHub Actions currently checks:

- Python unit tests for GCA/GCF selection and current NCBI metadata parsing;
- Python syntax;
- shell syntax for all workflow scripts.

External tools such as NCBI Datasets, CheckM2 and FastANI are not executed against large live datasets in CI. Real-data runs remain the appropriate validation for data-dependent behavior.

## Citation

Citation metadata for PanGenFlow are provided in [`CITATION.cff`](CITATION.cff). Please also cite the external software used in your analysis, especially NCBI Datasets, CheckM2 and FastANI.

## License

MIT. See [`LICENSE`](LICENSE).
