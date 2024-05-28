nextflow.enable.dsl=2

// Define the input parameters
params.input_file = 'path/to/tumor.bam'
params.number = 4

// Define the channels for input files
Channel.fromPath(params.input_file).set { input_file }



// Process for running GISTIC
process WordCounter {
    input:
    path file_to_count_lines
    output:
    int num_lines
    script:
    """
    wc -l $file_to_count_lines
    """
}

// Process to take head of lines
process HeaderFile {
    input:
    path file_x

    output:
    path "output_file_name"

    script:
    """
    head -n $params.number $file_x > output_file_name
    """
}




// Define the workflow
workflow {
    main:
    HeaderFile(input_file)
    WordCounter(HeaderFile.out)
}
