fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto_dir = "../proto";
    let protos = &[
        format!("{proto_dir}/sensor.proto"),
        format!("{proto_dir}/sync.proto"),
    ];

    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .compile_protos(protos, &[proto_dir])?;

    // proto 파일 변경 시 재빌드
    for proto in protos {
        println!("cargo:rerun-if-changed={proto}");
    }

    Ok(())
}
