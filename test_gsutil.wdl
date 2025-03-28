version 1.0

workflow test_gsutil {
	input {
		String gcs_path
	}

	call cp_testfile {
		input:
		gcs_path = gcs_path
	}

	output {
		File out_file = cp_testfile.out_file
	}
}

task cp_testfile {
    input {
        String gcs_path
	}

	String out_file = "~{gcs_path}/test.file"

	command <<<
		touch test.file
		gsutil cp test.file ~{out_file}
	>>>

    runtime {
        docker: "baerlachlan/google-cloud-sdk:latest"
        cpu: 1
        memory: "2 GB"
        disks: "local-disk 2 HDD"
    }

	output {
		File out_file = out_file
	}
}