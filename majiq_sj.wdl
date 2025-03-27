version 1.0

workflow majiq_sj {
    input {
        Array[File] bam
		Array[File]? bai
        File gff3
        String proj_dir
        String reference_genome
    }

    scatter(i in range(length(bam))) {
        call splice_junctions {
            input:
            bam = bam[i],
            proj_dir = proj_dir,
            reference_genome = reference_genome,
            gff3 = gff3,
        }
    }

    output {
        Array[File] sj = splice_junctions.sj
    }
}

task splice_junctions {
    input {
        File bam
        File bai = "~{bam}.bai"
        File gff3
        String proj_dir
        String reference_genome
    }

    String sample = basename(bam, ".bam")
    String sj_file = "~{sample}.sj"
	String sj_out = "~{proj_dir}/sj/~{sj_file}"

    command <<<
        mkdir -p ~{proj_dir}/sj
        echo -e "[info]\nbamdirs=$(dirname ~{bam})\ngenome=~{reference_genome}\n[experiments]\nsample=~{sample}" > majiq.conf
        majiq build -j 1 -c majiq.conf -o . ~{gff3} --junc-files-only
        mv ~{sj_file} ~{sj_out}
    >>>

	## Determine disk request based on input
	Int input_size_gb = ceil(size(bam, "GB")) +
		ceil(size(bai, "GB")) +
		ceil(size(gff3, "GB"))
	Int disk_size_gb = input_size_gb + 5  # Add a buffer

    runtime {
        docker: "baerlachlan/majiq:v2.5.8"
        cpu: 1
        memory: "4 GB"
        disks: "local-disk " + disk_size_gb + " HDD"
    }

    output {
        File sj = sj_out
    }
}