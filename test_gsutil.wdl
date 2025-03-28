version 1.0

workflow test_gsutil {
	input {
		String gcs_path
	}

	call cp_test {
		input:
		gcs_path = gcs_path
	}

	output {
		File test_file = cp_test.test_file
	}
}

task cp_test {
    input {
        String gcs_path
	}

	String test_dir = "test_dir"
	String test_file = "test.file"

	command <<<
		mkdir ~{test_dir}
		touch ~{test_dir}/~{test_file}
		gsutil cp -r ~{test_dir} ~{gcs_path}/~{test_dir}
		gsutil cp ~{test_dir}/~{test_file} ~{gcs_path}/~{test_file}
	>>>

    runtime {
        docker: "baerlachlan/google-cloud-sdk:latest"
        cpu: 1
        memory: "2 GB"
        disks: "local-disk 2 HDD"
    }

	output {
		File test_file = "~{test_dir}/~{test_file}"
	}
}