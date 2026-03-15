fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto_dir = "../proto";
    let protos = &[
        format!("{proto_dir}/common.proto"),
        format!("{proto_dir}/mapping/request.proto"),
        format!("{proto_dir}/mapping/response.proto"),
        format!("{proto_dir}/localization/request.proto"),
        format!("{proto_dir}/localization/response.proto"),
        format!("{proto_dir}/session/request.proto"),
        format!("{proto_dir}/session/response.proto"),
        format!("{proto_dir}/service.proto"),
    ];

    tonic_build::configure()
        .build_server(true)
        .build_client(true)
        .compile_protos(protos, &[proto_dir])?;

    for proto in protos {
        println!("cargo:rerun-if-changed={proto}");
    }

    Ok(())
}
