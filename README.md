# seq-format-conversion
Workflows for converting between sequence data formats

### cram-to-bam :
This script should convert a CRAM to SAM to BAM and output a BAM, BAM Index, 
and validation report to a Google bucket. If you'd like to do this on multiple CRAMS, 
create a sample set in the Data tab.  
The reason this approach was chosen instead of converting CRAM to BAM directly 
using Samtools is because Samtools 1.3 produces incorrect bins due to an old version of htslib 
included in the package. Samtools versions 1.4 & 1.5 have an NM issue that 
causes them to not validate  with Picard. 

#### Requirements/expectations
- Cram file 

#### Outputs 
- Bam file and index
- Validation report

### paired-fastq-to-unmapped-bam :
This WDL converts paired FASTQ to uBAM and adds read group information 

#### Requirements/expectations
- Pair-end sequencing data in FASTQ format (one file per orientation)
- One or more read groups, one per pair of FASTQ files 
- This WDL requires an input TSV file such that each row corresponds to a readgroup and the columns contain metadata for each readgroup. The WDL depends on the input TSV to follow a specific format for the columns. Please use the template provided below as the header for the input TSV file: 
```
readgroup   fastq_pair1_file_path   fastq_pair2_file_path   sample_name   library_name   platform_unit   run_date   platform_name   sequecing_center
```  

#### Outputs 
- Set of unmapped BAMs, one per read group
- File containing a list of the generated unmapped BAMs 

### bam-to-unmapped-bams :
This WDL converts BAM  to unmapped BAMs

#### Requirements/expectations 
- BAM file

#### Outputs 
- Sorted Unmapped BAMs

### Software version requirements :
Cromwell version support 
- Successfully tested on v32
- Does not work on versions < v23 due to output syntax
Runtime parameters are optimized for Broad's Google Cloud Platform implementation. 
For program versions, see docker containers.
