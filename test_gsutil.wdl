version 1.0

workflow test_gsutil {
	input {
		String dest_gs_uri = "NULL"
	}

	call cp_test {
		input:
		dest_gs_uri = dest_gs_uri
	}

	output {
		File test_file = cp_test.test_file
	}
}

task cp_test {
    input {
        String dest_gs_uri
	}

	String test_dir = "test_dir"
	String test_file = "test.file"

	command <<<
		mkdir ~{test_dir}
		touch ~{test_dir}/~{test_file}
		if [[ ~{dest_gs_uri} != "NULL" ]]; then
			gsutil cp -r ~{test_dir} ~{dest_gs_uri}/~{test_dir}
			gsutil cp ~{test_dir}/~{test_file} ~{dest_gs_uri}/~{test_file}
		fi
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