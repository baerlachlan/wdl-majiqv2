version 1.0

workflow majiq_v2 {
    input {
        File gencode_gtf
    }

    call gtf_to_gff3 {
        input:
        gencode_gtf = gencode_gtf
    }

    output {
        File gff3 = gtf_to_gff3.gff3
    }

    meta {
        author: "Lachlan Baer"
    }
}

task gtf_to_gff3 {
    input {
        File gencode_gtf
    }

    command {
        zcat ${gencode_gtf} | \
            sed 's/chrM/chrMT/;s/chr//' | \
            gffread -T -o annotation.gff3
    }

    runtime {
        docker: "baerlachlan/gffread:v0.12.7"
        memory: "2 GB"
        disks: "local-disk 4 HDD"
    }

    output {
        File gff3 = "annotation.gff3"
    }
}