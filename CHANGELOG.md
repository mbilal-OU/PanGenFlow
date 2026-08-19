# Changelog

## 0.2.0 - 2026-08-19

### Changed
- Reworked `batch_download.sh` into the documented taxon/taxid CLI with current NCBI Datasets options.
- Added first-class dehydrated/rehydrated download support for large packages.
- Made GCA/GCF **assembly-record reconciliation** version-aware and RefSeq-preferred without dropping GCA-only assemblies.
- Updated metadata parsing to the current NCBI genome assembly report structure.
- Changed CheckM2 staging from full file copies to traceable symlinks.
- Reframed FastANI as an optional close-genome relatedness check.
- Removed artificial ANI values for unreported FastANI comparisons.
- Added unit tests, stronger CI, MkDocs documentation, citation metadata, license and contribution guidance.
- Added a PanGenFlow-specific curation figure and clarified optional downstream use with PanPhyloFlow.
- Restructured the public README around curation decisions, recipes and outputs rather than mirroring PanPhyloFlow's presentation.
