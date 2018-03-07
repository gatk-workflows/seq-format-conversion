## Copyright Broad Institute, 2017
## 
## This WDL converts paired FASTQ to uBAM and adds read group information 
##
## Requirements/expectations :
## - Pair-end sequencing data in FASTQ format (one file per orientation)
## - One or more read groups, one per pair of FASTQ files  
## - A readgroup.list file with the following format :  
##   ``readgroup   fastq_pair1   fastq_pair2   sample_name   library_name   platform_unit   run_date   platform_name   sequecing_center``
##
## Outputs :
## - Set of unmapped BAMs, one per read group
## - File of a list of the generated unmapped BAMs
##
## Cromwell version support 
## - Successfully tested on v30.2
## - Does not work on versions < v23 due to output syntax
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation. 
## For program versions, see docker containers. 
##
## LICENSING : 
## This script is released under the WDL source code license (BSD-3) (see LICENSE in 
## https://github.com/broadinstitute/wdl). Note however that the programs it calls may 
## be subject to different licenses. Users are responsible for checking that they are
## authorized to run all programs before running this script. Please see the docker 
## page at https://hub.docker.com/r/broadinstitute/genomes-in-the-cloud/ for detailed
## licensing information pertaining to the included programs.

# WORKFLOW DEFINITION
workflow ConvertPairedFastQsToUnmappedBamWf {
  File readgroup_list  
  Array[Array[String]] readgroup_array = read_tsv(readgroup_list) 
  String ubam_list_name = basename(readgroup_list,".list")
  
  String docker
  Int? preemptible_attempts

  # Convert multiple pairs of input fastqs in parallel
  scatter (i in range(length(readgroup_array))) {

    # Convert pair of FASTQs to uBAM
    call PairedFastQsToUnmappedBAM {
      input:
        fastq_1 = readgroup_array[i][1],
        fastq_2 = readgroup_array[i][2],
        readgroup_name = readgroup_array[i][0],
        sample_name = readgroup_array[i][3],
        library_name = readgroup_array[i][4],
        platform_unit = readgroup_array[i][5],
        run_date = readgroup_array[i][6],
        platform_name = readgroup_array[i][7],
        sequencing_center = readgroup_array[i][8],
        docker = docker,
        preemptible_attempts = preemptible_attempts
    }
   }

    #Create a list with the generated ubams
    call CreateUbamList {
      input:
        unmapped_bams = PairedFastQsToUnmappedBAM.output_bam,
        ubam_list_name = ubam_list_name,
	    docker = docker,
        preemptible_attempts = preemptible_attempts
    }

  # Outputs that will be retained when execution is complete
  output {
    Array[File] output_bams = PairedFastQsToUnmappedBAM.output_bam
    File unmapped_bam_list = CreateUbamList.unmapped_bam_list
  }
}

# TASK DEFINITIONS

# Convert a pair of FASTQs to uBAM
task PairedFastQsToUnmappedBAM {
  File fastq_1
  File fastq_2
  String readgroup_name
  String sample_name
  String library_name
  String platform_unit
  String run_date
  String platform_name
  String sequencing_center
  
  Int? disk_space_gb
  Int? machine_mem_gb
  Int? preemptible_attempts
  String docker
  String gatk_path

  command {
    ${gatk_path} --java-options "-Xmx3000m" \
      FastqToSam \
      --FASTQ ${fastq_1} \
      --FASTQ2 ${fastq_2} \
      --OUTPUT ${readgroup_name}.unmapped.bam \
      --READ_GROUP_NAME ${readgroup_name} \
      --SAMPLE_NAME ${sample_name} \
      --LIBRARY_NAME ${library_name} \
      --PLATFORM_UNIT ${platform_unit} \
      --RUN_DATE ${run_date} \
      --PLATFORM ${platform_name} \
      --SEQUENCING_CENTER ${sequencing_center} 
  }
  runtime {
    docker: docker
    memory: select_first([machine_mem_gb,10]) + " GB"
    cpu: "1"
    disks: "local-disk " + select_first([disk_space_gb, 100]) + " HDD"
    preemptible: select_first([preemptible_attempts, 3])
  }
  output {
    File output_bam = "${readgroup_name}.unmapped.bam"
  }
}

task CreateUbamList {
  Array[String] unmapped_bams
  String ubam_list_name
  
  Int? machine_mem_gb
  Int? disk_space_gb
  Int? preemptible_attempts
  String docker
  
  command {
    echo "${sep=',' unmapped_bams}" | sed s/"\""//g | sed s/"\["//g | sed s/\]//g | sed s/" "//g | sed 's/,/\n/g' >> ${ubam_list_name}.unmapped_bams.list

  }
  output {
	File unmapped_bam_list = "${ubam_list_name}.unmapped_bams.list"
  }
  runtime {
    docker: docker
    memory: select_first([machine_mem_gb,5]) + " GB"
    cpu: "1"
    disks: "local-disk " + select_first([disk_space_gb, 10]) + " HDD"
    preemptible: select_first([preemptible_attempts, 3])
  }
}

