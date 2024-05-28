nextflow.enable.dsl=2

// Define the input parameters
params.tumor_bam = 'path/to/tumor.bam'
params.tumor_bai = 'path/to/tumor.bai'
params.normal_bam = 'path/to/normal.bam'
params.normal_bai = 'path/to/normal.bai'
params.reference = 'path/to/reference.tar.gz'

// Define the channels for input files
Channel.fromPath(params.tumor_bam).set { tumor_bam_file }
Channel.fromPath(params.tumor_bai).set { tumor_bai_file }
Channel.fromPath(params.normal_bam).set { normal_bam_file }
Channel.fromPath(params.normal_bai).set { normal_bai_file }
Channel.fromPath(params.reference).set { reference_tarball }

// Process for running Mutect2 using NVIDIA Parabricks
process Mutect2 {
    tag "$sample_id"
    input:
    path tumor_bam_file
    path tumor_bai_file
    path normal_bam_file
    path normal_bai_file
    path reference_tarball
    output:
    path 'mutect2_output.vcf'
    script:
    """
        nvcr.io/nvidia/clara/clara-parabricks:4.2.1-1 \\
        pbrun mutectcaller \\
        --ref /workdir/${reference_tarball} \\
        --in-tumor-bam /workdir/${tumor_bam_file} \\
        --in-normal-bam /workdir/${normal_bam_file} \\
        --tumor-name tumor \\
        --normal-name normal \\
        --out-vcf /workdir/mutect2_output.vcf
    """
}

// Process for running GISTIC
process GISTIC {
    input:
    path 'mutect2_output.vcf'
    output:
    path 'gistic_output'
    script:
    """
    gistic2 -b . -seg mutect2_output.vcf -refgene $reference_tarball -o gistic_output
    """
}

// Process for running Sequenza
process Sequenza {
    input:
    path tumor_bam_file
    path tumor_bai_file
    path normal_bam_file
    path normal_bai_file
    path reference_tarball
    output:
    path 'sequenza_output'
    script:
    """
    sequenza-utils bam2seqz -n $normal_bam_file -t $tumor_bam_file -r $reference_tarball -o sequenza_output.seqz
    sequenza-utils seqz_binning --seqz sequenza_output.seqz -w 50 -o sequenza_output.binned.seqz
    sequenza-utils seqz2seg -s sequenza_output.binned.seqz -o sequenza_output.seg
    """
}

// Define the workflow
workflow {
    main:
    Mutect2(tumor_bam_file, tumor_bai_file, normal_bam_file, normal_bai_file, reference_tarball)
    GISTIC(Mutect2.out)
    Sequenza(tumor_bam_file, tumor_bai_file, normal_bam_file, normal_bai_file, reference_tarball)
}
