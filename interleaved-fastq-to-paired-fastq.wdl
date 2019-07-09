#This WDL takes in a single interleaved(R1+R2) FASTQ file and separates it into separate R1 and R2 FASTQ (i.e. paired FASTQ) files. Paired FASTQ files are the input format for the tool that generates unmapped BAMs (the format used in most GATK processing and analysis tools).
#
#Requirements/expectations 
#- Interleaved Fastq file
#
#Outputs 
#- Separate R1 and R2 FASTQ files (i.e. paired FASTQ)
#
##################

workflow UninterleaveFastqs {

  call uninterleave_fqs
}
  task uninterleave_fqs {

    File inputFastq

    Int? cpu
    Int? memory
    Int? disk

    String r1_name = basename(inputFastq, ".fastq") + "_reads_1.fastq"
    String r2_name = basename(inputFastq, ".fastq") + "_reads_2.fastq"

  command {
    cat ${inputFastq} | paste - - - - - - - -  | \
    tee >(cut -f 1-4 | tr "\t" "\n" > ${r1_name}) | \
    cut -f 5-8 | tr "\t" "\n" > ${r2_name}
  }

  runtime {
    docker: "ubuntu:latest"
    memory: select_first([memory, 8]) + " GB"
    cpu: select_first([cpu, 2])
    zones: "us-central1-c us-central1-b"
    disks: "local-disk " + select_first([disk, 3]) + " HDD"
  }

  output {
    File r1_fastq = "${r1_name}"
    File r2_fastq = "${r2_name}"
  }
}
