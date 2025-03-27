version 1.0

workflow test_gsutil {
    input {
        String gs_loc
	}

	String out_file = "~{gs_loc}/test.file"

	command <<<
		touch test.file
		gsutil cp test.file ~{out_file}
	>>>

	output {
		File out_file
	}
}