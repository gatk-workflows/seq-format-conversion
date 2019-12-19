version 1.0
# This WDL takes in a single interleaved(R1+R2) FASTQ file and separates it into 
# separate R1 and R2 FASTQ (i.e. paired FASTQ) files. Paired FASTQ files are the 
# input format for the tool that generates unmapped BAMs (the format used in most 
# GATK processing and analysis tools).
#
# Requirements/expectations 
# - Interleaved Fastq file
#
# Outputs 
# - Separate R1 and R2 FASTQ files (i.e. paired FASTQ)
#
##################

workflow UninterleaveFastqs {

  call uninterleave_fqs

}

task uninterleave_fqs {
  input {
    File input_fastq

    Int machine_mem_gb = 8
    Int addtional_disk_size = 10
  }
    Int disk_size = ceil(size(input_fastq, "GB") * 2) + addtional_disk_size
    String r1_name = basename(input_fastq, ".fastq") + "_reads_1.fastq"
    String r2_name = basename(input_fastq, ".fastq") + "_reads_2.fastq"
  
  command {
    cat ~{input_fastq} | paste - - - - - - - -  | \
    tee >(cut -f 1-4 | tr "\t" "\n" > ~{r1_name}) | \
    cut -f 5-8 | tr "\t" "\n" > ~{r2_name}
  }

  runtime {
    docker: "ubuntu:latest"
    memory: machine_mem_gb + " GB"
    disks: "local-disk " + disk_size + " HDD"
  }

  output {
    File r1_fastq = "~{r1_name}"
    File r2_fastq = "~{r2_name}"
  }
}
